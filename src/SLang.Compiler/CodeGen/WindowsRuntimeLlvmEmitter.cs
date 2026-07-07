using System.Globalization;
using System.Text;
using SLang.Compiler.Diagnostics;
using SLang.Compiler.Semantics;
using SLang.Compiler.Syntax;

namespace SLang.Compiler.CodeGen;

internal sealed class WindowsRuntimeLlvmEmitter(BoundProgram program)
{
    private readonly StringBuilder _globals = new();
    private readonly StringBuilder _functions = new();
    private readonly Dictionary<string, RuntimeValue> _locals = new(StringComparer.Ordinal);
    private int _stringId;
    private int _tempId;

    public string Emit()
    {
        var header = new StringBuilder();
        header.AppendLine("target triple = \"x86_64-pc-windows-msvc\"");
        header.AppendLine();
        header.AppendLine("%slang.text = type { ptr, i64 }");
        header.AppendLine();

        _functions.AppendLine("declare dllimport ptr @GetStdHandle(i32)");
        _functions.AppendLine("declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)");
        _functions.AppendLine();

        EmitUserFunctions();
        EmitRuntimeHelpers();
        EmitMain();
        _functions.AppendLine("attributes #0 = { noinline optnone }");

        return header.ToString() + _globals + _functions;
    }

    private void EmitUserFunctions()
    {
        foreach (var function in program.Functions.Values)
        {
            switch (function.ReturnType)
            {
                case BoundType.Text:
                    EmitTextFunction(function);
                    break;
                case BoundType.Int:
                    EmitIntFunction(function);
                    break;
                default:
                    throw new SlangException($"unsupported function return type {function.ReturnType}");
            }
        }
    }

    private void EmitTextFunction(BoundFunction function)
    {
        if (function.InputType is not null)
        {
            throw new SlangException("Text-returning functions with input are not in the current runtime slice");
        }

        var text = GetPlainText(function.Body, function.Line, function.Column);
        var global = AddGlobalString(text);

        _functions.Append("define internal %slang.text ")
            .Append(SymbolForFunction(function.Name))
            .AppendLine("() #0 {");
        _functions.AppendLine("entry:");
        _functions.Append("  ret %slang.text { ptr ")
            .Append(global.Name)
            .Append(", i64 ")
            .Append(global.Length.ToString(CultureInfo.InvariantCulture))
            .AppendLine(" }");
        _functions.AppendLine("}");
        _functions.AppendLine();
    }

    private void EmitIntFunction(BoundFunction function)
    {
        _locals.Clear();
        var parameterList = function.InputType switch
        {
            null => "",
            BoundType.Int => "i64 %it",
            _ => throw new SlangException("only Int function input is supported in the current runtime slice")
        };

        _functions.Append("define internal i64 ")
            .Append(SymbolForFunction(function.Name))
            .Append('(')
            .Append(parameterList)
            .AppendLine(") #0 {");
        _functions.AppendLine("entry:");
        if (function.InputType == BoundType.Int)
        {
            _locals.Add("it", new RuntimeInt("%it"));
        }

        var value = EmitIntExpression(function.Body);
        _functions.Append("  ret i64 ").AppendLine(value.ValueName);
        _functions.AppendLine("}");
        _functions.AppendLine();
    }

    private void EmitRuntimeHelpers()
    {
        _functions.AppendLine("""
            define internal i32 @slang_write(ptr %stdout, ptr %data, i64 %len64, ptr %written) #0 {
            entry:
              %len = trunc i64 %len64 to i32
              %ok = call i32 @WriteFile(ptr %stdout, ptr %data, i32 %len, ptr %written, ptr null)
              ret i32 %ok
            }

            define internal i32 @slang_write_u64(ptr %stdout, i64 %value, ptr %written) #0 {
            entry:
              %buf = alloca [20 x i8], align 1
              %end = getelementptr inbounds [20 x i8], ptr %buf, i64 0, i64 20
              br label %digits

            digits:
              %n = phi i64 [ %value, %entry ], [ %q, %digits ]
              %p = phi ptr [ %end, %entry ], [ %next, %digits ]
              %digit = urem i64 %n, 10
              %q = udiv i64 %n, 10
              %next = getelementptr i8, ptr %p, i64 -1
              %digit8 = trunc i64 %digit to i8
              %ascii = add i8 %digit8, 48
              store i8 %ascii, ptr %next, align 1
              %done = icmp eq i64 %q, 0
              br i1 %done, label %write, label %digits

            write:
              %start_int = ptrtoint ptr %next to i64
              %end_int = ptrtoint ptr %end to i64
              %len = sub i64 %end_int, %start_int
              %ok = call i32 @slang_write(ptr %stdout, ptr %next, i64 %len, ptr %written)
              ret i32 %ok
            }

            """);
    }

    private void EmitMain()
    {
        _locals.Clear();
        _functions.AppendLine("define dso_local i32 @slang_start() local_unnamed_addr {");
        _functions.AppendLine("entry:");
        _functions.AppendLine("  %written = alloca i32, align 4");
        _functions.AppendLine("  %stdout = call ptr @GetStdHandle(i32 -11)");

        var ok = "true";
        foreach (var statement in program.MainStatements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    _locals.Add(binding.Name, EmitExpression(binding.Value));
                    break;
                case ExpressionStatement expressionStatement:
                    ok = EmitExpressionStatement(expressionStatement.Expression, ok);
                    break;
                default:
                    throw new SlangException($"unsupported runtime statement {statement.GetType().Name}");
            }
        }

        _functions.Append("  ")
            .Append(NextTemp("exit"))
            .Append(" = select i1 ")
            .Append(ok)
            .AppendLine(", i32 0, i32 1");
        _functions.Append("  ret i32 ").AppendLine(CurrentTemp("exit"));
        _functions.AppendLine("}");
        _functions.AppendLine();
    }

    private string EmitExpressionStatement(Expression expression, string ok)
    {
        if (expression is CallExpression call)
        {
            return EmitPrintCall(call, ok);
        }

        if (expression is FlowExpression flow)
        {
            var result = EmitFlowExpression(flow, ok, allowBindingTarget: true);
            if (result.Binding is { } binding)
            {
                _locals.Add(binding.Name, binding.Value);
                return result.Ok;
            }

            if (result.Value is null)
            {
                return result.Ok;
            }

            throw new SlangException("value-flow expression statements must end in print or bind their result");
        }

        throw new SlangException($"unsupported runtime expression statement {expression.GetType().Name}");
    }

    private string EmitPrintCall(CallExpression call, string ok)
    {
        var path = string.Join('.', call.Path);
        if (path != "print" || call.Arguments.Count != 1)
        {
            throw new SlangException($"unsupported runtime call '{path}'");
        }

        return EmitPrintArgument(call.Arguments[0], ok);
    }

    private string EmitPrintArgument(Expression expression, string ok)
    {
        if (expression is StringExpression str)
        {
            foreach (var segment in str.Segments)
            {
                ok = segment switch
                {
                    TextSegment text => EmitWriteText(text.Text, ok),
                    InterpolationSegment interpolation => EmitWriteInterpolation(interpolation, ok),
                    _ => throw new SlangException($"unsupported string segment {segment.GetType().Name}")
                };
            }

            return ok;
        }

        var value = EmitExpression(expression);
        return EmitWriteValue(value, ok);
    }

    private string EmitWriteInterpolation(InterpolationSegment interpolation, string ok)
    {
        if (interpolation.Path.Count != 1)
        {
            throw new SlangException("path interpolation is reserved until modules are specified");
        }

        if (!_locals.TryGetValue(interpolation.Path[0], out var value))
        {
            throw new SlangException($"unknown runtime binding '{interpolation.Path[0]}'");
        }

        return EmitWriteValue(value, ok);
    }

    private string EmitWriteValue(RuntimeValue value, string ok)
    {
        return value switch
        {
            RuntimeText text => EmitWriteTextValue(text, ok),
            RuntimeInt integer => EmitWriteIntegerValue(integer, ok),
            _ => throw new SlangException($"unsupported runtime value {value.GetType().Name}")
        };
    }

    private string EmitWriteText(string text, string ok)
    {
        if (text.Length == 0)
        {
            return ok;
        }

        var global = AddGlobalString(text);
        return EmitWriteTextValue(new RuntimeText(global.Name, global.Length.ToString(CultureInfo.InvariantCulture)), ok);
    }

    private string EmitWriteTextValue(RuntimeText text, string ok)
    {
        var write = NextTemp("write");
        _functions.Append("  ")
            .Append(write)
            .Append(" = call i32 @slang_write(ptr %stdout, ptr ")
            .Append(text.PointerName)
            .Append(", i64 ")
            .Append(text.LengthName)
            .AppendLine(", ptr %written)");
        return CombineWriteOk(write, ok);
    }

    private string EmitWriteIntegerValue(RuntimeInt value, string ok)
    {
        var write = NextTemp("write");
        _functions.Append("  ")
            .Append(write)
            .Append(" = call i32 @slang_write_u64(ptr %stdout, i64 ")
            .Append(value.ValueName)
            .AppendLine(", ptr %written)");
        return CombineWriteOk(write, ok);
    }

    private string CombineWriteOk(string writeResult, string ok)
    {
        var isOk = NextTemp("is_ok");
        _functions.Append("  ")
            .Append(isOk)
            .Append(" = icmp ne i32 ")
            .Append(writeResult)
            .AppendLine(", 0");

        if (ok == "true")
        {
            return isOk;
        }

        var combined = NextTemp("ok");
        _functions.Append("  ")
            .Append(combined)
            .Append(" = and i1 ")
            .Append(ok)
            .Append(", ")
            .AppendLine(isOk);
        return combined;
    }

    private RuntimeValue EmitExpression(Expression expression)
    {
        return expression switch
        {
            StringExpression str => EmitTextLiteral(str),
            NumberExpression number => new RuntimeInt(ParseNumber(number).ToString(CultureInfo.InvariantCulture)),
            NameExpression name => ResolveLocal(name.Name),
            AddExpression add => EmitAddExpression(add),
            MultiplyExpression multiply => EmitMultiplyExpression(multiply),
            CallExpression call => EmitFunctionCall(call),
            FlowExpression flow => EmitFlowExpressionValue(flow),
            _ => throw new SlangException($"unsupported runtime expression {expression.GetType().Name}")
        };
    }

    private RuntimeText EmitTextLiteral(StringExpression expression)
    {
        var text = GetPlainText(expression, expression.Line, expression.Column);
        var global = AddGlobalString(text);
        return new RuntimeText(global.Name, global.Length.ToString(CultureInfo.InvariantCulture));
    }

    private RuntimeInt EmitIntExpression(Expression expression)
    {
        var value = EmitExpression(expression);
        return value as RuntimeInt
            ?? throw new SlangException("expected runtime integer expression");
    }

    private RuntimeInt EmitAddExpression(AddExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("add");
        _functions.Append("  ")
            .Append(result)
            .Append(" = add nsw i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitMultiplyExpression(MultiplyExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("mul");
        _functions.Append("  ")
            .Append(result)
            .Append(" = mul nsw i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeValue EmitFlowExpressionValue(FlowExpression expression)
    {
        var result = EmitFlowExpression(expression, ok: "true", allowBindingTarget: false);
        return result.Value
            ?? throw new SlangException("value-flow expression does not produce a runtime value");
    }

    private RuntimeFlowResult EmitFlowExpression(FlowExpression expression, string ok, bool allowBindingTarget)
    {
        if (expression.Targets.Count == 1 && IsPath(expression.Targets[0], "print"))
        {
            return new RuntimeFlowResult(
                Value: null,
                Binding: null,
                Ok: EmitPrintArgument(expression.Source, ok));
        }

        var current = EmitFlowSource(expression.Source);
        for (var i = 0; i < expression.Targets.Count; i++)
        {
            var target = expression.Targets[i];
            var isLast = i == expression.Targets.Count - 1;
            var path = string.Join('.', target);

            if (path == "print")
            {
                if (!isLast)
                {
                    throw new SlangException("print must be the final value-flow target");
                }

                return new RuntimeFlowResult(
                    Value: null,
                    Binding: null,
                    Ok: EmitWriteValue(current, ok));
            }

            if (program.Functions.TryGetValue(path, out var function))
            {
                current = EmitFlowFunctionCall(function, current);
                continue;
            }

            if (allowBindingTarget && isLast && target.Count == 1)
            {
                return new RuntimeFlowResult(
                    Value: null,
                    Binding: new RuntimeFlowBinding(target[0], current),
                    Ok: ok);
            }

            throw new SlangException($"unknown runtime value-flow target '{path}'");
        }

        return new RuntimeFlowResult(
            Value: current,
            Binding: null,
            Ok: ok);
    }

    private RuntimeValue EmitFlowSource(Expression source)
    {
        if (source is NameExpression name
            && !_locals.ContainsKey(name.Name)
            && program.Functions.TryGetValue(name.Name, out var function)
            && function.InputType is null)
        {
            return EmitFunctionCall(function, argument: null);
        }

        return EmitExpression(source);
    }

    private RuntimeValue EmitFunctionCall(CallExpression expression)
    {
        var path = string.Join('.', expression.Path);
        if (!program.Functions.TryGetValue(path, out var function))
        {
            throw new SlangException($"unknown runtime function '{path}'");
        }

        RuntimeValue? argument = null;
        if (function.InputType is null)
        {
            if (expression.Arguments.Count != 0)
            {
                throw new SlangException($"function '{path}' does not accept arguments");
            }
        }
        else
        {
            if (expression.Arguments.Count != 1)
            {
                throw new SlangException($"function '{path}' expects exactly one argument");
            }

            argument = EmitExpression(expression.Arguments[0]);
            EnsureRuntimeType(argument, function.InputType.Value, path);
        }

        return EmitFunctionCall(function, argument);
    }

    private RuntimeValue EmitFlowFunctionCall(BoundFunction function, RuntimeValue argument)
    {
        if (function.InputType is null)
        {
            throw new SlangException($"function '{function.Name}' does not accept a flowed input");
        }

        EnsureRuntimeType(argument, function.InputType.Value, function.Name);
        return EmitFunctionCall(function, argument);
    }

    private RuntimeValue EmitFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        return function.ReturnType switch
        {
            BoundType.Text => EmitTextFunctionCall(function, argument),
            BoundType.Int => EmitIntFunctionCall(function, argument),
            _ => throw new SlangException($"unsupported function return type {function.ReturnType}")
        };
    }

    private RuntimeText EmitTextFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        if (argument is not null)
        {
            throw new SlangException("Text-returning functions with input are not in the current runtime slice");
        }

        var aggregate = NextTemp("text");
        _functions.Append("  ")
            .Append(aggregate)
            .Append(" = call %slang.text ")
            .Append(SymbolForFunction(function.Name))
            .AppendLine("()");

        var pointer = NextTemp("text_ptr");
        _functions.Append("  ")
            .Append(pointer)
            .Append(" = extractvalue %slang.text ")
            .Append(aggregate)
            .AppendLine(", 0");

        var length = NextTemp("text_len");
        _functions.Append("  ")
            .Append(length)
            .Append(" = extractvalue %slang.text ")
            .Append(aggregate)
            .AppendLine(", 1");

        return new RuntimeText(pointer, length);
    }

    private RuntimeInt EmitIntFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        var value = NextTemp("call");
        _functions.Append("  ")
            .Append(value)
            .Append(" = call i64 ")
            .Append(SymbolForFunction(function.Name))
            .Append('(');

        if (argument is null)
        {
            _functions.Append(')');
        }
        else if (argument is RuntimeInt integer)
        {
            _functions.Append("i64 ")
                .Append(integer.ValueName)
                .Append(')');
        }
        else
        {
            throw new SlangException($"function '{function.Name}' expects an integer argument");
        }

        _functions.AppendLine();
        return new RuntimeInt(value);
    }

    private static void EnsureRuntimeType(RuntimeValue value, BoundType expected, string path)
    {
        if (value.Type != expected)
        {
            throw new SlangException($"function '{path}' expects {expected} but received {value.Type}");
        }
    }

    private static bool IsPath(IReadOnlyList<string> path, string name)
    {
        return path.Count == 1 && path[0] == name;
    }

    private RuntimeValue ResolveLocal(string name)
    {
        return _locals.TryGetValue(name, out var value)
            ? value
            : throw new SlangException($"unknown runtime binding '{name}'");
    }

    private GlobalString AddGlobalString(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        var name = "@.slang.str." + _stringId.ToString(CultureInfo.InvariantCulture);
        _stringId++;
        _globals.Append(name)
            .Append(" = private unnamed_addr constant [")
            .Append(bytes.Length.ToString(CultureInfo.InvariantCulture))
            .Append(" x i8] c\"")
            .Append(EscapeLlvmBytes(bytes))
            .AppendLine("\", align 1");
        return new GlobalString(name, bytes.Length);
    }

    private static string GetPlainText(Expression expression, int line, int column)
    {
        if (expression is not StringExpression str)
        {
            throw new SlangException($"codegen error at {line}:{column}: expected a string literal");
        }

        var builder = new StringBuilder();
        foreach (var segment in str.Segments)
        {
            if (segment is TextSegment text)
            {
                builder.Append(text.Text);
                continue;
            }

            throw new SlangException($"codegen error at {line}:{column}: expected a plain string literal");
        }

        return builder.ToString();
    }

    private static long ParseNumber(NumberExpression expression)
    {
        return long.TryParse(
            expression.Text,
            NumberStyles.None,
            CultureInfo.InvariantCulture,
            out var value)
            ? value
            : throw new SlangException($"codegen error at {expression.Line}:{expression.Column}: integer literal is out of range");
    }

    private static string SymbolForFunction(string name)
    {
        var builder = new StringBuilder("@slang_fn_");
        foreach (var c in name)
        {
            builder.Append(char.IsLetterOrDigit(c) || c == '_' ? c : '_');
        }

        return builder.ToString();
    }

    private string NextTemp(string prefix)
    {
        var name = "%" + prefix + _tempId.ToString(CultureInfo.InvariantCulture);
        _tempId++;
        return name;
    }

    private string CurrentTemp(string prefix)
    {
        return "%" + prefix + (_tempId - 1).ToString(CultureInfo.InvariantCulture);
    }

    private static string EscapeLlvmBytes(byte[] bytes)
    {
        var builder = new StringBuilder(bytes.Length);
        foreach (var b in bytes)
        {
            if (b is >= 0x20 and <= 0x7E && b != (byte)'\\' && b != (byte)'"')
            {
                builder.Append((char)b);
            }
            else
            {
                builder.Append('\\');
                builder.Append(b.ToString("X2", CultureInfo.InvariantCulture));
            }
        }

        return builder.ToString();
    }

    private sealed record GlobalString(string Name, int Length);

    private abstract record RuntimeValue(BoundType Type);

    private sealed record RuntimeText(string PointerName, string LengthName) : RuntimeValue(BoundType.Text);

    private sealed record RuntimeInt(string ValueName) : RuntimeValue(BoundType.Int);

    private sealed record RuntimeFlowBinding(string Name, RuntimeValue Value);

    private sealed record RuntimeFlowResult(RuntimeValue? Value, RuntimeFlowBinding? Binding, string Ok);
}
