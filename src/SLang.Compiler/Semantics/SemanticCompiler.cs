using SLang.Compiler.Diagnostics;
using SLang.Compiler.Syntax;

namespace SLang.Compiler.Semantics;

internal sealed class SemanticCompiler(SlangProgram program)
{
    public BoundProgram Compile()
    {
        var functions = BindFunctions();
        var mainBindings = BindMain(functions);
        return new BoundProgram(functions, program.Statements, mainBindings);
    }

    private IReadOnlyDictionary<string, BoundFunction> BindFunctions()
    {
        var functions = new Dictionary<string, BoundFunction>(StringComparer.Ordinal);
        foreach (var function in program.Functions)
        {
            if (functions.ContainsKey(function.Name))
            {
                throw Error(function.Line, function.Column, $"function '{function.Name}' already exists");
            }

            if (function.Name == "main" || function.Name == "print")
            {
                throw Error(function.Line, function.Column, $"function name '{function.Name}' is reserved");
            }

            var returnType = ParseType(function.ReturnType, function.Line, function.Column);
            functions.Add(function.Name, new BoundFunction(
                function.Name,
                returnType,
                function.Body,
                function.Line,
                function.Column));
        }

        foreach (var function in functions.Values)
        {
            var bodyType = InferExpression(function.Body, functions, new Dictionary<string, BoundType>(), allowPrintCall: false);
            if (bodyType != function.ReturnType)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"function '{function.Name}' returns {FormatType(bodyType)} but declares {FormatType(function.ReturnType)}");
            }

            if (function.ReturnType == BoundType.Text && !IsPlainStringLiteral(function.Body))
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "the first Text function body must be a plain string literal");
            }
        }

        return functions;
    }

    private IReadOnlyDictionary<string, BoundType> BindMain(IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var bindings = new Dictionary<string, BoundType>(StringComparer.Ordinal);
        foreach (var statement in program.Statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    if (bindings.ContainsKey(binding.Name))
                    {
                        throw Error(binding.Line, binding.Column, $"binding '{binding.Name}' already exists in this scope");
                    }

                    var valueType = InferExpression(binding.Value, functions, bindings, allowPrintCall: false);
                    if (valueType == BoundType.Unit)
                    {
                        throw Error(binding.Line, binding.Column, "cannot bind a unit value");
                    }

                    bindings.Add(binding.Name, valueType);
                    break;
                case ExpressionStatement expressionStatement:
                    var expressionType = InferExpression(expressionStatement.Expression, functions, bindings, allowPrintCall: true);
                    if (expressionType != BoundType.Unit)
                    {
                        throw Error(
                            expressionStatement.Expression.Line,
                            expressionStatement.Expression.Column,
                            "only function calls with side effects are valid expression statements");
                    }

                    break;
                default:
                    throw new SlangException($"unsupported statement {statement.GetType().Name}");
            }
        }

        return bindings;
    }

    private static BoundType InferExpression(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowPrintCall)
    {
        return expression switch
        {
            StringExpression str => InferStringExpression(str, bindings),
            NumberExpression => BoundType.Int,
            NameExpression name => ResolveBindingType(name.Name, bindings, name.Line, name.Column),
            AddExpression add => InferAddExpression(add, functions, bindings),
            CallExpression call => InferCallExpression(call, functions, bindings, allowPrintCall),
            _ => throw Error(expression.Line, expression.Column, "expected an expression value")
        };
    }

    private static BoundType InferStringExpression(
        StringExpression expression,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        foreach (var segment in expression.Segments)
        {
            if (segment is not InterpolationSegment interpolation)
            {
                continue;
            }

            if (interpolation.Path.Count != 1)
            {
                throw Error(expression.Line, expression.Column, "path interpolation is reserved until modules are specified");
            }

            _ = ResolveBindingType(interpolation.Path[0], bindings, expression.Line, expression.Column);
        }

        return BoundType.Text;
    }

    private static BoundType InferAddExpression(
        AddExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        var left = InferExpression(expression.Left, functions, bindings, allowPrintCall: false);
        var right = InferExpression(expression.Right, functions, bindings, allowPrintCall: false);
        if (left != BoundType.Int)
        {
            throw Error(expression.Left.Line, expression.Left.Column, "left operand of '+' must be an integer");
        }

        if (right != BoundType.Int)
        {
            throw Error(expression.Right.Line, expression.Right.Column, "right operand of '+' must be an integer");
        }

        return BoundType.Int;
    }

    private static BoundType InferCallExpression(
        CallExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowPrintCall)
    {
        var path = string.Join('.', expression.Path);
        if (path == "print")
        {
            if (!allowPrintCall)
            {
                throw Error(expression.Line, expression.Column, "print is only valid as an expression statement");
            }

            if (expression.Arguments.Count != 1)
            {
                throw Error(expression.Line, expression.Column, "print expects exactly one argument");
            }

            _ = InferExpression(expression.Arguments[0], functions, bindings, allowPrintCall: false);
            return BoundType.Unit;
        }

        if (expression.Arguments.Count != 0)
        {
            throw Error(expression.Line, expression.Column, $"function '{path}' does not accept arguments in the current slice");
        }

        return functions.TryGetValue(path, out var function)
            ? function.ReturnType
            : throw Error(expression.Line, expression.Column, $"unknown function '{path}'");
    }

    private static BoundType ResolveBindingType(
        string name,
        IReadOnlyDictionary<string, BoundType> bindings,
        int line,
        int column)
    {
        return bindings.TryGetValue(name, out var type)
            ? type
            : throw Error(line, column, $"unknown binding '{name}'");
    }

    private static BoundType ParseType(string typeName, int line, int column)
    {
        return typeName switch
        {
            "Text" => BoundType.Text,
            "Int" => BoundType.Int,
            _ => throw Error(line, column, $"unknown type '{typeName}'")
        };
    }

    private static string FormatType(BoundType type)
    {
        return type switch
        {
            BoundType.Unit => "Unit",
            BoundType.Text => "Text",
            BoundType.Int => "Int",
            _ => type.ToString()
        };
    }

    private static bool IsPlainStringLiteral(Expression expression)
    {
        return expression is StringExpression str
            && str.Segments.All(static segment => segment is TextSegment);
    }

    private static SlangException Error(int line, int column, string message)
    {
        return new SlangException($"semantic error at {line}:{column}: {message}");
    }
}
