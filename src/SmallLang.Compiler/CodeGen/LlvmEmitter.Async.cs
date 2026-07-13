using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Semantics;

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
            EmitFunctionLine($"define internal i32 @{workerName}(ptr %context) #0 {{");
            EmitLabel("entry");
            EmitStackFrameAllocations();
            _currentBlockLabel = "entry";

            EmitAsyncContextLoad("%stdin", "%context", function.ReturnType, 0, "ptr", 8);
            EmitAsyncContextLoad("%stdout", "%context", function.ReturnType, 1, "ptr", 8);
            EmitAsyncContextLoad("%written", "%context", function.ReturnType, 2, "ptr", 8);
            EmitAsyncContextLoad("%read", "%context", function.ReturnType, 3, "ptr", 8);
            EmitAsyncContextLoad("%ok_state", "%context", function.ReturnType, 4, "ptr", 8);
            if (function.InputType == BoundType.Int)
            {
                EmitAsyncContextLoad("%it", "%context", function.ReturnType, 5, "i32", 4);
            }

            var functionLocals = CaptureLocals();
            BindFunctionParameter(function);
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
            var result = MaterializeAsyncResult(value);
            var resultAddress = AsyncContextField(
                "%context", function.ReturnType, 6, "async_result_address");
            EmitStore(result.TypeName, result.ValueName, resultAddress, RuntimeAlignment(function.ReturnType));
            EmitRet("i32", "0");
            EmitFunctionLine("}");
            EmitFunctionLine();

            ClearLocalState();
            EmitFunctionLine($"define internal %smalllang.task {SymbolForFunction(function.Name)}({ParameterListForFunction(function)}) #0 {{");
            EmitLabel("entry");
            var context = NextTemp("async_context");
            EmitCall(context, "ptr", "smalllang_alloc", $"i64 {AsyncContextSize(function.ReturnType)}");
            EmitAsyncContextStore(context, function.ReturnType, 0, "ptr", "%stdin", 8);
            EmitAsyncContextStore(context, function.ReturnType, 1, "ptr", "%stdout", 8);
            EmitAsyncContextStore(context, function.ReturnType, 2, "ptr", "%written", 8);
            EmitAsyncContextStore(context, function.ReturnType, 3, "ptr", "%read", 8);
            EmitAsyncContextStore(context, function.ReturnType, 4, "ptr", "%ok_state", 8);
            EmitAsyncContextStore(context, function.ReturnType, 5, "i32", function.InputType == BoundType.Int ? "%it" : "0", 4);
            EmitAsyncContextStore(context, function.ReturnType, 6, AsyncResultLlvmType(function.ReturnType), "zeroinitializer", RuntimeAlignment(function.ReturnType));

            var handle = NextTemp("async_handle");
            EmitCall(handle, "ptr", "CreateThread", $"ptr null, i64 0, ptr @{workerName}, ptr {context}, i32 0, ptr null");
            var started = NextTemp("async_started");
            EmitCompare(started, "ne", "ptr", handle, "null");
            var readyLabel = NextLabel("async_ready");
            var failedLabel = NextLabel("async_failed");
            EmitConditionalBranch(started, readyLabel, failedLabel);
            EmitLabel(failedLabel);
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
        return new RuntimeTask(_program.Types.GetOrAddTask(function.ReturnType), function.ReturnType, handle, context);
    }

    private RuntimeValue EmitAwaitTask(RuntimeTask task, bool discardResult = false)
    {
        var waitResult = NextTemp("task_wait");
        EmitCall(waitResult, "i32", "WaitForSingleObject", $"ptr {task.HandleName}, i32 -1");
        var waitSucceeded = NextTemp("task_wait_succeeded");
        EmitCompare(waitSucceeded, "eq", "i32", waitResult, "0");
        var waitedLabel = NextLabel("task_waited");
        var waitFailedLabel = NextLabel("task_wait_failed");
        EmitConditionalBranch(waitSucceeded, waitedLabel, waitFailedLabel);
        EmitLabel(waitFailedLabel);
        EmitTrap();
        EmitLabel(waitedLabel);
        var resultAddress = AsyncContextField(task.ContextName, task.ResultType, 6, "task_result_address");
        var loaded = NextTemp(discardResult ? "task_discarded_result" : "task_result");
        EmitLoad(loaded, AsyncResultLlvmType(task.ResultType), resultAddress, RuntimeAlignment(task.ResultType));
        var value = DematerializeAsyncResult(task.ResultType, loaded);
        if (discardResult && _program.Types.ContainsOwnedStorage(task.ResultType))
        {
            DropDiscardedAsyncResult(value);
        }
        var closeResult = NextTemp("task_close");
        EmitCall(closeResult, "i32", "CloseHandle", $"ptr {task.HandleName}");
        EmitCall(target: null, "void", "smalllang_free", $"ptr {task.ContextName}");
        var closeSucceeded = NextTemp("task_close_succeeded");
        EmitCompare(closeSucceeded, "ne", "i32", closeResult, "0");
        var closedLabel = NextLabel("task_closed");
        var closeFailedLabel = NextLabel("task_close_failed");
        EmitConditionalBranch(closeSucceeded, closedLabel, closeFailedLabel);
        EmitLabel(closeFailedLabel);
        EmitTrap();
        EmitLabel(closedLabel);
        return value;
    }

    private void EmitAsyncContextLoad(
        string target, string context, BoundType resultType, int field, string type, int alignment)
    {
        var address = AsyncContextField(context, resultType, field, "async_context_field");
        EmitLoad(target, type, address, alignment);
    }

    private void EmitAsyncContextStore(
        string context, BoundType resultType, int field, string type, string value, int alignment)
    {
        var address = AsyncContextField(context, resultType, field, "async_context_field");
        EmitStore(type, value, address, alignment);
    }

    private string AsyncContextField(
        string context, BoundType resultType, int field, string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address, $"getelementptr {AsyncContextType(resultType)}, ptr {context}, i32 0, i32 {field}");
        return address;
    }

    private string AsyncContextType(BoundType resultType) =>
        $"{{ ptr, ptr, ptr, ptr, ptr, i32, {AsyncResultLlvmType(resultType)} }}";

    private string AsyncResultLlvmType(BoundType resultType) =>
        resultType == BoundType.Unit ? "i8" : LlvmType(resultType);

    private (string TypeName, string ValueName) MaterializeAsyncResult(RuntimeValue value) =>
        value is RuntimeUnit ? ("i8", "0") : MaterializeAggregateValue(value);

    private RuntimeValue DematerializeAsyncResult(BoundType type, string value) =>
        type == BoundType.Unit ? RuntimeUnit.Instance : DematerializeAggregateValue(type, value);

    private void DropDiscardedAsyncResult(RuntimeValue value)
    {
        if (IsCustomOwnedType(value.Type))
        {
            var materialized = MaterializeAggregateValue(value);
            EmitOwnedDropCall(value.Type, materialized.ValueName);
            return;
        }

        switch (value)
        {
            case RuntimeDynamicIntArray array:
                EmitCall(target: null, "void", "smalllang_free", $"ptr {array.PointerName}");
                break;
            case RuntimeDynamicInlineArray array:
                DropDynamicInlineArrayElements(array);
                EmitCall(target: null, "void", "smalllang_free", $"ptr {array.PointerName}");
                break;
            case RuntimeIntDictionary dictionary:
                EmitCall(target: null, "void", "smalllang_free", $"ptr {dictionary.PointerName}");
                break;
            case RuntimeInlineDictionary dictionary:
                DropInlineDictionaryElements(dictionary);
                EmitCall(target: null, "void", "smalllang_free", $"ptr {dictionary.PointerName}");
                break;
        }
    }

    private int AsyncContextSize(BoundType resultType)
    {
        var alignment = RuntimeAlignment(resultType);
        var resultOffset = AlignAsyncSize(44, alignment);
        var resultSize = Math.Max(_program.Types.InlineSizeOf(resultType), 1);
        return AlignAsyncSize(resultOffset + resultSize, 8);
    }

    private static int AlignAsyncSize(int value, int alignment) =>
        checked((value + alignment - 1) / alignment * alignment);

    private static string AsyncWorkerSymbol(BoundFunction function) =>
        SymbolForFunction(function.Name)[1..] + "_async_worker";
}
