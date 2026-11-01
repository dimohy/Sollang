using StableNames = Sollang.Compiler.Shared.TypeNamePolicy;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal static class SemanticStableIdentity
{
    public static byte[] DeclarationFingerprint(
        TypeDefinitionTable types,
        IEnumerable<BoundTraitDefinition> traits,
        IEnumerable<BoundFunction> functions)
    {
        var fields = new List<string>();
        foreach (var structure in types.Structs.Where(static value => value.IsPublic)
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            fields.Add("struct");
            fields.Add(structure.ModuleName);
            fields.Add(structure.Name);
            fields.Add(structure.DeclaringTypeName ?? "");
            fields.Add(structure.IsPublic ? "public" : "private");
            fields.Add(structure.IsAbi ? "abi" : "sollang");
            fields.Add(structure.ComInterface is not null
                ? "com"
                : structure.NativeHandle is not null ? "native-handle" : "value");
            if (structure.ComInterface is { } comInterface)
            {
                fields.Add(comInterface.ClassId);
                fields.Add(comInterface.InterfaceId);
                fields.Add(comInterface.Server ?? "");
                fields.Add(((int)comInterface.Apartment).ToString(CultureInfo.InvariantCulture));
            }
            if (structure.NativeHandle is { } nativeHandle)
            {
                fields.Add(nativeHandle.Alias);
                fields.Add(nativeHandle.Library);
                fields.Add(nativeHandle.DropSymbol);
            }
            foreach (var field in structure.Fields)
            {
                fields.Add(field.Name);
                fields.Add(Type(types, field.Type));
                fields.Add(field.IsPublic ? "public" : "private");
            }
        }
        foreach (var enumeration in types.Enums.Where(static value => value.IsPublic)
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            fields.Add("enum");
            fields.Add(enumeration.ModuleName);
            fields.Add(enumeration.Name);
            fields.Add(enumeration.IsPublic ? "public" : "private");
            foreach (var variant in enumeration.Variants)
            {
                fields.Add(variant.Name);
                fields.Add(variant.PayloadType is { } payload ? Type(types, payload) : "-");
            }
        }
        foreach (var trait in traits.Where(static value => value.IsPublic)
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            fields.Add("trait");
            fields.Add(trait.ModuleName);
            fields.Add(trait.Name);
            fields.Add(trait.IsPublic ? "public" : "private");
            foreach (var associated in trait.AssociatedTypes)
                fields.Add(associated.Name);
            foreach (var method in trait.Methods)
            {
                fields.Add(method.Name);
                fields.Add(((int)method.SelfOwnership).ToString(CultureInfo.InvariantCulture));
                fields.Add(method.ReturnType is { } result ? Type(types, result) : "-");
                fields.Add(method.ReturnAssociatedTypeSyntax ?? "");
                fields.Add(method.AdditionalParameters.Count.ToString(CultureInfo.InvariantCulture));
                foreach (var parameter in method.AdditionalParameters)
                {
                    fields.Add(((int)parameter.Ownership).ToString(CultureInfo.InvariantCulture));
                    fields.Add(parameter.Type is { } parameterType ? Type(types, parameterType) : "-");
                    fields.Add(parameter.AssociatedTypeSyntax ?? "");
                }
            }
        }
        var seen = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in functions.Where(seen.Add).Where(static value => value.IsPublic)
                     .OrderBy(static value => value.ModuleName, StringComparer.Ordinal)
                     .ThenBy(static value => value.Name, StringComparer.Ordinal))
        {
            fields.Add(Function(types, function));
        }

        var builder = new StringBuilder();
        foreach (var field in fields)
            Append(builder, field);
        return SHA256.HashData(Encoding.UTF8.GetBytes(builder.ToString()));
    }

    public static IReadOnlyDictionary<object, string> IndexSyntaxCallSites(
        IEnumerable<BoundFunction> roots,
        IReadOnlyList<Statement> mainStatements,
        IReadOnlyDictionary<BoundFunction, string> functionIdentities)
    {
        var result = new Dictionary<object, string>(ReferenceEqualityComparer.Instance);
        var visitedFunctions = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var root in roots
                     .OrderBy(static function => function.ModuleName, StringComparer.Ordinal)
                     .ThenBy(static function => function.Name, StringComparer.Ordinal))
        {
            IndexFunctionCallSites(
                root,
                functionIdentities,
                visitedFunctions,
                result);
        }

        var mainOrdinal = 0;
        VisitStatements(mainStatements, "main", result, ref mainOrdinal);
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
        foreach (var part in Sollang.Compiler.Shared.CodegenCacheKeyPolicy.StableFunctionIdentity().Parts
                     .Concat(Sollang.Compiler.Shared.CodegenCacheKeyPolicy.StableFunctionIdentityTail().Parts))
        {
            switch (part)
            {
                case Sollang.Compiler.Shared.CodegenKeyPart.StableScope:
                    Append(builder, parentIdentity is null ? "function" : "local");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableParent:
                    Append(builder, parentIdentity ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableModule:
                    Append(builder, function.ModuleName);
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableName:
                    Append(builder, function.Name);
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableKind:
                    Append(builder, ((int)function.Kind).ToString(CultureInfo.InvariantCulture));
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableInput:
                    Append(builder, function.InputType is { } input ? Type(types, input) : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableInputOwnership:
                    Append(builder, ((int)function.InputOwnership).ToString(CultureInfo.InvariantCulture));
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableReturn:
                    Append(builder, Type(types, function.ReturnType));
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableBlockInput:
                    Append(builder, function.BlockInputType is { } blockInput ? Type(types, blockInput) : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableBlockResult:
                    Append(builder, function.BlockResultType is { } blockResult ? Type(types, blockResult) : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableStream:
                    Append(builder, function.StreamElementType is { } streamElement ? Type(types, streamElement) : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableAsync:
                    Append(builder, function.IsAsync ? "async" : "sync");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableGenericPrimary:
                    Append(builder, function.GenericParameterName ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableGenericSecondary:
                    Append(builder, function.SecondaryGenericParameterName ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableGenericTertiary:
                    Append(builder, function.TertiaryGenericParameterName ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableGenericTraitBound:
                    Append(builder, function.GenericTraitBound ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableGenericAssociatedName:
                    Append(builder, function.GenericAssociatedTypeName ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableGenericAssociatedType:
                    Append(builder, function.GenericAssociatedTypeConstraint is { } constraint
                        ? Type(types, constraint)
                        : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableSpecializedPrimary:
                    Append(builder, function.SpecializedType is { } specialized
                        ? Type(types, specialized)
                        : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableSpecializedSecondary:
                    Append(builder, function.SpecializedSecondaryType is { } secondary
                        ? Type(types, secondary)
                        : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableSpecializedTertiary:
                    Append(builder, function.SpecializedTertiaryType is { } tertiary
                        ? Type(types, tertiary)
                        : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableSpecializedValue:
                    Append(builder, function.SpecializedValue?.ToString(CultureInfo.InvariantCulture) ?? "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableInputTemplate:
                    Append(builder, function.InputTypeTemplate ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableReturnTemplate:
                    Append(builder, function.ReturnTypeTemplate ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableBlockInputTemplate:
                    Append(builder, function.BlockInputTypeTemplate ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableBlockResultTemplate:
                    Append(builder, function.BlockResultTypeTemplate ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableStreamTemplate:
                    Append(builder, function.StreamElementTypeTemplate ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableNativeLibrary:
                    Append(builder, function.NativeLibrary ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableNativeSymbol:
                    Append(builder, function.NativeSymbol ?? "");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableNativeError:
                    Append(
                        builder,
                        ((int)function.NativeError).ToString(CultureInfo.InvariantCulture));
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableNativeSuccess:
                    Append(
                        builder,
                        function.NativeSuccessType is { } nativeSuccess
                            ? Type(types, nativeSuccess)
                            : "-");
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableCom:
                    if (function.Com is { } com)
                    {
                        Append(builder, ((int)com.Operation).ToString(CultureInfo.InvariantCulture));
                        Append(builder, com.InterfaceType);
                        Append(builder, com.ClassId);
                        Append(builder, com.InterfaceId);
                        Append(builder, com.Server ?? "");
                        Append(builder, ((int)com.Apartment).ToString(CultureInfo.InvariantCulture));
                        Append(builder, com.VtableSlot.ToString(CultureInfo.InvariantCulture));
                        Append(builder, com.ReceiverInterfaceType ?? "");
                    }
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableParameters:
                    foreach (var parameter in function.AdditionalParameters ?? [])
                    {
                        Append(builder, parameter.Name);
                        Append(builder, Type(types, parameter.Type));
                        Append(builder, ((int)parameter.Ownership).ToString(CultureInfo.InvariantCulture));
                        Append(builder, parameter.TypeTemplate ?? "");
                    }
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableBlockParameters:
                    foreach (var parameter in function.AdditionalBlockParameters ?? [])
                    {
                        Append(builder, parameter.Name);
                        Append(builder, Type(types, parameter.Type));
                        Append(builder, parameter.TypeTemplate ?? "");
                    }
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableAssociated:
                    foreach (var associated in (function.ImplAssociatedTypes
                                 ?? new Dictionary<string, TypeId>(StringComparer.Ordinal))
                             .OrderBy(static pair => pair.Key, StringComparer.Ordinal))
                    {
                        Append(builder, associated.Key);
                        Append(builder, Type(types, associated.Value));
                    }
                    break;
                case Sollang.Compiler.Shared.CodegenKeyPart.StableEffects:
                    foreach (var effect in (function.Effects ?? new HashSet<string>(StringComparer.Ordinal))
                                 .Order(StringComparer.Ordinal))
                    {
                        Append(builder, effect);
                    }
                    break;
                default:
                    throw new InvalidOperationException($"unsupported stable function identity part: {part}");
            }
        }
        return builder.ToString();
    }

    public static string Type(TypeDefinitionTable types, TypeId type)
    {
        if (types.TryGetOptionValue(type, out var optionValue))
        {
            return StableNames.StableOptionPrefix() + Type(types, optionValue) + ">";
        }
        if (types.TryGetResultTypes(type, out var result))
        {
            return StableNames.StableResultPrefix() + Type(types, result.Ok) + "," + Type(types, result.Error) + ">";
        }
        if (types.TryGetTaskValue(type, out var taskValue))
        {
            return StableNames.StableTaskPrefix() + Type(types, taskValue) + ">";
        }
        if (types.TryGetStreamValue(type, out var streamValue))
        {
            return StableNames.StableStreamPrefix() + Type(types, streamValue) + ">";
        }
        if (types.TryGetEventStreamValue(type, out var eventStreamValue))
        {
            return StableNames.StableEventStreamPrefix() + Type(types, eventStreamValue) + ">";
        }
        if (types.IsStaticArray(type))
        {
            var definition = types.GetStaticArray(type);
            return definition.FixedLength is { } length
                ? StableNames.StableFixedArrayPrefix() + Type(types, definition.ElementType) + "," + length + ">"
                : StableNames.StableStaticArrayPrefix() + Type(types, definition.ElementType) + ">";
        }
        if (types.IsBinaryHeap(type))
        {
            return StableNames.StableBinaryHeapPrefix() + Type(types, types.GetBinaryHeapElement(type)) + ">";
        }
        if (types.IsDeque(type))
        {
            return StableNames.StableDequePrefix() + Type(types, types.GetDequeElement(type)) + ">";
        }
        if (types.IsSet(type))
        {
            return StableNames.StableSetPrefix() + Type(types, types.GetSetElement(type)) + ">";
        }
        if (types.IsDynamicArray(type))
        {
            return StableNames.StableArrayPrefix() + Type(types, types.GetDynamicArray(type).ElementType) + ">";
        }
        if (types.IsBoundedArray(type))
        {
            var bounded = types.GetBoundedArray(type);
            return StableNames.StableBoundedArrayPrefix() + Type(types, bounded.ElementType) + "," + bounded.Capacity + ">";
        }
        if (types.IsBitSet(type))
        {
            return StableNames.StableBitSetPrefix() + types.GetBitSet(type).BitCount + ">";
        }
        if (types.IsDictionary(type))
        {
            if (types.IsBoundedDictionary(type))
            {
                var bounded = types.GetBoundedDictionary(type);
                return StableNames.StableBoundedDictionaryPrefix() + Type(types, bounded.KeyType) + ","
                    + Type(types, bounded.ValueType) + "," + bounded.MaxEntries + ">";
            }
            var dictionary = types.GetDictionary(type);
            return StableNames.StableDictionaryPrefix() + Type(types, dictionary.KeyType) + ","
                + Type(types, dictionary.ValueType) + ">";
        }
        if (types.IsBox(type))
        {
            return StableNames.StableBoxPrefix() + Type(types, types.GetBox(type).ElementType) + ">";
        }
        if (types.IsReference(type))
        {
            return StableNames.StableReferencePrefix() + Type(types, types.GetReference(type).ElementType) + ">";
        }
        if (types.IsSlice(type))
        {
            return StableNames.StableSlicePrefix() + Type(types, types.GetSliceElement(type)) + ">";
        }
        if (types.IsDynTrait(type))
        {
            return StableNames.StableDynTraitPrefix() + types.GetDynTrait(type).TraitName + ">";
        }
        if (types.IsStruct(type))
        {
            if (types.IsProduct(type))
            {
                var product = types.GetStruct(type);
                var labels = types.GetProductLabels(type);
                return StableNames.StableProductPrefix() + string.Join(",", product.Fields.Select((field, index) =>
                {
                    var label = labels[index] ?? string.Empty;
                    return label.Length.ToString(CultureInfo.InvariantCulture) + ":" + label + ":"
                        + Type(types, field.Type);
                })) + ">";
            }
            return StableNames.StableStructPrefix() + types.GetStruct(type).Name;
        }
        if (types.IsEnum(type))
        {
            return StableNames.StableEnumPrefix() + types.GetEnum(type).Name;
        }
        if ((int)type < (int)TypeId.FirstUserDefined)
        {
            return StableNames.StableBuiltinPrefix() + type;
        }
        throw new InvalidOperationException(
            $"type id '{(int)type}' has no stable structural identity");
    }

    public static TypeId ResolveType(TypeDefinitionTable types, string identity)
    {
        var parser = new StableTypeParser(types, identity);
        var result = parser.Parse();
        parser.RequireEnd();
        return result;
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
            VisitExpression(function.Body, owner, result, ref ordinal);
        }
        VisitStatements(function.BlockBody, owner, result, ref ordinal);
        foreach (var local in function.LocalFunctions.Values
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            IndexFunctionCallSites(
                local,
                functionIdentities,
                visitedFunctions,
                result);
        }
    }

    private static void VisitStatements(
        IReadOnlyList<Statement> statements,
        string owner,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        foreach (var statement in statements)
        {
            RegisterSyntaxCall(statement, owner, result, ref ordinal);
            switch (statement)
            {
                case BindingStatement binding:
                    VisitExpression(binding.Value, owner, result, ref ordinal);
                    break;
                case IndexAssignmentStatement assignment:
                    VisitExpression(assignment.Index, owner, result, ref ordinal);
                    VisitExpression(assignment.Value, owner, result, ref ordinal);
                    break;
                case FieldAssignmentStatement assignment:
                    VisitExpression(assignment.Value, owner, result, ref ordinal);
                    break;
                case BlockFunctionCallStatement block:
                    VisitExpression(block.Source, owner, result, ref ordinal);
                    foreach (var argument in block.Arguments ?? [])
                    {
                        VisitExpression(argument, owner, result, ref ordinal);
                    }
                    VisitStatements(block.Body, owner, result, ref ordinal);
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    foreach (var block in pipeline.Calls)
                    {
                        RegisterSyntaxCall(block, owner, result, ref ordinal);
                        VisitExpression(block.Source, owner, result, ref ordinal);
                        foreach (var argument in block.Arguments ?? [])
                        {
                            VisitExpression(argument, owner, result, ref ordinal);
                        }
                        VisitStatements(block.Body, owner, result, ref ordinal);
                    }
                    break;
                case ExpressionStatement expression:
                    VisitExpression(expression.Expression, owner, result, ref ordinal);
                    break;
                case GuardLoopControlStatement guard:
                    VisitExpression(guard.Condition, owner, result, ref ordinal);
                    break;
                case ReturnStatement { Value: { } value }:
                    VisitExpression(value, owner, result, ref ordinal);
                    break;
            }
        }
    }

    private static void VisitExpression(
        Expression expression,
        string owner,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        RegisterSyntaxCall(expression, owner, result, ref ordinal);
        switch (expression)
        {
            case StringExpression text:
                foreach (var segment in text.Segments.OfType<InterpolationSegment>())
                    VisitExpression(segment.Expression, owner, result, ref ordinal);
                break;
            case AddExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case SubtractExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case MultiplyExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case DivideExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case ModuloExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case CompareExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case AndExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case OrExpression binary:
                VisitBinary(binary.Left, binary.Right, owner, result, ref ordinal);
                break;
            case RangeExpression binary:
                VisitBinary(binary.Start, binary.End, owner, result, ref ordinal);
                break;
            case NegateExpression unary:
                VisitExpression(unary.Value, owner, result, ref ordinal);
                break;
            case NotExpression unary:
                VisitExpression(unary.Value, owner, result, ref ordinal);
                break;
            case TryExpression unary:
                VisitExpression(unary.Value, owner, result, ref ordinal);
                break;
            case BoxExpression unary:
                VisitExpression(unary.Value, owner, result, ref ordinal);
                break;
            case CompileTimeEachExpression each:
                VisitExpression(each.Source, owner, result, ref ordinal);
                VisitExpression(each.Selector, owner, result, ref ordinal);
                if (each.DictionaryValueSelector is not null)
                    VisitExpression(each.DictionaryValueSelector, owner, result, ref ordinal);
                break;
            case FoldExpression fold:
                VisitExpression(fold.Source, owner, result, ref ordinal);
                VisitExpression(fold.Initial, owner, result, ref ordinal);
                VisitBlock(fold.Body, owner, result, ref ordinal);
                break;
            case IfExpression conditional:
                VisitExpression(conditional.Condition, owner, result, ref ordinal);
                VisitBlock(conditional.Then, owner, result, ref ordinal);
                if (conditional.Else is not null)
                    VisitBlock(conditional.Else, owner, result, ref ordinal);
                break;
            case WhenExpression selection:
                if (selection.Subject is not null)
                    VisitExpression(selection.Subject, owner, result, ref ordinal);
                VisitArms(selection.Arms, owner, result, ref ordinal);
                VisitBlock(selection.Else, owner, result, ref ordinal);
                break;
            case FlowExpression flow:
                VisitExpression(flow.Source, owner, result, ref ordinal);
                foreach (var target in flow.Targets)
                {
                    RegisterSyntaxCall(target, owner, result, ref ordinal);
                    foreach (var argument in target.Arguments)
                        VisitExpression(argument, owner, result, ref ordinal);
                }
                break;
            case BranchExpression branch:
                VisitExpression(branch.Source, owner, result, ref ordinal);
                foreach (var target in branch.Arms.SelectMany(static arm => arm.Targets))
                {
                    RegisterSyntaxCall(target, owner, result, ref ordinal);
                    foreach (var argument in target.Arguments)
                        VisitExpression(argument, owner, result, ref ordinal);
                }
                break;
            case TapExpression tap:
                VisitExpression(tap.Source, owner, result, ref ordinal);
                foreach (var target in tap.Targets)
                {
                    RegisterSyntaxCall(target, owner, result, ref ordinal);
                    foreach (var argument in target.Arguments)
                        VisitExpression(argument, owner, result, ref ordinal);
                }
                break;
            case PartitionExpression partition:
                VisitExpression(partition.Source, owner, result, ref ordinal);
                foreach (var arm in partition.Arms)
                {
                    if (arm.Condition is not null)
                        VisitExpression(arm.Condition, owner, result, ref ordinal);
                }
                break;
            case StreamJoinExpression join:
                VisitExpression(join.Source, owner, result, ref ordinal);
                break;
            case CallExpression call:
                foreach (var argument in call.Arguments)
                    VisitExpression(argument, owner, result, ref ordinal);
                break;
            case ArrayLiteralExpression array:
                foreach (var element in array.Elements)
                    VisitExpression(element, owner, result, ref ordinal);
                break;
            case ArrayRepeatExpression repeat:
                VisitExpression(repeat.Value, owner, result, ref ordinal);
                break;
            case DictionaryLiteralExpression dictionary:
                foreach (var entry in dictionary.Entries)
                {
                    VisitExpression(entry.Key, owner, result, ref ordinal);
                    VisitExpression(entry.Value, owner, result, ref ordinal);
                }
                break;
            case IndexExpression index:
                VisitBinary(index.Source, index.Index, owner, result, ref ordinal);
                break;
            case StructLiteralExpression structure:
                foreach (var field in structure.Fields)
                    VisitExpression(field.Value, owner, result, ref ordinal);
                break;
            case ProductExpression product:
                foreach (var element in product.Elements)
                    VisitExpression(element.Value, owner, result, ref ordinal);
                break;
            case FieldAccessExpression field:
                VisitExpression(field.Source, owner, result, ref ordinal);
                break;
            case MapExpression map:
                VisitExpression(map.Path, owner, result, ref ordinal);
                if (map.Offset is not null) VisitExpression(map.Offset, owner, result, ref ordinal);
                if (map.Length is not null) VisitExpression(map.Length, owner, result, ref ordinal);
                if (map.FileSize is not null) VisitExpression(map.FileSize, owner, result, ref ordinal);
                break;
            case EnumMatchExpression match:
                VisitExpression(match.Subject, owner, result, ref ordinal);
                VisitArms(match.Arms, owner, result, ref ordinal);
                if (match.Else is not null) VisitBlock(match.Else, owner, result, ref ordinal);
                break;
            case SubjectCompareExpression compare:
                VisitExpression(compare.Right, owner, result, ref ordinal);
                break;
            case SubjectRangeExpression range:
                VisitBinary(range.Start, range.End, owner, result, ref ordinal);
                break;
        }
    }

    private static void VisitBinary(
        Expression left,
        Expression right,
        string owner,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        VisitExpression(left, owner, result, ref ordinal);
        VisitExpression(right, owner, result, ref ordinal);
    }

    private static void VisitBlock(
        BlockBody block,
        string owner,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        VisitStatements(block.Statements, owner, result, ref ordinal);
        if (block.Value is not null)
            VisitExpression(block.Value, owner, result, ref ordinal);
    }

    private static void VisitArms(
        IReadOnlyList<WhenArm> arms,
        string owner,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        foreach (var arm in arms)
        {
            VisitExpression(arm.Condition, owner, result, ref ordinal);
            VisitBlock(arm.Body, owner, result, ref ordinal);
        }
    }

    private static void RegisterSyntaxCall(
        object node,
        string owner,
        IDictionary<object, string> result,
        ref int ordinal)
    {
        if (node is not (CallExpression
            or TypeApplicationExpression
            or FlowTarget
            or BlockFunctionCallStatement
            or FieldAccessExpression
            or IfExpression
            or WhenExpression))
        {
            return;
        }
        var identity = owner
            + "/call:"
            + ordinal.ToString(CultureInfo.InvariantCulture)
            + ":"
            + CallSiteShape(node);
        if (!result.TryAdd(node, identity))
        {
            throw new InvalidOperationException("syntax call site occurs more than once in syntax traversal");
        }
        ordinal++;
    }

    private static string CallSiteShape(object node) => node switch
    {
        CallExpression call => "call:" + string.Join('.', call.Path),
        TypeApplicationExpression application =>
            "type:"
            + string.Join('.', application.Path)
            + "<"
            + application.TypeArgument
            + ";"
            + string.Join(',', application.AdditionalTypeArguments ?? [])
            + ">",
        FlowTarget target =>
            "flow:"
            + string.Join('.', target.Path)
            + "<"
            + (target.TypeArgument ?? string.Empty)
            + ";"
            + (target.CompileTimeValueArgument?.ToString(CultureInfo.InvariantCulture) ?? string.Empty)
            + ">",
        BlockFunctionCallStatement block => "block:" + string.Join('.', block.Target),
        FieldAccessExpression field => "field:" + field.FieldName,
        IfExpression => "contextual-if",
        WhenExpression => "contextual-when",
        _ => throw new InvalidOperationException("unsupported stable call-site node")
    };

    private static void Append(StringBuilder builder, string value)
    {
        builder.Append(value.Length.ToString(CultureInfo.InvariantCulture));
        builder.Append(':');
        builder.Append(value);
    }

    private sealed class StableTypeParser(TypeDefinitionTable types, string text)
    {
        private int _position;

        public TypeId Parse()
        {
            if (Take(StableNames.StableProductPrefix()))
            {
                var fields = new List<(string? Label, TypeId Type)>();
                while (true)
                {
                    var labelLength = ParseNumber();
                    Expect(':');
                    if (labelLength > text.Length - _position)
                        throw Invalid("product label exceeds its identity");
                    var label = text.Substring(_position, labelLength);
                    _position += labelLength;
                    Expect(':');
                    var fieldType = Parse();
                    if (fieldType == TypeId.Unit)
                        throw Invalid("product fields must produce values");
                    fields.Add((labelLength == 0 ? null : label, fieldType));
                    if (Take(">"))
                        break;
                    Expect(',');
                }
                if (fields.Count < 2)
                    throw Invalid("product types require at least two fields");
                var displayName = "(" + string.Join(", ", fields.Select(field =>
                    (field.Label is null ? string.Empty : field.Label + ": ")
                    + types.DisplayTypeName(field.Type))) + ")";
                return types.GetOrAddProduct(fields, displayName, 0, 0);
            }
            if (Take(StableNames.StableOptionPrefix()))
                return Close(types.GetOrAddOption(Parse(), "Option"));
            if (Take(StableNames.StableTaskPrefix()))
                return Close(types.GetOrAddTask(Parse()));
            if (Take(StableNames.StableStreamPrefix()))
                return Close(types.GetOrAddStream(Parse()));
            if (Take(StableNames.StableEventStreamPrefix()))
                return Close(types.GetOrAddEventStream(Parse()));
            if (Take(StableNames.StableStaticArrayPrefix()))
                return Close(types.GetOrAddStaticArray(Parse()));
            if (Take(StableNames.StableFixedArrayPrefix()))
            {
                var element = Parse();
                Expect(',');
                var length = ParseNumber();
                Expect('>');
                return types.GetOrAddFixedStaticArray(element, length);
            }
            if (Take(StableNames.StableArrayPrefix()))
                return Close(types.GetOrAddDynamicArray(Parse()));
            if (Take(StableNames.StableBoundedArrayPrefix()))
            {
                var element = Parse();
                Expect(',');
                var capacity = ParseNumber();
                Expect('>');
                return types.GetOrAddBoundedArray(element, capacity);
            }
            if (Take(StableNames.StableBinaryHeapPrefix()))
                return Close(types.GetOrAddBinaryHeap(Parse()));
            if (Take(StableNames.StableDequePrefix()))
                return Close(types.GetOrAddDeque(Parse()));
            if (Take(StableNames.StableSetPrefix()))
                return Close(types.GetOrAddSet(Parse()));
            if (Take(StableNames.StableBitSetPrefix()))
            {
                var bitCount = ParseNumber();
                Expect('>');
                if (bitCount <= 0 || bitCount > int.MaxValue - 63)
                    throw Invalid("invalid BitSet size");
                return types.GetOrAddBitSet(bitCount);
            }
            if (Take(StableNames.StableBoxPrefix()))
            {
                var element = Parse();
                Expect('>');
                if (types.Boxes.FirstOrDefault(box => box.ElementType == element) is { } box)
                    return box.Id;
                throw Invalid("unknown box type");
            }
            if (Take(StableNames.StableReferencePrefix()))
                return Close(types.GetOrAddReference(Parse()));
            if (Take(StableNames.StableSlicePrefix()))
                return Close(types.GetOrAddSlice(Parse()));
            if (Take(StableNames.StableDynTraitPrefix()))
            {
                var traitName = Rest();
                Expect('>');
                return types.GetOrAddDynTrait(traitName);
            }
            if (Take(StableNames.StableResultPrefix()))
            {
                var ok = Parse();
                Expect(',');
                var error = Parse();
                Expect('>');
                return types.GetOrAddResult(ok, error, "Result");
            }
            if (Take(StableNames.StableDictionaryPrefix()))
            {
                var key = Parse();
                Expect(',');
                var value = Parse();
                Expect('>');
                return types.GetOrAddDictionary(key, value);
            }
            if (Take(StableNames.StableBoundedDictionaryPrefix()))
            {
                var key = Parse();
                Expect(',');
                var value = Parse();
                Expect(',');
                var capacity = ParseNumber();
                Expect('>');
                return types.GetOrAddBoundedDictionary(key, value, capacity);
            }
            if (Take(StableNames.StableBuiltinPrefix()))
            {
                var name = Rest();
                if (Enum.TryParse<TypeId>(name, out var builtin)
                    && (int)builtin < (int)TypeId.FirstUserDefined)
                    return builtin;
                throw Invalid("unknown builtin type");
            }
            if (Take(StableNames.StableStructPrefix()) || Take(StableNames.StableEnumPrefix()))
            {
                var name = Rest();
                if (types.TryResolve(name, out var nominal))
                    return nominal;
                throw Invalid("unknown nominal type");
            }
            throw Invalid("unknown stable type identity");
        }

        public void RequireEnd()
        {
            if (_position != text.Length)
                throw Invalid("trailing stable type data");
        }

        private TypeId Close(TypeId type)
        {
            Expect('>');
            return type;
        }

        private bool Take(string value)
        {
            if (!text.AsSpan(_position).StartsWith(value, StringComparison.Ordinal))
                return false;
            _position += value.Length;
            return true;
        }

        private string Rest()
        {
            var start = _position;
            while (_position < text.Length && text[_position] is not ('>' or ','))
                _position++;
            return text[start.._position];
        }

        private int ParseNumber()
        {
            var start = _position;
            while (_position < text.Length && char.IsAsciiDigit(text[_position]))
                _position++;
            if (start == _position
                || !int.TryParse(text.AsSpan(start, _position - start), NumberStyles.None,
                    CultureInfo.InvariantCulture, out var value))
            {
                throw Invalid("expected integer");
            }
            return value;
        }

        private void Expect(char value)
        {
            if (_position >= text.Length || text[_position] != value)
                throw Invalid($"expected '{value}'");
            _position++;
        }

        private InvalidDataException Invalid(string message) =>
            new($"{message} at stable type offset {_position}");
    }
}
