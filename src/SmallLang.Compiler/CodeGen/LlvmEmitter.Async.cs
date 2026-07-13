using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Semantics;

namespace SmallLang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private const string AsyncIntContextType = "%smalllang.async_context.i32";

    private void EmitAsyncIntFunction(BoundFunction function)
    {
        if (function.Body is null)
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

            EmitAsyncContextLoad("%stdin", "%context", 0, "ptr", 8);
            EmitAsyncContextLoad("%stdout", "%context", 1, "ptr", 8);
            EmitAsyncContextLoad("%written", "%context", 2, "ptr", 8);
            EmitAsyncContextLoad("%read", "%context", 3, "ptr", 8);
            EmitAsyncContextLoad("%ok_state", "%context", 4, "ptr", 8);
            if (function.InputType == BoundType.Int)
            {
                EmitAsyncContextLoad("%it", "%context", 5, "i32", 4);
            }

            var functionLocals = CaptureLocals();
            BindFunctionParameter(function);
            EmitStatements(function.BlockBody);
            var movedBodySourceName = GetMoveConsumingContainerSourceName(function.Body);
            var value = EmitExpression(function.Body);
            EnsureRuntimeType(value, BoundType.Int, function.Name);
            if (movedBodySourceName is not null)
            {
                RemoveLocal(movedBodySourceName);
            }
            DropOwnedLocalsCreatedSince(functionLocals, transferredOwnerName: null);
            var result = value is RuntimeInt integer
                ? integer.ValueName
                : throw new SmallLangException($"async function '{function.Name}' did not produce Int");
            var resultAddress = AsyncContextField("%context", 6, "async_result_address");
            EmitStore("i32", result, resultAddress, 4);
            EmitRet("i32", "0");
            EmitFunctionLine("}");
            EmitFunctionLine();

            ClearLocalState();
            EmitFunctionLine($"define internal %smalllang.task.i32 {SymbolForFunction(function.Name)}({ParameterListForFunction(function)}) #0 {{");
            EmitLabel("entry");
            var context = NextTemp("async_context");
            EmitCall(context, "ptr", "smalllang_alloc", "i64 48");
            EmitAsyncContextStore(context, 0, "ptr", "%stdin", 8);
            EmitAsyncContextStore(context, 1, "ptr", "%stdout", 8);
            EmitAsyncContextStore(context, 2, "ptr", "%written", 8);
            EmitAsyncContextStore(context, 3, "ptr", "%read", 8);
            EmitAsyncContextStore(context, 4, "ptr", "%ok_state", 8);
            EmitAsyncContextStore(context, 5, "i32", function.InputType == BoundType.Int ? "%it" : "0", 4);
            EmitAsyncContextStore(context, 6, "i32", "0", 4);

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
            EmitAssign(withHandle, $"insertvalue %smalllang.task.i32 poison, ptr {handle}, 0");
            var task = NextTemp("task");
            EmitAssign(task, $"insertvalue %smalllang.task.i32 {withHandle}, ptr {context}, 1");
            EmitRet("%smalllang.task.i32", task);
            EmitFunctionLine("}");
            EmitFunctionLine();
        }
        finally
        {
            _currentFunctions = previousFunctions;
        }
    }

    private RuntimeTaskInt EmitAsyncIntFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        var aggregate = NextTemp("task_call");
        EmitCall(
            aggregate,
            "%smalllang.task.i32",
            SymbolForFunction(function.Name)[1..],
            FunctionCallArgumentList(function, argument));
        var handle = NextTemp("task_handle");
        EmitAssign(handle, $"extractvalue %smalllang.task.i32 {aggregate}, 0");
        var context = NextTemp("task_context");
        EmitAssign(context, $"extractvalue %smalllang.task.i32 {aggregate}, 1");
        return new RuntimeTaskInt(handle, context);
    }

    private RuntimeInt EmitAwaitTask(RuntimeTaskInt task, bool discardResult = false)
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
        var resultAddress = AsyncContextField(task.ContextName, 6, "task_result_address");
        var value = NextTemp(discardResult ? "task_discarded_result" : "task_result");
        EmitLoad(value, "i32", resultAddress, 4);
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
        return new RuntimeInt(value);
    }

    private void EmitAsyncContextLoad(string target, string context, int field, string type, int alignment)
    {
        var address = AsyncContextField(context, field, "async_context_field");
        EmitLoad(target, type, address, alignment);
    }

    private void EmitAsyncContextStore(string context, int field, string type, string value, int alignment)
    {
        var address = AsyncContextField(context, field, "async_context_field");
        EmitStore(type, value, address, alignment);
    }

    private string AsyncContextField(string context, int field, string prefix)
    {
        var address = NextTemp(prefix);
        EmitAssign(address, $"getelementptr {AsyncIntContextType}, ptr {context}, i32 0, i32 {field}");
        return address;
    }

    private static string AsyncWorkerSymbol(BoundFunction function) =>
        SymbolForFunction(function.Name)[1..] + "_async_worker";
}
