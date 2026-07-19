using System.Globalization;
using System.Text;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal static class SemanticStableIdentity
{
    public static IReadOnlyDictionary<object, string> IndexCallSites(
        IEnumerable<BoundFunction> roots,
        IReadOnlyList<Statement> mainStatements,
        IReadOnlyDictionary<object, BoundFunction> resolvedCalls,
        IReadOnlyDictionary<BoundFunction, string> functionIdentities)
    {
        var result = new Dictionary<object, string>(ReferenceEqualityComparer.Instance);
        var resolved = new HashSet<object>(resolvedCalls.Keys, ReferenceEqualityComparer.Instance);
        var visitedFunctions = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var root in roots
                     .OrderBy(static function => function.ModuleName, StringComparer.Ordinal)
                     .ThenBy(static function => function.Name, StringComparer.Ordinal))
        {
            IndexFunctionCallSites(
                root,
                resolved,
                functionIdentities,
                visitedFunctions,
                result);
        }

        var mainOrdinal = 0;
        VisitStatements(mainStatements, "main", resolved, result, ref mainOrdinal);
        if (result.Count != resolved.Count)
        {
            throw new InvalidOperationException(
                $"stable call-site traversal found {result.Count} of {resolved.Count} resolved calls");
        }
        return result;
    }

    public static IReadOnlyDictionary<BoundFunction, string> IndexFunctions(
        TypeDefinitionTable types,
        IEnumerable<BoundFunction> roots,
        IEnumerable<BoundFunction> resolvedTargets)
    {
        var result = new Dictionary<BoundFunction, string>(ReferenceEqualityComparer.Instance);
        foreach (var root in roots
                     .OrderBy(static function => function.ModuleName, StringComparer.Ordinal)
                     .ThenBy(static function => function.Name, StringComparer.Ordinal))
        {
            AddFunction(types, root, parentIdentity: null, result);
        }
        foreach (var target in resolvedTargets)
        {
            if (!result.ContainsKey(target))
            {
                result.Add(target, Function(types, target, parentIdentity: null));
            }
        }
        return result;
    }

    public static string Function(
        TypeDefinitionTable types,
        BoundFunction function,
        string? parentIdentity = null)
    {
        var builder = new StringBuilder(256);
        Append(builder, parentIdentity is null ? "function" : "local");
        Append(builder, parentIdentity ?? "");
        Append(builder, function.ModuleName);
        Append(builder, function.Name);
        Append(builder, ((int)function.Kind).ToString(CultureInfo.InvariantCulture));
        Append(builder, function.InputType is { } input ? Type(types, input) : "-");
        Append(builder, ((int)function.InputOwnership).ToString(CultureInfo.InvariantCulture));
        Append(builder, Type(types, function.ReturnType));
        Append(builder, function.BlockInputType is { } blockInput ? Type(types, blockInput) : "-");
        Append(builder, function.BlockResultType is { } blockResult ? Type(types, blockResult) : "-");
        Append(builder, function.IsAsync ? "async" : "sync");
        Append(builder, function.GenericParameterName ?? "");
        Append(builder, function.SecondaryGenericParameterName ?? "");
        Append(builder, function.TertiaryGenericParameterName ?? "");
        Append(builder, function.GenericTraitBound ?? "");
        Append(builder, function.GenericAssociatedTypeName ?? "");
        Append(builder, function.GenericAssociatedTypeConstraint is { } constraint
            ? Type(types, constraint)
            : "-");
        Append(builder, function.SpecializedType is { } specialized
            ? Type(types, specialized)
            : "-");
        Append(builder, function.SpecializedSecondaryType is { } secondary
            ? Type(types, secondary)
            : "-");
        Append(builder, function.SpecializedTertiaryType is { } tertiary
            ? Type(types, tertiary)
            : "-");
        Append(builder, function.SpecializedValue?.ToString(CultureInfo.InvariantCulture) ?? "-");
        Append(builder, function.InputTypeTemplate ?? "");
        Append(builder, function.ReturnTypeTemplate ?? "");
        Append(builder, function.BlockInputTypeTemplate ?? "");
        Append(builder, function.BlockResultTypeTemplate ?? "");
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            Append(builder, parameter.Name);
            Append(builder, Type(types, parameter.Type));
            Append(builder, ((int)parameter.Ownership).ToString(CultureInfo.InvariantCulture));
        }
        foreach (var associated in (function.ImplAssociatedTypes
                     ?? new Dictionary<string, TypeId>(StringComparer.Ordinal))
                 .OrderBy(static pair => pair.Key, StringComparer.Ordinal))
        {
            Append(builder, associated.Key);
            Append(builder, Type(types, associated.Value));
        }
        foreach (var effect in (function.Effects ?? new HashSet<string>(StringComparer.Ordinal))
                     .Order(StringComparer.Ordinal))
        {
            Append(builder, effect);
        }
        return builder.ToString();
    }

    public static string Type(TypeDefinitionTable types, TypeId type)
    {
        if (types.TryGetOptionValue(type, out var optionValue))
        {
            return "Option<" + Type(types, optionValue) + ">";
        }
        if (types.TryGetResultTypes(type, out var result))
        {
            return "Result<" + Type(types, result.Ok) + "," + Type(types, result.Error) + ">";
        }
        if (types.TryGetTaskValue(type, out var taskValue))
        {
            return "Task<" + Type(types, taskValue) + ">";
        }
        if (types.IsStaticArray(type))
        {
            return "StaticArray<" + Type(types, types.GetStaticArray(type).ElementType) + ">";
        }
        if (types.IsDynamicArray(type))
        {
            return "Array<" + Type(types, types.GetDynamicArray(type).ElementType) + ">";
        }
        if (types.IsDictionary(type))
        {
            var dictionary = types.GetDictionary(type);
            return "Dictionary<" + Type(types, dictionary.KeyType) + ","
                + Type(types, dictionary.ValueType) + ">";
        }
        if (types.IsBox(type))
        {
            return "Box<" + Type(types, types.GetBox(type).ElementType) + ">";
        }
        if (types.IsStruct(type))
        {
            return "struct:" + types.GetStruct(type).Name;
        }
        if (types.IsEnum(type))
        {
            return "enum:" + types.GetEnum(type).Name;
        }
        if ((int)type < (int)TypeId.FirstUserDefined)
        {
            return "builtin:" + type;
        }
        throw new InvalidOperationException(
            $"type id '{(int)type}' has no stable structural identity");
    }

    private static void AddFunction(
        TypeDefinitionTable types,
        BoundFunction function,
        string? parentIdentity,
        IDictionary<BoundFunction, string> result)
    {
        if (result.ContainsKey(function))
        {
            return;
        }
        var identity = Function(types, function, parentIdentity);
        result.Add(function, identity);
        foreach (var local in function.LocalFunctions.Values
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            AddFunction(types, local, identity, result);
        }
    }

    private static void IndexFunctionCallSites(
        BoundFunction function,
        IReadOnlySet<object> resolved,
        IReadOnlyDictionary<BoundFunction, string> functionIdentities,
        ISet<BoundFunction> visitedFunctions,
        IDictionary<object, string> result)
    {
        if (!visitedFunctions.Add(function))
        {
            return;
        }
        var owner = functionIdentities[function];
        var ordinal = 0;
        if (function.Body is not null)
        {
            VisitExpression(function.Body, owner, resolved, result, ref ordinal);
        }
        VisitStatements(function.BlockBody, owner, resolved, result, ref ordinal);
        foreach (var local in function.LocalFunctions.Values
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            IndexFunctionCallSites(
                local,
                resolved,
                functionIdentities,
                visitedFunctions,
                result);
        }
    }

    private static void VisitStatements(
        IReadOnlyList<Statement> statements,
        string owner,
        IReadOnlySet<object> resolved,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        foreach (var statement in statements)
        {
            Register(statement, owner, resolved, result, ref ordinal);
            switch (statement)
            {
                case BindingStatement binding:
                    VisitExpression(binding.Value, owner, resolved, result, ref ordinal);
                    break;
                case IndexAssignmentStatement assignment:
                    VisitExpression(assignment.Index, owner, resolved, result, ref ordinal);
                    VisitExpression(assignment.Value, owner, resolved, result, ref ordinal);
                    break;
                case FieldAssignmentStatement assignment:
                    VisitExpression(assignment.Value, owner, resolved, result, ref ordinal);
                    break;
                case BlockFunctionCallStatement block:
                    VisitExpression(block.Source, owner, resolved, result, ref ordinal);
                    VisitStatements(block.Body, owner, resolved, result, ref ordinal);
                    break;
                case ExpressionStatement expression:
                    VisitExpression(expression.Expression, owner, resolved, result, ref ordinal);
                    break;
                case GuardLoopControlStatement guard:
                    VisitExpression(guard.Condition, owner, resolved, result, ref ordinal);
                    break;
                case ReturnStatement { Value: { } value }:
                    VisitExpression(value, owner, resolved, result, ref ordinal);
                    break;
            }
        }
    }

    private static void VisitExpression(
        Expression expression,
        string owner,
        IReadOnlySet<object> resolved,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        Register(expression, owner, resolved, result, ref ordinal);
        switch (expression)
        {
            case StringExpression text:
                foreach (var segment in text.Segments.OfType<InterpolationSegment>())
                    VisitExpression(segment.Expression, owner, resolved, result, ref ordinal);
                break;
            case AddExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case SubtractExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case MultiplyExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case DivideExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case ModuloExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case CompareExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case AndExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case OrExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, resolved, result, ref ordinal);
                break;
            case RangeExpression binary:
                VisitBinary(binary.Start, binary.End, owner, resolved, result, ref ordinal);
                break;
            case NegateExpression unary:
                VisitExpression(unary.Value, owner, resolved, result, ref ordinal);
                break;
            case NotExpression unary:
                VisitExpression(unary.Value, owner, resolved, result, ref ordinal);
                break;
            case TryExpression unary:
                VisitExpression(unary.Value, owner, resolved, result, ref ordinal);
                break;
            case BoxExpression unary:
                VisitExpression(unary.Value, owner, resolved, result, ref ordinal);
                break;
            case CompileTimeEachExpression each:
                VisitExpression(each.Source, owner, resolved, result, ref ordinal);
                VisitExpression(each.Selector, owner, resolved, result, ref ordinal);
                if (each.DictionaryValueSelector is not null)
                    VisitExpression(each.DictionaryValueSelector, owner, resolved, result, ref ordinal);
                break;
            case FoldExpression fold:
                VisitExpression(fold.Source, owner, resolved, result, ref ordinal);
                VisitExpression(fold.Initial, owner, resolved, result, ref ordinal);
                VisitBlock(fold.Body, owner, resolved, result, ref ordinal);
                break;
            case IfExpression conditional:
                VisitExpression(conditional.Condition, owner, resolved, result, ref ordinal);
                VisitBlock(conditional.Then, owner, resolved, result, ref ordinal);
                if (conditional.Else is not null)
                    VisitBlock(conditional.Else, owner, resolved, result, ref ordinal);
                break;
            case WhenExpression selection:
                if (selection.Subject is not null)
                    VisitExpression(selection.Subject, owner, resolved, result, ref ordinal);
                VisitArms(selection.Arms, owner, resolved, result, ref ordinal);
                VisitBlock(selection.Else, owner, resolved, result, ref ordinal);
                break;
            case FlowExpression flow:
                VisitExpression(flow.Source, owner, resolved, result, ref ordinal);
                foreach (var target in flow.Targets)
                {
                    Register(target, owner, resolved, result, ref ordinal);
                    foreach (var argument in target.Arguments)
                        VisitExpression(argument, owner, resolved, result, ref ordinal);
                }
                break;
            case CallExpression call:
                foreach (var argument in call.Arguments)
                    VisitExpression(argument, owner, resolved, result, ref ordinal);
                break;
            case ArrayLiteralExpression array:
                foreach (var element in array.Elements)
                    VisitExpression(element, owner, resolved, result, ref ordinal);
                break;
            case ArrayRepeatExpression repeat:
                VisitExpression(repeat.Value, owner, resolved, result, ref ordinal);
                break;
            case DictionaryLiteralExpression dictionary:
                foreach (var entry in dictionary.Entries)
                {
                    VisitExpression(entry.Key, owner, resolved, result, ref ordinal);
                    VisitExpression(entry.Value, owner, resolved, result, ref ordinal);
                }
                break;
            case IndexExpression index:
                VisitBinary(index.Source, index.Index, owner, resolved, result, ref ordinal);
                break;
            case StructLiteralExpression structure:
                foreach (var field in structure.Fields)
                    VisitExpression(field.Value, owner, resolved, result, ref ordinal);
                break;
            case FieldAccessExpression field:
                VisitExpression(field.Source, owner, resolved, result, ref ordinal);
                break;
            case MapExpression map:
                VisitExpression(map.Path, owner, resolved, result, ref ordinal);
                if (map.Offset is not null) VisitExpression(map.Offset, owner, resolved, result, ref ordinal);
                if (map.Length is not null) VisitExpression(map.Length, owner, resolved, result, ref ordinal);
                if (map.FileSize is not null) VisitExpression(map.FileSize, owner, resolved, result, ref ordinal);
                break;
            case EnumMatchExpression match:
                VisitExpression(match.Subject, owner, resolved, result, ref ordinal);
                VisitArms(match.Arms, owner, resolved, result, ref ordinal);
                if (match.Else is not null) VisitBlock(match.Else, owner, resolved, result, ref ordinal);
                break;
            case SubjectCompareExpression compare:
                VisitExpression(compare.Right, owner, resolved, result, ref ordinal);
                break;
            case SubjectRangeExpression range:
                VisitBinary(range.Start, range.End, owner, resolved, result, ref ordinal);
                break;
        }
    }

    private static void VisitBinary(
        Expression left,
        Expression right,
        string owner,
        IReadOnlySet<object> resolved,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        VisitExpression(left, owner, resolved, result, ref ordinal);
        VisitExpression(right, owner, resolved, result, ref ordinal);
    }

    private static void VisitBlock(
        BlockBody block,
        string owner,
        IReadOnlySet<object> resolved,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        VisitStatements(block.Statements, owner, resolved, result, ref ordinal);
        if (block.Value is not null)
            VisitExpression(block.Value, owner, resolved, result, ref ordinal);
    }

    private static void VisitArms(
        IReadOnlyList<WhenArm> arms,
        string owner,
        IReadOnlySet<object> resolved,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        foreach (var arm in arms)
        {
            VisitExpression(arm.Condition, owner, resolved, result, ref ordinal);
            VisitBlock(arm.Body, owner, resolved, result, ref ordinal);
        }
    }

    private static void Register(
        object node,
        string owner,
        IReadOnlySet<object> resolved,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        if (!resolved.Contains(node))
        {
            return;
        }
        if (!result.TryAdd(node, owner + "/call:" + ordinal.ToString(CultureInfo.InvariantCulture)))
        {
            throw new InvalidOperationException("resolved call site occurs more than once in syntax traversal");
        }
        ordinal++;
    }

    private static void Append(StringBuilder builder, string value)
    {
        builder.Append(value.Length.ToString(CultureInfo.InvariantCulture));
        builder.Append(':');
        builder.Append(value);
    }
}
