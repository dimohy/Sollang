using System.Text;
using SLang.Compiler.Diagnostics;
using SLang.Compiler.Syntax;

namespace SLang.Compiler.Semantics;

internal sealed class SemanticCompiler(SlangProgram program)
{
    public byte[] CompileToStdoutBytes()
    {
        var bindings = new Dictionary<string, string>(StringComparer.Ordinal);
        var output = new StringBuilder();

        foreach (var statement in program.Statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    if (bindings.ContainsKey(binding.Name))
                    {
                        throw Error(binding.Line, binding.Column, $"binding '{binding.Name}' already exists in this scope");
                    }

                    bindings.Add(binding.Name, EvaluateString(binding.Value, bindings));
                    break;
                case ExpressionStatement expressionStatement:
                    CompileExpressionStatement(expressionStatement.Expression, bindings, output);
                    break;
                default:
                    throw new SlangException($"unsupported statement {statement.GetType().Name}");
            }
        }

        return Encoding.UTF8.GetBytes(output.ToString());
    }

    private static void CompileExpressionStatement(
        Expression expression,
        IReadOnlyDictionary<string, string> bindings,
        StringBuilder output)
    {
        if (expression is not CallExpression call)
        {
            throw Error(expression.Line, expression.Column, "only function calls are valid expression statements");
        }

        var path = string.Join('.', call.Path);
        if (path != "print")
        {
            throw Error(call.Line, call.Column, $"unknown function '{path}'");
        }

        if (call.Arguments.Count != 1)
        {
            throw Error(call.Line, call.Column, "print expects exactly one argument");
        }

        output.Append(EvaluateString(call.Arguments[0], bindings));
    }

    private static string EvaluateString(Expression expression, IReadOnlyDictionary<string, string> bindings)
    {
        return expression switch
        {
            StringExpression str => EvaluateStringLiteral(str, bindings),
            NameExpression name => ResolveName(name.Name, bindings, name.Line, name.Column),
            _ => throw Error(expression.Line, expression.Column, "expected a string expression")
        };
    }

    private static string EvaluateStringLiteral(StringExpression expression, IReadOnlyDictionary<string, string> bindings)
    {
        var result = new StringBuilder();
        foreach (var segment in expression.Segments)
        {
            switch (segment)
            {
                case TextSegment text:
                    result.Append(text.Text);
                    break;
                case InterpolationSegment interpolation:
                    if (interpolation.Path.Count != 1)
                    {
                        throw Error(expression.Line, expression.Column, "path interpolation is reserved until modules are specified");
                    }

                    result.Append(ResolveName(interpolation.Path[0], bindings, expression.Line, expression.Column));
                    break;
                default:
                    throw new SlangException($"unsupported string segment {segment.GetType().Name}");
            }
        }

        return result.ToString();
    }

    private static string ResolveName(string name, IReadOnlyDictionary<string, string> bindings, int line, int column)
    {
        return bindings.TryGetValue(name, out var value)
            ? value
            : throw Error(line, column, $"unknown binding '{name}'");
    }

    private static SlangException Error(int line, int column, string message)
    {
        return new SlangException($"semantic error at {line}:{column}: {message}");
    }
}
