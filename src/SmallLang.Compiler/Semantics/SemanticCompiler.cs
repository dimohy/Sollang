using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.Semantics;

internal sealed class SemanticCompiler(SmallLangProgram program)
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

            if (IsReservedName(function.Name))
            {
                throw Error(function.Line, function.Column, $"function name '{function.Name}' is reserved");
            }

            if (!function.IsStandardLibrary && function.Name.StartsWith("sys.", StringComparison.Ordinal))
            {
                throw Error(function.Line, function.Column, "the sys namespace is reserved for the standard library");
            }

            if (function.InputName is not null && function.InputType is null)
            {
                throw Error(function.Line, function.Column, "function input name requires an input type");
            }

            if (function.InputName is not null)
            {
                ValidateBindingName(function.InputName, function.Line, function.Column);
            }

            var inputType = function.InputType is null
                ? (BoundType?)null
                : ParseType(function.InputType, function.Line, function.Column);
            var returnType = ParseType(function.ReturnType, function.Line, function.Column);
            var kind = BindFunctionKind(function, inputType, returnType);

            functions.Add(function.Name, new BoundFunction(
                function.Name,
                function.InputName,
                inputType,
                returnType,
                function.Body,
                function.Line,
                function.Column,
                kind,
                function.IsStandardLibrary));
        }

        AddGlobalAliases(functions);

        var checkedFunctions = new HashSet<string>(StringComparer.Ordinal);
        foreach (var function in functions.Values)
        {
            if (function.Kind != BoundFunctionKind.User || !checkedFunctions.Add(function.Name))
            {
                continue;
            }

            var bodyBindings = new Dictionary<string, BoundType>(StringComparer.Ordinal);
            if (function.InputType is { } inputType)
            {
                bodyBindings.Add(function.InputName ?? "it", inputType);
            }

            if (function.Body is null)
            {
                throw Error(function.Line, function.Column, $"function '{function.Name}' has no body");
            }

            var bodyType = InferExpression(
                function.Body,
                functions,
                bodyBindings,
                allowPrintCall: false,
                allowReadIntCall: function.IsStandardLibrary,
                allowFlowBindingTarget: false);
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

    private static BoundFunctionKind BindFunctionKind(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (!function.IsIntrinsic)
        {
            return BoundFunctionKind.User;
        }

        if (!function.IsStandardLibrary)
        {
            throw Error(function.Line, function.Column, "intrinsic functions are reserved for the standard library");
        }

        if (function.Body is not null)
        {
            throw Error(function.Line, function.Column, $"intrinsic function '{function.Name}' cannot have a body");
        }

        return function.Name switch
        {
            "sys.runtime.print" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Text,
                BoundType.Unit,
                BoundFunctionKind.RuntimePrint),
            "sys.runtime.println" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Text,
                BoundType.Unit,
                BoundFunctionKind.RuntimePrintLine),
            "sys.runtime.readInt" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Text,
                BoundType.Int,
                BoundFunctionKind.RuntimeReadInt),
            _ => throw Error(function.Line, function.Column, $"unknown intrinsic function '{function.Name}'")
        };
    }

    private static BoundFunctionKind RequireIntrinsicSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        BoundType expectedInputType,
        BoundType expectedReturnType,
        BoundFunctionKind kind)
    {
        if (inputType != expectedInputType || returnType != expectedReturnType)
        {
            throw Error(
                function.Line,
                function.Column,
                $"intrinsic function '{function.Name}' must be {FormatType(expectedInputType)} -> {FormatType(expectedReturnType)}");
        }

        return kind;
    }

    private static void AddGlobalAliases(Dictionary<string, BoundFunction> functions)
    {
        AddGlobalAlias(functions, "print", "sys.io.print");
        AddGlobalAlias(functions, "println", "sys.io.println");
        AddGlobalAlias(functions, "readInt", "sys.io.readInt");
    }

    private static void AddGlobalAlias(
        Dictionary<string, BoundFunction> functions,
        string alias,
        string target)
    {
        if (!functions.TryGetValue(target, out var function))
        {
            throw Error(0, 0, $"standard library function '{target}' was not loaded");
        }

        if (functions.ContainsKey(alias))
        {
            throw Error(function.Line, function.Column, $"global import alias '{alias}' conflicts with an existing function");
        }

        functions.Add(alias, function);
    }

    private IReadOnlyDictionary<string, BoundType> BindMain(IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var bindings = new Dictionary<string, BoundType>(StringComparer.Ordinal);
        BindStatements(program.Statements, functions, bindings);
        return bindings;
    }

    private static void BindStatements(
        IReadOnlyList<Statement> statements,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings)
    {
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    ValidateBindingName(binding.Name, binding.Line, binding.Column);
                    if (bindings.ContainsKey(binding.Name))
                    {
                        throw Error(binding.Line, binding.Column, $"binding '{binding.Name}' already exists in this scope");
                    }

                    var valueType = InferExpression(
                        binding.Value,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall: true,
                        allowFlowBindingTarget: false);
                    if (valueType == BoundType.Unit)
                    {
                        throw Error(binding.Line, binding.Column, "cannot bind a unit value");
                    }

                    bindings.Add(binding.Name, valueType);
                    break;
                case BlockFunctionCallStatement blockFunctionCall:
                    BindBlockFunctionCall(blockFunctionCall, functions, bindings);
                    break;
                case ExpressionStatement expressionStatement:
                    var effect = InferExpressionStatement(expressionStatement.Expression, functions, bindings);
                    if (effect is FlowBindingEffect bindingEffect)
                    {
                        ValidateBindingName(
                            bindingEffect.Name,
                            expressionStatement.Expression.Line,
                            expressionStatement.Expression.Column);
                        if (bindings.ContainsKey(bindingEffect.Name))
                        {
                            throw Error(
                                expressionStatement.Expression.Line,
                                expressionStatement.Expression.Column,
                                $"binding '{bindingEffect.Name}' already exists in this scope");
                        }

                        bindings.Add(bindingEffect.Name, bindingEffect.Type);
                    }

                    break;
                default:
                    throw new SmallLangException($"unsupported statement {statement.GetType().Name}");
            }
        }
    }

    private static void BindBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings)
    {
        var target = string.Join('.', call.Target);
        if (target != "each")
        {
            throw Error(call.Line, call.Column, $"unknown block function '{target}'");
        }

        if (call.Source is not RangeExpression range)
        {
            throw Error(call.Source.Line, call.Source.Column, "each expects a range input");
        }

        if (!call.UsesDefaultItemName)
        {
            ValidateBindingName(call.ItemName, call.Line, call.Column);
        }

        if (bindings.ContainsKey(call.ItemName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ItemName}' already exists in this scope");
        }

        var startType = InferExpression(
            range.Start,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false);
        if (startType != BoundType.Int)
        {
            throw Error(range.Start.Line, range.Start.Column, "range start must be an integer");
        }

        var endType = InferExpression(
            range.End,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false);
        if (endType != BoundType.Int)
        {
            throw Error(range.End.Line, range.End.Column, "range end must be an integer");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = BoundType.Int
        };
        BindStatements(call.Body, functions, bodyBindings);
    }

    private static FlowEffect InferExpressionStatement(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (expression is FlowExpression flow)
        {
            var result = InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall: true,
                allowFlowBindingTarget: true);
            if (result.Type != BoundType.Unit && result.Effect is NoFlowEffect)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "value-flow expression statements must end in print or bind their result");
            }

            return result.Effect;
        }

        var expressionType = InferExpression(
            expression,
            functions,
            bindings,
            allowPrintCall: true,
            allowReadIntCall: true,
            allowFlowBindingTarget: false);
        if (expressionType != BoundType.Unit)
        {
            throw Error(
                expression.Line,
                expression.Column,
                "only function calls with side effects are valid expression statements");
        }

        return FlowEffect.None;
    }

    private static BoundType InferExpression(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowPrintCall,
        bool allowReadIntCall,
        bool allowFlowBindingTarget)
    {
        return expression switch
        {
            StringExpression str => InferStringExpression(str, bindings),
            NumberExpression => BoundType.Int,
            NameExpression name => ResolveBindingType(name.Name, bindings, name.Line, name.Column),
            AddExpression add => InferAddExpression(add, functions, bindings, allowReadIntCall),
            MultiplyExpression multiply => InferMultiplyExpression(multiply, functions, bindings, allowReadIntCall),
            RangeExpression => throw Error(expression.Line, expression.Column, "range values are only valid as block-function input"),
            CallExpression call => InferCallExpression(call, functions, bindings, allowPrintCall, allowReadIntCall),
            FlowExpression flow => InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall,
                allowFlowBindingTarget).Type,
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
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "+");
    }

    private static BoundType InferMultiplyExpression(
        MultiplyExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "*");
    }

    private static BoundType InferIntegerBinaryExpression(
        Expression leftExpression,
        Expression rightExpression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string operatorText)
    {
        var left = InferExpression(
            leftExpression,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        var right = InferExpression(
            rightExpression,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (left != BoundType.Int)
        {
            throw Error(leftExpression.Line, leftExpression.Column, $"left operand of '{operatorText}' must be an integer");
        }

        if (right != BoundType.Int)
        {
            throw Error(rightExpression.Line, rightExpression.Column, $"right operand of '{operatorText}' must be an integer");
        }

        return BoundType.Int;
    }

    private static FlowResult InferFlowExpression(
        FlowExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        bool allowFlowBindingTarget)
    {
        var currentType = InferFlowSource(expression.Source, functions, bindings, allowReadIntCall);
        for (var i = 0; i < expression.Targets.Count; i++)
        {
            var target = expression.Targets[i];
            var isLast = i == expression.Targets.Count - 1;
            var path = string.Join('.', target);

            if (functions.TryGetValue(path, out var function))
            {
                switch (function.Kind)
                {
                    case BoundFunctionKind.RuntimePrint:
                    case BoundFunctionKind.RuntimePrintLine:
                        if (!isLast)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} must be the final value-flow target");
                        }

                        EnsureDisplayable(currentType, expression.Line, expression.Column, path);
                        return new FlowResult(BoundType.Unit, FlowEffect.None);
                    case BoundFunctionKind.RuntimeReadInt:
                        if (!allowReadIntCall)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} is only valid in main for the current runtime slice");
                        }

                        if (currentType != BoundType.Text)
                        {
                            throw Error(
                                expression.Line,
                                expression.Column,
                                $"{path} expects Text but received {FormatType(currentType)}");
                        }

                        currentType = BoundType.Int;
                        continue;
                    case BoundFunctionKind.User:
                        if (IsReadIntFunction(function) && !allowReadIntCall)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} is only valid in main for the current runtime slice");
                        }

                        if (function.InputType is null)
                        {
                            throw Error(expression.Line, expression.Column, $"function '{path}' does not accept a flowed input");
                        }

                        if (currentType != function.InputType)
                        {
                            throw Error(
                                expression.Line,
                                expression.Column,
                                $"function '{path}' expects {FormatType(function.InputType.Value)} but received {FormatType(currentType)}");
                        }

                        currentType = function.ReturnType;
                        continue;
                    default:
                        throw Error(expression.Line, expression.Column, $"unsupported function kind '{function.Kind}'");
                }
            }

            if (allowFlowBindingTarget && isLast && target.Count == 1)
            {
                return new FlowResult(BoundType.Unit, new FlowBindingEffect(target[0], currentType));
            }

            throw Error(expression.Line, expression.Column, $"unknown value-flow target '{path}'");
        }

        return new FlowResult(currentType, FlowEffect.None);
    }

    private static BoundType InferFlowSource(
        Expression source,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        if (source is NameExpression name && !bindings.ContainsKey(name.Name))
        {
            if (functions.TryGetValue(name.Name, out var function)
                && function.Kind == BoundFunctionKind.User
                && function.InputType is null)
            {
                return function.ReturnType;
            }
        }

        return InferExpression(
            source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
    }

    private static BoundType InferCallExpression(
        CallExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowPrintCall,
        bool allowReadIntCall)
    {
        var path = string.Join('.', expression.Path);
        if (!functions.TryGetValue(path, out var function))
        {
            throw Error(expression.Line, expression.Column, $"unknown function '{path}'");
        }

        switch (function.Kind)
        {
            case BoundFunctionKind.RuntimePrint:
            case BoundFunctionKind.RuntimePrintLine:
                if (!allowPrintCall)
                {
                    throw Error(expression.Line, expression.Column, $"{path} is only valid as an expression statement");
                }

                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one argument");
                }

                var valueType = InferExpression(
                    expression.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
                EnsureDisplayable(valueType, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
                return BoundType.Unit;
            case BoundFunctionKind.RuntimeReadInt:
                if (!allowReadIntCall)
                {
                    throw Error(expression.Line, expression.Column, $"{path} is only valid in main for the current runtime slice");
                }

                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one Text prompt");
                }

                var promptType = InferExpression(
                    expression.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
                if (promptType != BoundType.Text)
                {
                    throw Error(
                        expression.Arguments[0].Line,
                        expression.Arguments[0].Column,
                        $"{path} expects Text but received {FormatType(promptType)}");
                }

                return BoundType.Int;
            case BoundFunctionKind.User:
                return InferUserCallExpression(expression, function, functions, bindings, allowReadIntCall, path);
            default:
                throw Error(expression.Line, expression.Column, $"unsupported function kind '{function.Kind}'");
        }
    }

    private static BoundType InferUserCallExpression(
        CallExpression expression,
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string path)
    {
        if (IsReadIntFunction(function) && !allowReadIntCall)
        {
            throw Error(expression.Line, expression.Column, $"{path} is only valid in main for the current runtime slice");
        }

        if (function.InputType is null)
        {
            if (expression.Arguments.Count != 0)
            {
                throw Error(expression.Line, expression.Column, $"function '{path}' does not accept arguments");
            }

            return function.ReturnType;
        }

        if (expression.Arguments.Count != 1)
        {
            throw Error(expression.Line, expression.Column, $"function '{path}' expects exactly one argument");
        }

        var argumentType = InferExpression(
            expression.Arguments[0],
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (argumentType != function.InputType)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"function '{path}' expects {FormatType(function.InputType.Value)} but received {FormatType(argumentType)}");
        }

        return function.ReturnType;
    }

    private static void EnsureDisplayable(BoundType type, int line, int column, string path)
    {
        if (type is not (BoundType.Text or BoundType.Int))
        {
            throw Error(line, column, $"{path} expects Text or Int but received {FormatType(type)}");
        }
    }

    private static bool IsReadIntFunction(BoundFunction function)
    {
        return function.Name == "sys.io.readInt";
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

    private static void ValidateBindingName(string name, int line, int column)
    {
        if (IsReservedName(name))
        {
            throw Error(line, column, $"binding name '{name}' is reserved");
        }
    }

    private static bool IsReservedName(string name)
    {
        return name is "main" or "sys" or "print" or "println" or "readInt" or "each" or "in" or "it";
    }

    private static BoundType ParseType(string typeName, int line, int column)
    {
        return typeName switch
        {
            "Unit" => BoundType.Unit,
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

    private static SmallLangException Error(int line, int column, string message)
    {
        return new SmallLangException($"semantic error at {line}:{column}: {message}");
    }

    private sealed record FlowResult(BoundType Type, FlowEffect Effect);

    private abstract record FlowEffect
    {
        public static FlowEffect None { get; } = new NoFlowEffect();
    }

    private sealed record NoFlowEffect : FlowEffect;

    private sealed record FlowBindingEffect(string Name, BoundType Type) : FlowEffect;
}
