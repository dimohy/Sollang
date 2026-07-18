using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private SollangProgram InferPrivateFunctionSignatures(SollangProgram program)
    {
        var states = new List<InferredSignatureState>();
        foreach (var declaration in program.Functions)
        {
            CollectSignatureStates(declaration, owner: null, states);
        }

        if (!states.Any(static state => state.HasOmittedType))
        {
            return program;
        }

        foreach (var state in states.Where(static state => state.HasOmittedType))
        {
            if (state.Declaration.IsPublic || state.Declaration.IsStandardLibrary)
            {
                throw SignatureInferenceError(state,
                    "public function signatures require explicit input and return types");
            }
            if (state.Declaration.TraitName is not null || state.Declaration.GenericParameterName is not null)
            {
                throw SignatureInferenceError(state,
                    "impl and generic function signatures require explicit input and return types");
            }
        }

        var topLevel = BuildTopLevelSignatureIndex(states);

        for (var pass = 0; pass < 32; pass++)
        {
            var changed = false;
            foreach (var state in states)
            {
                var locals = states
                    .Where(candidate => ReferenceEquals(candidate.Owner, state))
                    .ToDictionary(candidate => LocalName(candidate.Declaration.Name), StringComparer.Ordinal);
                changed |= AnalyzeSignatureBody(state, locals, topLevel);
            }

            var mainEnvironment = new Dictionary<string, string>(StringComparer.Ordinal);
            changed |= AnalyzeStatements(
                program.Statements,
                mainEnvironment,
                caller: null,
                locals: EmptySignatureStates,
                topLevel,
                returnedTypes: null);
            if (!changed)
            {
                break;
            }
        }

        foreach (var state in states.Where(static state => state.HasOmittedType))
        {
            if (!state.IsLocal)
            {
                var externalConsumers = state.Callers
                    .Where(caller => caller != state.Declaration.Name)
                    .Distinct(StringComparer.Ordinal)
                    .ToArray();
                if (externalConsumers.Length != 1)
                {
                    throw SignatureInferenceError(state,
                        externalConsumers.Length == 0
                            ? "an inferred private function must be consumed by exactly one function or main scope"
                            : "an inferred private function is consumed by multiple functions; write its signature explicitly");
                }
            }

            if (state.Declaration.InputName is not null && state.InputType is null)
            {
                throw SignatureInferenceError(state,
                    $"cannot infer input type for '{state.Declaration.InputName}' from a unique call context");
            }
            if (state.ReturnType is null)
            {
                throw SignatureInferenceError(state,
                    "cannot infer one return type from the function body");
            }
        }

        var rewritten = program.Functions
            .Select(declaration => RewriteInferredDeclaration(declaration, states))
            .ToArray();
        return program with { Functions = rewritten };
    }

    private static readonly IReadOnlyDictionary<string, InferredSignatureState> EmptySignatureStates =
        new Dictionary<string, InferredSignatureState>(StringComparer.Ordinal);

    private static IReadOnlyDictionary<string, InferredSignatureState> BuildTopLevelSignatureIndex(
        IEnumerable<InferredSignatureState> states)
    {
        var index = new Dictionary<string, InferredSignatureState>(StringComparer.Ordinal);
        foreach (var state in states.Where(static candidate => candidate.Owner is null))
        {
            index[state.Declaration.Name] = state;
            index[ModuleInferenceKey(state.Declaration.ModuleName, LocalName(state.Declaration.Name))] = state;
        }
        return index;
    }

    private static void CollectSignatureStates(
        FunctionDeclaration declaration,
        InferredSignatureState? owner,
        List<InferredSignatureState> states)
    {
        var state = new InferredSignatureState(declaration, owner);
        states.Add(state);
        foreach (var local in declaration.LocalFunctions)
        {
            CollectSignatureStates(local, state, states);
        }
    }

    private bool AnalyzeSignatureBody(
        InferredSignatureState state,
        IReadOnlyDictionary<string, InferredSignatureState> locals,
        IReadOnlyDictionary<string, InferredSignatureState> topLevel)
    {
        var environment = new Dictionary<string, string>(StringComparer.Ordinal);
        if (state.Declaration.InputName is { } inputName && state.InputType is { } inputType)
        {
            environment[inputName] = inputType;
        }
        foreach (var parameter in state.Declaration.AdditionalParameters ?? [])
        {
            environment[parameter.Name] = parameter.TypeName;
        }

        var returnedTypes = new List<string>();
        var changed = AnalyzeStatements(
            state.Declaration.BlockBody,
            environment,
            state,
            locals,
            topLevel,
            returnedTypes);
        if (state.Declaration.Body is { } body)
        {
            var bodyType = AnalyzeExpression(body, environment, state, locals, topLevel, ref changed);
            AddKnownType(returnedTypes, bodyType);
        }
        else if (state.Declaration.ReturnType == InferredFunctionType.Name)
        {
            AddKnownType(returnedTypes, "Unit");
        }

        foreach (var returnType in returnedTypes)
        {
            changed |= state.MergeReturn(returnType, this);
        }
        return changed;
    }

    private bool AnalyzeStatements(
        IReadOnlyList<Statement> statements,
        Dictionary<string, string> environment,
        InferredSignatureState? caller,
        IReadOnlyDictionary<string, InferredSignatureState> locals,
        IReadOnlyDictionary<string, InferredSignatureState> topLevel,
        List<string>? returnedTypes)
    {
        var changed = false;
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    AddBindingType(environment, binding.Name,
                        AnalyzeExpression(binding.Value, environment, caller, locals, topLevel, ref changed));
                    break;
                case IndexAssignmentStatement assignment:
                    AnalyzeExpression(assignment.Index, environment, caller, locals, topLevel, ref changed);
                    AnalyzeExpression(assignment.Value, environment, caller, locals, topLevel, ref changed);
                    break;
                case FieldAssignmentStatement assignment:
                    AnalyzeExpression(assignment.Value, environment, caller, locals, topLevel, ref changed);
                    break;
                case ExpressionStatement expression:
                    AnalyzeExpression(expression.Expression, environment, caller, locals, topLevel, ref changed);
                    break;
                case GuardLoopControlStatement guard:
                    AnalyzeExpression(guard.Condition, environment, caller, locals, topLevel, ref changed);
                    break;
                case ReturnStatement { Value: null }:
                    AddKnownType(returnedTypes, "Unit");
                    break;
                case ReturnStatement { Value: { } value }:
                    AddKnownType(returnedTypes,
                        AnalyzeExpression(value, environment, caller, locals, topLevel, ref changed));
                    break;
                case BlockFunctionCallStatement blockCall:
                    AnalyzeExpression(blockCall.Source, environment, caller, locals, topLevel, ref changed);
                    var blockEnvironment = new Dictionary<string, string>(environment, StringComparer.Ordinal);
                    changed |= AnalyzeStatements(
                        blockCall.Body, blockEnvironment, caller, locals, topLevel, returnedTypes);
                    break;
            }
        }
        return changed;
    }

    private string? AnalyzeExpression(
        Expression expression,
        Dictionary<string, string> environment,
        InferredSignatureState? caller,
        IReadOnlyDictionary<string, InferredSignatureState> locals,
        IReadOnlyDictionary<string, InferredSignatureState> topLevel,
        ref bool changed)
    {
        switch (expression)
        {
            case NumberExpression:
                return "Int";
            case BoolExpression:
                return "Bool";
            case StringExpression text:
                foreach (var interpolation in text.Segments.OfType<InterpolationSegment>())
                {
                    AnalyzeExpression(interpolation.Expression, environment, caller, locals, topLevel, ref changed);
                }
                return "Text";
            case NameExpression name:
                if (environment.TryGetValue(name.Name, out var boundNameType))
                {
                    return boundNameType;
                }
                return AnalyzeCall([name.Name], [], caller, locals, topLevel, ref changed);
            case NegateExpression negate:
                return AnalyzeExpression(negate.Value, environment, caller, locals, topLevel, ref changed);
            case NotExpression not:
                AnalyzeExpression(not.Value, environment, caller, locals, topLevel, ref changed);
                return "Bool";
            case CompareExpression compare:
                AnalyzeExpression(compare.Left, environment, caller, locals, topLevel, ref changed);
                AnalyzeExpression(compare.Right, environment, caller, locals, topLevel, ref changed);
                return "Bool";
            case AndExpression and:
                AnalyzeExpression(and.Left, environment, caller, locals, topLevel, ref changed);
                AnalyzeExpression(and.Right, environment, caller, locals, topLevel, ref changed);
                return "Bool";
            case OrExpression or:
                AnalyzeExpression(or.Left, environment, caller, locals, topLevel, ref changed);
                AnalyzeExpression(or.Right, environment, caller, locals, topLevel, ref changed);
                return "Bool";
            case AddExpression add:
                return AnalyzeBinary(add.Left, add.Right, environment, caller, locals, topLevel, ref changed);
            case SubtractExpression subtract:
                return AnalyzeBinary(subtract.Left, subtract.Right, environment, caller, locals, topLevel, ref changed);
            case MultiplyExpression multiply:
                return AnalyzeBinary(multiply.Left, multiply.Right, environment, caller, locals, topLevel, ref changed);
            case DivideExpression divide:
                return AnalyzeBinary(divide.Left, divide.Right, environment, caller, locals, topLevel, ref changed);
            case ModuloExpression modulo:
                return AnalyzeBinary(modulo.Left, modulo.Right, environment, caller, locals, topLevel, ref changed);
            case StructLiteralExpression structure:
                foreach (var field in structure.Fields)
                {
                    AnalyzeExpression(field.Value, environment, caller, locals, topLevel, ref changed);
                }
                return structure.TypeName;
            case BoxExpression box:
                var boxed = AnalyzeExpression(box.Value, environment, caller, locals, topLevel, ref changed);
                return boxed is null ? null : $"box {boxed}";
            case ArrayLiteralExpression array:
                var elementTypes = new HashSet<string>(StringComparer.Ordinal);
                foreach (var item in array.Elements)
                {
                    if (AnalyzeExpression(item, environment, caller, locals, topLevel, ref changed) is { } itemType)
                    {
                        elementTypes.Add(itemType);
                    }
                }
                return elementTypes.Count == 1
                    ? array.IsDynamic ? $"[{elementTypes.Single()}; ~]" : $"[{elementTypes.Single()}]"
                    : null;
            case TypedEmptyArrayExpression emptyArray:
                return $"[{emptyArray.ElementType}; ~]";
            case DictionaryLiteralExpression dictionary:
                var keyTypes = new HashSet<string>(StringComparer.Ordinal);
                var valueTypes = new HashSet<string>(StringComparer.Ordinal);
                foreach (var entry in dictionary.Entries)
                {
                    if (AnalyzeExpression(entry.Key, environment, caller, locals, topLevel, ref changed) is { } keyType)
                    {
                        keyTypes.Add(keyType);
                    }
                    if (AnalyzeExpression(entry.Value, environment, caller, locals, topLevel, ref changed) is { } valueType)
                    {
                        valueTypes.Add(valueType);
                    }
                }
                return keyTypes.Count == 1 && valueTypes.Count == 1
                    ? $"{{{keyTypes.Single()}: {valueTypes.Single()}}}"
                    : null;
            case TypedEmptyDictionaryExpression emptyDictionary:
                return $"{{{emptyDictionary.KeyType}: {emptyDictionary.ValueType}}}";
            case IndexExpression index:
                var sourceType = AnalyzeExpression(index.Source, environment, caller, locals, topLevel, ref changed);
                AnalyzeExpression(index.Index, environment, caller, locals, topLevel, ref changed);
                return ElementTypeOf(sourceType);
            case CallExpression call:
                var callArguments = new List<string?>();
                foreach (var argument in call.Arguments)
                {
                    callArguments.Add(AnalyzeExpression(argument, environment, caller, locals, topLevel, ref changed));
                }
                return AnalyzeCall(call.Path, callArguments, caller, locals, topLevel, ref changed);
            case FlowExpression flow:
                var currentType = AnalyzeExpression(flow.Source, environment, caller, locals, topLevel, ref changed);
                foreach (var target in flow.Targets)
                {
                    var flowArguments = new List<string?> { currentType };
                    foreach (var argument in target.Arguments)
                    {
                        flowArguments.Add(AnalyzeExpression(argument, environment, caller, locals, topLevel, ref changed));
                    }
                    currentType = AnalyzeCall(target.Path, flowArguments, caller, locals, topLevel, ref changed);
                }
                return currentType;
            case IfExpression conditional:
                AnalyzeExpression(conditional.Condition, environment, caller, locals, topLevel, ref changed);
                var thenType = AnalyzeBlock(conditional.Then, environment, caller, locals, topLevel, ref changed);
                var elseType = conditional.Else is null
                    ? "Unit"
                    : AnalyzeBlock(conditional.Else, environment, caller, locals, topLevel, ref changed);
                return thenType == elseType ? thenType : null;
            case RangeExpression range:
                AnalyzeExpression(range.Start, environment, caller, locals, topLevel, ref changed);
                AnalyzeExpression(range.End, environment, caller, locals, topLevel, ref changed);
                return "Range";
            default:
                return null;
        }
    }

    private string? AnalyzeBinary(
        Expression left,
        Expression right,
        Dictionary<string, string> environment,
        InferredSignatureState? caller,
        IReadOnlyDictionary<string, InferredSignatureState> locals,
        IReadOnlyDictionary<string, InferredSignatureState> topLevel,
        ref bool changed)
    {
        var leftType = AnalyzeExpression(left, environment, caller, locals, topLevel, ref changed);
        var rightType = AnalyzeExpression(right, environment, caller, locals, topLevel, ref changed);
        return leftType == rightType ? leftType : leftType ?? rightType;
    }

    private string? AnalyzeBlock(
        BlockBody block,
        Dictionary<string, string> outerEnvironment,
        InferredSignatureState? caller,
        IReadOnlyDictionary<string, InferredSignatureState> locals,
        IReadOnlyDictionary<string, InferredSignatureState> topLevel,
        ref bool changed)
    {
        var environment = new Dictionary<string, string>(outerEnvironment, StringComparer.Ordinal);
        changed |= AnalyzeStatements(block.Statements, environment, caller, locals, topLevel, returnedTypes: null);
        return block.Value is null
            ? "Unit"
            : AnalyzeExpression(block.Value, environment, caller, locals, topLevel, ref changed);
    }

    private string? AnalyzeCall(
        IReadOnlyList<string> path,
        IReadOnlyList<string?> argumentTypes,
        InferredSignatureState? caller,
        IReadOnlyDictionary<string, InferredSignatureState> locals,
        IReadOnlyDictionary<string, InferredSignatureState> topLevel,
        ref bool changed)
    {
        var name = string.Join('.', path);
        var localName = path.Count == 1 ? path[0] : name;
        var callerModule = caller?.Declaration.ModuleName ?? string.Join('.', _program.NamespacePath);
        if (!locals.TryGetValue(localName, out var target)
            && !topLevel.TryGetValue(name, out target)
            && !topLevel.TryGetValue(ModuleInferenceKey(callerModule, name), out target))
        {
            return BuiltinReturnType(name, argumentTypes);
        }

        target.Callers.Add(caller?.Declaration.Name ?? "<main>");
        if (target.Declaration.InputName is not null && argumentTypes.Count > 0 && argumentTypes[0] is { } inputType)
        {
            changed |= target.MergeInput(inputType, this);
        }
        return target.ReturnType;
    }

    private static string ModuleInferenceKey(string moduleName, string name) =>
        moduleName + "|" + name;

    private static string? BuiltinReturnType(string name, IReadOnlyList<string?> argumentTypes) => name switch
    {
        "println" or "print" => "Unit",
        "len" or "capacity" or "nowMillis" => "Int",
        "append" or "updated" => argumentTypes.FirstOrDefault(),
        _ => null
    };

    private static string? ElementTypeOf(string? type)
    {
        if (type is null || !type.StartsWith('[', StringComparison.Ordinal))
        {
            return null;
        }
        var end = type.IndexOfAny([';', ']']);
        return end > 1 ? type[1..end].Trim() : null;
    }

    private static void AddBindingType(Dictionary<string, string> environment, string name, string? type)
    {
        if (type is not null)
        {
            environment[name] = type;
        }
    }

    private static void AddKnownType(List<string>? types, string? type)
    {
        if (types is not null && type is not null)
        {
            types.Add(type);
        }
    }

    private static string LocalName(string name) =>
        name[(name.LastIndexOf('.') + 1)..];

    private FunctionDeclaration RewriteInferredDeclaration(
        FunctionDeclaration declaration,
        IReadOnlyList<InferredSignatureState> states)
    {
        var state = states.First(candidate => ReferenceEquals(candidate.Declaration, declaration));
        var locals = declaration.LocalFunctions
            .Select(local => RewriteInferredDeclaration(local, states))
            .ToArray();
        return declaration with
        {
            InputType = declaration.InputName is null ? null : state.InputType,
            ReturnType = state.ReturnType!,
            LocalFunctions = locals
        };
    }

    private SollangException SignatureInferenceError(InferredSignatureState state, string message) =>
        Error(state.Declaration.Line, state.Declaration.Column,
            $"function '{state.Declaration.Name}' {message}");

    private sealed class InferredSignatureState(
        FunctionDeclaration declaration,
        InferredSignatureState? owner)
    {
        public FunctionDeclaration Declaration { get; } = declaration;
        public InferredSignatureState? Owner { get; } = owner;
        public bool IsLocal => Owner is not null;
        public bool HasOmittedType { get; } =
            (declaration.InputName is not null && declaration.InputType is null)
            || declaration.ReturnType == InferredFunctionType.Name;
        public string? InputType { get; private set; } = declaration.InputType;
        public string? ReturnType { get; private set; } =
            declaration.ReturnType == InferredFunctionType.Name ? null : declaration.ReturnType;
        public HashSet<string> Callers { get; } = new(StringComparer.Ordinal);

        public bool MergeInput(string type, SemanticCompiler compiler)
        {
            if (Declaration.InputType is not null)
            {
                return false;
            }
            if (InputType is null)
            {
                InputType = type;
                return true;
            }
            if (InputType != type)
            {
                throw compiler.SignatureInferenceError(this,
                    $"has conflicting inferred input types {InputType} and {type}");
            }
            return false;
        }

        public bool MergeReturn(string type, SemanticCompiler compiler)
        {
            if (Declaration.ReturnType != InferredFunctionType.Name)
            {
                return false;
            }
            if (ReturnType is null)
            {
                ReturnType = type;
                return true;
            }
            if (ReturnType != type)
            {
                throw compiler.SignatureInferenceError(this,
                    $"has conflicting inferred return types {ReturnType} and {type}");
            }
            return false;
        }
    }
}
