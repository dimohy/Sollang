using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitAsyncFunction(BoundFunction function)
    {
        if (function.Body is null && function.ReturnType != BoundType.Unit)
        {
            throw new SollangException($"async function '{function.Name}' has no body");
        }

        var previousFunctions = _currentFunctions;
        _currentFunctions = FunctionScope(function);
        ClearLocalState();
        SelectStackFrame(function);
        try
        {
            var workerName = AsyncWorkerSymbol(function);
            var hasCfgSuspension = TryGetCfgSuspendPlan(function, out var cfgSuspendPlan);
            EmitFunctionLine($"define internal i1 @{workerName}(ptr %control) #0 {{");
            EmitLabel("entry");
            EmitStackFrameAllocations();
            _currentBlockLabel = "entry";

            var contextSlot = NextTemp("async_control_context_slot");
            EmitAssign(
                contextSlot,
                "getelementptr %sollang.task_control, ptr %control, i32 0, i32 0");
            EmitLoad("%context", "ptr", contextSlot, 8);

            if (_usesAsyncDiagnostics)
            {
                _currentAsyncDiagnosticHeader = AsyncFunctionDiagnosticHeader(
                    "%context", function, "async_diagnostic_header");
            }

            EmitAsyncContextLoad("%stdin", "%context", function.InputType, function.ReturnType, 0, "ptr", 8);
            EmitAsyncContextLoad("%stdout", "%context", function.InputType, function.ReturnType, 1, "ptr", 8);
            EmitAsyncContextLoad("%written", "%context", function.InputType, function.ReturnType, 2, "ptr", 8);
            EmitAsyncContextLoad("%read", "%context", function.InputType, function.ReturnType, 3, "ptr", 8);
            EmitAsyncContextLoad("%ok_state", "%context", function.InputType, function.ReturnType, 4, "ptr", 8);
            if (function.InputType is { } inputType)
            {
                EmitAsyncContextLoad(
                    "%it", "%context", function.InputType, function.ReturnType, 5,
                    AsyncStorageLlvmType(inputType), RuntimeAlignment(inputType));
            }
            var additionalParameters = function.AdditionalParameters ?? [];
            for (var parameterIndex = 0; parameterIndex < additionalParameters.Count; parameterIndex++)
            {
                var parameter = additionalParameters[parameterIndex];
                EmitAsyncFunctionContextLoad(
                    $"%arg_{parameterIndex}",
                    "%context",
                    function,
                    10 + parameterIndex,
                    AsyncStorageLlvmType(parameter.Type),
                    RuntimeAlignment(parameter.Type));
            }
            BindFunctionCaptures(function);
            var functionLocals = CaptureLocals();
            BindAllFunctionParameters(function);
            if (hasCfgSuspension)
            {
                EmitCfgSuspendWorker(function, cfgSuspendPlan!, functionLocals);
            }
            else
            {
                EmitAsyncWorkerCompletion(function, functionLocals);
            }
            EmitFunctionLine("}");
            EmitFunctionLine();

            ClearLocalState();
            EmitAsyncCancelFunction(function, cfgSuspendPlan);

            ClearLocalState();
            EmitFunctionLine($"define internal %sollang.task {SymbolForFunction(function)}({ParameterListForFunction(function)}) #0 {{");
            EmitLabel("entry");
            var context = NextTemp("async_context");
            EmitCall(context, "ptr", "sollang_alloc", $"i64 {AsyncContextSize(function)}");
            EmitAsyncContextStore(context, function.InputType, function.ReturnType, 0, "ptr", "%stdin", 8);
            EmitAsyncContextStore(context, function.InputType, function.ReturnType, 1, "ptr", "%stdout", 8);
            EmitAsyncContextStore(context, function.InputType, function.ReturnType, 2, "ptr", "%written", 8);
            EmitAsyncContextStore(context, function.InputType, function.ReturnType, 3, "ptr", "%read", 8);
            EmitAsyncContextStore(context, function.InputType, function.ReturnType, 4, "ptr", "%ok_state", 8);
            EmitAsyncContextStore(
                context, function.InputType, function.ReturnType, 5,
                AsyncStorageLlvmType(function.InputType), function.InputType is null ? "0" : "%it",
                AsyncStorageAlignment(function.InputType));
            EmitAsyncContextStore(
                context, function.InputType, function.ReturnType, 6,
                AsyncStorageLlvmType(function.ReturnType), "zeroinitializer",
                RuntimeAlignment(function.ReturnType));
            EmitAsyncContextStore(
                context, function.InputType, function.ReturnType, 7,
                "ptr", "null", 8);
            EmitAsyncContextStore(
                context, function.InputType, function.ReturnType, 8,
                "ptr", "null", 8);
            EmitAsyncContextStore(
                context, function.InputType, function.ReturnType, 9,
                "ptr", "null", 8);
            for (var parameterIndex = 0; parameterIndex < additionalParameters.Count; parameterIndex++)
            {
                var parameter = additionalParameters[parameterIndex];
                EmitAsyncFunctionContextStore(
                    context,
                    function,
                    10 + parameterIndex,
                    AsyncStorageLlvmType(parameter.Type),
                    $"%arg_{parameterIndex}",
                    RuntimeAlignment(parameter.Type));
            }
            if (_usesAsyncDiagnostics)
            {
                EmitInitializeAsyncFunctionDiagnosticHeader(context, function, "%diagnostic_context");
            }

            var handle = NextTemp("async_handle");
            EmitCall(
                handle,
                "ptr",
                "sollang_task_start",
                $"ptr @{workerName}, ptr @sollang_free, ptr @{AsyncCancelSymbol(function)}, ptr {context}");
            var started = NextTemp("async_started");
            EmitCompare(started, "ne", "ptr", handle, "null");
            var readyLabel = NextLabel("async_ready");
            var failedLabel = NextLabel("async_failed");
            EmitConditionalBranch(started, readyLabel, failedLabel);
            EmitLabel(failedLabel);
            DropFailedAsyncInput(function);
            DropFailedAsyncAdditionalInputs(function);
            EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
            EmitTrap();
            EmitLabel(readyLabel);
            if (_usesAsyncDiagnostics)
            {
                var header = AsyncFunctionDiagnosticHeader(context, function, "async_started_diagnostic_header");
                EmitStore("ptr", header, TaskDiagnosticHeaderSlot(handle), 8);
                EmitAttachInheritedDiagnosticRecord(header, handle);
            }

            EmitInitializeTaskResult(handle, context, function.InputType, function.ReturnType, function);
            var withHandle = NextTemp("task");
            EmitAssign(withHandle, $"insertvalue %sollang.task poison, ptr {handle}, 0");
            var task = NextTemp("task");
            EmitAssign(task, $"insertvalue %sollang.task {withHandle}, ptr {context}, 1");
            EmitRet("%sollang.task", task);
            EmitFunctionLine("}");
            EmitFunctionLine();
        }
        finally
        {
            _currentFunctions = previousFunctions;
        }
    }

    private void EmitAsyncCancelFunction(
        BoundFunction function,
        AsyncCfgPlan? cfgPlan)
    {
        EmitFunctionLine($"define internal void @{AsyncCancelSymbol(function)}(ptr %control) #0 {{");
        EmitLabel("entry");
        _currentBlockLabel = "entry";
        var contextSlot = NextTemp("cancel_context_slot");
        EmitAssign(
            contextSlot,
            "getelementptr %sollang.task_control, ptr %control, i32 0, i32 0");
        EmitLoad("%context", "ptr", contextSlot, 8);
        var statusSlot = NextTemp("cancel_status_slot");
        EmitAssign(
            statusSlot,
            "getelementptr %sollang.task_control, ptr %control, i32 0, i32 4");
        var status = NextTemp("cancel_status");
        EmitLoad(status, "i32", statusSlot, 4);
        var completed = NextTemp("cancel_completed");
        EmitCompare(completed, "eq", "i32", status, "2");
        var completedLabel = NextLabel("cancel_completed");
        var pendingLabel = NextLabel("cancel_pending");
        var cleanupLabel = NextLabel("cancel_cleanup");
        EmitConditionalBranch(completed, completedLabel, pendingLabel);

        EmitLabel(completedLabel);
        _currentBlockLabel = completedLabel;
        DropCancelledAsyncResult(function);
        EmitBranch(cleanupLabel);

        EmitLabel(pendingLabel);
        _currentBlockLabel = pendingLabel;
        var stateSlot = NextTemp("cancel_state_slot");
        EmitAssign(
            stateSlot,
            "getelementptr %sollang.task_control, ptr %control, i32 0, i32 5");
        var state = NextTemp("cancel_state");
        EmitLoad(state, "i32", stateSlot, 4);
        var pendingStates = cfgPlan?.Points.Count ?? 0;
        var stateLabels = Enumerable.Range(0, pendingStates + 1)
            .Select(index => NextLabel(index == 0 ? "cancel_initial" : "cancel_suspended"))
            .ToArray();
        var invalidLabel = NextLabel("cancel_invalid");
        var switchCases = string.Join(" ", stateLabels.Select((label, index) =>
            $"i32 {index}, label %{label}"));
        EmitInstruction(
            $"switch i32 {state}, label %{invalidLabel} [ {switchCases} ]");
        _currentBlockTerminated = true;

        EmitLabel(invalidLabel);
        _currentBlockLabel = invalidLabel;
        EmitTrap();

        EmitLabel(stateLabels[0]);
        _currentBlockLabel = stateLabels[0];
        DropCancelledAsyncInput(function);
        DropCancelledAsyncAdditionalInputs(function);
        EmitBranch(cleanupLabel);

        for (var stateIndex = 1; stateIndex <= pendingStates; stateIndex++)
        {
            EmitLabel(stateLabels[stateIndex]);
            _currentBlockLabel = stateLabels[stateIndex];
            var point = cfgPlan!.Points[stateIndex - 1];
            if (point.OwnsPrimaryInput)
            {
                DropCancelledAsyncInput(function);
            }
            DropCancelledAsyncAdditionalInputs(function, point.OwnedAdditionalInputIndexes);
            if (!point.IsYield)
            {
                CancelStoredChild(function);
            }
            DropCancelledAsyncSpills(function, point.Spills);
            EmitBranch(cleanupLabel);
        }

        EmitLabel(cleanupLabel);
        _currentBlockLabel = cleanupLabel;
        if (_usesAsyncDiagnostics)
        {
            var diagnosticHeader = AsyncFunctionDiagnosticHeader("%context", function, "cancel_diagnostic_header");
            EmitMarkDiagnosticHeaderTerminal(diagnosticHeader, 3);
            EmitDetachDiagnosticHeader(diagnosticHeader);
        }
        EmitCall(target: null, "void", "sollang_free", "ptr %context");
        EmitInstruction("ret void");
        _currentBlockTerminated = true;
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private void DropCancelledAsyncInput(BoundFunction function)
    {
        if (function.InputOwnership != BoundFunctionInputOwnership.Move
            || function.InputType is not { } inputType
            || !_program.Types.ContainsOwnedStorage(inputType))
        {
            return;
        }

        var inputAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 5, "cancel_input_address");
        var input = NextTemp("cancel_input");
        EmitLoad(input, AsyncStorageLlvmType(inputType), inputAddress, RuntimeAlignment(inputType));
        DropOwnedRuntimeValue(DematerializeAggregateValue(inputType, input));
    }

    private void DropCancelledAsyncResult(BoundFunction function)
    {
        if (!_program.Types.ContainsOwnedStorage(function.ReturnType))
        {
            return;
        }

        var resultAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 6, "cancel_result_address");
        var result = NextTemp("cancel_result");
        EmitLoad(
            result,
            AsyncStorageLlvmType(function.ReturnType),
            resultAddress,
            RuntimeAlignment(function.ReturnType));
        DropOwnedRuntimeValue(DematerializeAsyncResult(function.ReturnType, result));
    }

    private void CancelStoredChild(BoundFunction function)
    {
        var handleAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 7, "cancel_child_handle_address");
        var handle = NextTemp("cancel_child_handle");
        EmitLoad(handle, "ptr", handleAddress, 8);
        EmitCancelTaskHandle(handle);
    }

    private void DropCancelledAsyncSpills(
        BoundFunction function,
        IReadOnlyList<AsyncSpillPlan> spills)
    {
        if (spills.Count == 0)
        {
            return;
        }

        var frameAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 9, "cancel_spill_frame_address");
        var frame = NextTemp("cancel_spill_frame");
        EmitLoad(frame, "ptr", frameAddress, 8);
        var layouts = new List<(AsyncSpillPlan Spill, int Offset, int Alignment)>(spills.Count);
        var offset = 0;
        foreach (var spill in spills)
        {
            var alignment = RuntimeAlignment(spill.Type);
            offset = AlignAsyncSize(offset, alignment);
            layouts.Add((spill, offset, alignment));
            offset = checked(offset + Math.Max(_program.Types.InlineSizeOf(spill.Type), 1));
            if (spill.HasOwnershipFlag)
                offset = checked(offset + 1);
        }
        foreach (var layout in layouts.AsEnumerable().Reverse())
        {
            var spill = layout.Spill;
            if (!spill.DropOnCancel)
            {
                continue;
            }
            var address = NextTemp("cancel_spill_address");
            EmitAssign(address, $"getelementptr i8, ptr {frame}, i64 {layout.Offset}");
            string? retainedEnd = null;
            if (spill.HasOwnershipFlag)
            {
                var flagOffset = checked(layout.Offset + Math.Max(_program.Types.InlineSizeOf(spill.Type), 1));
                var flagAddress = NextTemp("cancel_spill_owned_flag_address");
                var retained = NextTemp("cancel_spill_owned_flag");
                EmitAssign(flagAddress, $"getelementptr i8, ptr {frame}, i64 {flagOffset}");
                EmitLoad(retained, "i1", flagAddress, 1);
                var retainedBody = NextLabel("cancel_spill_owned");
                retainedEnd = NextLabel("cancel_spill_owned_end");
                EmitConditionalBranch(retained, retainedBody, retainedEnd);
                EmitLabel(retainedBody);
                _currentBlockLabel = retainedBody;
            }
            var loaded = NextTemp("cancel_spill_value");
            EmitLoad(loaded, LlvmType(spill.Type), address, layout.Alignment);
            if (_program.Types.IsTask(spill.Type))
            {
                var handle = NextTemp("cancel_spill_task_handle");
                EmitAssign(handle, $"extractvalue %sollang.task {loaded}, 0");
                EmitCancelTaskHandle(handle);
            }
            else if (_program.Types.ContainsOwnedStorage(spill.Type))
            {
                var value = DematerializeAggregateValue(spill.Type, loaded);
                if (value is RuntimeStruct structure && spill.MovedOwnedFields.Count > 0)
                {
                    DropOwnedStructFieldsExceptTransferred(
                        structure,
                        spill.MovedOwnedFields
                            .Select(static path => (IReadOnlyList<string>)path.Split('.'))
                            .ToArray());
                }
                else
                {
                    DropOwnedRuntimeValue(value);
                }
            }
            if (retainedEnd is not null)
            {
                EmitBranch(retainedEnd);
                EmitLabel(retainedEnd);
                _currentBlockLabel = retainedEnd;
            }
        }
        EmitCall(target: null, "void", "sollang_free", $"ptr {frame}");
    }

    private void EmitAsyncWorkerCompletion(BoundFunction function, LocalScope functionLocals)
    {
        EmitAsyncWorkerCompletion(function, functionLocals, function.BlockBody);
    }

    private void EmitAsyncWorkerCompletion(
        BoundFunction function,
        LocalScope functionLocals,
        IReadOnlyList<Statement> statements)
    {
        EmitStatements(statements);
        var movedBodySourceName = function.Body is null
            ? null
            : GetMoveConsumingContainerSourceName(function.Body);
        var value = function.Body is null
            ? RuntimeUnit.Instance
            : EmitFunctionArgumentExpression(function.Body, function.ReturnType);
        EnsureRuntimeType(value, function.ReturnType, function.Name);
        if (movedBodySourceName is not null)
        {
            RemoveLocal(movedBodySourceName);
        }
        var transferredOwnerName = IsOwnedContainerRuntimeValue(value)
            && function.Body is not null
            ? GetFunctionResultTransferredOwnerName(function, function.Body)
            : null;
        DropOwnedLocalsCreatedSince(functionLocals, transferredOwnerName, function.Body);
        StoreAsyncResult(function, value);
        EmitMarkCurrentDiagnosticTerminal(2);
        EmitRet("i1", "true");
    }

    private void EmitCfgSuspendWorker(
        BoundFunction function,
        AsyncCfgPlan plan,
        LocalScope functionLocals)
    {
        var resumeBaseLocals = CaptureLocals();
        var stateSlot = NextTemp("async_resume_state_slot");
        EmitAssign(
            stateSlot,
            "getelementptr %sollang.task_control, ptr %control, i32 0, i32 5");
        var state = NextTemp("async_resume_state");
        EmitLoad(state, "i32", stateSlot, 4);
        var startLabel = NextLabel("async_state_start");
        foreach (var point in plan.Points)
        {
            point.ResumeLabel = NextLabel("async_cfg_resume");
        }
        var invalidLabel = NextLabel("async_state_invalid");
        var switchCases = string.Join(" ",
            new[] { $"i32 0, label %{startLabel}" }.Concat(plan.Points.Select(point =>
                $"i32 {point.State.ToString(CultureInfo.InvariantCulture)}, label %{point.ResumeLabel}")));
        EmitInstruction($"switch i32 {state}, label %{invalidLabel} [ {switchCases} ]");
        _currentBlockTerminated = true;

        EmitLabel(invalidLabel);
        EmitTrap();
        EmitLabel(startLabel);
        _currentBlockLabel = startLabel;

        _activeAsyncCfg = new AsyncCfgLowering(function, plan, resumeBaseLocals, stateSlot);
        try
        {
            EmitAsyncWorkerCompletion(function, functionLocals);
        }
        finally
        {
            _activeAsyncCfg = null;
            _asyncScopeSnapshots.Clear();
            _asyncHiddenScopes.Clear();
            _asyncStreamCancellationBindings.Clear();
        }
    }

    private bool TryEmitCfgAwaitBinding(BindingStatement binding)
    {
        if (_activeAsyncCfg is not { } lowering
            || !lowering.Plan.ByBinding.TryGetValue(binding, out var point))
        {
            return false;
        }

        if (!TryGetAwaitTaskName(binding, out var taskName))
        {
            throw new SollangException("CFG await plan contains a non-await binding");
        }
        var child = ResolveLocal(taskName) as RuntimeTask
            ?? throw new SollangException(
                $"await in async function '{lowering.Function.Name}' did not produce Task<T>");

        var spillPlans = BuildCfgSpillPlans(lowering, excludedName: taskName);
        EmitRecordCurrentDiagnosticSuspension(point, child, taskExpression: null);
        StoreSuspendedChild(lowering.Function, child);
        RemoveLocal(taskName);
        SuspendAndResumeCfgPoint(lowering, point, spillPlans);
        var resumedValue = EmitStoredChildAwait(lowering.Function, child);
        _locals.Add(binding.Name, resumedValue);
        return true;
    }

    private bool TryEmitCfgAwaitExpressionStatement(ExpressionStatement statement)
    {
        if (_activeAsyncCfg is not { } lowering
            || !lowering.Plan.ByAwaitExpressionStatement.TryGetValue(statement, out var point)
            || !TryGetAwaitTaskExpression(statement.Expression, out var taskExpression))
        {
            return false;
        }
        var child = EmitExpression(taskExpression) as RuntimeTask
            ?? throw new SollangException(
                $"await in async function '{lowering.Function.Name}' did not produce Task<T>");
        var value = EmitCfgAwaitValue(lowering, point, child, taskExpression);
        if (value.Type != BoundType.Unit)
            throw new SollangException("an await expression statement must produce Unit");
        return true;
    }

    private bool TryEmitCfgAwaitExpression(Expression expression, out RuntimeValue value)
    {
        value = null!;
        if (_activeAsyncCfg is not { } lowering
            || !lowering.Plan.ByAwaitExpression.TryGetValue(expression, out var point)
            || !TryGetAwaitTaskExpression(expression, out var taskExpression))
        {
            return false;
        }
        var child = EmitExpression(taskExpression) as RuntimeTask
            ?? throw new SollangException(
                $"await in async function '{lowering.Function.Name}' did not produce Task<T>");
        value = EmitCfgAwaitValue(lowering, point, child, taskExpression);
        return true;
    }

    private bool TryEmitCfgFlowAwait(
        Expression source, FlowTarget target, RuntimeTask child, out RuntimeValue value)
    {
        value = null!;
        if (_activeAsyncCfg is not { } lowering
            || !lowering.Plan.ByFlowAwaitTarget.TryGetValue(target, out var point))
        {
            return false;
        }
        value = EmitCfgAwaitValue(lowering, point, child, source);
        return true;
    }

    private RuntimeValue EmitCfgAwaitValue(
        AsyncCfgLowering lowering, AsyncCfgSuspendPoint point, RuntimeTask child, Expression taskExpression)
    {
        var consumedTaskName = taskExpression is NameExpression taskName
            && _locals.TryGetValue(taskName.Name, out var local)
            && ReferenceEquals(local, child)
                ? taskName.Name
                : null;
        if (consumedTaskName is null && taskExpression is FieldAccessExpression)
            ConsumeOwnedFieldProjection(taskExpression, child.Type);
        var spillPlans = BuildCfgSpillPlans(lowering, excludedName: consumedTaskName);
        EmitRecordCurrentDiagnosticSuspension(point, child, taskExpression);
        StoreSuspendedChild(lowering.Function, child);
        if (consumedTaskName is not null)
            RemoveLocal(consumedTaskName);
        SuspendAndResumeCfgPoint(lowering, point, spillPlans);
        return EmitStoredChildAwait(lowering.Function, child);
    }

    private bool TryEmitCfgYieldStatement(ExpressionStatement statement)
    {
        if (_activeAsyncCfg is not { } lowering
            || !lowering.Plan.ByYield.TryGetValue(statement, out var point))
        {
            return false;
        }

        var spillPlans = BuildCfgSpillPlans(lowering, excludedName: null);
        EmitRecordCurrentDiagnosticSuspension(point, child: null, taskExpression: null);
        SuspendAndResumeCfgPoint(lowering, point, spillPlans);
        return true;
    }

    private sealed record AsyncExpressionCarrier(string Name, bool Introduced);

    private AsyncExpressionCarrier? PreserveAsyncExpressionValue(RuntimeValue value, bool ownsValue)
    {
        if (_activeAsyncCfg is null || value is RuntimeUnit)
            return null;
        foreach (var (name, local) in _locals)
            if (!_mutableLocals.Contains(name) && ReferenceEquals(local, value))
                return new AsyncExpressionCarrier(name, false);
        var carrier = NextAsyncBindingName("expression_value");
        _locals.Add(carrier, value);
        if (!ownsValue)
            _borrowedOwnedLocals.Add(carrier);
        return new AsyncExpressionCarrier(carrier, true);
    }

    private RuntimeValue RestoreAsyncExpressionValue(AsyncExpressionCarrier? carrier, RuntimeValue original)
    {
        if (carrier is null)
            return original;
        var value = ResolveLocal(carrier.Name);
        if (carrier.Introduced)
            ForgetAsyncSpillCarrier(carrier.Name);
        return value;
    }

    private IReadOnlyList<AsyncSpillPlan> BuildCfgSpillPlans(
        AsyncCfgLowering lowering,
        string? excludedName)
    {
        var spillPlans = new List<AsyncSpillPlan>();
        var activeScope = CaptureLocals();
        foreach (var (name, value) in _locals)
        {
            if (string.Equals(name, excludedName, StringComparison.Ordinal)
                || AsyncScopeSharesBinding(activeScope, name, lowering.ResumeBaseLocals, name))
            {
                continue;
            }
            if (!IsAsyncSpillType(value.Type))
            {
                throw new SollangException(
                    $"binding '{name}' of type {value.Type} cannot cross async suspension");
            }
            var isMutable = _mutableLocals.Contains(name);
            if (isMutable && !IsAsyncMutableSpillType(value.Type))
            {
                throw new SollangException(
                    $"mutable binding '{name}' of type {value.Type} cannot cross async suspension");
            }
            var movedOwnedFields = _movedOwnedStructFields.TryGetValue(name, out var fields)
                ? fields.Order(StringComparer.Ordinal).ToArray()
                : [];
            spillPlans.Add(new AsyncSpillPlan(
                name, value.Type, isMutable, movedOwnedFields,
                ScopeBindings: _asyncScopeSnapshots
                    .Where(scope => AsyncScopeSharesBinding(activeScope, name, scope, name))
                    .Select(scope => CaptureAsyncScopeBinding(scope, name)).ToArray(),
                DropOnCancel: _borrowedOwnedTransferFlags.ContainsKey(name)
                    || (!_borrowedOwnedLocals.Contains(name) && !_borrowedMutableLocals.Contains(name)),
                HasOwnershipFlag: _borrowedOwnedTransferFlags.ContainsKey(name)));
        }
        foreach (var hidden in _asyncHiddenScopes.Concat(
                     _asyncScopeSnapshots.Select(scope => new AsyncHiddenScope(scope, []))))
        {
            foreach (var (name, value) in hidden.Scope.Locals)
            {
                if (AsyncScopeSharesBinding(hidden.Scope, name, lowering.ResumeBaseLocals, name))
                {
                    continue;
                }
                var mutable = hidden.Scope.MutableLocals.Contains(name);
                if (!IsAsyncSpillType(value.Type)
                    || (mutable && !IsAsyncMutableSpillType(value.Type)))
                {
                    throw new SollangException(
                        $"binding '{name}' of type {value.Type} cannot cross async suspension");
                }
                var bindings = new List<AsyncScopeBinding> { CaptureAsyncScopeBinding(hidden.Scope, name) };
                bindings.AddRange(hidden.Mirrors
                    .Where(scope => AsyncScopeSharesBinding(hidden.Scope, name, scope, name))
                    .Select(scope => CaptureAsyncScopeBinding(scope, name)));
                var owns = hidden.Scope.BorrowedOwnedTransferFlags.ContainsKey(name)
                    || (!hidden.Scope.BorrowedOwnedLocals.Contains(name)
                        && !hidden.Scope.BorrowedMutableLocals.Contains(name));
                var existing = spillPlans.FindIndex(plan =>
                    AsyncSpillSharesBinding(plan, hidden.Scope, name, value, mutable));
                if (existing >= 0)
                {
                    var plan = spillPlans[existing];
                    spillPlans[existing] = plan with
                    {
                        ScopeBindings = [.. (plan.ScopeBindings ?? []), .. bindings],
                        DropOnCancel = plan.DropOnCancel || owns
                    };
                    continue;
                }
                var fields = hidden.Scope.MovedOwnedStructFields.TryGetValue(name, out var moved)
                    ? moved.Order(StringComparer.Ordinal).ToArray()
                    : [];
                spillPlans.Add(new AsyncSpillPlan(
                    NextAsyncBindingName("hidden_binding"), value.Type, mutable, fields,
                    hidden.Scope, name, bindings, owns,
                    hidden.Scope.BorrowedOwnedTransferFlags.ContainsKey(name)));
            }
        }
        return spillPlans;
    }

    private bool AsyncSpillSharesBinding(
        AsyncSpillPlan plan, LocalScope scope, string name, RuntimeValue value, bool mutable)
    {
        var source = plan.SourceScope;
        var sourceName = plan.SourceName ?? plan.Name;
        var sourceValue = source is null ? _locals[sourceName] : source.Locals[sourceName];
        if (plan.IsMutable != mutable || sourceValue.Type != value.Type
            || (!mutable && !ReferenceEquals(sourceValue, value)))
            return false;
        var flags = source?.BorrowedOwnedTransferFlags ?? _borrowedOwnedTransferFlags;
        if (flags.GetValueOrDefault(sourceName) != scope.BorrowedOwnedTransferFlags.GetValueOrDefault(name))
            return false;
        if (!mutable)
            return true;
        var scalars = source?.MutableScalarSlots ?? _mutableScalarSlots;
        var structs = source?.MutableStructSlots ?? _mutableStructSlots;
        var containers = source?.MutableContainerSlots ?? _mutableContainerSlots;
        return (scalars.ContainsKey(sourceName) || structs.ContainsKey(sourceName)
                || containers.ContainsKey(sourceName))
            && scalars.GetValueOrDefault(sourceName) == scope.MutableScalarSlots.GetValueOrDefault(name)
            && structs.GetValueOrDefault(sourceName) == scope.MutableStructSlots.GetValueOrDefault(name)
            && containers.GetValueOrDefault(sourceName) == scope.MutableContainerSlots.GetValueOrDefault(name);
    }

    private static bool AsyncScopeSharesBinding(
        LocalScope source, string sourceName, LocalScope target, string targetName)
    {
        return source.Locals.TryGetValue(sourceName, out var sourceValue)
            && target.Locals.TryGetValue(targetName, out var targetValue)
            && sourceValue.Type == targetValue.Type
            && source.MutableLocals.Contains(sourceName) == target.MutableLocals.Contains(targetName)
            && (source.MutableLocals.Contains(sourceName)
                ? source.MutableScalarSlots.ContainsKey(sourceName)
                    || source.MutableStructSlots.ContainsKey(sourceName)
                    || source.MutableContainerSlots.ContainsKey(sourceName)
                : ReferenceEquals(sourceValue, targetValue))
            && source.MutableScalarSlots.GetValueOrDefault(sourceName) == target.MutableScalarSlots.GetValueOrDefault(targetName)
            && source.MutableStructSlots.GetValueOrDefault(sourceName) == target.MutableStructSlots.GetValueOrDefault(targetName)
            && source.MutableContainerSlots.GetValueOrDefault(sourceName) == target.MutableContainerSlots.GetValueOrDefault(targetName)
            && source.BorrowedOwnedTransferFlags.GetValueOrDefault(sourceName) == target.BorrowedOwnedTransferFlags.GetValueOrDefault(targetName);
    }

    private static AsyncScopeBinding CaptureAsyncScopeBinding(LocalScope scope, string name) => new(
        scope, name, scope.Locals[name],
        scope.MutableScalarSlots.GetValueOrDefault(name),
        scope.MutableStructSlots.GetValueOrDefault(name),
        scope.MutableContainerSlots.GetValueOrDefault(name),
        scope.BorrowedOwnedTransferFlags.GetValueOrDefault(name));

    private static bool AsyncScopeBindingUnchanged(AsyncScopeBinding binding) =>
        binding.Scope.Locals.TryGetValue(binding.Name, out var value)
        && value.Type == binding.Value.Type
        && (binding.ScalarSlot is not null || binding.StructSlot is not null
            || binding.ContainerSlot is not null || ReferenceEquals(value, binding.Value))
        && binding.Scope.MutableScalarSlots.GetValueOrDefault(binding.Name) == binding.ScalarSlot
        && binding.Scope.MutableStructSlots.GetValueOrDefault(binding.Name) == binding.StructSlot
        && binding.Scope.MutableContainerSlots.GetValueOrDefault(binding.Name) == binding.ContainerSlot
        && binding.Scope.BorrowedOwnedTransferFlags.GetValueOrDefault(binding.Name) == binding.OwnershipFlag;

    private void SuspendAndResumeCfgPoint(
        AsyncCfgLowering lowering,
        AsyncCfgSuspendPoint point,
        IReadOnlyList<AsyncSpillPlan> spillPlans)
    {
        var inputName = lowering.Function.InputName ?? "it";
        var suspendedScope = CaptureLocals();
        var ownsPrimaryInput = lowering.Function.InputOwnership == BoundFunctionInputOwnership.Move
            && lowering.Function.InputType is { } inputType
            && _program.Types.ContainsOwnedStorage(inputType)
            && _locals.ContainsKey(inputName);
        var ownedAdditionalInputIndexes = (lowering.Function.AdditionalParameters ?? [])
            .Select((parameter, index) => (parameter, index))
            .Where(item => item.parameter.Ownership == BoundFunctionInputOwnership.Move
                && _program.Types.ContainsOwnedStorage(item.parameter.Type)
                && _locals.ContainsKey(item.parameter.Name))
            .Select(static item => item.index)
            .ToArray();
        var movedInputFields = new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
        var inputScopeBindings = new Dictionary<string, AsyncScopeBinding[]>(StringComparer.Ordinal);
        foreach (var name in new[] { inputName }.Concat(
                     ownedAdditionalInputIndexes.Select(index =>
                         (lowering.Function.AdditionalParameters ?? [])[index].Name)))
        {
            if (_movedOwnedStructFields.TryGetValue(name, out var fields))
            {
                movedInputFields[name] = new HashSet<string>(fields, StringComparer.Ordinal);
                inputScopeBindings[name] = _asyncScopeSnapshots
                    .Where(scope => AsyncScopeSharesBinding(suspendedScope, name, scope, name))
                    .Select(scope => CaptureAsyncScopeBinding(scope, name)).ToArray();
            }
        }
        point.SetRuntimeShape(spillPlans, ownsPrimaryInput, ownedAdditionalInputIndexes);
        var spills = BuildRuntimeAsyncSpills(point.Spills);
        StoreAsyncSpills(lowering.Function, spills);
        foreach (var spill in spills)
        {
            RemoveLocal(spill.Name);
        }
        DropOwnedLocalsCreatedSince(lowering.ResumeBaseLocals, transferredOwnerName: null);
        EmitStore(
            "i32",
            point.State.ToString(CultureInfo.InvariantCulture),
            lowering.StateSlot,
            4);
        EmitRet("i1", "false");

        RestoreLocals(lowering.ResumeBaseLocals);
        if (lowering.Function.InputOwnership == BoundFunctionInputOwnership.Move
            && lowering.Function.InputType is { } resumedInputType
            && _program.Types.ContainsOwnedStorage(resumedInputType)
            && !point.OwnsPrimaryInput)
        {
            RemoveLocal(inputName);
        }
        var ownedAdditionalInputIndexSet = point.OwnedAdditionalInputIndexes.ToHashSet();
        var additionalParameters = lowering.Function.AdditionalParameters ?? [];
        for (var index = 0; index < additionalParameters.Count; index++)
        {
            var parameter = additionalParameters[index];
            if (parameter.Ownership == BoundFunctionInputOwnership.Move
                && _program.Types.ContainsOwnedStorage(parameter.Type)
                && !ownedAdditionalInputIndexSet.Contains(index))
            {
                RemoveLocal(parameter.Name);
            }
        }
        foreach (var (name, fields) in movedInputFields)
        {
            _movedOwnedStructFields[name] = new HashSet<string>(fields, StringComparer.Ordinal);
            foreach (var binding in inputScopeBindings[name].Where(AsyncScopeBindingUnchanged))
            {
                binding.Scope.MovedOwnedStructFields[binding.Name] = new HashSet<string>(fields, StringComparer.Ordinal);
            }
        }
        EmitLabel(point.ResumeLabel);
        _currentBlockLabel = point.ResumeLabel;
        LoadAsyncSpills(lowering.Function, spills);
        foreach (var spill in point.Spills.Where(spill => spill.MovedOwnedFields.Count > 0))
        {
            var fields = new HashSet<string>(spill.MovedOwnedFields, StringComparer.Ordinal);
            _movedOwnedStructFields[spill.Name] = fields;
        }
        RefreshAsyncScopeSnapshots(spills);
        foreach (var spill in point.Spills)
        {
            if (spill.SourceScope is not null)
                ForgetAsyncSpillCarrier(spill.Name);
        }
    }

    private void ForgetAsyncSpillCarrier(string name)
    {
        // This is a compiler-only alias, not an ownership transfer. Its
        // resumed flag/slot now belongs to the exact registered scope.
        _locals.Remove(name);
        _mutableLocals.Remove(name);
        _borrowedMutableLocals.Remove(name);
        _borrowedOwnedLocals.Remove(name);
        _movedOwnedStructFields.Remove(name);
        _mutableContainerSlots.Remove(name);
        _mutableStructSlots.Remove(name);
        _mutableScalarSlots.Remove(name);
        _borrowedOwnedTransferFlags.Remove(name);
        _readonlyCaptureBorrowPointers.Remove(name);
    }

    private void RefreshAsyncScopeSnapshots(IReadOnlyList<RuntimeAsyncSpill> spills)
    {
        foreach (var spill in spills)
        {
            var value = _locals[spill.Name];
            foreach (var binding in spill.ScopeBindings.Where(AsyncScopeBindingUnchanged))
            {
                var scope = binding.Scope;
                scope.Locals[binding.Name] = value;
                scope.MovedOwnedStructFields[binding.Name] = new HashSet<string>(
                    spill.MovedOwnedFields, StringComparer.Ordinal);
                if (_borrowedOwnedTransferFlags.TryGetValue(spill.Name, out var transferFlag))
                {
                    scope.BorrowedOwnedTransferFlags[binding.Name] = transferFlag;
                    var resumedObligation = _terminatingOwnedCleanupObligations.FirstOrDefault(obligation =>
                        string.Equals(obligation.BindingName, spill.Name, StringComparison.Ordinal)
                        && ReferenceEquals(obligation.Value, value)
                        && string.Equals(obligation.RetainedFlag, transferFlag, StringComparison.Ordinal));
                    if (resumedObligation is not null)
                    {
                        var obligationIndex = scope.TerminatingOwnedCleanupObligations.FindIndex(
                            obligation => obligation.BindingId == resumedObligation.BindingId);
                        if (obligationIndex >= 0)
                        {
                            scope.TerminatingOwnedCleanupObligations[obligationIndex] = resumedObligation;
                        }
                    }
                    for (var index = 0; index < scope.TerminatingOwnedCleanupObligations.Count; index++)
                    {
                        var obligation = scope.TerminatingOwnedCleanupObligations[index];
                        if (string.Equals(obligation.BindingName, binding.Name, StringComparison.Ordinal)
                            && ReferenceEquals(obligation.Value, binding.Value))
                        {
                            scope.TerminatingOwnedCleanupObligations[index] = obligation with
                            {
                                Value = value, RetainedFlag = transferFlag
                            };
                        }
                    }
                }
                if (!spill.IsMutable)
                {
                    continue;
                }
                if (_mutableContainerSlots.TryGetValue(spill.Name, out var container))
                {
                    scope.MutableContainerSlots[binding.Name] = container;
                }
                if (_mutableStructSlots.TryGetValue(spill.Name, out var structure))
                {
                    scope.MutableStructSlots[binding.Name] = structure;
                }
                if (_mutableScalarSlots.TryGetValue(spill.Name, out var scalar))
                {
                    scope.MutableScalarSlots[binding.Name] = scalar;
                }
            }
        }
    }

    private void StoreSuspendedChild(BoundFunction function, RuntimeTask child)
    {
        EmitAsyncContextStore(
            "%context", function.InputType, function.ReturnType, 7,
            "ptr", child.HandleName, 8);
        EmitAsyncContextStore(
            "%context", function.InputType, function.ReturnType, 8,
            "ptr", child.ContextName, 8);
        EmitCall(
            target: null,
            "void",
            "sollang_task_park_on",
            $"ptr %control, ptr {child.HandleName}");
    }

    private RuntimeValue EmitStoredChildAwait(BoundFunction function, RuntimeTask child)
    {
        var childHandleAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 7, "async_child_handle_address");
        var childHandle = NextTemp("async_child_handle");
        EmitLoad(childHandle, "ptr", childHandleAddress, 8);
        var childContextAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 8, "async_child_context_address");
        var childContext = NextTemp("async_child_context");
        EmitLoad(childContext, "ptr", childContextAddress, 8);
        var resumedChild = child with
        {
            HandleName = childHandle,
            ContextName = childContext,
            DiagnosticHeaderName = child.DiagnosticHeaderName is null
                ? null
                : AsyncContextField(
                    childContext, child.InputType, child.ResultType, 10, "async_child_diagnostic_header")
        };
        return EmitAwaitTask(resumedChild);
    }

    private IReadOnlyList<RuntimeAsyncSpill> BuildRuntimeAsyncSpills(
        IReadOnlyList<AsyncSpillPlan> spillPlans)
    {
        var spills = new List<RuntimeAsyncSpill>(spillPlans.Count);
        var offset = 0;
        foreach (var spill in spillPlans)
        {
            var active = spill.SourceScope is null ? null : CaptureLocals();
            if (spill.SourceScope is { } sourceScope)
                RestoreLocals(sourceScope);
            try
            {
                var sourceName = spill.SourceName ?? spill.Name;
                var value = ResolveLocal(sourceName);
                EnsureRuntimeType(value, spill.Type, spill.Name);
                var materialized = MaterializeAggregateValue(value);
                var alignment = RuntimeAlignment(spill.Type);
                offset = AlignAsyncSize(offset, alignment);
                var valueOffset = offset;
                offset = checked(offset + Math.Max(_program.Types.InlineSizeOf(spill.Type), 1));
                var ownershipFlagPointer = _borrowedOwnedTransferFlags.GetValueOrDefault(sourceName);
                int? ownershipFlagOffset = null;
                if (ownershipFlagPointer is not null)
                {
                    ownershipFlagOffset = offset;
                    offset = checked(offset + 1);
                }
                spills.Add(new RuntimeAsyncSpill(
                    spill.Name,
                    spill.Type,
                    valueOffset,
                    alignment,
                    materialized.TypeName,
                    materialized.ValueName,
                    spill.IsMutable,
                    value,
                    ownershipFlagPointer,
                    ownershipFlagOffset,
                    _borrowedOwnedLocals.Contains(sourceName),
                    _borrowedMutableLocals.Contains(sourceName),
                    spill.ScopeBindings ?? [],
                    spill.MovedOwnedFields));
            }
            finally
            {
                if (active is not null)
                    RestoreLocals(active);
            }
        }

        return spills;
    }

    private void StoreAsyncSpills(
        BoundFunction function,
        IReadOnlyList<RuntimeAsyncSpill> spills)
    {
        if (spills.Count == 0)
        {
            return;
        }

        var size = spills.Max(spill => spill.OwnershipFlagOffset is { } flagOffset
            ? checked(flagOffset + 1)
            : checked(spill.Offset + Math.Max(_program.Types.InlineSizeOf(spill.Type), 1)));
        var frame = NextTemp("async_spill_frame");
        EmitCall(frame, "ptr", "sollang_alloc", $"i64 {size}");
        EmitAsyncContextStore(
            "%context", function.InputType, function.ReturnType, 9,
            "ptr", frame, 8);
        foreach (var spill in spills)
        {
            var address = NextTemp("async_spill_address");
            EmitAssign(address, $"getelementptr i8, ptr {frame}, i64 {spill.Offset}");
            EmitStore(spill.LlvmType, spill.ValueName, address, spill.Alignment);
            if (spill.OwnershipFlagPointer is not null
                && spill.OwnershipFlagOffset is { } ownershipFlagOffset)
            {
                var flag = NextTemp("async_spill_owned_flag");
                EmitLoad(flag, "i1", spill.OwnershipFlagPointer, 1);
                var flagAddress = NextTemp("async_spill_owned_flag_address");
                EmitAssign(flagAddress, $"getelementptr i8, ptr {frame}, i64 {ownershipFlagOffset}");
                EmitStore("i1", flag, flagAddress, 1);
            }
        }
    }

    private void LoadAsyncSpills(
        BoundFunction function,
        IReadOnlyList<RuntimeAsyncSpill> spills)
    {
        if (spills.Count == 0)
        {
            return;
        }

        var frameAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 9, "async_spill_frame_address");
        var frame = NextTemp("async_spill_frame");
        EmitLoad(frame, "ptr", frameAddress, 8);
        foreach (var spill in spills)
        {
            var address = NextTemp("async_spill_address");
            EmitAssign(address, $"getelementptr i8, ptr {frame}, i64 {spill.Offset}");
            var loaded = NextTemp("async_spill_value");
            EmitLoad(loaded, spill.LlvmType, address, spill.Alignment);
            var value = spill.Template is RuntimeTask task
                ? DematerializeTask(task, loaded)
                : DematerializeAggregateValue(spill.Type, loaded);
            _locals[spill.Name] = value;
            if (spill.IsBorrowedOwned)
                _borrowedOwnedLocals.Add(spill.Name);
            if (spill.IsBorrowedMutable)
                _borrowedMutableLocals.Add(spill.Name);
            if (spill.OwnershipFlagOffset is { } ownershipFlagOffset)
            {
                var storedFlagAddress = NextTemp("async_spill_owned_flag_address");
                EmitAssign(storedFlagAddress, $"getelementptr i8, ptr {frame}, i64 {ownershipFlagOffset}");
                var storedFlag = NextTemp("async_spill_owned_flag");
                EmitLoad(storedFlag, "i1", storedFlagAddress, 1);
                var resumedFlag = NextTemp("async_spill_owned_flag_slot");
                EmitAlloca(resumedFlag, "i1", 1);
                EmitStore("i1", storedFlag, resumedFlag, 1);
                _borrowedOwnedTransferFlags[spill.Name] = resumedFlag;
                var obligationIndex = _terminatingOwnedCleanupObligations.FindIndex(obligation =>
                    string.Equals(obligation.BindingName, spill.Name, StringComparison.Ordinal)
                    && ReferenceEquals(obligation.Value, spill.Template)
                    && string.Equals(
                        obligation.RetainedFlag,
                        spill.OwnershipFlagPointer,
                        StringComparison.Ordinal));
                var suspendedObligation = obligationIndex >= 0
                    ? _terminatingOwnedCleanupObligations[obligationIndex]
                    : _asyncScopeSnapshots
                        .SelectMany(static scope => scope.TerminatingOwnedCleanupObligations)
                        .FirstOrDefault(obligation =>
                            string.Equals(obligation.BindingName, spill.Name, StringComparison.Ordinal)
                            && ReferenceEquals(obligation.Value, spill.Template)
                            && string.Equals(
                                obligation.RetainedFlag,
                                spill.OwnershipFlagPointer,
                                StringComparison.Ordinal));
                if (obligationIndex < 0 && suspendedObligation is not null)
                {
                    var suspendedGroup = _asyncScopeSnapshots
                        .SelectMany(static scope => scope.TerminatingOwnedCleanupObligations)
                        .Where(obligation => obligation.BindingId == suspendedObligation.BindingId)
                        .Distinct()
                        .ToArray();
                    _terminatingOwnedCleanupObligations.AddRange(suspendedGroup);
                    obligationIndex = _terminatingOwnedCleanupObligations.FindIndex(obligation =>
                        obligation.BindingId == suspendedObligation.BindingId
                        && ReferenceEquals(obligation.Value, spill.Template));
                }
                if (obligationIndex >= 0)
                {
                    _terminatingOwnedCleanupObligations[obligationIndex] =
                        _terminatingOwnedCleanupObligations[obligationIndex] with
                        {
                            Value = value,
                            RetainedFlag = resumedFlag
                        };
                }
            }
            if (spill.IsMutable)
            {
                CreateResumedMutableSlot(spill.Name, value);
            }
        }
        EmitCall(target: null, "void", "sollang_free", $"ptr {frame}");
        EmitStore("ptr", "null", frameAddress, 8);
    }

    private RuntimeTask DematerializeTask(RuntimeTask template, string aggregate)
    {
        var handle = NextTemp("async_spill_task_handle");
        EmitAssign(handle, $"extractvalue %sollang.task {aggregate}, 0");
        var context = NextTemp("async_spill_task_context");
        EmitAssign(context, $"extractvalue %sollang.task {aggregate}, 1");
        return template with
        {
            HandleName = handle,
            ContextName = context,
            DiagnosticHeaderName = template.DiagnosticHeaderName is null
                ? null
                : AsyncContextField(
                    context, template.InputType, template.ResultType, 10, "async_spill_task_diagnostic_header")
        };
    }

    private void StoreAsyncResult(BoundFunction function, RuntimeValue value)
    {
        var result = MaterializeAsyncResult(value);
        var resultAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 6, "async_result_address");
        EmitStore(result.TypeName, result.ValueName, resultAddress, RuntimeAlignment(function.ReturnType));
    }

    private void EmitPropagatedResultReturn(BoundFunction function, RuntimeValue value)
    {
        if (function.IsAsync)
        {
            StoreAsyncResult(function, value);
            EmitMarkCurrentDiagnosticTerminal(2);
            EmitRet("i1", "true");
            return;
        }

        var materialized = MaterializeAggregateValue(value);
        EmitRet(materialized.TypeName, materialized.ValueName);
    }

    private bool TryGetCfgSuspendPlan(BoundFunction function, out AsyncCfgPlan? plan)
    {
        plan = null;
        var candidates = new List<AsyncCfgCandidate>();
        CollectCfgSuspensions(function.BlockBody, candidates);
        if (function.Body is not null)
        {
            CollectCfgSuspensions(function.Body, candidates);
        }
        // Linear and tail awaits need the same per-suspension ownership and
        // spill shape as nested awaits. A syntactic fast path cannot keep
        // start-block SSA owners alive on a resumed or cancelled worker.
        if (candidates.Count == 0)
        {
            return false;
        }

        var points = candidates
            .Select((candidate, index) => new AsyncCfgSuspendPoint(
                index + 1,
                candidate.Site,
                candidate.IsYield))
            .ToArray();
        plan = new AsyncCfgPlan(points);
        return true;
    }

    private static void CollectCfgSuspensions(
        IReadOnlyList<Statement> statements,
        List<AsyncCfgCandidate> candidates)
    {
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    if (TryGetAwaitTaskName(binding, out _))
                    {
                        candidates.Add(new AsyncCfgCandidate(binding, IsYield: false));
                    }
                    else
                    {
                        CollectCfgSuspensions(binding.Value, candidates);
                    }
                    break;
                case ExpressionStatement { Expression: NameExpression { Name: "yield" } } yield:
                    candidates.Add(new AsyncCfgCandidate(yield, IsYield: true));
                    break;
                case ExpressionStatement expression:
                    if (TryGetAwaitTaskExpression(expression.Expression, out _))
                    {
                        var flow = (FlowExpression)expression.Expression;
                        CollectCfgFlowSuspensions(flow, candidates, flow.Targets.Count - 1);
                        candidates.Add(new AsyncCfgCandidate(expression, IsYield: false));
                    }
                    else
                    {
                        CollectCfgSuspensions(expression.Expression, candidates);
                    }
                    break;
                case BlockFunctionCallStatement block:
                    CollectCfgSuspensions(block.Source, candidates);
                    foreach (var argument in block.Arguments ?? [])
                    {
                        CollectCfgSuspensions(argument, candidates);
                    }
                    CollectCfgSuspensions(block.Body, candidates);
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    foreach (var block in pipeline.Calls)
                    {
                        CollectCfgSuspensions(block.Source, candidates);
                        foreach (var argument in block.Arguments ?? [])
                        {
                            CollectCfgSuspensions(argument, candidates);
                        }
                        CollectCfgSuspensions(block.Body, candidates);
                    }
                    break;
            }
        }
    }

    private static void CollectCfgSuspensions(
        Expression expression,
        List<AsyncCfgCandidate> candidates)
    {
        if (TryGetAwaitTaskExpression(expression, out _))
        {
            var flow = (FlowExpression)expression;
            CollectCfgFlowSuspensions(flow, candidates, flow.Targets.Count - 1);
            candidates.Add(new AsyncCfgCandidate(expression, IsYield: false));
            return;
        }

        switch (expression)
        {
            case StringExpression text:
                foreach (var segment in text.Segments.OfType<InterpolationSegment>())
                {
                    CollectCfgSuspensions(segment.Expression, candidates);
                }
                break;
            case FlowExpression flow:
                CollectCfgFlowSuspensions(flow, candidates, flow.Targets.Count);
                break;
            case CallExpression call:
                foreach (var argument in call.Arguments)
                    CollectCfgSuspensions(argument, candidates);
                break;
            case FieldAccessExpression field:
                CollectCfgSuspensions(field.Source, candidates);
                break;
            case IfExpression conditional:
                CollectCfgSuspensions(conditional.Then.Statements, candidates);
                if (conditional.Then.Value is not null)
                {
                    CollectCfgSuspensions(conditional.Then.Value, candidates);
                }
                if (conditional.Else is not null)
                {
                    CollectCfgSuspensions(conditional.Else.Statements, candidates);
                    if (conditional.Else.Value is not null)
                    {
                        CollectCfgSuspensions(conditional.Else.Value, candidates);
                    }
                }
                break;
            case WhenExpression selection:
                foreach (var arm in selection.Arms)
                {
                    CollectCfgSuspensions(arm.Body.Statements, candidates);
                    if (arm.Body.Value is not null)
                    {
                        CollectCfgSuspensions(arm.Body.Value, candidates);
                    }
                }
                CollectCfgSuspensions(selection.Else.Statements, candidates);
                if (selection.Else.Value is not null)
                {
                    CollectCfgSuspensions(selection.Else.Value, candidates);
                }
                break;
            case EnumMatchExpression selection:
                foreach (var arm in selection.Arms)
                {
                    CollectCfgSuspensions(arm.Body.Statements, candidates);
                    if (arm.Body.Value is not null)
                    {
                        CollectCfgSuspensions(arm.Body.Value, candidates);
                    }
                }
                if (selection.Else is not null)
                {
                    CollectCfgSuspensions(selection.Else.Statements, candidates);
                    if (selection.Else.Value is not null)
                    {
                        CollectCfgSuspensions(selection.Else.Value, candidates);
                    }
                }
                break;
            default:
                foreach (var child in ExpressionChildren(expression))
                    CollectCfgSuspensions(child, candidates);
                break;
        }
    }

    private static void CollectCfgFlowSuspensions(
        FlowExpression flow, List<AsyncCfgCandidate> candidates, int targetCount)
    {
        CollectCfgSuspensions(flow.Source, candidates);
        for (var index = 0; index < targetCount; index++)
        {
            var target = flow.Targets[index];
            foreach (var argument in target.Arguments)
                CollectCfgSuspensions(argument, candidates);
            if (target.Path.Count == 1 && target.Path[0] == "await" && target.Arguments.Count == 0)
                candidates.Add(new AsyncCfgCandidate(target, IsYield: false));
        }
    }

    private static bool TryGetAwaitTaskName(BindingStatement binding, out string taskName)
    {
        if (!binding.IsMutable
            && binding.Value is FlowExpression
            {
                Source: NameExpression source,
                Targets.Count: 1
            } flow
            && flow.Targets[0].Path.Count == 1
            && string.Equals(flow.Targets[0].Path[0], "await", StringComparison.Ordinal)
            && flow.Targets[0].Arguments.Count == 0)
        {
            taskName = source.Name;
            return true;
        }

        taskName = string.Empty;
        return false;
    }

    private static bool TryGetAwaitTaskExpression(Expression expression, out Expression taskExpression)
    {
        if (expression is FlowExpression flow
            && flow.Targets.Count > 0
            && flow.Targets[^1].Path.Count == 1
            && string.Equals(flow.Targets[^1].Path[0], "await", StringComparison.Ordinal)
            && flow.Targets[^1].Arguments.Count == 0)
        {
            taskExpression = flow.Targets.Count == 1
                ? flow.Source
                : new FlowExpression(flow.Source, flow.Targets.Take(flow.Targets.Count - 1).ToArray(), flow.Line, flow.Column);
            return true;
        }

        taskExpression = null!;
        return false;
    }

    private bool IsAsyncSpillType(BoundType type)
    {
        return IsAsyncSpillType(type, new HashSet<BoundType>());
    }

    private bool IsAsyncSpillType(BoundType type, HashSet<BoundType> visiting)
    {
        if (IsIntegerType(type)
            || IsFloatType(type)
            || type is BoundType.Bool or BoundType.Text or BoundType.Arguments
                or BoundType.MappedBytes or BoundType.MutableMappedBytes
            || _program.Types.IsBox(type)
            || _program.Types.IsTask(type)
            || _program.Types.IsStream(type)
            || _program.Types.IsEventStream(type)
            || type == BoundType.DynamicIntArray
            || type == BoundType.IntDictionary
            || _program.Types.IsStaticArray(type)
            || _program.Types.IsDynamicArray(type)
            || _program.Types.IsBoundedArray(type)
            || _program.Types.IsDictionary(type)
            || _program.Types.IsSet(type)
            || _program.Types.IsDeque(type))
        {
            return true;
        }
        if (!visiting.Add(type))
        {
            return true;
        }

        try
        {
            if (_program.Types.IsSlice(type))
                return IsAsyncSpillType(_program.Types.GetSliceElement(type), visiting);
            if (_program.Types.IsStruct(type))
            {
                return _program.Types.GetStruct(type).Fields.All(field =>
                    IsAsyncSpillType(field.Type, visiting));
            }
            if (_program.Types.IsEnum(type))
            {
                return _program.Types.GetEnum(type).Variants.All(variant =>
                    variant.PayloadType is null
                    || IsAsyncSpillType(variant.PayloadType.Value, visiting));
            }
            return false;
        }
        finally
        {
            visiting.Remove(type);
        }
    }

    private bool IsAsyncMutableSpillType(BoundType type)
    {
        return IsIntegerType(type)
            || IsFloatType(type)
            || type is BoundType.Bool or BoundType.Text
            || _program.Types.IsStruct(type)
            || type == BoundType.DynamicIntArray
            || type == BoundType.IntDictionary
            || _program.Types.IsStaticArray(type)
            || _program.Types.IsDynamicArray(type)
            || _program.Types.IsBoundedArray(type)
            || _program.Types.IsDictionary(type)
            || _program.Types.IsSet(type)
            || _program.Types.IsDeque(type);
    }

    private void CreateResumedMutableSlot(string name, RuntimeValue value)
    {
        _mutableLocals.Add(name);
        if (value is RuntimeStruct structure)
        {
            var pointer = NextTemp("async_mutable_struct_slot");
            EmitAlloca(pointer, LlvmStructType(structure.Type), RuntimeAlignment(structure.Type));
            EmitStore(LlvmStructType(structure.Type), structure.ValueName, pointer, RuntimeAlignment(structure.Type));
            _mutableStructSlots[name] = pointer;
            return;
        }
        if (value is RuntimeInt or RuntimeFloat or RuntimeBool or RuntimeText)
        {
            var materialized = MaterializeAggregateValue(value);
            var pointer = NextTemp("async_mutable_scalar_slot");
            EmitAlloca(pointer, materialized.TypeName, RuntimeAlignment(value.Type));
            EmitStore(materialized.TypeName, materialized.ValueName, pointer, RuntimeAlignment(value.Type));
            _mutableScalarSlots[name] = pointer;
            return;
        }

        var slot = new MutableContainerSlot(
            NextTemp("async_mutable_ptr_slot"),
            NextTemp("async_mutable_len_slot"),
            NextTemp("async_mutable_capacity_slot"),
            StackAllocation: null);
        EmitAlloca(slot.PointerAddress, "ptr", 8);
        EmitAlloca(slot.LengthAddress, "i64", 8);
        EmitAlloca(slot.CapacityAddress, "i64", 8);
        _mutableContainerSlots[name] = slot;
        StoreMutableContainer(name, value);
    }

    private RuntimeTask EmitAsyncFunctionCall(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments)
    {
        var aggregate = NextTemp("task_call");
        EmitCall(
            aggregate,
            "%sollang.task",
            SymbolForFunction(function)[1..],
            FunctionCallArgumentList(function, argument, additionalArguments));
        var handle = NextTemp("task_handle");
        EmitAssign(handle, $"extractvalue %sollang.task {aggregate}, 0");
        var context = NextTemp("task_context");
        EmitAssign(context, $"extractvalue %sollang.task {aggregate}, 1");
        return CreateRuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            function.InputType,
            function.ReturnType,
            handle,
            context,
            function);
    }

    private RuntimeValue EmitAwaitTask(RuntimeTask task, bool discardResult = false)
    {
        var waitSucceeded = NextTemp("task_wait_succeeded");
        EmitCall(waitSucceeded, "i1", "sollang_task_join", $"ptr {task.HandleName}");
        var waitedLabel = NextLabel("task_waited");
        var waitFailedLabel = NextLabel("task_wait_failed");
        EmitConditionalBranch(waitSucceeded, waitedLabel, waitFailedLabel);
        EmitLabel(waitFailedLabel);
        EmitTrap();
        EmitLabel(waitedLabel);
        if (task.RuntimeFunction is null)
        {
            var completionSlot = TaskControlField(task.HandleName, 22, "erased_task_completion_slot");
            var completion = NextTemp("erased_task_completion");
            EmitLoad(completion, "ptr", completionSlot, 8);
            var needsCompletion = NextTemp("erased_task_needs_completion");
            EmitCompare(needsCompletion, "ne", "ptr", completion, "null");
            var completeLabel = NextLabel("erased_task_complete");
            var readyLabel = NextLabel("erased_task_result_ready");
            EmitConditionalBranch(needsCompletion, completeLabel, readyLabel);
            EmitLabel(completeLabel);
            EmitInstruction($"call void {completion}(ptr {task.HandleName})");
            EmitStore("ptr", "null", completionSlot, 8);
            EmitBranch(readyLabel);
            EmitLabel(readyLabel);
            _currentBlockLabel = readyLabel;
        }
        else
        {
            EmitRuntimeTaskResultCompletion(task);
        }
        string resultAddress;
        if (task.RuntimeFunction is null)
        {
            resultAddress = NextTemp("erased_task_result_address");
            EmitLoad(resultAddress, "ptr", TaskControlField(task.HandleName, 21, "erased_task_result_slot"), 8);
        }
        else
        {
            resultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "task_result_address");
        }
        var loaded = NextTemp(discardResult ? "task_discarded_result" : "task_result");
        EmitLoad(loaded, AsyncStorageLlvmType(task.ResultType), resultAddress, RuntimeAlignment(task.ResultType));
        var value = DematerializeAsyncResult(task.ResultType, loaded);
        if (discardResult && _program.Types.ContainsOwnedStorage(task.ResultType))
        {
            DropOwnedRuntimeValue(value);
        }
        if (_usesAsyncDiagnostics && DiagnosticHeaderForTask(task) is { } diagnosticHeader)
        {
            EmitMarkDiagnosticHeaderTerminal(diagnosticHeader, 2);
            EmitDetachDiagnosticHeader(diagnosticHeader);
        }
        var closeSucceeded = NextTemp("task_close_succeeded");
        EmitCall(closeSucceeded, "i1", "sollang_task_release", $"ptr {task.HandleName}");
        var closedLabel = NextLabel("task_closed");
        var closeFailedLabel = NextLabel("task_close_failed");
        EmitConditionalBranch(closeSucceeded, closedLabel, closeFailedLabel);
        EmitLabel(closeFailedLabel);
        EmitTrap();
        EmitLabel(closedLabel);
        _currentBlockLabel = closedLabel;
        return value;
    }

    // The two-pointer Task value may cross aggregate/function boundaries. Its
    // control block owns the producer-dependent result address and adapter.
    private RuntimeTask CreateRuntimeTask(
        BoundType taskType, BoundType? inputType, BoundType resultType,
        string handle, string context, BoundFunction? function = null,
        string? DiagnosticHeaderName = null)
    {
        EmitInitializeTaskResult(handle, context, inputType, resultType, function);
        if (_usesAsyncDiagnostics && function is not { Kind: BoundFunctionKind.User, IsAsync: true })
        {
            var header = DiagnosticHeaderName
                ?? AsyncContextField(context, inputType, resultType, 10, "task_created_diagnostic_header");
            if (DiagnosticHeaderName is null)
            {
                EmitInitializeAsyncDiagnosticHeader(header, _currentAsyncDiagnosticHeader);
                EmitAttachInheritedDiagnosticRecord(header, handle);
            }
            EmitStore("ptr", header, TaskDiagnosticHeaderSlot(handle), 8);
        }
        return new RuntimeTask(taskType, inputType, resultType, handle, context, function, DiagnosticHeaderName);
    }

    private string TaskControlField(string handle, int field, string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 {field}");
        return address;
    }

    private void EmitInitializeTaskResult(
        string handle, string context, BoundType? inputType, BoundType resultType, BoundFunction? function)
    {
        var result = AsyncContextField(context, inputType, resultType, 6, "task_stored_result_address");
        EmitStore("ptr", result, TaskControlField(handle, 21, "task_stored_result_slot"), 8);
        var completion = function is not null && HasDeferredTaskResult(function)
            ? $"@{TaskResultCompletionSymbol(function)}"
            : "null";
        EmitStore("ptr", completion, TaskControlField(handle, 22, "task_stored_completion_slot"), 8);
    }

    private static bool HasDeferredTaskResult(BoundFunction function) => function.Kind is
        BoundFunctionKind.RuntimeReadScalarAsync
        or BoundFunctionKind.RuntimeWriteScalarAtAsync
        or BoundFunctionKind.RuntimeSyncFileAsync
        or BoundFunctionKind.RuntimeReadBytesAtAsync
        or BoundFunctionKind.RuntimeWriteBytesAtAsync
        or BoundFunctionKind.RuntimeOpenFileAsync
        or BoundFunctionKind.RuntimeOpenWriteFileAsync
        or BoundFunctionKind.RuntimeSocketCompletionDequeue;

    private static string TaskResultCompletionSymbol(BoundFunction function) =>
        SymbolForFunction(function)[1..] + "_task_result_complete";

    private void EmitTaskResultCompletionFunctions()
    {
        foreach (var function in _reachableFunctions.Where(HasDeferredTaskResult)
            .DistinctBy(TaskResultCompletionSymbol, StringComparer.Ordinal))
        {
            _currentFunction = function;
            _tempId = 0;
            _labelId = 0;
            ClearLocalState();
            EmitFunctionLine($"define internal void @{TaskResultCompletionSymbol(function)}(ptr %control) #0 {{");
            EmitLabel("entry");
            _currentBlockLabel = "entry";
            EmitLoad("%context", "ptr", TaskControlField("%control", 0, "task_completion_context_slot"), 8);
            EmitRuntimeTaskResultCompletion(new RuntimeTask(
                _program.Types.GetOrAddTask(function.ReturnType), function.InputType,
                function.ReturnType, "%control", "%context", function));
            EmitInstruction("ret void");
            _currentBlockTerminated = true;
            EmitFunctionLine("}");
            EmitFunctionLine();
        }
    }

    private void EmitRuntimeTaskResultCompletion(RuntimeTask task)
    {
        if (task.RuntimeFunction is { Kind: BoundFunctionKind.RuntimeReadScalarAsync } fileRead)
        {
            var fileResult = EmitRuntimeReadScalar(fileRead, task.HandleName);
            var fileResultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "file_task_result_address");
            EmitStore(
                LlvmEnumType(fileResult.Type),
                fileResult.ValueName,
                fileResultAddress,
                RuntimeAlignment(fileResult.Type));
        }
        else if (task.RuntimeFunction is { Kind: BoundFunctionKind.RuntimeWriteScalarAtAsync } fileWrite)
        {
            var fileResult = EmitRuntimeCompletedWriteScalarAt(fileWrite, task.HandleName);
            var fileResultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "file_write_task_result_address");
            EmitStore(
                LlvmEnumType(fileResult.Type),
                fileResult.ValueName,
                fileResultAddress,
                RuntimeAlignment(fileResult.Type));
        }
        else if (task.RuntimeFunction is { Kind: BoundFunctionKind.RuntimeSyncFileAsync } fileSync)
        {
            var fileResult = EmitRuntimeCompletedSyncFile(fileSync, task.HandleName);
            var fileResultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "file_sync_task_result_address");
            EmitStore(
                LlvmEnumType(fileResult.Type),
                fileResult.ValueName,
                fileResultAddress,
                RuntimeAlignment(fileResult.Type));
        }
        else if (task.RuntimeFunction is
                 {
                     Kind: BoundFunctionKind.RuntimeReadBytesAtAsync
                         or BoundFunctionKind.RuntimeWriteBytesAtAsync
                 } fileBuffer)
        {
            var fileResult = EmitRuntimeCompletedFileBuffer(
                fileBuffer,
                task.HandleName,
                task.ContextName);
            var fileResultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "file_buffer_task_result_address");
            EmitStore(
                LlvmEnumType(fileResult.Type),
                fileResult.ValueName,
                fileResultAddress,
                RuntimeAlignment(fileResult.Type));
        }
        else if (task.RuntimeFunction is
                 {
                     Kind: BoundFunctionKind.RuntimeOpenFileAsync
                         or BoundFunctionKind.RuntimeOpenWriteFileAsync
                 } fileOpen)
        {
            var fileResult = EmitRuntimeCompletedOpenFile(fileOpen, task.HandleName);
            var fileResultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "file_open_task_result_address");
            EmitStore(
                LlvmEnumType(fileResult.Type),
                fileResult.ValueName,
                fileResultAddress,
                RuntimeAlignment(fileResult.Type));
        }
        else if (task.RuntimeFunction is { Kind: BoundFunctionKind.RuntimeSocketCompletionDequeue } socketDequeue)
        {
            var socketResult = EmitRuntimeCompletedSocketDequeue(
                socketDequeue,
                task.HandleName,
                task.ContextName);
            var socketResultAddress = AsyncContextField(
                task.ContextName, task.InputType, task.ResultType, 6, "socket_completion_task_result_address");
            EmitStore(
                LlvmEnumType(socketResult.Type),
                socketResult.ValueName,
                socketResultAddress,
                RuntimeAlignment(socketResult.Type));
        }
    }

    private void EmitCancelTask(RuntimeTask task)
    {
        if (_usesAsyncDiagnostics && DiagnosticHeaderForTask(task) is { } diagnosticHeader)
        {
            EmitMarkDiagnosticHeaderTerminal(diagnosticHeader, 3);
            EmitDetachDiagnosticHeader(diagnosticHeader);
        }
        EmitCancelTaskHandle(task.HandleName);
    }

    private void EmitCancelTaskHandle(string handle)
    {
        var cancelled = NextTemp("task_cancel_succeeded");
        EmitCall(cancelled, "i1", "sollang_task_cancel", $"ptr {handle}");
        var cancelledLabel = NextLabel("task_cancelled");
        var cancelFailedLabel = NextLabel("task_cancel_failed");
        EmitConditionalBranch(cancelled, cancelledLabel, cancelFailedLabel);
        EmitLabel(cancelFailedLabel);
        _currentBlockLabel = cancelFailedLabel;
        EmitTrap();
        EmitLabel(cancelledLabel);
        _currentBlockLabel = cancelledLabel;
    }

    private void EmitAsyncContextLoad(
        string target, string context, BoundType? inputType, BoundType resultType,
        int field, string type, int alignment)
    {
        var address = AsyncContextField(context, inputType, resultType, field, "async_context_field");
        EmitLoad(target, type, address, alignment);
    }

    private void EmitAsyncContextStore(
        string context, BoundType? inputType, BoundType resultType,
        int field, string type, string value, int alignment)
    {
        var address = AsyncContextField(context, inputType, resultType, field, "async_context_field");
        EmitStore(type, value, address, alignment);
    }

    private void EmitAsyncFunctionContextLoad(
        string target,
        string context,
        BoundFunction function,
        int field,
        string type,
        int alignment)
    {
        var address = AsyncFunctionContextField(context, function, field, "async_function_context_field");
        EmitLoad(target, type, address, alignment);
    }

    private void EmitAsyncFunctionContextStore(
        string context,
        BoundFunction function,
        int field,
        string type,
        string value,
        int alignment)
    {
        var address = AsyncFunctionContextField(context, function, field, "async_function_context_field");
        EmitStore(type, value, address, alignment);
    }

    private string AsyncFunctionContextField(
        string context,
        BoundFunction function,
        int field,
        string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address,
            $"getelementptr {AsyncFunctionContextType(function)}, ptr {context}, i32 0, i32 {field}");
        return address;
    }

    private string AsyncFunctionDiagnosticHeader(
        string context,
        BoundFunction function,
        string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address,
            $"getelementptr {AsyncFunctionContextType(function)}, ptr {context}, i32 0, i32 {10 + (function.AdditionalParameters?.Count ?? 0)}");
        return address;
    }

    private void EmitInitializeAsyncFunctionDiagnosticHeader(
        string context,
        BoundFunction function,
        string parentHeader)
    {
        var header = AsyncFunctionDiagnosticHeader(context, function, "async_diagnostic_header");
        EmitInitializeAsyncDiagnosticHeader(header, parentHeader);
    }

    private void EmitInitializeAsyncDiagnosticHeader(string header, string parentHeader)
    {
        for (var index = 0; index < 6; index++)
        {
            var slot = NextTemp("async_diagnostic_header_slot");
            EmitAssign(slot,
                $"getelementptr {{ ptr, ptr, i64, i64, ptr, ptr }}, ptr {header}, i32 0, i32 {index}");
            var pointer = index < 2 || index >= 4;
            EmitStore(pointer ? "ptr" : "i64", pointer ? "null" : "0", slot, 8);
        }

        var hasParent = NextTemp("async_diagnostic_has_parent");
        EmitCompare(hasParent, "ne", "ptr", parentHeader, "null");
        var inheritLabel = NextLabel("async_diagnostic_inherit");
        var readyLabel = NextLabel("async_diagnostic_ready");
        EmitConditionalBranch(hasParent, inheritLabel, readyLabel);
        EmitLabel(inheritLabel);
        var parentSessionSlot = NextTemp("async_diagnostic_parent_session_slot");
        EmitAssign(parentSessionSlot,
            $"getelementptr {{ ptr, ptr, i64, i64, ptr, ptr }}, ptr {parentHeader}, i32 0, i32 0");
        var parentSession = NextTemp("async_diagnostic_parent_session");
        EmitLoad(parentSession, "ptr", parentSessionSlot, 8);
        var childSessionSlot = NextTemp("async_diagnostic_child_session_slot");
        EmitAssign(childSessionSlot,
            $"getelementptr {{ ptr, ptr, i64, i64, ptr, ptr }}, ptr {header}, i32 0, i32 0");
        EmitStore("ptr", parentSession, childSessionSlot, 8);
        var parentTaskIdSlot = NextTemp("async_diagnostic_parent_task_id_slot");
        EmitAssign(parentTaskIdSlot,
            $"getelementptr {{ ptr, ptr, i64, i64, ptr, ptr }}, ptr {parentHeader}, i32 0, i32 2");
        var parentTaskId = NextTemp("async_diagnostic_parent_task_id");
        EmitLoad(parentTaskId, "i64", parentTaskIdSlot, 8);
        var childParentIdSlot = NextTemp("async_diagnostic_child_parent_id_slot");
        EmitAssign(childParentIdSlot,
            $"getelementptr {{ ptr, ptr, i64, i64, ptr, ptr }}, ptr {header}, i32 0, i32 3");
        EmitStore("i64", parentTaskId, childParentIdSlot, 8);
        EmitBranch(readyLabel);
        EmitLabel(readyLabel);
    }

    private string AsyncContextField(
        string context, BoundType? inputType, BoundType resultType, int field, string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address, $"getelementptr {AsyncContextType(inputType, resultType)}, ptr {context}, i32 0, i32 {field}");
        return address;
    }

    private string AsyncContextType(BoundType? inputType, BoundType resultType)
    {
        var fields = new List<string>
        {
            "ptr", "ptr", "ptr", "ptr", "ptr",
            AsyncStorageLlvmType(inputType),
            AsyncStorageLlvmType(resultType),
            "ptr", "ptr", "ptr"
        };
        AppendAsyncDiagnosticHeaderFields(fields);
        return $"{{ {string.Join(", ", fields)} }}";
    }

    private string AsyncFunctionContextType(BoundFunction function)
    {
        var fields = new List<string>
        {
            "ptr", "ptr", "ptr", "ptr", "ptr",
            AsyncStorageLlvmType(function.InputType),
            AsyncStorageLlvmType(function.ReturnType),
            "ptr", "ptr", "ptr"
        };
        fields.AddRange((function.AdditionalParameters ?? [])
            .Select(parameter => AsyncStorageLlvmType(parameter.Type)));
        AppendAsyncDiagnosticHeaderFields(fields);
        return $"{{ {string.Join(", ", fields)} }}";
    }

    private void AppendAsyncDiagnosticHeaderFields(ICollection<string> fields)
    {
        if (_usesAsyncDiagnostics)
        {
            fields.Add("ptr");
            fields.Add("ptr");
            fields.Add("i64");
            fields.Add("i64");
            fields.Add("ptr");
            fields.Add("ptr");
        }
    }

    private string AsyncStorageLlvmType(BoundType? type) =>
        type is null or BoundType.Unit ? "i8" : LlvmType(type.Value);

    private int AsyncStorageAlignment(BoundType? type) =>
        type is null ? 1 : RuntimeAlignment(type.Value);

    private (string TypeName, string ValueName) MaterializeAsyncResult(RuntimeValue value) =>
        value is RuntimeUnit ? ("i8", "0") : MaterializeAggregateValue(value);

    private RuntimeValue DematerializeAsyncResult(BoundType type, string value) =>
        type == BoundType.Unit ? RuntimeUnit.Instance : DematerializeAggregateValue(type, value);

    private void DropFailedAsyncInput(BoundFunction function)
    {
        if (function.InputOwnership != BoundFunctionInputOwnership.Move
            || function.InputType is not { } inputType
            || !_program.Types.ContainsOwnedStorage(inputType))
        {
            return;
        }

        DropOwnedRuntimeValue(DematerializeAggregateValue(inputType, "%it"));
    }

    private void DropFailedAsyncAdditionalInputs(BoundFunction function)
    {
        var parameters = function.AdditionalParameters ?? [];
        for (var index = 0; index < parameters.Count; index++)
        {
            var parameter = parameters[index];
            if (parameter.Ownership == BoundFunctionInputOwnership.Move
                && _program.Types.ContainsOwnedStorage(parameter.Type))
            {
                DropOwnedRuntimeValue(DematerializeAggregateValue(parameter.Type, $"%arg_{index}"));
            }
        }
    }

    private void DropCancelledAsyncAdditionalInputs(
        BoundFunction function,
        IReadOnlyCollection<int>? ownedInputIndexes = null)
    {
        var parameters = function.AdditionalParameters ?? [];
        for (var index = 0; index < parameters.Count; index++)
        {
            var parameter = parameters[index];
            if (parameter.Ownership != BoundFunctionInputOwnership.Move
                || !_program.Types.ContainsOwnedStorage(parameter.Type)
                || (ownedInputIndexes is not null && !ownedInputIndexes.Contains(index)))
            {
                continue;
            }

            var value = NextTemp($"cancel_arg_{index}");
            EmitAsyncFunctionContextLoad(
                value,
                "%context",
                function,
                10 + index,
                AsyncStorageLlvmType(parameter.Type),
                RuntimeAlignment(parameter.Type));
            DropOwnedRuntimeValue(DematerializeAggregateValue(parameter.Type, value));
        }
    }

    private int AsyncContextSize(BoundFunction function)
    {
        var size = AsyncContextSizeCore(function.InputType, function.ReturnType);
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            var alignment = RuntimeAlignment(parameter.Type);
            size = AlignAsyncSize(size, alignment);
            size += Math.Max(_program.Types.InlineSizeOf(parameter.Type), 1);
        }
        if (_usesAsyncDiagnostics)
        {
            size = AlignAsyncSize(size, 8);
            size += AsyncDiagnosticHeaderBytes;
        }
        return size;
    }

    private int AsyncContextSize(BoundType? inputType, BoundType resultType)
    {
        var size = AsyncContextSizeCore(inputType, resultType);
        if (_usesAsyncDiagnostics)
        {
            size = AlignAsyncSize(size, 8);
            size += AsyncDiagnosticHeaderBytes;
        }
        return size;
    }

    private int AsyncContextSizeCore(BoundType? inputType, BoundType resultType)
    {
        var inputAlignment = AsyncStorageAlignment(inputType);
        var inputOffset = AlignAsyncSize(40, inputAlignment);
        var inputSize = inputType is null
            ? 1
            : Math.Max(_program.Types.InlineSizeOf(inputType.Value), 1);
        var resultAlignment = RuntimeAlignment(resultType);
        var resultOffset = AlignAsyncSize(inputOffset + inputSize, resultAlignment);
        var resultSize = Math.Max(_program.Types.InlineSizeOf(resultType), 1);
        var childTaskOffset = AlignAsyncSize(resultOffset + resultSize, 8);
        return childTaskOffset + 24;
    }

    private static int AlignAsyncSize(int value, int alignment) =>
        checked((value + alignment - 1) / alignment * alignment);

    private static string AsyncWorkerSymbol(BoundFunction function) =>
        SymbolForFunction(function)[1..] + "_async_worker";

    private static string AsyncCancelSymbol(BoundFunction function) =>
        SymbolForFunction(function)[1..] + "_async_cancel";

    private sealed class AsyncCfgPlan
    {
        public AsyncCfgPlan(IReadOnlyList<AsyncCfgSuspendPoint> points)
        {
            Points = points;
            BySite = points.ToDictionary(point => point.Site);
            ByBinding = points
                .Where(point => point.Site is BindingStatement)
                .ToDictionary(point => (BindingStatement)point.Site);
            ByYield = points
                .Where(point => point.Site is ExpressionStatement && point.IsYield)
                .ToDictionary(point => (ExpressionStatement)point.Site);
            ByAwaitExpressionStatement = points
                .Where(point => point.Site is ExpressionStatement && !point.IsYield)
                .ToDictionary(point => (ExpressionStatement)point.Site);
            ByAwaitExpression = points
                .Where(point => point.Site is Expression)
                .ToDictionary(point => (Expression)point.Site);
            ByFlowAwaitTarget = points
                .Where(point => point.Site is FlowTarget)
                .ToDictionary(point => (FlowTarget)point.Site);
        }

        public IReadOnlyList<AsyncCfgSuspendPoint> Points { get; }

        public IReadOnlyDictionary<object, AsyncCfgSuspendPoint> BySite { get; }

        public IReadOnlyDictionary<BindingStatement, AsyncCfgSuspendPoint> ByBinding { get; }

        public IReadOnlyDictionary<ExpressionStatement, AsyncCfgSuspendPoint> ByYield { get; }

        public IReadOnlyDictionary<ExpressionStatement, AsyncCfgSuspendPoint> ByAwaitExpressionStatement { get; }

        public IReadOnlyDictionary<Expression, AsyncCfgSuspendPoint> ByAwaitExpression { get; }

        public IReadOnlyDictionary<FlowTarget, AsyncCfgSuspendPoint> ByFlowAwaitTarget { get; }
    }

    private sealed class AsyncCfgSuspendPoint(int state, object site, bool isYield)
    {
        public int State { get; } = state;

        public object Site { get; } = site;

        public bool IsYield { get; } = isYield;

        public string ResumeLabel { get; set; } = string.Empty;

        public IReadOnlyList<AsyncSpillPlan> Spills { get; private set; } = [];

        public bool OwnsPrimaryInput { get; private set; }

        public IReadOnlyList<int> OwnedAdditionalInputIndexes { get; private set; } = [];

        public void SetRuntimeShape(
            IReadOnlyList<AsyncSpillPlan> spills,
            bool ownsPrimaryInput,
            IReadOnlyList<int> ownedAdditionalInputIndexes)
        {
            Spills = spills;
            OwnsPrimaryInput = ownsPrimaryInput;
            OwnedAdditionalInputIndexes = ownedAdditionalInputIndexes;
        }
    }

    private sealed record AsyncCfgLowering(
        BoundFunction Function,
        AsyncCfgPlan Plan,
        LocalScope ResumeBaseLocals,
        string StateSlot);

    private bool HasCurrentFunctionAsyncCfg() =>
        _activeAsyncCfg is { } lowering
        && ReferenceEquals(lowering.Function, _currentFunction);

    private sealed record AsyncCfgCandidate(object Site, bool IsYield);

    private sealed record AsyncSpillPlan(
        string Name,
        BoundType Type,
        bool IsMutable,
        IReadOnlyList<string> MovedOwnedFields,
        LocalScope? SourceScope = null,
        string? SourceName = null,
        IReadOnlyList<AsyncScopeBinding>? ScopeBindings = null,
        bool DropOnCancel = true,
        bool HasOwnershipFlag = false);

    private sealed record AsyncScopeBinding(
        LocalScope Scope, string Name, RuntimeValue Value,
        string? ScalarSlot, string? StructSlot, MutableContainerSlot? ContainerSlot,
        string? OwnershipFlag);

    private sealed record AsyncHiddenScope(LocalScope Scope, IReadOnlyList<LocalScope> Mirrors);

    private readonly Stack<AsyncHiddenScope> _asyncHiddenScopes = new();

    private readonly Dictionary<string, string> _asyncStreamCancellationBindings = new(StringComparer.Ordinal);

    private void RegisterAsyncStreamCancellationSlot(string slot)
    {
        if (_activeAsyncCfg is null)
            return;
        var name = NextAsyncBindingName("stream_cancellation");
        _asyncStreamCancellationBindings.Add(slot, name);
        _locals.Add(name, new RuntimeBool("false"));
        _mutableLocals.Add(name);
        _mutableScalarSlots.Add(name, slot);
    }

    private string ResolveAsyncStreamCancellationSlot(string slot)
    {
        if (!_asyncStreamCancellationBindings.TryGetValue(slot, out var name))
            return slot;
        if (_mutableScalarSlots.TryGetValue(name, out var pointer))
            return pointer;
        foreach (var hidden in _asyncHiddenScopes)
            if (hidden.Scope.MutableScalarSlots.TryGetValue(name, out pointer))
                return pointer;
        foreach (var scope in _asyncScopeSnapshots)
            if (scope.MutableScalarSlots.TryGetValue(name, out pointer))
                return pointer;
        throw new SollangException("async stream cancellation binding is not live");
    }

    private void UnregisterAsyncStreamCancellationSlot(string slot)
    {
        if (_asyncStreamCancellationBindings.Remove(slot, out var name))
            ForgetAsyncSpillCarrier(name);
    }

    private sealed record RuntimeAsyncSpill(
        string Name,
        BoundType Type,
        int Offset,
        int Alignment,
        string LlvmType,
        string ValueName,
        bool IsMutable,
        RuntimeValue Template,
        string? OwnershipFlagPointer,
        int? OwnershipFlagOffset,
        bool IsBorrowedOwned,
        bool IsBorrowedMutable,
        IReadOnlyList<AsyncScopeBinding> ScopeBindings,
        IReadOnlyList<string> MovedOwnedFields);
}
