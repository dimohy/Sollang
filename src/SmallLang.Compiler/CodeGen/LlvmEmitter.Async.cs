using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Semantics;
using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitAsyncFunction(BoundFunction function)
    {
        if (function.Body is null && function.ReturnType != BoundType.Unit)
        {
            throw new SmallLangException($"async function '{function.Name}' has no body");
        }

        var previousFunctions = _currentFunctions;
        _currentFunctions = CreateFunctionScope(_program.Functions, function.LocalFunctions);
        ClearLocalState();
        SelectStackFrame(function);
        try
        {
            var workerName = AsyncWorkerSymbol(function);
            var hasTailAwait = TryGetTailAwaitBinding(function, out var tailAwaitBinding);
            EmitFunctionLine($"define internal i1 @{workerName}(ptr %control) #0 {{");
            EmitLabel("entry");
            EmitStackFrameAllocations();
            _currentBlockLabel = "entry";

            var contextSlot = NextTemp("async_control_context_slot");
            EmitAssign(
                contextSlot,
                "getelementptr %smalllang.task_control, ptr %control, i32 0, i32 0");
            EmitLoad("%context", "ptr", contextSlot, 8);

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

            var functionLocals = CaptureLocals();
            BindFunctionParameter(function);
            if (hasTailAwait)
            {
                EmitTailAwaitWorker(function, tailAwaitBinding!, functionLocals);
            }
            else
            {
                EmitAsyncWorkerCompletion(function, functionLocals);
            }
            EmitFunctionLine("}");
            EmitFunctionLine();

            ClearLocalState();
            EmitFunctionLine($"define internal %smalllang.task {SymbolForFunction(function.Name)}({ParameterListForFunction(function)}) #0 {{");
            EmitLabel("entry");
            var context = NextTemp("async_context");
            EmitCall(context, "ptr", "smalllang_alloc", $"i64 {AsyncContextSize(function.InputType, function.ReturnType)}");
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

            var handle = NextTemp("async_handle");
            EmitCall(
                handle,
                "ptr",
                "smalllang_task_start",
                $"ptr @{workerName}, ptr @smalllang_free, ptr {context}");
            var started = NextTemp("async_started");
            EmitCompare(started, "ne", "ptr", handle, "null");
            var readyLabel = NextLabel("async_ready");
            var failedLabel = NextLabel("async_failed");
            EmitConditionalBranch(started, readyLabel, failedLabel);
            EmitLabel(failedLabel);
            DropFailedAsyncInput(function);
            EmitCall(target: null, "void", "smalllang_free", $"ptr {context}");
            EmitTrap();
            EmitLabel(readyLabel);

            var withHandle = NextTemp("task");
            EmitAssign(withHandle, $"insertvalue %smalllang.task poison, ptr {handle}, 0");
            var task = NextTemp("task");
            EmitAssign(task, $"insertvalue %smalllang.task {withHandle}, ptr {context}, 1");
            EmitRet("%smalllang.task", task);
            EmitFunctionLine("}");
            EmitFunctionLine();
        }
        finally
        {
            _currentFunctions = previousFunctions;
        }
    }

    private void EmitAsyncWorkerCompletion(BoundFunction function, LocalScope functionLocals)
    {
        EmitStatements(function.BlockBody);
        var movedBodySourceName = function.Body is null
            ? null
            : GetMoveConsumingContainerSourceName(function.Body);
        var value = function.Body is null
            ? RuntimeUnit.Instance
            : EmitExpression(function.Body);
        EnsureRuntimeType(value, function.ReturnType, function.Name);
        if (movedBodySourceName is not null)
        {
            RemoveLocal(movedBodySourceName);
        }
        var transferredOwnerName = IsOwnedContainerRuntimeValue(value)
            && function.Body is not null
            ? GetFunctionResultTransferredOwnerName(function, function.Body)
            : null;
        DropOwnedLocalsCreatedSince(functionLocals, transferredOwnerName);
        StoreAsyncResult(function, value);
        EmitRet("i1", "true");
    }

    private void EmitTailAwaitWorker(
        BoundFunction function,
        BindingStatement tailAwaitBinding,
        LocalScope functionLocals)
    {
        var stateSlot = NextTemp("async_resume_state_slot");
        EmitAssign(
            stateSlot,
            "getelementptr %smalllang.task_control, ptr %control, i32 0, i32 5");
        var state = NextTemp("async_resume_state");
        EmitLoad(state, "i32", stateSlot, 4);
        var startLabel = NextLabel("async_state_start");
        var resumeLabel = NextLabel("async_state_resume");
        var invalidLabel = NextLabel("async_state_invalid");
        EmitInstruction(
            $"switch i32 {state}, label %{invalidLabel} [ i32 0, label %{startLabel} i32 1, label %{resumeLabel} ]");
        _currentBlockTerminated = true;

        EmitLabel(invalidLabel);
        EmitTrap();

        EmitLabel(startLabel);
        EmitStatements(function.BlockBody);
        var child = ResolveLocal(tailAwaitBinding.Name) as RuntimeTask
            ?? throw new SmallLangException(
                $"tail await in async function '{function.Name}' did not produce Task<T>");
        EmitAsyncContextStore(
            "%context", function.InputType, function.ReturnType, 7,
            "ptr", child.HandleName, 8);
        EmitAsyncContextStore(
            "%context", function.InputType, function.ReturnType, 8,
            "ptr", child.ContextName, 8);
        RemoveLocal(tailAwaitBinding.Name);
        EmitStore("i32", "1", stateSlot, 4);
        EmitRet("i1", "false");

        EmitLabel(resumeLabel);
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
            ContextName = childContext
        };
        var value = EmitAwaitTask(resumedChild);
        EnsureRuntimeType(value, function.ReturnType, function.Name);
        DropOwnedLocalsCreatedSince(functionLocals, transferredOwnerName: null);
        StoreAsyncResult(function, value);
        EmitRet("i1", "true");
    }

    private void StoreAsyncResult(BoundFunction function, RuntimeValue value)
    {
        var result = MaterializeAsyncResult(value);
        var resultAddress = AsyncContextField(
            "%context", function.InputType, function.ReturnType, 6, "async_result_address");
        EmitStore(result.TypeName, result.ValueName, resultAddress, RuntimeAlignment(function.ReturnType));
    }

    private bool TryGetTailAwaitBinding(
        BoundFunction function,
        out BindingStatement? binding)
    {
        binding = null;
        if (function.InputType is { } inputType
            && _program.Types.ContainsOwnedStorage(inputType))
        {
            return false;
        }
        if (function.BlockBody.Count != 1
            || function.BlockBody[0] is not BindingStatement candidate
            || candidate.IsMutable
            || function.Body is not FlowExpression
            {
                Source: NameExpression source,
                Targets.Count: 1
            } flow
            || !string.Equals(source.Name, candidate.Name, StringComparison.Ordinal)
            || flow.Targets[0].Path.Count != 1
            || !string.Equals(flow.Targets[0].Path[0], "await", StringComparison.Ordinal)
            || flow.Targets[0].Arguments.Count != 0)
        {
            return false;
        }

        binding = candidate;
        return true;
    }

    private RuntimeTask EmitAsyncFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        var aggregate = NextTemp("task_call");
        EmitCall(
            aggregate,
            "%smalllang.task",
            SymbolForFunction(function.Name)[1..],
            FunctionCallArgumentList(function, argument));
        var handle = NextTemp("task_handle");
        EmitAssign(handle, $"extractvalue %smalllang.task {aggregate}, 0");
        var context = NextTemp("task_context");
        EmitAssign(context, $"extractvalue %smalllang.task {aggregate}, 1");
        return new RuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            function.InputType,
            function.ReturnType,
            handle,
            context);
    }

    private RuntimeValue EmitAwaitTask(RuntimeTask task, bool discardResult = false)
    {
        var waitSucceeded = NextTemp("task_wait_succeeded");
        EmitCall(waitSucceeded, "i1", "smalllang_task_join", $"ptr {task.HandleName}");
        var waitedLabel = NextLabel("task_waited");
        var waitFailedLabel = NextLabel("task_wait_failed");
        EmitConditionalBranch(waitSucceeded, waitedLabel, waitFailedLabel);
        EmitLabel(waitFailedLabel);
        EmitTrap();
        EmitLabel(waitedLabel);
        var resultAddress = AsyncContextField(
            task.ContextName, task.InputType, task.ResultType, 6, "task_result_address");
        var loaded = NextTemp(discardResult ? "task_discarded_result" : "task_result");
        EmitLoad(loaded, AsyncStorageLlvmType(task.ResultType), resultAddress, RuntimeAlignment(task.ResultType));
        var value = DematerializeAsyncResult(task.ResultType, loaded);
        if (discardResult && _program.Types.ContainsOwnedStorage(task.ResultType))
        {
            DropOwnedRuntimeValue(value);
        }
        var closeSucceeded = NextTemp("task_close_succeeded");
        EmitCall(closeSucceeded, "i1", "smalllang_task_release", $"ptr {task.HandleName}");
        var closedLabel = NextLabel("task_closed");
        var closeFailedLabel = NextLabel("task_close_failed");
        EmitConditionalBranch(closeSucceeded, closedLabel, closeFailedLabel);
        EmitLabel(closeFailedLabel);
        EmitTrap();
        EmitLabel(closedLabel);
        return value;
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

    private string AsyncContextField(
        string context, BoundType? inputType, BoundType resultType, int field, string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address, $"getelementptr {AsyncContextType(inputType, resultType)}, ptr {context}, i32 0, i32 {field}");
        return address;
    }

    private string AsyncContextType(BoundType? inputType, BoundType resultType) =>
        $"{{ ptr, ptr, ptr, ptr, ptr, {AsyncStorageLlvmType(inputType)}, {AsyncStorageLlvmType(resultType)}, ptr, ptr }}";

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

    private int AsyncContextSize(BoundType? inputType, BoundType resultType)
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
        return childTaskOffset + 16;
    }

    private static int AlignAsyncSize(int value, int alignment) =>
        checked((value + alignment - 1) / alignment * alignment);

    private static string AsyncWorkerSymbol(BoundFunction function) =>
        SymbolForFunction(function.Name)[1..] + "_async_worker";
}
