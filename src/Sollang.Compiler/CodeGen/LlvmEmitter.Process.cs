using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeUnit EmitRuntimeExitProcessIntrinsic(RuntimeValue value, string path)
    {
        EnsureRuntimeType(value, BoundType.Int, path);
        var code = (RuntimeInt)value;
        if (_platform is WindowsLlvmRuntimePlatform)
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

    private RuntimeEnum EmitRuntimeRunProcessIntrinsic(BoundFunction function, RuntimeDynamicInlineArray argv)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }
        if (argv.ElementType != BoundType.Text)
        {
            throw new SollangException($"{function.Name} expects Text argv entries");
        }

        var raw = NextTemp("process_result");
        EmitCall(raw, "%sollang.process_result", "sollang_run_process",
            $"ptr {argv.PointerName}, i64 {argv.LengthName}");
        return EmitRuntimeProcessResult(function, raw);
    }

    private RuntimeEnum EmitRuntimeRunProcessToFileIntrinsic(
        BoundFunction function,
        RuntimeStruct request)
    {
        if (!_platform.SupportsChildProcesses)
        {
            throw new SollangException("child processes are unavailable on the current target");
        }

        var definition = _program.Types.GetStruct(request.Type);
        var argvField = definition.GetField("argv");
        var outputField = definition.GetField("output");
        var argvAggregate = NextTemp("process_argv");
        EmitAssign(argvAggregate,
            $"extractvalue {LlvmStructType(request.Type)} {request.ValueName}, {argvField.Index}");
        var argv = DematerializeAggregateValue(argvField.Type, argvAggregate) as RuntimeDynamicInlineArray
            ?? throw new SollangException($"{function.Name} expects Text argv entries");
        var outputAggregate = NextTemp("process_output");
        EmitAssign(outputAggregate,
            $"extractvalue {LlvmStructType(request.Type)} {request.ValueName}, {outputField.Index}");
        var output = DematerializeAggregateValue(outputField.Type, outputAggregate) as RuntimeText
            ?? throw new SollangException($"{function.Name} expects a Text output path");

        var raw = NextTemp("process_file_result");
        EmitCall(raw, "%sollang.process_result", "sollang_run_process_to_file",
            $"ptr {argv.PointerName}, i64 {argv.LengthName}, ptr {output.PointerName}, i64 {output.LengthName}");
        return EmitRuntimeProcessResult(function, raw);
    }

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
        incoming.Add((EmitEnumValue(function.ReturnType, okVariant,
            new RuntimeInt(BoundType.Int, exitCode)), _currentBlockLabel));
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
}
