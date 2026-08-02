using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeStruct EmitBranchExpression(BranchExpression expression)
    {
        if (expression.IsParallel)
        {
            return EmitParallelBranchExpression(expression);
        }

        var source = EmitExpression(expression.Source);
        var localName = $"$branch_{_tempId.ToString(CultureInfo.InvariantCulture)}";
        _locals.Add(localName, source);
        var values = new RuntimeValue[expression.Arms.Count];
        var consumesSource = false;
        for (var index = 0; index < expression.Arms.Count; index++)
        {
            var arm = expression.Arms[index];
            var first = arm.Targets[0];
            if (TryResolveFunction(first.Path, out var function)
                || TryResolveInstanceMethod(source.Type, string.Join('.', first.Path), out function))
            {
                consumesSource |= function.InputOwnership == BoundFunctionInputOwnership.Move;
            }
            values[index] = EmitFlowExpressionValue(new FlowExpression(
                new NameExpression(localName, arm.Line, arm.Column),
                arm.Targets,
                arm.Line,
                arm.Column));
        }
        RemoveLocal(localName);
        if (consumesSource)
        {
            RemoveOwnedLiteralSources(expression.Source, source.Type);
        }

        var definition = _program.Types.Structs.SingleOrDefault(candidate =>
            candidate.IsProduct
            && candidate.Fields.Count == values.Length
            && candidate.Fields.Select(static field => field.Type).SequenceEqual(values.Select(static value => value.Type))
            && candidate.Fields.Select(static field => field.Name).SequenceEqual(
                expression.Arms.Select(static arm => arm.Label),
                StringComparer.Ordinal))
            ?? throw new SollangException("semantic branch product type is missing during LLVM emission");

        var aggregate = "poison";
        for (var index = 0; index < values.Length; index++)
        {
            var value = values[index];
            var materialized = MaterializeAggregateValue(value);
            var next = NextTemp("branch_product");
            EmitAssign(
                next,
                $"insertvalue {LlvmStructType(definition.Id)} {aggregate}, {materialized.TypeName} {materialized.ValueName}, {index.ToString(CultureInfo.InvariantCulture)}");
            aggregate = next;
        }
        return new RuntimeStruct(definition.Id, aggregate);
    }

    private RuntimeValue EmitTapExpression(TapExpression expression)
    {
        var source = EmitExpression(expression.Source);
        var localName = $"$tap_{_tempId.ToString(CultureInfo.InvariantCulture)}";
        _locals.Add(localName, source);
        _ = EmitFlowExpressionValue(new FlowExpression(
            new NameExpression(localName, expression.Line, expression.Column),
            expression.Targets,
            expression.Line,
            expression.Column));
        RemoveLocal(localName);
        return source;
    }

    private void EmitParallelBranchCallbacks()
    {
        if (_program.ParallelBranches.Count == 0)
        {
            return;
        }
        if (!_platform.SupportsComputePool)
        {
            throw new SollangException("parallel branch is unavailable on the current target because it has no structured compute pool");
        }

        var callbackIndex = 0;
        foreach (var pair in _program.ParallelBranches)
        {
            var expression = pair.Key;
            var bound = pair.Value;
            var captures = new List<ParallelBranchCapture>();
            foreach (var (name, type) in bound.Captures)
            {
                captures.Add(new ParallelBranchCapture(
                    new NameExpression(name, expression.Line, expression.Column),
                    type,
                    UsesBorrowAbi: false,
                    IsSharedOwner: _program.Types.ContainsOwnedStorage(type),
                    LocalName: name));
            }
            var rewrittenArms = new List<BranchArm>(expression.Arms.Count);
            for (var armIndex = 0; armIndex < expression.Arms.Count; armIndex++)
            {
                var arm = expression.Arms[armIndex];
                var rewrittenTargets = new List<FlowTarget>(arm.Targets.Count);
                for (var targetIndex = 0; targetIndex < arm.Targets.Count; targetIndex++)
                {
                    var target = arm.Targets[targetIndex];
                    var function = bound.ArmTargets[armIndex][targetIndex];
                    var parameters = function.AdditionalParameters ?? [];
                    if (parameters.Count != target.Arguments.Count)
                    {
                        throw new SollangException(
                            $"parallel branch target '{function.Name}' argument metadata is inconsistent");
                    }
                    var rewrittenArguments = new Expression[target.Arguments.Count];
                    for (var argumentIndex = 0; argumentIndex < target.Arguments.Count; argumentIndex++)
                    {
                        var parameter = parameters[argumentIndex];
                        var localName = "$parallel_branch_arg_" + captures.Count.ToString(CultureInfo.InvariantCulture);
                        var usesBorrowAbi = _program.Types.IsReference(parameter.Type);
                        captures.Add(new ParallelBranchCapture(
                            target.Arguments[argumentIndex],
                            parameter.Type,
                            usesBorrowAbi,
                            IsSharedOwner: false,
                            localName));
                        rewrittenArguments[argumentIndex] = new NameExpression(
                            localName,
                            target.Arguments[argumentIndex].Line,
                            target.Arguments[argumentIndex].Column);
                    }
                    rewrittenTargets.Add(target with { Arguments = rewrittenArguments });
                }
                rewrittenArms.Add(arm with { Targets = rewrittenTargets });
            }

            var sourceUsesBorrowAbi = _program.Types.ContainsOwnedStorage(bound.SourceType);
            var environmentFields = new List<string>
            {
                sourceUsesBorrowAbi ? "ptr" : LlvmType(bound.SourceType)
            };
            environmentFields.AddRange(captures.Select(capture =>
                capture.UsesBorrowAbi || capture.IsSharedOwner ? "ptr" : LlvmType(capture.Type)));
            var info = new ParallelBranchCallbackInfo(
                "sollang_parallel_branch_" + callbackIndex.ToString(CultureInfo.InvariantCulture),
                bound,
                captures,
                rewrittenArms,
                "{ " + string.Join(", ", environmentFields) + " }");
            callbackIndex++;
            _parallelBranchCallbacks.Add(expression, info);
            EmitParallelBranchCallback(expression, info);
        }
    }

    private void EmitParallelBranchCallback(
        BranchExpression expression,
        ParallelBranchCallbackInfo info)
    {
        var previousLocals = CaptureLocals();
        var previousFunction = _currentFunction;
        var previousFunctions = _currentFunctions;
        var previousBlockLabel = _currentBlockLabel;
        var previousTerminated = _currentBlockTerminated;
        try
        {
            RestoreLocals(new LocalScope(
                new Dictionary<string, RuntimeValue>(StringComparer.Ordinal),
                new HashSet<string>(StringComparer.Ordinal),
                new HashSet<string>(StringComparer.Ordinal),
                new HashSet<string>(StringComparer.Ordinal),
                new Dictionary<string, MutableContainerSlot>(StringComparer.Ordinal),
                new Dictionary<string, string>(StringComparer.Ordinal),
                new Dictionary<string, string>(StringComparer.Ordinal),
                new Dictionary<string, string>(StringComparer.Ordinal)));
            _currentFunction = null;
            var callbackFunctions = new Dictionary<string, BoundFunction>(_program.Functions, StringComparer.Ordinal);
            foreach (var target in info.Branch.ArmTargets.SelectMany(static targets => targets))
            {
                foreach (var (name, function) in FunctionScope(target))
                {
                    callbackFunctions[name] = function;
                }
            }
            _currentFunctions = callbackFunctions;
            _currentBlockLabel = "entry";
            _currentBlockTerminated = false;
            EmitFunctionLine($"define internal void @{info.Name}(ptr %group, i64 %index) #0 {{");
            EmitFunctionLine("entry:");
            EmitFunctionLine("  %environment_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 4");
            EmitFunctionLine("  %environment = load ptr, ptr %environment_slot, align 8");
            EmitFunctionLine("  %output_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 2");
            EmitFunctionLine("  %output = load ptr, ptr %output_slot, align 8");
            EmitFunctionLine("  %stdin_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 6");
            EmitFunctionLine("  %stdin = load ptr, ptr %stdin_slot, align 8");
            EmitFunctionLine("  %stdout_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 7");
            EmitFunctionLine("  %stdout = load ptr, ptr %stdout_slot, align 8");
            EmitFunctionLine("  %written_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 8");
            EmitFunctionLine("  %written = load ptr, ptr %written_slot, align 8");
            EmitFunctionLine("  %read_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 9");
            EmitFunctionLine("  %read = load ptr, ptr %read_slot, align 8");
            EmitFunctionLine("  %ok_state_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 10");
            EmitFunctionLine("  %ok_state = load ptr, ptr %ok_state_slot, align 8");
            var invalidLabel = NextLabel("parallel_branch_invalid");
            var armLabels = expression.Arms.Select(arm => NextLabel("parallel_branch_" + arm.Label)).ToArray();
            EmitFunctionLine("  switch i64 %index, label %" + invalidLabel + " [");
            for (var index = 0; index < armLabels.Length; index++)
            {
                EmitFunctionLine($"    i64 {index.ToString(CultureInfo.InvariantCulture)}, label %{armLabels[index]}");
            }
            EmitFunctionLine("  ]");

            for (var armIndex = 0; armIndex < expression.Arms.Count; armIndex++)
            {
                EmitFunctionLine();
                EmitLabel(armLabels[armIndex]);
                var sourceAddress = NextTemp("parallel_branch_source_address");
                EmitInstruction($"{sourceAddress} = getelementptr {info.EnvironmentType}, ptr %environment, i32 0, i32 0");
                var sourceLocalName = "$parallel_branch_source";
                if (_program.Types.ContainsOwnedStorage(info.Branch.SourceType))
                {
                    var sourcePointer = NextTemp("parallel_branch_source");
                    EmitLoad(sourcePointer, "ptr", sourceAddress, 8);
                    _locals[sourceLocalName] = DematerializeAggregateValue(info.Branch.SourceType, "poison");
                    _readonlyCaptureBorrowPointers[sourceLocalName] = sourcePointer;
                }
                else
                {
                    var sourceValue = NextTemp("parallel_branch_source");
                    EmitLoad(
                        sourceValue,
                        LlvmType(info.Branch.SourceType),
                        sourceAddress,
                        RuntimeAlignment(info.Branch.SourceType));
                    _locals[sourceLocalName] = DematerializeAggregateValue(info.Branch.SourceType, sourceValue);
                }

                for (var captureIndex = 0; captureIndex < info.Captures.Count; captureIndex++)
                {
                    var capture = info.Captures[captureIndex];
                    var captureAddress = NextTemp("parallel_branch_capture_address");
                    EmitInstruction(
                        $"{captureAddress} = getelementptr {info.EnvironmentType}, ptr %environment, i32 0, i32 {(captureIndex + 1).ToString(CultureInfo.InvariantCulture)}");
                    if (capture.IsSharedOwner)
                    {
                        var pointer = NextTemp("parallel_branch_capture");
                        EmitLoad(pointer, "ptr", captureAddress, 8);
                        _locals[capture.LocalName] = DematerializeAggregateValue(capture.Type, "poison");
                        _readonlyCaptureBorrowPointers[capture.LocalName] = pointer;
                    }
                    else if (capture.UsesBorrowAbi)
                    {
                        var pointer = NextTemp("parallel_branch_capture");
                        EmitLoad(pointer, "ptr", captureAddress, 8);
                        var elementType = _program.Types.GetReference(capture.Type).ElementType;
                        _locals[capture.LocalName] = new RuntimeReference(capture.Type, elementType, pointer);
                    }
                    else
                    {
                        var loaded = NextTemp("parallel_branch_capture");
                        EmitLoad(loaded, LlvmType(capture.Type), captureAddress, RuntimeAlignment(capture.Type));
                        _locals[capture.LocalName] = DematerializeAggregateValue(capture.Type, loaded);
                    }
                }

                var arm = info.RewrittenArms[armIndex];
                var result = EmitFlowExpressionValue(new FlowExpression(
                    new NameExpression(sourceLocalName, arm.Line, arm.Column),
                    arm.Targets,
                    arm.Line,
                    arm.Column));
                var outputField = _program.Types.GetStruct(info.Branch.ResultType).Fields[armIndex];
                EnsureRuntimeType(result, outputField.Type, $"parallel branch arm '{arm.Label}'");
                var materialized = MaterializeAggregateValue(result);
                var outputAddress = NextTemp("parallel_branch_output_address");
                EmitInstruction(
                    $"{outputAddress} = getelementptr {LlvmStructType(info.Branch.ResultType)}, ptr %output, i32 0, i32 {armIndex.ToString(CultureInfo.InvariantCulture)}");
                EmitStore(
                    materialized.TypeName,
                    materialized.ValueName,
                    outputAddress,
                    RuntimeAlignment(outputField.Type));
                EmitFunctionLine("  ret void");
                _locals.Clear();
                _readonlyCaptureBorrowPointers.Clear();
            }

            EmitFunctionLine();
            EmitLabel(invalidLabel);
            EmitFunctionLine("  call void @llvm.trap()");
            EmitFunctionLine("  unreachable");
            EmitFunctionLine("}");
            EmitFunctionLine();
        }
        finally
        {
            _currentFunction = previousFunction;
            _currentFunctions = previousFunctions;
            _currentBlockLabel = previousBlockLabel;
            _currentBlockTerminated = previousTerminated;
            RestoreLocals(previousLocals);
        }
    }

    private RuntimeStruct EmitParallelBranchExpression(BranchExpression expression)
    {
        if (!_parallelBranchCallbacks.TryGetValue(expression, out var info))
        {
            throw new SollangException("parallel branch callback metadata is missing");
        }
        var source = EmitExpression(expression.Source);
        EnsureRuntimeType(source, info.Branch.SourceType, "parallel branch source");
        var environment = NextTemp("parallel_branch_environment");
        EmitAlloca(environment, info.EnvironmentType, 8);
        RuntimeValue storedSource;
        if (_program.Types.ContainsOwnedStorage(info.Branch.SourceType))
        {
            var referenceType = _program.Types.GetOrAddReference(info.Branch.SourceType);
            storedSource = new RuntimeReference(
                referenceType,
                info.Branch.SourceType,
                GetOrCreateReadonlyValuePointer(source, "parallel_branch_source"));
        }
        else
        {
            storedSource = source;
        }
        StoreParallelBranchEnvironmentField(
            info.EnvironmentType,
            environment,
            0,
            storedSource,
            info.Branch.SourceType);

        for (var captureIndex = 0; captureIndex < info.Captures.Count; captureIndex++)
        {
            var capture = info.Captures[captureIndex];
            RuntimeValue value;
            if (capture.IsSharedOwner)
            {
                var captured = ResolveLocal(capture.LocalName);
                value = new RuntimeReference(
                    _program.Types.GetOrAddReference(capture.Type),
                    capture.Type,
                    GetOrCreateReadonlyValuePointer(captured, "parallel_branch_capture"));
            }
            else
            {
                value = capture.UsesBorrowAbi
                    ? CreateReadonlyReferenceArgument(capture.Expression, capture.Type, "parallel branch argument")
                    : EmitFunctionArgumentExpression(capture.Expression, capture.Type);
            }
            StoreParallelBranchEnvironmentField(
                info.EnvironmentType,
                environment,
                captureIndex + 1,
                value,
                capture.Type);
        }

        var output = NextTemp("parallel_branch_output");
        EmitAlloca(output, LlvmStructType(info.Branch.ResultType), RuntimeAlignment(info.Branch.ResultType));
        var group = NextTemp("parallel_branch_group");
        EmitAlloca(group, "%sollang.compute_group", 8);
        StoreComputeGroupField(group, 0, "ptr", "@" + info.Name, 8, "parallel_branch_callback");
        StoreComputeGroupField(group, 1, "ptr", "null", 8, "parallel_branch_input");
        StoreComputeGroupField(group, 2, "ptr", output, 8, "parallel_branch_output");
        StoreComputeGroupField(
            group,
            3,
            "i64",
            expression.Arms.Count.ToString(CultureInfo.InvariantCulture),
            8,
            "parallel_branch_count");
        StoreComputeGroupField(group, 4, "ptr", environment, 8, "parallel_branch_environment");
        var sinkBytes = NextTemp("parallel_branch_sink_bytes");
        EmitInstruction($"{sinkBytes} = mul i64 {expression.Arms.Count.ToString(CultureInfo.InvariantCulture)}, 24");
        var sinks = NextTemp("parallel_branch_sinks");
        EmitCall(sinks, "ptr", "sollang_alloc", $"i64 {sinkBytes}");
        EmitCall(target: null, "void", "llvm.memset.p0.i64", $"ptr {sinks}, i8 0, i64 {sinkBytes}, i1 false");
        StoreComputeGroupField(group, 5, "ptr", sinks, 8, "parallel_branch_sinks");
        var runtimeValues = new[] { "%stdin", "%stdout", "%written", "%read", "%ok_state" };
        for (var runtimeIndex = 0; runtimeIndex < runtimeValues.Length; runtimeIndex++)
        {
            StoreComputeGroupField(
                group,
                runtimeIndex + 6,
                "ptr",
                runtimeValues[runtimeIndex],
                8,
                "parallel_branch_runtime");
        }
        StoreComputeGroupField(
            group,
            11,
            "i64",
            expression.Arms.Count.ToString(CultureInfo.InvariantCulture),
            8,
            "parallel_branch_failure_limit");
        StoreComputeGroupField(group, 12, "ptr", "null", 8, "parallel_branch_initialized");
        EmitCall(target: null, "void", "sollang_compute_execute", $"ptr {group}");
        var aggregate = NextTemp("parallel_branch_result");
        EmitLoad(
            aggregate,
            LlvmStructType(info.Branch.ResultType),
            output,
            RuntimeAlignment(info.Branch.ResultType));
        return new RuntimeStruct(info.Branch.ResultType, aggregate);
    }

    private void StoreParallelBranchEnvironmentField(
        string environmentType,
        string environment,
        int index,
        RuntimeValue value,
        BoundType type)
    {
        var materialized = MaterializeAggregateValue(value);
        var address = NextTemp("parallel_branch_environment_field");
        EmitInstruction(
            $"{address} = getelementptr {environmentType}, ptr {environment}, i32 0, i32 {index.ToString(CultureInfo.InvariantCulture)}");
        EmitStore(
            materialized.TypeName,
            materialized.ValueName,
            address,
            materialized.TypeName == "ptr" ? 8 : RuntimeAlignment(type));
    }

    private void StoreComputeGroupField(
        string group,
        int index,
        string type,
        string value,
        int alignment,
        string prefix)
    {
        var address = NextTemp(prefix + "_slot");
        EmitInstruction($"{address} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 {index.ToString(CultureInfo.InvariantCulture)}");
        EmitStore(type, value, address, alignment);
    }
}
