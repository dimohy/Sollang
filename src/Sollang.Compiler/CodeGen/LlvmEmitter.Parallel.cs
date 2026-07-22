using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitParallelCallbacks()
    {
        if (!_usesParallel)
        {
            return;
        }

        var previousFunction = _currentFunction;
        var previousFunctions = _currentFunctions;
        try
        {
            CollectParallelCallbacks(_program.MainStatements);
            foreach (var function in EnumerateEmittableFunctions(_program.Functions.Values))
            {
                if (function.IsStandardLibrary)
                {
                    continue;
                }
                _currentFunction = function;
                _currentFunctions = FunctionScope(function);
                CollectParallelCallbacks(function.BlockBody);
            }
        }
        finally
        {
            _currentFunction = previousFunction;
            _currentFunctions = previousFunctions;
        }
    }

    private void CollectParallelCallbacks(IReadOnlyList<Statement> statements)
    {
        foreach (var statement in statements)
        {
            if (statement is BlockFunctionPipelineStatement pipeline)
            {
                foreach (var pipelineBlock in pipeline.Calls)
                {
                    CollectParallelCallback(pipelineBlock);
                }
                continue;
            }
            if (statement is not BlockFunctionCallStatement block)
            {
                continue;
            }

            CollectParallelCallback(block);
        }
    }

    private void CollectParallelCallback(BlockFunctionCallStatement block)
    {
        if (_program.ResolvedGenericCalls.TryGetValue(block, out var specialization)
            && specialization.Kind == BoundFunctionKind.RuntimeParallel
            && TryResolveDirectParallelTarget(block, out var target))
        {
            EmitDirectParallelCallback(block, specialization, target, isFallible: false);
        }
        else if (_program.ResolvedGenericCalls.TryGetValue(block, out specialization)
            && specialization.Kind == BoundFunctionKind.RuntimeTryParallel
            && TryResolveDirectParallelTarget(block, out target))
        {
            EmitDirectParallelCallback(block, specialization, target, isFallible: true);
        }
        CollectParallelCallbacks(block.Body);
    }

    private bool TryResolveDirectParallelTarget(
        BlockFunctionCallStatement block,
        out BoundFunction target)
    {
        target = null!;
        if (block.Body.Count != 1
            || block.Body[0] is not ExpressionStatement
            {
                Expression: FlowExpression
                {
                    Source: NameExpression source,
                    Targets.Count: 1
                } flow
            }
            || source.Name != block.ItemName
            || flow.Targets[0].Arguments.Count != 0
            || !TryResolveFunction(flow.Targets[0].Path, out target)
            || target.Kind != BoundFunctionKind.User
            || target.IsAsync)
        {
            target = null!;
            return false;
        }
        return true;
    }

    private void EmitDirectParallelCallback(
        BlockFunctionCallStatement block,
        BoundFunction specialization,
        BoundFunction target,
        bool isFallible)
    {
        var inputType = specialization.BlockInputType
            ?? throw new SollangException("parallel input type was not specialized");
        var resultType = specialization.BlockResultType
            ?? throw new SollangException("parallel result type was not specialized");
        if (target.InputType != inputType || target.ReturnType != resultType)
        {
            return;
        }

        var inputArrayType = specialization.InputType!.Value;
        var inputSize = inputArrayType == BoundType.DynamicIntArray
            ? 4
            : _program.Types.GetDynamicArray(inputArrayType).ElementSize;
        var inputAlignment = inputArrayType == BoundType.DynamicIntArray
            ? 4
            : _program.Types.GetDynamicArray(inputArrayType).ElementAlignment;
        var outputSize = isFallible
            ? _program.Types.InlineSizeOf(resultType)
            : specialization.ReturnType == BoundType.DynamicIntArray
                ? 4
                : _program.Types.GetDynamicArray(specialization.ReturnType).ElementSize;
        var outputAlignment = isFallible
            ? RuntimeAlignment(resultType)
            : specialization.ReturnType == BoundType.DynamicIntArray
                ? 4
                : _program.Types.GetDynamicArray(specialization.ReturnType).ElementAlignment;
        var callbackName = "sollang_parallel_callback_"
            + _parallelCallbacks.Count.ToString(CultureInfo.InvariantCulture);
        var captures = CapturedBindingsForFunction(target);
        _parallelCallbacks.Add(block, new ParallelCallbackInfo(callbackName, target, captures));

        EmitFunctionLine($"define internal void @{callbackName}(ptr %group, i64 %index) #0 {{");
        EmitFunctionLine("entry:");
        EmitFunctionLine("  %input_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 1");
        EmitFunctionLine("  %input = load ptr, ptr %input_slot, align 8");
        EmitFunctionLine($"  %input_offset = mul i64 %index, {inputSize.ToString(CultureInfo.InvariantCulture)}");
        EmitFunctionLine("  %input_address = getelementptr i8, ptr %input, i64 %input_offset");
        EmitFunctionLine($"  %item = load {LlvmType(inputType)}, ptr %input_address, align {inputAlignment.ToString(CultureInfo.InvariantCulture)}");
        var captureArguments = new List<string>();
        if (captures.Count > 0)
        {
            var captureType = ParallelCaptureType(captures);
            EmitFunctionLine("  %capture_environment_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 4");
            EmitFunctionLine("  %capture_environment = load ptr, ptr %capture_environment_slot, align 8");
            for (var captureIndex = 0; captureIndex < captures.Count; captureIndex++)
            {
                var capture = captures[captureIndex];
                var captureTypeName = LlvmType(capture.Value);
                var captureAddress = $"%capture_address_{captureIndex.ToString(CultureInfo.InvariantCulture)}";
                EmitFunctionLine($"  {captureAddress} = getelementptr {captureType}, ptr %capture_environment, i32 0, i32 {captureIndex.ToString(CultureInfo.InvariantCulture)}");
                if (CaptureUsesBorrowAbi(capture.Value))
                {
                    captureArguments.Add($"ptr {captureAddress}");
                    continue;
                }
                var captureValue = $"%capture_value_{captureIndex.ToString(CultureInfo.InvariantCulture)}";
                EmitFunctionLine($"  {captureValue} = load {captureTypeName}, ptr {captureAddress}, align {RuntimeAlignment(capture.Value).ToString(CultureInfo.InvariantCulture)}");
                captureArguments.Add($"{captureTypeName} {captureValue}");
            }
        }
        captureArguments.Add($"{LlvmType(inputType)} %item");
        EmitFunctionLine("  %stdin_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 6");
        EmitFunctionLine("  %stdin = load ptr, ptr %stdin_slot, align 8");
        EmitFunctionLine("  %stdout_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 7");
        EmitFunctionLine("  %stdout = load ptr, ptr %stdout_slot, align 8");
        EmitFunctionLine("  %sinks_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 5");
        EmitFunctionLine("  %sinks = load ptr, ptr %sinks_slot, align 8");
        EmitFunctionLine("  %sink = getelementptr %sollang.output_sink, ptr %sinks, i64 %index");
        EmitFunctionLine("  %sink_value = ptrtoint ptr %sink to i64");
        EmitFunctionLine("  %sink_tagged_value = or i64 %sink_value, 1");
        EmitFunctionLine("  %sink_stdout = inttoptr i64 %sink_tagged_value to ptr");
        EmitFunctionLine("  %written_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 8");
        EmitFunctionLine("  %written = load ptr, ptr %written_slot, align 8");
        EmitFunctionLine("  %read_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 9");
        EmitFunctionLine("  %read = load ptr, ptr %read_slot, align 8");
        EmitFunctionLine("  %ok_state_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 10");
        EmitFunctionLine("  %ok_state = load ptr, ptr %ok_state_slot, align 8");
        EmitFunctionLine($"  %mapped = call {LlvmType(resultType)} {SymbolForFunction(target)}(ptr %stdin, ptr %sink_stdout, ptr %written, ptr %read, ptr %ok_state, {string.Join(", ", captureArguments)})");
        EmitFunctionLine("  %output_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 2");
        EmitFunctionLine("  %output = load ptr, ptr %output_slot, align 8");
        EmitFunctionLine($"  %output_offset = mul i64 %index, {outputSize.ToString(CultureInfo.InvariantCulture)}");
        EmitFunctionLine("  %output_address = getelementptr i8, ptr %output, i64 %output_offset");
        EmitFunctionLine($"  store {LlvmType(resultType)} %mapped, ptr %output_address, align {outputAlignment.ToString(CultureInfo.InvariantCulture)}");
        if (isFallible)
        {
            EmitFunctionLine("  %initialized_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 12");
            EmitFunctionLine("  %initialized = load ptr, ptr %initialized_slot, align 8");
            EmitFunctionLine("  %initialized_address = getelementptr i8, ptr %initialized, i64 %index");
            EmitFunctionLine("  store atomic i8 1, ptr %initialized_address release, align 1");
            EmitFunctionLine($"  %result_tag = extractvalue {LlvmEnumType(resultType)} %mapped, 0");
            EmitFunctionLine("  %is_error = icmp eq i32 %result_tag, 1");
            EmitFunctionLine("  br i1 %is_error, label %publish_error, label %done");
            EmitFunctionLine("publish_error:");
            EmitFunctionLine("  %failure_limit_slot = getelementptr %sollang.compute_group, ptr %group, i32 0, i32 11");
            EmitFunctionLine("  %failure_before = atomicrmw min ptr %failure_limit_slot, i64 %index acq_rel");
            EmitFunctionLine("  br label %done");
            EmitFunctionLine("done:");
        }
        EmitFunctionLine("  ret void");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private string ParallelCaptureType(IReadOnlyList<KeyValuePair<string, BoundType>> captures)
    {
        return "{ " + string.Join(", ", captures.Select(capture => LlvmType(capture.Value))) + " }";
    }
}
