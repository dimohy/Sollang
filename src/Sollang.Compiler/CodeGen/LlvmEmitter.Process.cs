using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeUnit EmitRuntimeFlushStandardOutputIntrinsic()
    {
        if (_platform is WindowsLlvmRuntimePlatform or LinuxLlvmRuntimePlatform)
        {
            var flushOk = NextTemp("explicit_stdout_flush_ok");
            EmitCall(flushOk, "i32", "sollang_flush_stdout", "ptr %stdout, ptr %written");
            var flushSucceeded = NextTemp("explicit_stdout_flush_succeeded");
            EmitCompare(flushSucceeded, "ne", "i32", flushOk, "0");
            EmitTrapUnless(flushSucceeded, "stdout_flush");
        }
        return RuntimeUnit.Instance;
    }

    private RuntimeUnit EmitRuntimeExitProcessIntrinsic(RuntimeValue value, string path)
    {
        EnsureRuntimeType(value, BoundType.Int, path);
        var code = (RuntimeInt)value;
        if (_platform is WindowsLlvmRuntimePlatform or LinuxLlvmRuntimePlatform)
        {
            EmitCall(NextTemp("exit_flush"), "i32", "sollang_flush_stdout", "ptr %stdout, ptr %written");
        }
        var function = _platform is WindowsLlvmRuntimePlatform ? "ExitProcess" : "exit";
        EmitCall(target: null, "void", function, $"i32 {code.ValueName}");
        return RuntimeUnit.Instance;
    }

    private RuntimeArguments EmitRuntimeArgumentsIntrinsic()
    {
        if (!_platform.SupportsProcessArguments)
        {
            throw new SollangException("process arguments are unavailable on the current target");
        }
        var length = NextTemp("argument_count");
        EmitCall(length, "i64", "sollang_argument_count", "");
        return new RuntimeArguments(length);
    }

    private RuntimeText EmitArgumentLoad(RuntimeArguments arguments, Expression indexExpression)
    {
        var index = EmitMapInteger(indexExpression, BoundType.UIntSize, "argument_index");
        var inBounds = NextTemp("argument_in_bounds");
        EmitCompare(inBounds, "ult", "i64", index, arguments.LengthName);
        EmitTrapUnless(inBounds, "argument_bounds");
        return EmitArgumentLoad(index);
    }

    private RuntimeText EmitArgumentLoad(string index)
    {
        var value = NextTemp("argument");
        EmitCall(value, "%sollang.text", "sollang_argument", $"i64 {index}");
        var pointer = NextTemp("argument_ptr");
        EmitAssign(pointer, $"extractvalue %sollang.text {value}, 0");
        var length = NextTemp("argument_len");
        EmitAssign(length, $"extractvalue %sollang.text {value}, 1");
        return new RuntimeText(pointer, length);
    }

    private RuntimeEnum EmitRuntimeEnvironmentIntrinsic(BoundFunction function, RuntimeValue nameValue)
    {
        if (!_platform.SupportsEnvironment)
        {
            throw new SollangException("environment access is unavailable on the current target");
        }
        var name = nameValue as RuntimeText
            ?? throw new SollangException($"{function.Name} expects Text");
        var raw = NextTemp("environment_result");
        EmitCall(raw, "%sollang.environment_result", "sollang_environment",
            $"ptr {name.PointerName}, i64 {name.LengthName}");
        var pointer = NextTemp("environment_ptr");
        EmitAssign(pointer, $"extractvalue %sollang.environment_result {raw}, 0");
        var length = NextTemp("environment_len");
        EmitAssign(length, $"extractvalue %sollang.environment_result {raw}, 1");
        var found = NextTemp("environment_found");
        EmitAssign(found, $"extractvalue %sollang.environment_result {raw}, 2");
        var ok = NextTemp("environment_ok");
        EmitAssign(ok, $"extractvalue %sollang.environment_result {raw}, 3");
        EmitTrapUnless(ok, "environment_lookup");

        var definition = _program.Types.GetEnum(function.ReturnType);
        var noneVariant = definition.Variants.First(variant => variant.Name == "None");
        var someVariant = definition.Variants.First(variant => variant.Name == "Some");
        var someLabel = NextLabel("environment_some");
        var noneLabel = NextLabel("environment_none");
        var endLabel = NextLabel("environment_end");
        EmitConditionalBranch(found, someLabel, noneLabel);

        EmitLabel(someLabel);
        _currentBlockLabel = someLabel;
        var some = EmitEnumValue(function.ReturnType, someVariant, new RuntimeText(pointer, length));
        EmitBranch(endLabel);
        var someExit = _currentBlockLabel;

        EmitLabel(noneLabel);
        _currentBlockLabel = noneLabel;
        var none = EmitEnumValue(function.ReturnType, noneVariant, payload: null);
        EmitBranch(endLabel);
        var noneExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("environment_option", function.ReturnType,
            [(some, someExit), (none, noneExit)]);
    }

    private RuntimeEnum EmitRuntimeRunProcessIntrinsic(BoundFunction function, RuntimeStruct command)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        var invocation = ExtractProcessCommandInvocation(function, command);

        var raw = NextTemp("process_result");
        EmitCall(raw, "%sollang.process_result", "sollang_run_process_configured",
            ProcessConfiguredInvocationArguments(invocation));
        return EmitRuntimeProcessResult(function, raw);
    }

    private RuntimeEnum EmitRuntimeSpawnProcessIntrinsic(BoundFunction function, RuntimeStruct command)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !IsRuntimeNamedStruct(resultTypes.Ok, "sys.process.Child")
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} must return Result<Child, Text>");
        }

        var invocation = ExtractProcessCommandInvocation(function, command);
        var raw = NextTemp("process_spawn_result");
        EmitCall(raw, "%sollang.process_spawn_result", "sollang_spawn_process_configured",
            ProcessConfiguredInvocationArguments(invocation));
        var handle = NextTemp("process_child_handle");
        EmitAssign(handle, $"extractvalue %sollang.process_spawn_result {raw}, 0");
        var processId = NextTemp("process_child_id");
        EmitAssign(processId, $"extractvalue %sollang.process_spawn_result {raw}, 1");
        var errorCode = NextTemp("process_spawn_error_code");
        EmitAssign(errorCode, $"extractvalue %sollang.process_spawn_result {raw}, 2");

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var okLabel = NextLabel("process_spawn_ok");
        var errorLabel = NextLabel("process_spawn_error");
        var endLabel = NextLabel("process_spawn_end");
        var isOk = NextTemp("process_spawn_is_ok");
        EmitCompare(isOk, "eq", "i32", errorCode, "0");
        EmitConditionalBranch(isOk, okLabel, errorLabel);

        EmitLabel(okLabel);
        _currentBlockLabel = okLabel;
        var childDefinition = _program.Types.GetStruct(resultTypes.Ok);
        var tokenField = childDefinition.GetField("token");
        var processIdField = childDefinition.GetField("processId");
        var completionStateField = childDefinition.GetField("completionState");
        var exitCodeField = childDefinition.GetField("exitCode");
        var processIdDefinition = _program.Types.GetStruct(processIdField.Type);
        if (!string.Equals(processIdDefinition.Name, "sys.process.ProcessId", StringComparison.Ordinal))
        {
            throw new SollangException($"{function.Name} expects Child.processId to be ProcessId");
        }
        var processIdValueField = processIdDefinition.GetField("value");
        var processIdAggregate = NextTemp("process_id");
        EmitAssign(processIdAggregate,
            $"insertvalue {LlvmStructType(processIdField.Type)} poison, i64 {processId}, {processIdValueField.Index}");
        var childWithToken = NextTemp("process_child_token");
        EmitAssign(childWithToken,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, i64 {handle}, {tokenField.Index}");
        var childWithProcessId = NextTemp("process_child_id");
        EmitAssign(childWithProcessId,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {childWithToken}, {LlvmStructType(processIdField.Type)} {processIdAggregate}, {processIdField.Index}");
        var childWithoutExitStatus = NextTemp("process_child_status");
        EmitAssign(childWithoutExitStatus,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {childWithProcessId}, i32 0, {completionStateField.Index}");
        var childAggregate = NextTemp("process_child");
        EmitAssign(childAggregate,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {childWithoutExitStatus}, i32 0, {exitCodeField.Index}");
        var success = EmitEnumValue(function.ReturnType, okVariant,
            new RuntimeStruct(resultTypes.Ok, childAggregate));
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var failure = EmitEnumValue(function.ReturnType, errVariant,
            EmitProcessErrorText("spawn"));
        EmitBranch(endLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("process_spawn_result", function.ReturnType,
            [(success, successExit), (failure, failureExit)]);
    }

    private RuntimeEnum EmitRuntimeWaitProcessIntrinsic(BoundFunction function, RuntimeStruct child)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        var childDefinition = _program.Types.GetStruct(child.Type);
        if (!string.Equals(childDefinition.Name, "sys.process.Child", StringComparison.Ordinal))
        {
            throw new SollangException($"{function.Name} expects a Child receiver");
        }
        var tokenField = childDefinition.GetField("token");
        var completionStateField = childDefinition.GetField("completionState");
        var exitCodeField = childDefinition.GetField("exitCode");
        var completionState = NextTemp("process_wait_completion_state");
        EmitAssign(completionState,
            $"extractvalue {LlvmStructType(child.Type)} {child.ValueName}, {completionStateField.Index}");
        var cached = NextTemp("process_wait_cached");
        EmitCompare(cached, "ne", "i32", completionState, "0");
        var cachedLabel = NextLabel("process_wait_cached");
        var waitLabel = NextLabel("process_wait_os");
        var endLabel = NextLabel("process_wait_end");
        EmitConditionalBranch(cached, cachedLabel, waitLabel);

        EmitLabel(cachedLabel);
        _currentBlockLabel = cachedLabel;
        var cachedCode = NextTemp("process_wait_cached_code");
        EmitAssign(cachedCode,
            $"extractvalue {LlvmStructType(child.Type)} {child.ValueName}, {exitCodeField.Index}");
        var cachedIsExit = NextTemp("process_wait_cached_is_exit");
        EmitCompare(cachedIsExit, "eq", "i32", completionState, "1");
        var cachedError = NextTemp("process_wait_cached_error");
        EmitAssign(cachedError, $"select i1 {cachedIsExit}, i32 0, i32 3");
        var cachedRaw0 = NextTemp("process_wait_cached_raw");
        EmitAssign(cachedRaw0,
            $"insertvalue %sollang.process_result poison, i32 {cachedCode}, 0");
        var cachedRaw = NextTemp("process_wait_cached_raw");
        EmitAssign(cachedRaw,
            $"insertvalue %sollang.process_result {cachedRaw0}, i32 {cachedError}, 1");
        var cachedResult = EmitRuntimeProcessResult(function, cachedRaw);
        EmitBranch(endLabel);
        var cachedExit = _currentBlockLabel;

        EmitLabel(waitLabel);
        _currentBlockLabel = waitLabel;
        var handle = NextTemp("process_wait_handle");
        EmitAssign(handle,
            $"extractvalue {LlvmStructType(child.Type)} {child.ValueName}, {tokenField.Index}");
        var raw = NextTemp("process_wait_result");
        EmitCall(raw, "%sollang.process_result", "sollang_wait_process", $"i64 {handle}");
        var waitedResult = EmitRuntimeProcessResult(function, raw);
        EmitBranch(endLabel);
        var waitedExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("process_wait_cached_result", function.ReturnType,
            [(cachedResult, cachedExit), (waitedResult, waitedExit)]);
    }

    private RuntimeStruct EmitRuntimePollChildProcessIntrinsic(BoundFunction function, RuntimeInt token)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        if (token.Type != BoundType.UInt64
            || !IsRuntimeNamedStruct(function.ReturnType, "sys.process.ChildPoll"))
        {
            throw new SollangException($"{function.Name} expects UInt64 -> ChildPoll");
        }

        var raw = NextTemp("process_poll_result");
        EmitCall(raw, "%sollang.process_poll_result", "sollang_poll_process", $"i64 {token.ValueName}");
        var exitCode = NextTemp("process_poll_exit_code");
        EmitAssign(exitCode, $"extractvalue %sollang.process_poll_result {raw}, 0");
        var state = NextTemp("process_poll_state");
        EmitAssign(state, $"extractvalue %sollang.process_poll_result {raw}, 1");

        var definition = _program.Types.GetStruct(function.ReturnType);
        var stateField = definition.GetField("state");
        var exitCodeField = definition.GetField("exitCode");
        var withState = NextTemp("process_poll_value");
        EmitAssign(withState,
            $"insertvalue {LlvmStructType(function.ReturnType)} poison, i32 {state}, {stateField.Index}");
        var value = NextTemp("process_poll_value");
        EmitAssign(value,
            $"insertvalue {LlvmStructType(function.ReturnType)} {withState}, i32 {exitCode}, {exitCodeField.Index}");
        return new RuntimeStruct(function.ReturnType, value);
    }

    private RuntimeBool EmitRuntimeKillChildProcessIntrinsic(BoundFunction function, RuntimeInt token)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        if (token.Type != BoundType.UInt64 || function.ReturnType != BoundType.Bool)
        {
            throw new SollangException($"{function.Name} expects UInt64 -> Bool");
        }

        var succeeded = NextTemp("process_kill_succeeded");
        EmitCall(succeeded, "i1", "sollang_kill_process", $"i64 {token.ValueName}");
        return new RuntimeBool(succeeded);
    }

    private RuntimeStruct EmitRuntimeChildProcessIdIntrinsic(
        BoundFunction function,
        RuntimeStruct child)
    {
        var childDefinition = _program.Types.GetStruct(child.Type);
        if (!string.Equals(childDefinition.Name, "sys.process.Child", StringComparison.Ordinal)
            || !IsRuntimeNamedStruct(function.ReturnType, "sys.process.ProcessId"))
        {
            throw new SollangException($"{function.Name} expects Child -> ProcessId");
        }

        var processIdField = childDefinition.GetField("processId");
        if (processIdField.Type != function.ReturnType)
        {
            throw new SollangException($"{function.Name} must return Child.processId");
        }
        var processId = NextTemp("process_child_id");
        EmitAssign(processId,
            $"extractvalue {LlvmStructType(child.Type)} {child.ValueName}, {processIdField.Index}");
        return new RuntimeStruct(function.ReturnType, processId);
    }

    private RuntimeInt EmitRuntimeProcessIdValueIntrinsic(
        BoundFunction function,
        RuntimeStruct processId)
    {
        var definition = _program.Types.GetStruct(processId.Type);
        if (!string.Equals(definition.Name, "sys.process.ProcessId", StringComparison.Ordinal)
            || function.ReturnType != BoundType.UInt64)
        {
            throw new SollangException($"{function.Name} expects ProcessId -> UInt64");
        }

        var valueField = definition.GetField("value");
        if (valueField.Type != BoundType.UInt64)
        {
            throw new SollangException($"{function.Name} expects ProcessId.value to be UInt64");
        }
        var value = NextTemp("process_id_value");
        EmitAssign(value,
            $"extractvalue {LlvmStructType(processId.Type)} {processId.ValueName}, {valueField.Index}");
        return new RuntimeInt(BoundType.UInt64, value);
    }

    private RuntimeEnum EmitRuntimeRunProcessToFileIntrinsic(
        BoundFunction function,
        RuntimeStruct command,
        RuntimeText output)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }

        var invocation = ExtractProcessCommandInvocation(function, command);

        var raw = NextTemp("process_file_result");
        EmitCall(raw, "%sollang.process_result", "sollang_run_process_configured",
            ProcessConfiguredInvocationArguments(invocation, output));
        return EmitRuntimeProcessResult(function, raw);
    }

    private RuntimeEnum EmitRuntimeCollectProcessIntrinsic(
        BoundFunction function,
        RuntimeStruct command,
        RuntimeStruct limits)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !IsRuntimeNamedStruct(resultTypes.Ok, "sys.process.CapturedOutput")
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} must return Result<CapturedOutput, Text>");
        }

        var limitsDefinition = _program.Types.GetStruct(limits.Type);
        if (!string.Equals(limitsDefinition.Name, "sys.process.CaptureLimits", StringComparison.Ordinal))
        {
            throw new SollangException($"{function.Name} expects CaptureLimits");
        }
        var stdoutLimitField = limitsDefinition.GetField("standardOutputBytes");
        var stderrLimitField = limitsDefinition.GetField("standardErrorBytes");
        if (stdoutLimitField.Type != BoundType.UIntSize || stderrLimitField.Type != BoundType.UIntSize)
        {
            throw new SollangException("CaptureLimits fields must be UIntSize");
        }
        var stdoutLimit = NextTemp("process_capture_stdout_limit");
        EmitAssign(stdoutLimit,
            $"extractvalue {LlvmStructType(limits.Type)} {limits.ValueName}, {stdoutLimitField.Index}");
        var stderrLimit = NextTemp("process_capture_stderr_limit");
        EmitAssign(stderrLimit,
            $"extractvalue {LlvmStructType(limits.Type)} {limits.ValueName}, {stderrLimitField.Index}");

        var invocation = ExtractProcessCommandInvocation(function, command);
        var raw = NextTemp("process_capture_result");
        EmitCall(raw, "%sollang.process_capture_result", "sollang_collect_process_configured",
            ProcessConfiguredInvocationArguments(invocation)
                + $", i64 {stdoutLimit}, i64 {stderrLimit}");

        var exitCode = NextTemp("process_capture_exit_code");
        EmitAssign(exitCode, $"extractvalue %sollang.process_capture_result {raw}, 0");
        var stdoutPointer = NextTemp("process_capture_stdout_pointer");
        EmitAssign(stdoutPointer, $"extractvalue %sollang.process_capture_result {raw}, 1");
        var stdoutLength = NextTemp("process_capture_stdout_length");
        EmitAssign(stdoutLength, $"extractvalue %sollang.process_capture_result {raw}, 2");
        var stdoutCapacity = NextTemp("process_capture_stdout_capacity");
        EmitAssign(stdoutCapacity, $"extractvalue %sollang.process_capture_result {raw}, 3");
        var stdoutTruncated = NextTemp("process_capture_stdout_truncated");
        EmitAssign(stdoutTruncated, $"extractvalue %sollang.process_capture_result {raw}, 4");
        var stderrPointer = NextTemp("process_capture_stderr_pointer");
        EmitAssign(stderrPointer, $"extractvalue %sollang.process_capture_result {raw}, 5");
        var stderrLength = NextTemp("process_capture_stderr_length");
        EmitAssign(stderrLength, $"extractvalue %sollang.process_capture_result {raw}, 6");
        var stderrCapacity = NextTemp("process_capture_stderr_capacity");
        EmitAssign(stderrCapacity, $"extractvalue %sollang.process_capture_result {raw}, 7");
        var stderrTruncated = NextTemp("process_capture_stderr_truncated");
        EmitAssign(stderrTruncated, $"extractvalue %sollang.process_capture_result {raw}, 8");
        var errorCode = NextTemp("process_capture_error_code");
        EmitAssign(errorCode, $"extractvalue %sollang.process_capture_result {raw}, 9");

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var successLabel = NextLabel("process_capture_ok");
        var errorLabel = NextLabel("process_capture_error");
        var endLabel = NextLabel("process_capture_end");
        var succeeded = NextTemp("process_capture_succeeded");
        EmitCompare(succeeded, "eq", "i32", errorCode, "0");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var outputDefinition = _program.Types.GetStruct(resultTypes.Ok);
        var statusField = outputDefinition.GetField("status");
        var stdoutField = outputDefinition.GetField("standardOutput");
        var stderrField = outputDefinition.GetField("standardError");
        var stdoutTruncatedField = outputDefinition.GetField("standardOutputTruncated");
        var stderrTruncatedField = outputDefinition.GetField("standardErrorTruncated");
        if (!IsRuntimeNamedStruct(statusField.Type, "sys.process.ExitStatus")
            || stdoutField.Type != TypeId.DynamicUInt8Array
            || stderrField.Type != TypeId.DynamicUInt8Array
            || stdoutTruncatedField.Type != BoundType.Bool
            || stderrTruncatedField.Type != BoundType.Bool)
        {
            throw new SollangException("CapturedOutput has an invalid field contract");
        }
        var statusDefinition = _program.Types.GetStruct(statusField.Type);
        var statusCodeField = statusDefinition.GetField("code");
        var status = NextTemp("process_capture_status");
        EmitAssign(status,
            $"insertvalue {LlvmStructType(statusField.Type)} poison, i32 {exitCode}, {statusCodeField.Index}");
        var stdoutArray = BuildDynamicArrayAggregate(stdoutPointer, stdoutLength, stdoutCapacity);
        var stderrArray = BuildDynamicArrayAggregate(stderrPointer, stderrLength, stderrCapacity);
        var output0 = NextTemp("process_captured_output");
        EmitAssign(output0,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, {LlvmStructType(statusField.Type)} {status}, {statusField.Index}");
        var output1 = NextTemp("process_captured_output");
        EmitAssign(output1,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {output0}, %sollang.dynamic_int_array {stdoutArray}, {stdoutField.Index}");
        var output2 = NextTemp("process_captured_output");
        EmitAssign(output2,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {output1}, %sollang.dynamic_int_array {stderrArray}, {stderrField.Index}");
        var output3 = NextTemp("process_captured_output");
        EmitAssign(output3,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {output2}, i1 {stdoutTruncated}, {stdoutTruncatedField.Index}");
        var output4 = NextTemp("process_captured_output");
        EmitAssign(output4,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {output3}, i1 {stderrTruncated}, {stderrTruncatedField.Index}");
        var success = EmitEnumValue(
            function.ReturnType,
            okVariant,
            new RuntimeStruct(resultTypes.Ok, output4));
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var failure = EmitEnumValue(
            function.ReturnType,
            errVariant,
            EmitProcessErrorTextFromCode(errorCode));
        EmitBranch(endLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("process_capture_result", function.ReturnType,
            [(success, successExit), (failure, failureExit)]);
    }

    private ProcessCommandInvocation ExtractProcessCommandInvocation(
        BoundFunction function,
        RuntimeStruct command)
    {
        var definition = _program.Types.GetStruct(command.Type);
        if (!string.Equals(definition.Name, "sys.process.Command", StringComparison.Ordinal))
        {
            throw new SollangException($"{function.Name} expects a Command receiver");
        }
        var argvField = definition.GetField("argv");
        var argvAggregate = NextTemp("process_argv");
        EmitAssign(argvAggregate,
            $"extractvalue {LlvmStructType(command.Type)} {command.ValueName}, {argvField.Index}");
        var argv = DematerializeAggregateValue(argvField.Type, argvAggregate) as RuntimeDynamicInlineArray
            ?? throw new SollangException($"{function.Name} expects Text argv entries");
        if (argv.ElementType != BoundType.Text)
        {
            throw new SollangException($"{function.Name} expects Text argv entries");
        }

        var workingDirectoryField = definition.GetField("workingDirectoryValue");
        var workingDirectoryAggregate = NextTemp("process_working_directory");
        EmitAssign(workingDirectoryAggregate,
            $"extractvalue {LlvmStructType(command.Type)} {command.ValueName}, {workingDirectoryField.Index}");
        var workingDirectory = DematerializeAggregateValue(
            workingDirectoryField.Type,
            workingDirectoryAggregate) as RuntimeText
            ?? throw new SollangException($"{function.Name} expects a Text working directory");

        var hasWorkingDirectoryField = definition.GetField("hasWorkingDirectory");
        if (hasWorkingDirectoryField.Type != BoundType.Bool)
        {
            throw new SollangException($"{function.Name} expects a Bool working-directory marker");
        }
        var hasWorkingDirectory = NextTemp("process_has_working_directory");
        EmitAssign(hasWorkingDirectory,
            $"extractvalue {LlvmStructType(command.Type)} {command.ValueName}, {hasWorkingDirectoryField.Index}");

        var environmentChangesField = definition.GetField("environmentChanges");
        var environmentChangesAggregate = NextTemp("process_environment_changes");
        EmitAssign(environmentChangesAggregate,
            $"extractvalue {LlvmStructType(command.Type)} {command.ValueName}, {environmentChangesField.Index}");
        var environmentChanges = DematerializeAggregateValue(
            environmentChangesField.Type,
            environmentChangesAggregate) as RuntimeDynamicInlineArray
            ?? throw new SollangException($"{function.Name} expects environment changes");
        if (!IsRuntimeNamedStruct(environmentChanges.ElementType, "sys.process.EnvironmentChange"))
        {
            throw new SollangException($"{function.Name} expects EnvironmentChange entries");
        }

        var inheritsEnvironmentField = definition.GetField("inheritsEnvironment");
        if (inheritsEnvironmentField.Type != BoundType.Bool)
        {
            throw new SollangException($"{function.Name} expects a Bool environment-inheritance marker");
        }
        var inheritsEnvironment = NextTemp("process_inherits_environment");
        EmitAssign(inheritsEnvironment,
            $"extractvalue {LlvmStructType(command.Type)} {command.ValueName}, {inheritsEnvironmentField.Index}");

        var standardInput = ExtractProcessStdioConfiguration(
            definition,
            command,
            "standardInput",
            "sys.process.Input",
            "process_stdin");
        var standardOutput = ExtractProcessStdioConfiguration(
            definition,
            command,
            "standardOutput",
            "sys.process.Output",
            "process_stdout");
        var standardError = ExtractProcessStdioConfiguration(
            definition,
            command,
            "standardError",
            "sys.process.Output",
            "process_stderr");

        return new ProcessCommandInvocation(
            argv,
            workingDirectory,
            new RuntimeBool(hasWorkingDirectory),
            environmentChanges,
            new RuntimeBool(inheritsEnvironment),
            standardInput,
            standardOutput,
            standardError);
    }

    private ProcessStdioConfiguration ExtractProcessStdioConfiguration(
        BoundStructDefinition commandDefinition,
        RuntimeStruct command,
        string fieldName,
        string expectedTypeName,
        string prefix)
    {
        var field = commandDefinition.GetField(fieldName);
        if (!_program.Types.IsEnum(field.Type))
        {
            throw new SollangException($"sys.process.Command.{fieldName} must be {expectedTypeName}");
        }
        var definition = _program.Types.GetEnum(field.Type);
        if (!string.Equals(definition.Name, expectedTypeName, StringComparison.Ordinal))
        {
            throw new SollangException($"sys.process.Command.{fieldName} must be {expectedTypeName}");
        }
        var inherit = definition.Variants.FirstOrDefault(variant => variant.Name == "Inherit");
        var file = definition.Variants.FirstOrDefault(variant => variant.Name == "File");
        var nullDevice = definition.Variants.FirstOrDefault(variant => variant.Name == "Null");
        if (inherit is null || inherit.Tag != 0 || inherit.PayloadType is not null
            || file is null || file.Tag != 1 || file.PayloadType != BoundType.Text
            || nullDevice is null || nullDevice.Tag != 2 || nullDevice.PayloadType is not null)
        {
            throw new SollangException(
                $"{expectedTypeName} must declare Inherit, File(Text), then Null");
        }

        var aggregate = NextTemp(prefix + "_configuration");
        EmitAssign(aggregate,
            $"extractvalue {LlvmStructType(command.Type)} {command.ValueName}, {field.Index}");
        var mode = NextTemp(prefix + "_mode");
        EmitAssign(mode, $"extractvalue {LlvmEnumType(field.Type)} {aggregate}, 0");
        var slot = NextTemp(prefix + "_slot");
        EmitAlloca(slot, LlvmEnumType(field.Type), 8);
        EmitStore(LlvmEnumType(field.Type), aggregate, slot, 8);
        var pathAddress = NextTemp(prefix + "_path_address");
        EmitAssign(pathAddress,
            $"getelementptr inbounds {LlvmEnumType(field.Type)}, ptr {slot}, i32 0, i32 1");
        var pathAggregate = NextTemp(prefix + "_path");
        EmitLoad(pathAggregate, "%sollang.text", pathAddress, 8);
        var path = DematerializeAggregateValue(BoundType.Text, pathAggregate) as RuntimeText
            ?? throw new SollangException($"{expectedTypeName}.File payload must be Text");
        return new ProcessStdioConfiguration(mode, path);
    }

    private static string ProcessInvocationArguments(ProcessCommandInvocation invocation)
        => $"ptr {invocation.Argv.PointerName}, i64 {invocation.Argv.LengthName}, "
            + $"ptr {invocation.WorkingDirectory.PointerName}, i64 {invocation.WorkingDirectory.LengthName}, "
            + $"i1 {invocation.HasWorkingDirectory.ValueName}, "
            + $"ptr {invocation.EnvironmentChanges.PointerName}, i64 {invocation.EnvironmentChanges.LengthName}, "
            + $"i1 {invocation.InheritsEnvironment.ValueName}";

    private static string ProcessConfiguredInvocationArguments(ProcessCommandInvocation invocation)
        => ProcessInvocationArguments(invocation)
            + $", i32 {invocation.StandardInput.ModeName}, ptr {invocation.StandardInput.Path.PointerName}, i64 {invocation.StandardInput.Path.LengthName}"
            + $", i32 {invocation.StandardOutput.ModeName}, ptr {invocation.StandardOutput.Path.PointerName}, i64 {invocation.StandardOutput.Path.LengthName}"
            + $", i32 {invocation.StandardError.ModeName}, ptr {invocation.StandardError.Path.PointerName}, i64 {invocation.StandardError.Path.LengthName}";

    private static string ProcessConfiguredInvocationArguments(
        ProcessCommandInvocation invocation,
        RuntimeText standardOutputOverride)
        => ProcessInvocationArguments(invocation)
            + $", i32 {invocation.StandardInput.ModeName}, ptr {invocation.StandardInput.Path.PointerName}, i64 {invocation.StandardInput.Path.LengthName}"
            + $", i32 1, ptr {standardOutputOverride.PointerName}, i64 {standardOutputOverride.LengthName}"
            + $", i32 {invocation.StandardError.ModeName}, ptr {invocation.StandardError.Path.PointerName}, i64 {invocation.StandardError.Path.LengthName}";

    private readonly record struct ProcessStdioConfiguration(
        string ModeName,
        RuntimeText Path);

    private readonly record struct ProcessCommandInvocation(
        RuntimeDynamicInlineArray Argv,
        RuntimeText WorkingDirectory,
        RuntimeBool HasWorkingDirectory,
        RuntimeDynamicInlineArray EnvironmentChanges,
        RuntimeBool InheritsEnvironment,
        ProcessStdioConfiguration StandardInput,
        ProcessStdioConfiguration StandardOutput,
        ProcessStdioConfiguration StandardError);

    private RuntimeEnum EmitRuntimeProcessResult(BoundFunction function, string raw)
    {
        var exitCode = NextTemp("process_exit_code");
        EmitAssign(exitCode, $"extractvalue %sollang.process_result {raw}, 0");
        var errorCode = NextTemp("process_error_code");
        EmitAssign(errorCode, $"extractvalue %sollang.process_result {raw}, 1");

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var okLabel = NextLabel("process_ok");
        var errorLabel = NextLabel("process_error");
        var spawnLabel = NextLabel("process_spawn_error");
        var waitLabel = NextLabel("process_wait_error");
        var signalLabel = NextLabel("process_signal_error");
        var endLabel = NextLabel("process_end");
        var isOk = NextTemp("process_is_ok");
        EmitCompare(isOk, "eq", "i32", errorCode, "0");
        EmitConditionalBranch(isOk, okLabel, errorLabel);
        var incoming = new List<(RuntimeValue Value, string Label)>();

        EmitLabel(okLabel);
        _currentBlockLabel = okLabel;
        RuntimeValue successPayload = new RuntimeInt(BoundType.Int, exitCode);
        if (_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            && IsRuntimeNamedStruct(resultTypes.Ok, "sys.process.ExitStatus"))
        {
            var statusDefinition = _program.Types.GetStruct(resultTypes.Ok);
            var codeField = statusDefinition.GetField("code");
            var statusAggregate = NextTemp("process_exit_status");
            EmitAssign(statusAggregate,
                $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, i32 {exitCode}, {codeField.Index}");
            successPayload = new RuntimeStruct(resultTypes.Ok, statusAggregate);
        }
        incoming.Add((EmitEnumValue(function.ReturnType, okVariant,
            successPayload), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var isSpawn = NextTemp("process_is_spawn_error");
        EmitCompare(isSpawn, "eq", "i32", errorCode, "1");
        EmitConditionalBranch(isSpawn, spawnLabel, waitLabel);

        EmitLabel(spawnLabel);
        _currentBlockLabel = spawnLabel;
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant,
            EmitProcessErrorText("spawn")), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(waitLabel);
        _currentBlockLabel = waitLabel;
        var isWait = NextTemp("process_is_wait_error");
        EmitCompare(isWait, "eq", "i32", errorCode, "2");
        EmitBranch(signalLabel);

        EmitLabel(signalLabel);
        _currentBlockLabel = signalLabel;
        var errorText = EmitProcessErrorText("signal");
        var waitText = EmitProcessErrorText("wait");
        var selectedText = NextTemp("process_error_text");
        EmitAssign(selectedText, $"select i1 {isWait}, ptr {waitText.PointerName}, ptr {errorText.PointerName}");
        var selectedLength = NextTemp("process_error_length");
        EmitAssign(selectedLength, $"select i1 {isWait}, i64 {waitText.LengthName}, i64 {errorText.LengthName}");
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant,
            new RuntimeText(selectedText, selectedLength)), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("process_run_result", function.ReturnType, incoming);
    }

    private RuntimeText EmitProcessErrorText(string text)
    {
        var global = AddGlobalString(text);
        return new RuntimeText(global.Name, global.Length.ToString(System.Globalization.CultureInfo.InvariantCulture));
    }

    private RuntimeText EmitProcessErrorTextFromCode(string errorCode)
    {
        var spawn = EmitProcessErrorText("spawn");
        var wait = EmitProcessErrorText("wait");
        var signal = EmitProcessErrorText("signal");
        var capture = EmitProcessErrorText("capture");
        var isSpawn = NextTemp("process_error_is_spawn");
        EmitCompare(isSpawn, "eq", "i32", errorCode, "1");
        var isWait = NextTemp("process_error_is_wait");
        EmitCompare(isWait, "eq", "i32", errorCode, "2");
        var isSignal = NextTemp("process_error_is_signal");
        EmitCompare(isSignal, "eq", "i32", errorCode, "3");
        var waitOrCapturePointer = NextTemp("process_error_wait_or_capture_pointer");
        EmitAssign(waitOrCapturePointer,
            $"select i1 {isWait}, ptr {wait.PointerName}, ptr {capture.PointerName}");
        var waitOrCaptureLength = NextTemp("process_error_wait_or_capture_length");
        EmitAssign(waitOrCaptureLength,
            $"select i1 {isWait}, i64 {wait.LengthName}, i64 {capture.LengthName}");
        var nonSpawnPointer = NextTemp("process_error_non_spawn_pointer");
        EmitAssign(nonSpawnPointer,
            $"select i1 {isSignal}, ptr {signal.PointerName}, ptr {waitOrCapturePointer}");
        var nonSpawnLength = NextTemp("process_error_non_spawn_length");
        EmitAssign(nonSpawnLength,
            $"select i1 {isSignal}, i64 {signal.LengthName}, i64 {waitOrCaptureLength}");
        var pointer = NextTemp("process_error_selected_pointer");
        EmitAssign(pointer,
            $"select i1 {isSpawn}, ptr {spawn.PointerName}, ptr {nonSpawnPointer}");
        var length = NextTemp("process_error_selected_length");
        EmitAssign(length,
            $"select i1 {isSpawn}, i64 {spawn.LengthName}, i64 {nonSpawnLength}");
        return new RuntimeText(pointer, length);
    }
}
