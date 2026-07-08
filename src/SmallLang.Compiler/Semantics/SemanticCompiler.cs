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
        foreach (var declaration in program.Functions)
        {
            if (functions.ContainsKey(declaration.Name))
            {
                throw Error(declaration.Line, declaration.Column, $"function '{declaration.Name}' already exists");
            }

            var function = BindFunctionDeclaration(declaration, isLocal: false);
            functions.Add(function.Name, function);
        }

        AddGlobalAliases(functions);

        var checkedFunctions = new HashSet<string>(StringComparer.Ordinal);
        foreach (var function in functions.Values)
        {
            if (function.Kind is not (BoundFunctionKind.User or BoundFunctionKind.UserBlock)
                || !checkedFunctions.Add(function.Name))
            {
                continue;
            }

            ValidateUserFunction(
                function,
                functions,
                new Dictionary<string, BoundType>(StringComparer.Ordinal));
        }

        return functions;
    }

    private static BoundFunction BindFunctionDeclaration(FunctionDeclaration function, bool isLocal)
    {
        ValidateFunctionDeclaration(function, isLocal);

        var inputType = function.InputType is null
            ? (BoundType?)null
            : ParseType(function.InputType, function.Line, function.Column);
        var returnType = ParseType(function.ReturnType, function.Line, function.Column);
        var blockInputType = function.BlockInputType is null
            ? (BoundType?)null
            : ParseType(function.BlockInputType, function.Line, function.Column);
        var kind = BindFunctionKind(function, inputType, returnType, isLocal);
        var localFunctions = BindLocalFunctions(function);

        return new BoundFunction(
            function.Name,
            function.InputName,
            inputType,
            returnType,
            function.BlockInputName,
            blockInputType,
            localFunctions,
            function.Body,
            function.BlockBody,
            function.Line,
            function.Column,
            kind,
            function.IsStandardLibrary,
            isLocal);
    }

    private static void ValidateFunctionDeclaration(FunctionDeclaration function, bool isLocal)
    {
        if (isLocal && function.Name.Contains('.', StringComparison.Ordinal))
        {
            throw Error(function.Line, function.Column, "local function names cannot be path-qualified");
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

        if (function.BlockInputName is not null && function.BlockInputType is null)
        {
            throw Error(function.Line, function.Column, "block input name requires a block input type");
        }

        if (function.BlockInputName is not null)
        {
            ValidateBindingName(function.BlockInputName, function.Line, function.Column);
        }

        if (function.BlockInputName is not null && function.ReturnType != "Unit")
        {
            throw Error(function.Line, function.Column, "block functions must declare Unit return type");
        }

        if (function.BlockInputName is null && function.BlockBody.Count != 0)
        {
            throw Error(function.Line, function.Column, "block function body requires a block input declaration");
        }
    }

    private static IReadOnlyDictionary<string, BoundFunction> BindLocalFunctions(FunctionDeclaration owner)
    {
        var functions = new Dictionary<string, BoundFunction>(StringComparer.Ordinal);
        foreach (var localDeclaration in owner.LocalFunctions)
        {
            if (functions.ContainsKey(localDeclaration.Name))
            {
                throw Error(
                    localDeclaration.Line,
                    localDeclaration.Column,
                    $"local function '{localDeclaration.Name}' already exists in function '{owner.Name}'");
            }

            var localFunction = BindFunctionDeclaration(localDeclaration, isLocal: true);
            functions.Add(localFunction.Name, localFunction);
        }

        return functions;
    }

    private static void ValidateUserFunction(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundType> capturedBindings)
    {
        if (function.Kind == BoundFunctionKind.UserBlock)
        {
            ValidateUserBlockFunction(function, parentFunctions, capturedBindings);
            return;
        }

        var bodyBindings = new Dictionary<string, BoundType>(capturedBindings, StringComparer.Ordinal);
        if (function.InputType is { } inputType)
        {
            bodyBindings[function.InputName ?? "it"] = inputType;
        }

        var scopedFunctions = CreateFunctionScope(parentFunctions, function.LocalFunctions);
        foreach (var localFunction in function.LocalFunctions.Values)
        {
            ValidateUserFunction(localFunction, scopedFunctions, bodyBindings);
        }

        if (function.Body is null)
        {
            throw Error(function.Line, function.Column, $"function '{function.Name}' has no body");
        }

        var bodyType = InferExpression(
            function.Body,
            scopedFunctions,
            bodyBindings,
            allowPrintCall: false,
            allowReadIntCall: function.IsStandardLibrary,
            allowFlowBindingTarget: false,
            yieldInputType: null);
        if (bodyType != function.ReturnType)
        {
            throw Error(
                function.Line,
                function.Column,
                $"function '{function.Name}' returns {FormatType(bodyType)} but declares {FormatType(function.ReturnType)}");
        }

    }

    private static void ValidateUserBlockFunction(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundType> capturedBindings)
    {
        if (function.InputType is null)
        {
            throw Error(function.Line, function.Column, $"block function '{function.Name}' requires an input");
        }

        if (function.BlockInputType is null)
        {
            throw Error(function.Line, function.Column, $"block function '{function.Name}' requires a block input");
        }

        var bodyBindings = new Dictionary<string, BoundType>(capturedBindings, StringComparer.Ordinal)
        {
            [function.InputName ?? "it"] = function.InputType.Value
        };

        var scopedFunctions = CreateFunctionScope(parentFunctions, function.LocalFunctions);
        foreach (var localFunction in function.LocalFunctions.Values)
        {
            ValidateUserFunction(localFunction, scopedFunctions, bodyBindings);
        }

        BindStatements(function.BlockBody, scopedFunctions, bodyBindings, function.BlockInputType.Value);
    }

    private static IReadOnlyDictionary<string, BoundFunction> CreateFunctionScope(
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundFunction> localFunctions)
    {
        if (localFunctions.Count == 0)
        {
            return parentFunctions;
        }

        var functions = new Dictionary<string, BoundFunction>(parentFunctions, StringComparer.Ordinal);
        foreach (var (name, function) in localFunctions)
        {
            functions[name] = function;
        }

        return functions;
    }

    private static BoundFunctionKind BindFunctionKind(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        bool isLocal)
    {
        if (!function.IsIntrinsic)
        {
            return function.BlockInputName is null
                ? BoundFunctionKind.User
                : BoundFunctionKind.UserBlock;
        }

        if (isLocal)
        {
            throw Error(function.Line, function.Column, "local intrinsic functions are not supported");
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
            "sys.runtime.seedRandom" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                BoundType.Unit,
                BoundFunctionKind.RuntimeSeedRandom),
            "sys.runtime.randomBelow" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                BoundType.Int,
                BoundFunctionKind.RuntimeRandomBelow),
            "sys.runtime.openIntWriter" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Text,
                BoundType.Unit,
                BoundFunctionKind.RuntimeOpenIntWriter),
            "sys.runtime.writeInt" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                BoundType.Unit,
                BoundFunctionKind.RuntimeWriteInt),
            "sys.runtime.closeIntWriter" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Unit,
                BoundFunctionKind.RuntimeCloseIntWriter),
            "sys.runtime.openIntReader" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Text,
                BoundType.Unit,
                BoundFunctionKind.RuntimeOpenIntReader),
            "sys.runtime.closestInt" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                BoundType.Int,
                BoundFunctionKind.RuntimeClosestInt),
            "sys.runtime.closeIntReader" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Unit,
                BoundFunctionKind.RuntimeCloseIntReader),
            _ => throw Error(function.Line, function.Column, $"unknown intrinsic function '{function.Name}'")
        };
    }

    private static BoundFunctionKind RequireIntrinsicSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        BoundType? expectedInputType,
        BoundType expectedReturnType,
        BoundFunctionKind kind)
    {
        if (inputType != expectedInputType || returnType != expectedReturnType)
        {
            var expectedSignature = expectedInputType is null
                ? "-> " + FormatType(expectedReturnType)
                : FormatType(expectedInputType.Value) + " -> " + FormatType(expectedReturnType);
            throw Error(
                function.Line,
                function.Column,
                $"intrinsic function '{function.Name}' must be {expectedSignature}");
        }

        return kind;
    }

    private static void AddGlobalAliases(Dictionary<string, BoundFunction> functions)
    {
        AddGlobalAlias(functions, "print", "sys.io.print");
        AddGlobalAlias(functions, "println", "sys.io.println");
        AddGlobalAlias(functions, "readInt", "sys.io.readInt");
        AddGlobalAlias(functions, "seedRandom", "sys.random.seed");
        AddGlobalAlias(functions, "randomBelow", "sys.random.below");
        AddGlobalAlias(functions, "openIntWriter", "sys.file.openIntWriter");
        AddGlobalAlias(functions, "writeInt", "sys.file.writeInt");
        AddGlobalAlias(functions, "closeIntWriter", "sys.file.closeIntWriter");
        AddGlobalAlias(functions, "openIntReader", "sys.file.openIntReader");
        AddGlobalAlias(functions, "closestInt", "sys.file.closestInt");
        AddGlobalAlias(functions, "closeIntReader", "sys.file.closeIntReader");
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
        Dictionary<string, BoundType> bindings,
        BoundType? yieldInputType = null)
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
                        allowFlowBindingTarget: false,
                        yieldInputType: yieldInputType);
                    if (valueType == BoundType.Unit)
                    {
                        throw Error(binding.Line, binding.Column, "cannot bind a unit value");
                    }

                    bindings.Add(binding.Name, valueType);
                    break;
                case BlockFunctionCallStatement blockFunctionCall:
                    BindBlockFunctionCall(blockFunctionCall, functions, bindings, yieldInputType);
                    break;
                case ExpressionStatement expressionStatement:
                    var effect = InferExpressionStatement(expressionStatement.Expression, functions, bindings, yieldInputType);
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
        Dictionary<string, BoundType> bindings,
        BoundType? yieldInputType)
    {
        var target = string.Join('.', call.Target);
        switch (target)
        {
            case "each":
                BindEachBlockFunctionCall(call, functions, bindings, yieldInputType);
                return;
            case "repeat":
                BindRepeatBlockFunctionCall(call, functions, bindings, yieldInputType);
                return;
            default:
                if (functions.TryGetValue(target, out var function)
                    && function.Kind == BoundFunctionKind.UserBlock)
                {
                    BindUserBlockFunctionCall(call, function, functions, bindings, target);
                    return;
                }

                throw Error(call.Line, call.Column, $"unknown block function '{target}'");
        }
    }

    private static void BindEachBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        BoundType? yieldInputType)
    {
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
        BindStatements(call.Body, functions, bodyBindings, yieldInputType);
    }

    private static void BindUserBlockFunctionCall(
        BlockFunctionCallStatement call,
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        string target)
    {
        if (function.InputType is null || function.BlockInputType is null)
        {
            throw Error(call.Line, call.Column, $"block function '{target}' is not callable");
        }

        if (!call.UsesDefaultItemName)
        {
            ValidateBindingName(call.ItemName, call.Line, call.Column);
        }

        if (bindings.ContainsKey(call.ItemName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ItemName}' already exists in this scope");
        }

        var inputType = InferExpression(
            call.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false);
        if (inputType != function.InputType.Value)
        {
            throw Error(
                call.Source.Line,
                call.Source.Column,
                $"block function '{target}' expects {FormatType(function.InputType.Value)} but received {FormatType(inputType)}");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = function.BlockInputType.Value
        };
        BindStatements(call.Body, functions, bodyBindings);
    }

    private static void BindRepeatBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        BoundType? yieldInputType)
    {
        if (!call.UsesDefaultItemName)
        {
            ValidateBindingName(call.ItemName, call.Line, call.Column);
        }

        if (bindings.ContainsKey(call.ItemName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ItemName}' already exists in this scope");
        }

        var countType = InferExpression(
            call.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false);
        if (countType != BoundType.Int)
        {
            throw Error(call.Source.Line, call.Source.Column, "repeat expects an integer input");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = BoundType.Int
        };
        BindStatements(call.Body, functions, bodyBindings, yieldInputType);
    }

    private static FlowEffect InferExpressionStatement(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        BoundType? yieldInputType = null)
    {
        if (expression is FlowExpression flow)
        {
            var result = InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall: true,
                allowFlowBindingTarget: true,
                yieldInputType: yieldInputType);
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
            allowFlowBindingTarget: false,
            yieldInputType: yieldInputType);
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
        bool allowFlowBindingTarget,
        BoundType? yieldInputType = null)
    {
        return expression switch
        {
            StringExpression str => InferStringExpression(str, bindings),
            NumberExpression => BoundType.Int,
            BoolExpression => BoundType.Bool,
            NameExpression name => InferNameExpression(name, functions, bindings),
            AddExpression add => InferAddExpression(add, functions, bindings, allowReadIntCall),
            SubtractExpression subtract => InferSubtractExpression(subtract, functions, bindings, allowReadIntCall),
            MultiplyExpression multiply => InferMultiplyExpression(multiply, functions, bindings, allowReadIntCall),
            DivideExpression divide => InferDivideExpression(divide, functions, bindings, allowReadIntCall),
            ModuloExpression modulo => InferModuloExpression(modulo, functions, bindings, allowReadIntCall),
            NegateExpression negate => InferNegateExpression(negate, functions, bindings, allowReadIntCall),
            CompareExpression compare => InferCompareExpression(compare, functions, bindings, allowReadIntCall),
            AndExpression and => InferLogicalExpression(and.Left, and.Right, functions, bindings, allowReadIntCall, "and"),
            OrExpression or => InferLogicalExpression(or.Left, or.Right, functions, bindings, allowReadIntCall, "or"),
            NotExpression not => InferNotExpression(not, functions, bindings, allowReadIntCall),
            IfExpression conditional => InferIfExpression(conditional, functions, bindings, allowReadIntCall),
            WhenExpression whenExpression => InferWhenExpression(whenExpression, functions, bindings, allowReadIntCall),
            SubjectCompareExpression => throw Error(
                expression.Line,
                expression.Column,
                "subject comparison is only valid inside value-flow when"),
            SubjectRangeExpression => throw Error(
                expression.Line,
                expression.Column,
                "subject range is only valid inside value-flow when"),
            FoldExpression fold => InferFoldExpression(fold, functions, bindings, allowReadIntCall),
            RangeExpression => throw Error(expression.Line, expression.Column, "range values are only valid as block-function input"),
            CallExpression call => InferCallExpression(call, functions, bindings, allowPrintCall, allowReadIntCall),
            FlowExpression flow => InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall,
                allowFlowBindingTarget,
                yieldInputType).Type,
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

            var interpolationType = ResolveBindingType(interpolation.Path[0], bindings, expression.Line, expression.Column);
            EnsureDisplayable(interpolationType, expression.Line, expression.Column, "string interpolation");
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

    private static BoundType InferSubtractExpression(
        SubtractExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "-");
    }

    private static BoundType InferDivideExpression(
        DivideExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "/");
    }

    private static BoundType InferModuloExpression(
        ModuloExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "%");
    }

    private static BoundType InferNegateExpression(
        NegateExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var value = InferExpression(
            expression.Value,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (value != BoundType.Int)
        {
            throw Error(expression.Value.Line, expression.Value.Column, "operand of unary '-' must be an integer");
        }

        return BoundType.Int;
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

    private static BoundType InferCompareExpression(
        CompareExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var left = InferExpression(
            expression.Left,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        var right = InferExpression(
            expression.Right,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);

        if (left != BoundType.Int)
        {
            throw Error(expression.Left.Line, expression.Left.Column, "left operand of comparison must be an integer");
        }

        if (right != BoundType.Int)
        {
            throw Error(expression.Right.Line, expression.Right.Column, "right operand of comparison must be an integer");
        }

        return BoundType.Bool;
    }

    private static BoundType InferLogicalExpression(
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

        if (left != BoundType.Bool)
        {
            throw Error(leftExpression.Line, leftExpression.Column, $"left operand of '{operatorText}' must be Bool");
        }

        if (right != BoundType.Bool)
        {
            throw Error(rightExpression.Line, rightExpression.Column, $"right operand of '{operatorText}' must be Bool");
        }

        return BoundType.Bool;
    }

    private static BoundType InferNotExpression(
        NotExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var value = InferExpression(
            expression.Value,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (value != BoundType.Bool)
        {
            throw Error(expression.Value.Line, expression.Value.Column, "'not' expects Bool");
        }

        return BoundType.Bool;
    }

    private static BoundType InferIfExpression(
        IfExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var condition = InferExpression(
            expression.Condition,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (condition != BoundType.Bool)
        {
            throw Error(expression.Condition.Line, expression.Condition.Column, "if expects Bool input");
        }

        var thenType = InferBlockBody(expression.Then, functions, bindings, allowReadIntCall);
        if (expression.Else is null)
        {
            if (thenType != BoundType.Unit)
            {
                throw Error(expression.Line, expression.Column, "if used as a value requires an else block");
            }

            return BoundType.Unit;
        }

        var elseType = InferBlockBody(expression.Else, functions, bindings, allowReadIntCall);
        if (thenType != elseType)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"if branches must return the same type, got {FormatType(thenType)} and {FormatType(elseType)}");
        }

        return thenType;
    }

    private static BoundType InferWhenExpression(
        WhenExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var hasSubjectConditions = expression.Arms.Any(static arm => IsSubjectWhenCondition(arm.Condition));
        if (expression.Subject is not null)
        {
            var subjectType = InferExpression(
                expression.Subject,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
            if (subjectType != BoundType.Int)
            {
                throw Error(expression.Subject.Line, expression.Subject.Column, "value-flow when subject must be an integer");
            }
        }
        else if (hasSubjectConditions)
        {
            if (!bindings.TryGetValue("it", out var implicitSubject) || implicitSubject != BoundType.Int)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "subject-style when without an explicit subject requires the default integer input 'it'");
            }
        }

        BoundType? resultType = null;
        foreach (var arm in expression.Arms)
        {
            var condition = expression.Subject is null && !hasSubjectConditions
                ? InferExpression(
                    arm.Condition,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false)
                : InferSubjectWhenCondition(
                    arm.Condition,
                    functions,
                    bindings,
                    allowReadIntCall);
            if (condition != BoundType.Bool)
            {
                throw Error(arm.Condition.Line, arm.Condition.Column, "when arm condition must be Bool");
            }

            var armType = InferBlockBody(arm.Body, functions, bindings, allowReadIntCall);
            resultType ??= armType;
            if (armType != resultType)
            {
                throw Error(
                    arm.Line,
                    arm.Column,
                    $"when arms must return the same type, got {FormatType(resultType.Value)} and {FormatType(armType)}");
            }
        }

        var elseType = InferBlockBody(expression.Else, functions, bindings, allowReadIntCall);
        resultType ??= elseType;
        if (elseType != resultType)
        {
            throw Error(
                expression.Else.Line,
                expression.Else.Column,
                $"when else must return {FormatType(resultType.Value)} but returns {FormatType(elseType)}");
        }

        return resultType.Value;
    }

    private static bool IsSubjectWhenCondition(Expression condition)
    {
        return condition is SubjectCompareExpression or SubjectRangeExpression;
    }

    private static BoundType InferSubjectWhenCondition(
        Expression condition,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        if (condition is SubjectCompareExpression compare)
        {
            var right = InferExpression(
                compare.Right,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
            if (right != BoundType.Int)
            {
                throw Error(compare.Right.Line, compare.Right.Column, "right operand of value-flow when comparison must be an integer");
            }

            return BoundType.Bool;
        }

        if (condition is not SubjectRangeExpression range)
        {
            throw Error(condition.Line, condition.Column, "value-flow when arm must start with a comparison operator or range");
        }

        var start = InferExpression(
            range.Start,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (start != BoundType.Int)
        {
            throw Error(range.Start.Line, range.Start.Column, "range start of value-flow when arm must be an integer");
        }

        var end = InferExpression(
            range.End,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (end != BoundType.Int)
        {
            throw Error(range.End.Line, range.End.Column, "range end of value-flow when arm must be an integer");
        }

        return BoundType.Bool;
    }

    private static BoundType InferFoldExpression(
        FoldExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        ValidateBindingName(expression.AccumulatorName, expression.Line, expression.Column);
        ValidateBindingName(expression.ItemName, expression.Line, expression.Column);
        if (expression.AccumulatorName == expression.ItemName)
        {
            throw Error(expression.Line, expression.Column, "fold accumulator and item names must be different");
        }

        if (bindings.ContainsKey(expression.AccumulatorName))
        {
            throw Error(expression.Line, expression.Column, $"binding '{expression.AccumulatorName}' already exists in this scope");
        }

        if (bindings.ContainsKey(expression.ItemName))
        {
            throw Error(expression.Line, expression.Column, $"binding '{expression.ItemName}' already exists in this scope");
        }

        var startType = InferExpression(
            expression.Source.Start,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (startType != BoundType.Int)
        {
            throw Error(expression.Source.Start.Line, expression.Source.Start.Column, "range start must be an integer");
        }

        var endType = InferExpression(
            expression.Source.End,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (endType != BoundType.Int)
        {
            throw Error(expression.Source.End.Line, expression.Source.End.Column, "range end must be an integer");
        }

        var initialType = InferExpression(
            expression.Initial,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (initialType != BoundType.Int)
        {
            throw Error(expression.Initial.Line, expression.Initial.Column, "fold initial value must be an integer");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [expression.AccumulatorName] = BoundType.Int,
            [expression.ItemName] = BoundType.Int
        };
        var bodyType = InferBlockBody(expression.Body, functions, bodyBindings, allowReadIntCall);
        if (bodyType != BoundType.Int)
        {
            throw Error(expression.Body.Line, expression.Body.Column, "fold body must return the next integer accumulator value");
        }

        return BoundType.Int;
    }

    private static BoundType InferBlockBody(
        BlockBody body,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal);
        BindStatements(body.Statements, functions, bodyBindings);
        return body.Value is null
            ? BoundType.Unit
            : InferExpression(
                body.Value,
                functions,
                bodyBindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
    }

    private static FlowResult InferFlowExpression(
        FlowExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        bool allowFlowBindingTarget,
        BoundType? yieldInputType = null)
    {
        var currentType = InferFlowSource(expression.Source, functions, bindings, allowReadIntCall);
        for (var i = 0; i < expression.Targets.Count; i++)
        {
            var target = expression.Targets[i];
            var isLast = i == expression.Targets.Count - 1;
            var path = string.Join('.', target.Path);

            if (path == "yield")
            {
                if (yieldInputType is null)
                {
                    throw Error(target.Line, target.Column, "yield() is only valid inside a block function");
                }

                if (!target.UsesCallSyntax)
                {
                    throw Error(target.Line, target.Column, "yield must use empty call syntax 'yield()'");
                }

                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "yield() must be the final value-flow target");
                }

                if (currentType != yieldInputType.Value)
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"yield expects {FormatType(yieldInputType.Value)} but received {FormatType(currentType)}");
                }

                return new FlowResult(BoundType.Unit, FlowEffect.None);
            }

            if (functions.TryGetValue(path, out var function))
            {
                if (!target.UsesCallSyntax)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"function value-flow target '{path}' must use empty call syntax '{path}()' unless it is followed by a block argument");
                }

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
                    case BoundFunctionKind.RuntimeSeedRandom:
                    case BoundFunctionKind.RuntimeWriteInt:
                        EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        if (!isLast)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} must be the final value-flow target");
                        }

                        return new FlowResult(BoundType.Unit, FlowEffect.None);
                    case BoundFunctionKind.RuntimeOpenIntWriter:
                    case BoundFunctionKind.RuntimeOpenIntReader:
                        EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        if (!isLast)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} must be the final value-flow target");
                        }

                        return new FlowResult(BoundType.Unit, FlowEffect.None);
                    case BoundFunctionKind.RuntimeRandomBelow:
                    case BoundFunctionKind.RuntimeClosestInt:
                        EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeCloseIntWriter:
                    case BoundFunctionKind.RuntimeCloseIntReader:
                        throw Error(expression.Line, expression.Column, $"{path} does not accept a flowed input");
                    case BoundFunctionKind.User:
                        if (IsMainOnlyRuntimeWrapper(function) && !allowReadIntCall)
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

            if (allowFlowBindingTarget && isLast && !target.UsesCallSyntax && target.Path.Count == 1)
            {
                return new FlowResult(BoundType.Unit, new FlowBindingEffect(target.Path[0], currentType));
            }

            var targetKind = target.UsesCallSyntax ? "function" : "value-flow target";
            throw Error(target.Line, target.Column, $"unknown {targetKind} '{path}'");
        }

        return new FlowResult(currentType, FlowEffect.None);
    }

    private static BoundType InferFlowSource(
        Expression source,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
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
            case BoundFunctionKind.RuntimeSeedRandom:
            case BoundFunctionKind.RuntimeRandomBelow:
            case BoundFunctionKind.RuntimeOpenIntWriter:
            case BoundFunctionKind.RuntimeWriteInt:
            case BoundFunctionKind.RuntimeOpenIntReader:
            case BoundFunctionKind.RuntimeClosestInt:
                EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one argument");
                }

                var argumentType = InferExpression(
                    expression.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
                EnsureRuntimeInput(argumentType, function, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
                return function.ReturnType;
            case BoundFunctionKind.RuntimeCloseIntWriter:
            case BoundFunctionKind.RuntimeCloseIntReader:
                EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                if (expression.Arguments.Count != 0)
                {
                    throw Error(expression.Line, expression.Column, $"{path} does not accept arguments");
                }

                return BoundType.Unit;
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
        if (IsMainOnlyRuntimeWrapper(function) && !allowReadIntCall)
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

    private static bool IsMainOnlyRuntimeWrapper(BoundFunction function)
    {
        return function.Name is "sys.io.readInt"
            or "sys.random.seed"
            or "sys.random.below"
            or "sys.file.openIntWriter"
            or "sys.file.writeInt"
            or "sys.file.closeIntWriter"
            or "sys.file.openIntReader"
            or "sys.file.closestInt"
            or "sys.file.closeIntReader";
    }

    private static void EnsureRuntimeIntrinsicAllowed(
        BoundFunction function,
        bool allowRuntimeCall,
        int line,
        int column,
        string path)
    {
        if (!allowRuntimeCall)
        {
            throw Error(line, column, $"{path} is only valid in main for the current runtime slice");
        }
    }

    private static void EnsureRuntimeInput(
        BoundType actualType,
        BoundFunction function,
        int line,
        int column,
        string path)
    {
        if (function.InputType is null)
        {
            throw Error(line, column, $"{path} does not accept an input");
        }

        if (actualType != function.InputType)
        {
            throw Error(
                line,
                column,
                $"{path} expects {FormatType(function.InputType.Value)} but received {FormatType(actualType)}");
        }
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

    private static BoundType InferNameExpression(
        NameExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (bindings.TryGetValue(expression.Name, out var type))
        {
            return type;
        }

        if (functions.ContainsKey(expression.Name))
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"function '{expression.Name}' must be called with parentheses");
        }

        throw Error(expression.Line, expression.Column, $"unknown binding '{expression.Name}'");
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
        return name is "main"
            or "sys"
            or "print"
            or "println"
            or "readInt"
            or "seedRandom"
            or "randomBelow"
            or "openIntWriter"
            or "writeInt"
            or "closeIntWriter"
            or "openIntReader"
            or "closestInt"
            or "closeIntReader"
            or "each"
            or "fold"
            or "if"
            or "else"
            or "when"
            or "and"
            or "or"
            or "not"
            or "true"
            or "false"
            or "in"
            or "it"
            or "repeat"
            or "block"
            or "yield"
            or "namespace"
            or "import"
            or "as";
    }

    private static BoundType ParseType(string typeName, int line, int column)
    {
        return typeName switch
        {
            "Unit" => BoundType.Unit,
            "Text" => BoundType.Text,
            "Int" => BoundType.Int,
            "Bool" => BoundType.Bool,
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
            BoundType.Bool => "Bool",
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
