using System.Globalization;
using System.Numerics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private readonly Dictionary<StringExpression, IReadOnlySet<string>> _deferredTextOrigins =
        new(ReferenceEqualityComparer.Instance);

    private sealed record BorrowOriginState(
        IReadOnlyDictionary<string, IReadOnlySet<string>> Origins,
        IReadOnlySet<string> ReadonlyReferenceBindings);

    // Contract discovery precedes body validation; types and origin scope travel together.
    private sealed class BorrowOriginInferenceLocals : Dictionary<string, IReadOnlySet<string>>
    {
        public string ModuleName { get; }
        public Dictionary<string, BoundType> Types { get; }

        public BorrowOriginInferenceLocals(
            BoundFunction function,
            IEnumerable<KeyValuePair<string, IReadOnlySet<string>>> origins)
            : base(origins, StringComparer.Ordinal)
        {
            ModuleName = function.ModuleName;
            Types = new Dictionary<string, BoundType>(StringComparer.Ordinal);
            if (function.InputType is { } input)
                Types[function.InputName ?? "it"] = input;
            foreach (var parameter in function.AdditionalParameters ?? [])
                Types[parameter.Name] = parameter.Type;
        }

        public BorrowOriginInferenceLocals(BorrowOriginInferenceLocals parent)
            : base(parent, StringComparer.Ordinal)
        {
            ModuleName = parent.ModuleName;
            Types = new Dictionary<string, BoundType>(parent.Types, StringComparer.Ordinal);
        }
    }

    private static Dictionary<string, IReadOnlySet<string>> CopyBorrowOriginInferenceLocals(
        IReadOnlyDictionary<string, IReadOnlySet<string>> parent) =>
        parent is BorrowOriginInferenceLocals typed
            ? new BorrowOriginInferenceLocals(typed)
            : new Dictionary<string, IReadOnlySet<string>>(parent, StringComparer.Ordinal);

    [Flags]
    private enum BorrowControlExit
    {
        None = 0,
        Fallthrough = 1,
        Break = 2,
        Continue = 4,
        Return = 8
    }

    private void ValidateReadonlySliceReturnEscapes(IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var candidates = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in functions.Values)
            CollectFunctionTree(function, candidates);
        foreach (var function in candidates)
        {
            if (function.Kind != BoundFunctionKind.User)
                continue;
            var sources = new BorrowOriginInferenceLocals(function, []);
            if (function.InputType is { } input && _types.IsSlice(input)
                && TypeContains(function.ReturnType, input))
                sources.Add(function.InputName ?? "it", new HashSet<string>([function.InputName ?? "it"], StringComparer.Ordinal));
            foreach (var parameter in function.AdditionalParameters ?? [])
                if (_types.IsSlice(parameter.Type) && TypeContains(function.ReturnType, parameter.Type))
                    sources.Add(parameter.Name, new HashSet<string>([parameter.Name], StringComparer.Ordinal));
            if (sources.Count == 0)
                continue;
            var returned = new HashSet<string>(StringComparer.Ordinal);
            CollectBorrowedTextReturnOrigins(function.BlockBody, functions, sources, returned);
            if (function.Body is not null && TryInferBorrowedTextOrigins(function.Body, functions, sources, out var origins))
                returned.UnionWith(origins);
            if (returned.Count > 0)
                throw Error(function.Line, function.Column,
                    $"readonly slice parameter '{string.Join(", ", returned)}' cannot escape beyond the call; return an owned copy instead");
        }
    }

    private void DiscoverReadonlyReferenceReturnOrigins(
        IReadOnlyDictionary<string, BoundFunction> functions)
        => DiscoverReadonlyReferenceReturnOrigins(functions, functions.Values);

    private void DiscoverReadonlyReferenceReturnOrigins(
        IReadOnlyDictionary<string, BoundFunction> functions,
        IEnumerable<BoundFunction> roots)
    {
        var candidates = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in roots)
        {
            CollectFunctionTree(function, candidates);
        }

        var changed = true;
        while (changed)
        {
            changed = false;
            foreach (var function in candidates)
            {
                if (!TypeContainsReadonlyReference(function.ReturnType)
                    || !ReadonlyReferenceOriginParameterNames(function).Any())
                {
                    continue;
                }

                if (TryInferFunctionReadonlyReferenceOrigins(function, functions, out var origins)
                    && (!_readonlyReferenceReturnOrigins.TryGetValue(function, out var previous)
                        || !previous.IsSupersetOf(origins)))
                {
                    _readonlyReferenceReturnOrigins[function] = previous is null
                        ? origins
                        : new HashSet<string>(previous.Concat(origins), StringComparer.Ordinal);
                    changed = true;
                }
            }
        }
    }

    private IEnumerable<string> ReadonlyReferenceOriginParameterNames(BoundFunction function)
    {
        if (function.InputType is { } inputType && TypeContainsReadonlyReference(inputType))
        {
            yield return function.InputName ?? "it";
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            if (TypeContainsReadonlyReference(parameter.Type))
            {
                yield return parameter.Name;
            }
        }
    }

    private bool TryInferFunctionReadonlyReferenceOrigins(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out IReadOnlySet<string> origins)
    {
        var locals = ReadonlyReferenceOriginParameterNames(function).ToDictionary(
            static name => name,
            static name => (IReadOnlySet<string>)new HashSet<string>([name], StringComparer.Ordinal),
            StringComparer.Ordinal);
        var union = new HashSet<string>(StringComparer.Ordinal);
        CollectReadonlyReferenceReturnOrigins(function.BlockBody, functions, locals, union);
        if (function.Body is not null
            && TryInferReadonlyReferenceOrigins(function.Body, functions, locals, out var bodyOrigins))
        {
            union.UnionWith(bodyOrigins);
        }
        origins = union;
        return union.Count > 0;
    }

    private void CollectReadonlyReferenceReturnOrigins(
        IReadOnlyList<Statement> statements,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, IReadOnlySet<string>> locals,
        HashSet<string> union)
    {
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    CollectNestedReadonlyReferenceReturnOrigins(binding.Value, functions, locals, union);
                    if (TryInferReadonlyReferenceOrigins(binding.Value, functions, locals, out var bindingOrigins))
                    {
                        locals[binding.Name] = bindingOrigins;
                    }
                    break;
                case ReturnStatement { Value: { } value }:
                    if (TryInferReadonlyReferenceOrigins(value, functions, locals, out var returnOrigins))
                    {
                        union.UnionWith(returnOrigins);
                    }
                    CollectNestedReadonlyReferenceReturnOrigins(value, functions, locals, union);
                    break;
                case ExpressionStatement expression:
                    CollectNestedReadonlyReferenceReturnOrigins(expression.Expression, functions, locals, union);
                    break;
                case BlockFunctionCallStatement block:
                    CollectNestedReadonlyReferenceReturnOrigins(block.Source, functions, locals, union);
                    var blockLocals = new Dictionary<string, IReadOnlySet<string>>(locals, StringComparer.Ordinal);
                    CollectReadonlyReferenceReturnOrigins(block.Body, functions, blockLocals, union);
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    foreach (var block in pipeline.Calls)
                    {
                        CollectNestedReadonlyReferenceReturnOrigins(block.Source, functions, locals, union);
                        var pipelineLocals = new Dictionary<string, IReadOnlySet<string>>(locals, StringComparer.Ordinal);
                        CollectReadonlyReferenceReturnOrigins(block.Body, functions, pipelineLocals, union);
                    }
                    break;
            }
        }
    }

    private void CollectNestedReadonlyReferenceReturnOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        HashSet<string> union)
    {
        switch (expression)
        {
            case IfExpression conditional:
                CollectBlockReadonlyReferenceReturnOrigins(conditional.Then, functions, locals, union);
                if (conditional.Else is not null)
                {
                    CollectBlockReadonlyReferenceReturnOrigins(conditional.Else, functions, locals, union);
                }
                break;
            case WhenExpression match:
                foreach (var arm in match.Arms)
                {
                    CollectBlockReadonlyReferenceReturnOrigins(arm.Body, functions, locals, union);
                }
                CollectBlockReadonlyReferenceReturnOrigins(match.Else, functions, locals, union);
                break;
        }
    }

    private void CollectBlockReadonlyReferenceReturnOrigins(
        BlockBody block,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> parentLocals,
        HashSet<string> union)
    {
        var locals = new Dictionary<string, IReadOnlySet<string>>(parentLocals, StringComparer.Ordinal);
        CollectReadonlyReferenceReturnOrigins(block.Statements, functions, locals, union);
        if (block.Value is not null
            && TryInferReadonlyReferenceOrigins(block.Value, functions, locals, out var origins))
        {
            union.UnionWith(origins);
        }
    }

    private bool TryInferReadonlyReferenceOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        if (expression is NameExpression name && locals.TryGetValue(name.Name, out origins!))
        {
            return true;
        }
        if (expression is FieldAccessExpression field)
        {
            return TryInferReadonlyReferenceOrigins(field.Source, functions, locals, out origins);
        }
        if (expression is IndexExpression index)
        {
            return TryInferReadonlyReferenceOrigins(index.Source, functions, locals, out origins);
        }
        if (expression is StructLiteralExpression structure)
        {
            return TryUnionInferredReadonlyReferenceOrigins(
                structure.Fields.Select(static field => field.Value),
                functions,
                locals,
                out origins);
        }
        if (expression is ProductExpression product)
        {
            return TryUnionInferredReadonlyReferenceOrigins(
                product.Elements.Select(static element => element.Value),
                functions,
                locals,
                out origins);
        }
        if (expression is BranchExpression branch)
        {
            return TryUnionInferredReadonlyReferenceOrigins(
                branch.Arms.Select(arm => (Expression)new FlowExpression(
                    branch.Source,
                    arm.Targets,
                    arm.Line,
                    arm.Column)),
                functions,
                locals,
                out origins);
        }
        if (expression is TapExpression tap)
        {
            return TryInferReadonlyReferenceOrigins(tap.Source, functions, locals, out origins);
        }
        if (expression is PartitionExpression partition)
        {
            return TryInferReadonlyReferenceOrigins(partition.Source, functions, locals, out origins);
        }
        if (expression is StreamJoinExpression join)
        {
            return TryInferReadonlyReferenceOrigins(join.Source, functions, locals, out origins);
        }
        if (expression is ArrayLiteralExpression array)
        {
            return TryUnionInferredReadonlyReferenceOrigins(
                array.Elements,
                functions,
                locals,
                out origins);
        }
        if (expression is DictionaryLiteralExpression dictionary)
        {
            return TryUnionInferredReadonlyReferenceOrigins(
                dictionary.Entries.SelectMany(static entry => new[] { entry.Key, entry.Value }),
                functions,
                locals,
                out origins);
        }
        if (expression is CallExpression enumConstructor
            && TryGetBorrowCarrierEnumConstructor(
                enumConstructor,
                out _,
                out var enumVariant,
                out var enumPayload)
            && enumVariant.PayloadType is { } enumPayloadType
            && TypeContainsReadonlyReference(enumPayloadType))
        {
            return TryInferReadonlyReferenceOrigins(
                enumPayload,
                functions,
                locals,
                out origins);
        }
        if (expression is CallExpression call
            && TryGetFunction(call.Path, functions, out var called)
            && _readonlyReferenceReturnOrigins.TryGetValue(called, out var returnOrigins))
        {
            return TryMapReadonlyReferenceReturnOrigins(
                called, returnOrigins, call.Arguments, functions, locals, out origins);
        }
        if (expression is FlowExpression flow && flow.Targets.Count > 0)
        {
            var target = flow.Targets[^1];
            if (TryGetFunction(target.Path, functions, out var flowed)
                && _readonlyReferenceReturnOrigins.TryGetValue(flowed, out var flowedReturnOrigins))
            {
                var arguments = new Expression[] { BorrowOriginFlowReceiver(flow) }.Concat(target.Arguments).ToArray();
                return TryMapReadonlyReferenceReturnOrigins(
                    flowed, flowedReturnOrigins, arguments, functions, locals, out origins);
            }
        }
        if (expression is IfExpression conditional && conditional.Else is not null)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            CollectBlockReadonlyReferenceOrigins(conditional.Then, functions, locals, union);
            CollectBlockReadonlyReferenceOrigins(conditional.Else, functions, locals, union);
            origins = union;
            return union.Count > 0;
        }
        if (expression is WhenExpression match)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            foreach (var arm in match.Arms)
            {
                CollectBlockReadonlyReferenceOrigins(arm.Body, functions, locals, union);
            }
            CollectBlockReadonlyReferenceOrigins(match.Else, functions, locals, union);
            origins = union;
            return union.Count > 0;
        }

        origins = EmptyBorrowOrigins();
        return false;
    }

    private void CollectBlockReadonlyReferenceOrigins(
        BlockBody block,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> parentLocals,
        HashSet<string> union)
    {
        var locals = new Dictionary<string, IReadOnlySet<string>>(parentLocals, StringComparer.Ordinal);
        foreach (var statement in block.Statements)
        {
            if (statement is BindingStatement binding
                && TryInferReadonlyReferenceOrigins(binding.Value, functions, locals, out var bindingOrigins))
            {
                locals[binding.Name] = bindingOrigins;
            }
        }
        if (block.Value is not null
            && TryInferReadonlyReferenceOrigins(block.Value, functions, locals, out var origins))
        {
            union.UnionWith(origins);
        }
    }

    private bool TryMapReadonlyReferenceReturnOrigins(
        BoundFunction called,
        IReadOnlySet<string> returnOrigins,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        var parameters = FunctionParameters(called);
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var returnOrigin in returnOrigins)
        {
            var ordinal = parameters.FindIndex(parameter =>
                StringComparer.Ordinal.Equals(parameter, returnOrigin));
            if (ordinal < 0 || ordinal >= arguments.Count
                || !TryInferReadonlyReferenceOrigins(arguments[ordinal], functions, locals, out var argumentOrigins))
            {
                origins = EmptyBorrowOrigins();
                return false;
            }
            union.UnionWith(argumentOrigins);
        }
        origins = union;
        return union.Count > 0;
    }

    private bool TryUnionInferredReadonlyReferenceOrigins(
        IEnumerable<Expression> expressions,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var expression in expressions)
        {
            if (TryInferReadonlyReferenceOrigins(expression, functions, locals, out var nested))
            {
                union.UnionWith(nested);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private void DiscoverBorrowedTextReturnOrigins(
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var candidates = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in functions.Values)
        {
            CollectFunctionTree(function, candidates);
        }

        var changed = true;
        while (changed)
        {
            changed = false;
            foreach (var function in candidates)
            {
                if (!TypeCanCarryBorrowedTextOrigin(function.ReturnType)
                    || !BorrowedTextOriginParameterNames(function).Any())
                {
                    continue;
                }

                if (TryInferFunctionBorrowedTextOrigins(function, functions, out var origins)
                    && (!_borrowedTextReturnOrigins.TryGetValue(function, out var previous)
                        || !previous.IsSupersetOf(origins)))
                {
                    _borrowedTextReturnOrigins[function] = previous is null
                        ? origins
                        : new HashSet<string>(previous.Concat(origins), StringComparer.Ordinal);
                    changed = true;
                }
            }
        }
    }

    private bool TypeCanCarryBorrowedTextOrigin(BoundType type) =>
        TypeContains(type, BoundType.Text)
        || TypeContains(type, BoundType.SourceText);

    private static void CollectFunctionTree(
        BoundFunction function,
        HashSet<BoundFunction> functions)
    {
        if (!functions.Add(function))
        {
            return;
        }
        foreach (var local in function.LocalFunctions.Values)
        {
            CollectFunctionTree(local, functions);
        }
    }

    private IEnumerable<string> BorrowedTextOriginParameterNames(BoundFunction function)
    {
        if (function.InputType is { } inputType
            && CanSupplyBorrowedTextOrigin(inputType, function.InputOwnership))
        {
            yield return function.InputName ?? "it";
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            if (CanSupplyBorrowedTextOrigin(parameter.Type, parameter.Ownership))
            {
                yield return parameter.Name;
            }
        }
    }

    private bool CanSupplyBorrowedTextOrigin(
        BoundType type,
        BoundFunctionInputOwnership ownership)
    {
        return (type == BoundType.SourceText
                && ownership == BoundFunctionInputOwnership.Default)
            || type == BoundType.Arena
            || (ownership != BoundFunctionInputOwnership.Move
                && IsBorrowedTextByteStorage(type))
            || TypeContains(type, BoundType.Text)
            || (type != BoundType.SourceText
                && TypeContains(type, BoundType.SourceText));
    }

    private bool IsBorrowedTextByteStorage(BoundType type) =>
        TypeContains(type, TypeId.DynamicUInt8Array);

    private bool TryInferFunctionBorrowedTextOrigins(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out IReadOnlySet<string> origins)
    {
        var locals = new BorrowOriginInferenceLocals(
            function,
            BorrowedTextOriginParameterNames(function).Select(static name =>
                new KeyValuePair<string, IReadOnlySet<string>>(
                    name, new HashSet<string>([name], StringComparer.Ordinal))));
        var union = new HashSet<string>(StringComparer.Ordinal);
        CollectBorrowedTextReturnOrigins(
            function.BlockBody,
            functions,
            locals,
            union);

        if (function.Body is not null
            && TryInferBorrowedTextOrigins(function.Body, functions, locals, out var bodyOrigins))
        {
            union.UnionWith(bodyOrigins);
        }
        origins = union;
        return union.Count > 0;
    }

    private void CollectBorrowedTextReturnOrigins(
        IReadOnlyList<Statement> statements,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, IReadOnlySet<string>> locals,
        HashSet<string> union)
    {
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    CollectNestedBorrowedTextReturnOrigins(binding.Value, functions, locals, union);
                    if (TryInferBorrowedTextOrigins(
                            binding.Value,
                            functions,
                            locals,
                            out var bindingOrigins))
                    {
                        locals[binding.Name] = bindingOrigins;
                    }
                    else
                    {
                        locals.Remove(binding.Name);
                    }
                    RecordBorrowOriginInferenceBinding(binding, functions, locals);
                    break;
                case ReturnStatement { Value: { } value }:
                    if (TryInferBorrowedTextOrigins(value, functions, locals, out var returnOrigins))
                    {
                        union.UnionWith(returnOrigins);
                    }
                    CollectNestedBorrowedTextReturnOrigins(value, functions, locals, union);
                    break;
                case ExpressionStatement expression:
                    RecordBorrowOriginInferencePush(expression.Expression, functions, locals);
                    CollectNestedBorrowedTextReturnOrigins(
                        expression.Expression,
                        functions,
                        locals,
                        union);
                    break;
                case BlockFunctionCallStatement block:
                    CollectNestedBorrowedTextReturnOrigins(block.Source, functions, locals, union);
                    var blockLocals = CopyBorrowOriginInferenceLocals(locals);
                    SeedBorrowOriginInferenceEachItem(block, functions, blockLocals);
                    CollectBorrowedTextReturnOrigins(block.Body, functions, blockLocals, union);
                    MergeBorrowOriginInferenceMutations(locals, blockLocals, block.Body, block.ItemName);
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    foreach (var block in pipeline.Calls)
                    {
                        CollectNestedBorrowedTextReturnOrigins(block.Source, functions, locals, union);
                        var pipelineLocals = CopyBorrowOriginInferenceLocals(locals);
                        SeedBorrowOriginInferenceEachItem(block, functions, pipelineLocals);
                        CollectBorrowedTextReturnOrigins(block.Body, functions, pipelineLocals, union);
                        MergeBorrowOriginInferenceMutations(locals, pipelineLocals, block.Body, block.ItemName);
                    }
                    break;
            }
        }
    }

    private void CollectNestedBorrowedTextReturnOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        HashSet<string> union)
    {
        switch (expression)
        {
            case IfExpression conditional:
                CollectBlockBorrowedTextReturnOrigins(conditional.Then, functions, locals, union);
                if (conditional.Else is not null)
                {
                    CollectBlockBorrowedTextReturnOrigins(conditional.Else, functions, locals, union);
                }
                break;
            case WhenExpression match:
                foreach (var arm in match.Arms)
                {
                    CollectBlockBorrowedTextReturnOrigins(arm.Body, functions, locals, union);
                }
                CollectBlockBorrowedTextReturnOrigins(match.Else, functions, locals, union);
                break;
            case EnumMatchExpression match:
                foreach (var arm in match.Arms)
                {
                    CollectBlockBorrowedTextReturnOrigins(arm.Body, functions, locals, union);
                }
                if (match.Else is not null)
                {
                    CollectBlockBorrowedTextReturnOrigins(match.Else, functions, locals, union);
                }
                break;
            case FoldExpression fold:
                CollectBlockBorrowedTextReturnOrigins(fold.Body, functions, locals, union);
                break;
        }
    }

    private static bool IsBorrowedStorageViewIntrinsic(BoundFunctionKind kind) =>
        kind is BoundFunctionKind.RuntimeBorrowSourceBytes
            or BoundFunctionKind.RuntimeBorrowSourceText
            or BoundFunctionKind.RuntimePathText;

    private static Expression BorrowOriginFlowReceiver(FlowExpression flow)
    {
        // The final stage determines the returned view's origin. Preserve its
        // exact preceding flow for source-preserving and ordinary call mapping;
        // a materialize stage instead replaces that origin with its Arena.
        return flow.Targets.Count == 1
            ? flow.Source
            : new FlowExpression(
                flow.Source, flow.Targets.Take(flow.Targets.Count - 1).ToArray(), flow.Line, flow.Column);
    }

    private bool TryGetArrayPushElementType(BoundType type, out BoundType element)
    {
        if (type == BoundType.DynamicIntArray)
        {
            element = BoundType.Int;
            return true;
        }
        if (_types.IsBoundedArray(type))
        {
            element = _types.GetBoundedArray(type).ElementType;
            return true;
        }
        if (_types.IsDynamicArray(type))
        {
            element = _types.GetDynamicArray(type).ElementType;
            return true;
        }
        element = default;
        return false;
    }

    private static bool TryGetBorrowOriginReceiverBinding(
        Expression receiver,
        IReadOnlyDictionary<string, BoundType> bindings,
        out string binding)
    {
        if (TryGetBorrowPlace(receiver, out var place))
        {
            var root = SplitBorrowPlace(place)[0];
            foreach (var name in bindings.Keys)
            {
                if (CanonicalBorrowOriginName(name) == root)
                {
                    binding = name;
                    return true;
                }
            }
        }
        binding = "";
        return false;
    }

    private static void UnionBorrowOriginCarrier(
        IDictionary<string, IReadOnlySet<string>> carriers,
        string receiver,
        IReadOnlySet<string> storedOrigins)
    {
        if (storedOrigins.Count == 0)
            return;
        var union = carriers.TryGetValue(receiver, out var previous)
            ? new HashSet<string>(previous, StringComparer.Ordinal)
            : new HashSet<string>(StringComparer.Ordinal);
        union.UnionWith(storedOrigins);
        carriers[receiver] = union;
    }

    private void RecordBorrowOriginInferencePush(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, IReadOnlySet<string>> locals)
    {
        if (expression is not FlowExpression { Targets.Count: 1 } flow
            || flow.Targets[0] is not { Path.Count: 1, Arguments.Count: 1 } target
            || target.Path[0] != "push"
            || locals is not BorrowOriginInferenceLocals typed
            || !TryGetBorrowOriginInferenceType(flow.Source, functions, typed, out var receiverType)
            || !TryGetArrayPushElementType(receiverType, out var elementType)
            || !TypeCanCarryBorrowedTextOrigin(elementType))
            return;
        // Match declared-target precedence in TryInferContainerFlowTarget.
        if (TryGetBorrowOriginInferenceFunction(target, target.Path, flow.Source, functions, locals, out var declared)
            && declared.IsVisibleFrom(typed.ModuleName)
            && declared.Kind is BoundFunctionKind.User or BoundFunctionKind.Native)
            return;
        if (TryGetBorrowOriginReceiverBinding(flow.Source, typed.Types, out var receiver)
            && TryInferBorrowedTextOrigins(target.Arguments[0], functions, locals, out var origins))
            UnionBorrowOriginCarrier(locals, receiver, origins);
    }

    private void SeedBorrowOriginInferenceEachItem(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, IReadOnlySet<string>> locals)
    {
        // BindBlockFunctionCall selects builtin each before user block targets.
        if (call.Target.Count != 1 || call.Target[0] != "each"
            || locals is not BorrowOriginInferenceLocals typed
            || !TryGetBorrowOriginInferenceType(call.Source, functions, typed, out var sourceType))
            return;
        if (!TryGetContextualArrayElementType(sourceType, out var elementType))
            return;
        typed.Types[call.ItemName] = elementType;
        if (TypeCanCarryBorrowedTextOrigin(elementType)
            && TryInferBorrowedTextOrigins(call.Source, functions, locals, out var origins))
            locals[call.ItemName] = origins;
        else
            locals.Remove(call.ItemName);
    }

    private static void MergeBorrowOriginInferenceMutations(
        Dictionary<string, IReadOnlySet<string>> parent,
        Dictionary<string, IReadOnlySet<string>> child,
        IReadOnlyList<Statement> statements,
        string? itemName = null)
    {
        if (parent is not BorrowOriginInferenceLocals typedParent)
            return;
        // Only existing outer bindings survive this lexical block. Declarations
        // and callback items never replace an outer receiver by matching spelling.
        var localNames = statements.OfType<BindingStatement>()
            .Select(static binding => binding.Name).ToHashSet(StringComparer.Ordinal);
        if (itemName is not null)
            localNames.Add(itemName);
        var updates = child.Where(pair => typedParent.Types.ContainsKey(pair.Key)
            && !localNames.Contains(pair.Key)).ToDictionary(
                static pair => pair.Key, static pair => pair.Value, StringComparer.Ordinal);
        var merged = MergeBorrowedTextOriginStates([
            new BorrowOriginState(parent, new HashSet<string>(StringComparer.Ordinal)),
            new BorrowOriginState(updates, new HashSet<string>(StringComparer.Ordinal))]);
        foreach (var pair in merged.Origins)
            parent[pair.Key] = pair.Value;
    }

    private void RecordBorrowOriginInferenceBinding(
        BindingStatement binding,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals)
    {
        if (locals is not BorrowOriginInferenceLocals typed)
            return;
        if (TryGetBorrowOriginInferenceType(binding.Value, functions, typed, out var type))
            typed.Types[binding.Name] = type;
        else
            typed.Types.Remove(binding.Name);
    }

    private bool TryGetBorrowOriginInferenceFunction(
        object site,
        IReadOnlyList<string> path,
        Expression? receiver,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out BoundFunction function)
    {
        if (_resolvedGenericCalls.TryGetValue(site, out function!))
            return true;
        if (locals is BorrowOriginInferenceLocals typed)
        {
            var previousModule = _currentModuleName;
            _currentModuleName = typed.ModuleName;
            try
            {
                // Flow retains canonical receiver-first dispatch. Direct calls
                // retain global declaration priority before named-receiver dispatch.
                if (receiver is not null
                    && TryGetBorrowOriginInferenceType(receiver, functions, typed, out var receiverType)
                    && TryResolveInstanceMethod(receiverType, string.Join('.', path), functions, out function))
                    return true;
                if (TryGetFunction(path, functions, out function))
                    return true;
                if (receiver is null
                    && TryResolveInstanceMethodCall(path, functions, typed.Types, out function, out _, out _))
                    return true;
            }
            finally
            {
                _currentModuleName = previousModule;
            }
            function = null!;
            return false;
        }
        return TryGetFunction(path, functions, out function);
    }

    private bool TryGetBorrowOriginInferenceType(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        BorrowOriginInferenceLocals locals,
        out BoundType type)
    {
        if (expression is NameExpression name)
        {
            if (!locals.Types.TryGetValue(name.Name, out type))
                return false;
            // Match InferNameExpression's single reference read; binding metadata
            // remains unchanged for ownership and call-parameter decisions.
            if (_types.IsReference(type))
                type = _types.GetReference(type).ElementType;
            return true;
        }
        if (expression is TypedEmptyArrayExpression empty)
        {
            var previousModule = _currentModuleName;
            _currentModuleName = locals.ModuleName;
            try
            {
                type = InferTypedEmptyArrayExpression(empty);
                return true;
            }
            finally
            {
                _currentModuleName = previousModule;
            }
        }
        if (expression is FieldAccessExpression field
            && TryGetBorrowOriginInferenceType(field.Source, functions, locals, out var owner))
        {
            if (_types.IsReference(owner))
                owner = _types.GetReference(owner).ElementType;
            if (_types.IsStruct(owner))
            {
                var selected = _types.GetStruct(owner).Fields.FirstOrDefault(candidate =>
                    StringComparer.Ordinal.Equals(candidate.Name, field.FieldName));
                if (selected is not null)
                {
                    type = selected.Type;
                    return true;
                }
            }
        }
        if (expression is IndexExpression indexed
            && TryGetBorrowOriginInferenceType(indexed.Source, functions, locals, out var container)
            && TryGetContextualArrayElementType(container, out type))
            return true;
        if (expression is CallExpression call
            && TryGetBorrowOriginInferenceFunction(call, call.Path, null, functions, locals, out var called))
        {
            type = called.ReturnType;
            return true;
        }
        if (expression is FlowExpression flow
            && TryGetBorrowOriginInferenceType(flow.Source, functions, locals, out type))
        {
            foreach (var target in flow.Targets)
            {
                // Return types come from actual declarations, not builtin spelling.
                var previousModule = _currentModuleName;
                _currentModuleName = locals.ModuleName;
                try
                {
                    if (!_resolvedGenericCalls.TryGetValue(target, out var selected)
                        && !TryResolveInstanceMethod(type, string.Join('.', target.Path), functions, out selected)
                        && !TryGetFunction(target.Path, functions, out selected))
                    {
                        type = default;
                        return false;
                    }
                    type = selected.ReturnType;
                }
                finally
                {
                    _currentModuleName = previousModule;
                }
            }
            return true;
        }
        type = default;
        return false;
    }

    private bool TryInferBorrowedTextOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        if (expression is NameExpression name && locals.TryGetValue(name.Name, out origins!))
        {
            return true;
        }

        if (expression is StructLiteralExpression structure)
        {
            return TryUnionBorrowedTextOrigins(
                structure.Fields.Select(static field => field.Value),
                functions,
                locals,
                out origins);
        }
        if (expression is ProductExpression product)
        {
            return TryUnionBorrowedTextOrigins(
                product.Elements.Select(static element => element.Value),
                functions,
                locals,
                out origins);
        }
        if (expression is BranchExpression branch)
        {
            return TryUnionBorrowedTextOrigins(
                branch.Arms.Select(arm => (Expression)new FlowExpression(
                    branch.Source,
                    arm.Targets,
                    arm.Line,
                    arm.Column)),
                functions,
                locals,
                out origins);
        }
        if (expression is TapExpression tap)
        {
            return TryInferBorrowedTextOrigins(tap.Source, functions, locals, out origins);
        }
        if (expression is PartitionExpression partition)
        {
            return TryInferBorrowedTextOrigins(partition.Source, functions, locals, out origins);
        }
        if (expression is StreamJoinExpression join)
        {
            return TryInferBorrowedTextOrigins(join.Source, functions, locals, out origins);
        }

        if (expression is ArrayLiteralExpression array)
        {
            return TryUnionBorrowedTextOrigins(array.Elements, functions, locals, out origins);
        }

        if (expression is ArrayRepeatExpression repeat)
        {
            return TryInferBorrowedTextOrigins(repeat.Value, functions, locals, out origins);
        }

        if (expression is DictionaryLiteralExpression dictionary)
        {
            return TryUnionBorrowedTextOrigins(
                dictionary.Entries.SelectMany(static entry => new[] { entry.Key, entry.Value }),
                functions,
                locals,
                out origins);
        }

        if (expression is FieldAccessExpression field)
        {
            return TryInferBorrowedTextOrigins(field.Source, functions, locals, out origins);
        }

        if (expression is IndexExpression index)
        {
            return TryInferBorrowedTextOrigins(index.Source, functions, locals, out origins);
        }

        if (expression is TryExpression attempted)
        {
            return TryInferBorrowedTextOrigins(attempted.Value, functions, locals, out origins);
        }

        if (expression is BoxExpression boxed)
        {
            return TryInferBorrowedTextOrigins(boxed.Value, functions, locals, out origins);
        }

        if (TryGetBorrowedTextEnumPayload(expression, out var enumPayload))
        {
            return TryInferBorrowedTextOrigins(
                enumPayload,
                functions,
                locals,
                out origins);
        }

        if (expression is CallExpression call
            && TryGetBorrowOriginInferenceFunction(call, call.Path, null, functions, locals, out var called))
        {
            IReadOnlyList<Expression> arguments = call.Arguments;
            if (locals is BorrowOriginInferenceLocals typed
                && call.Path.Count == 2
                && typed.Types.ContainsKey(call.Path[0])
                && !TryGetFunction(call.Path, functions, out _))
            {
                arguments = new Expression[] { new NameExpression(call.Path[0], call.Line, call.Column) }
                    .Concat(call.Arguments).ToArray();
            }
            if (IsBorrowedStorageViewIntrinsic(called.Kind))
            {
                if (arguments.Count > 0)
                {
                    return TryInferBorrowedTextOrigins(
                        arguments[0], functions, locals, out origins);
                }
                origins = EmptyBorrowOrigins();
                return false;
            }
            if (_borrowedTextReturnOrigins.TryGetValue(called, out var returnOrigins))
            {
                return TryMapBorrowedReturnOrigins(
                    called,
                    returnOrigins,
                    arguments,
                    functions,
                    locals,
                    out origins);
            }
        }

        if (expression is FlowExpression flow)
        {
            if (flow.Targets.Count == 0)
                return TryInferBorrowedTextOrigins(flow.Source, functions, locals, out origins);

            var target = flow.Targets[^1];
            var current = BorrowOriginFlowReceiver(flow);
            var path = string.Join('.', target.Path);
            if (path == "materialize" && target.Arguments.Count == 1)
                return TryInferBorrowedTextOrigins(target.Arguments[0], functions, locals, out origins);
            if (path == "slice")
                return TryInferBorrowedTextOrigins(current, functions, locals, out origins);
            if (TryGetBorrowOriginInferenceFunction(target, target.Path, current, functions, locals, out var flowedFunction))
            {
                if (IsBorrowedStorageViewIntrinsic(flowedFunction.Kind))
                    return TryInferBorrowedTextOrigins(current, functions, locals, out origins);
                if (_borrowedTextReturnOrigins.TryGetValue(flowedFunction, out var flowedReturnOrigins))
                {
                    var arguments = new Expression[] { current }.Concat(target.Arguments).ToArray();
                    return TryMapBorrowedReturnOrigins(
                        flowedFunction, flowedReturnOrigins, arguments, functions, locals, out origins);
                }
            }
            origins = EmptyBorrowOrigins();
            return false;
        }

        if (expression is IfExpression conditional && conditional.Else is not null)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            CollectBlockBorrowedTextOrigins(conditional.Then, functions, locals, union);
            CollectBlockBorrowedTextOrigins(conditional.Else, functions, locals, union);
            origins = union;
            return union.Count > 0;
        }

        if (expression is WhenExpression when)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            foreach (var arm in when.Arms)
            {
                CollectBlockBorrowedTextOrigins(arm.Body, functions, locals, union);
            }
            CollectBlockBorrowedTextOrigins(when.Else, functions, locals, union);
            origins = union;
            return union.Count > 0;
        }

        if (expression is EnumMatchExpression match)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            foreach (var arm in match.Arms)
            {
                CollectBlockBorrowedTextOrigins(arm.Body, functions, locals, union);
            }
            if (match.Else is not null)
            {
                CollectBlockBorrowedTextOrigins(match.Else, functions, locals, union);
            }
            origins = union;
            return union.Count > 0;
        }

        origins = EmptyBorrowOrigins();
        return false;
    }

    private bool TryUnionBorrowedTextOrigins(
        IEnumerable<Expression> expressions,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var expression in expressions)
        {
            if (TryInferBorrowedTextOrigins(expression, functions, locals, out var nested))
            {
                union.UnionWith(nested);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private void CollectBlockBorrowedTextOrigins(
        BlockBody block,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> parentLocals,
        HashSet<string> union)
    {
        var locals = CopyBorrowOriginInferenceLocals(parentLocals);
        CollectBorrowedTextReturnOrigins(block.Statements, functions, locals, union);
        if (block.Value is not null)
        {
            RecordBorrowOriginInferencePush(block.Value, functions, locals);
            CollectNestedBorrowedTextReturnOrigins(block.Value, functions, locals, union);
            if (TryInferBorrowedTextOrigins(block.Value, functions, locals, out var origins))
                union.UnionWith(origins);
        }
        if (parentLocals is Dictionary<string, IReadOnlySet<string>> mutableParent)
            MergeBorrowOriginInferenceMutations(mutableParent, locals, block.Statements);
    }

    private void CollectBlockBorrowedTextReturnOrigins(
        BlockBody block,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> parentLocals,
        HashSet<string> union)
    {
        var locals = CopyBorrowOriginInferenceLocals(parentLocals);
        CollectBorrowedTextReturnOrigins(block.Statements, functions, locals, union);
        if (block.Value is not null)
        {
            RecordBorrowOriginInferencePush(block.Value, functions, locals);
            CollectNestedBorrowedTextReturnOrigins(block.Value, functions, locals, union);
        }
        if (parentLocals is Dictionary<string, IReadOnlySet<string>> mutableParent)
            MergeBorrowOriginInferenceMutations(mutableParent, locals, block.Statements);
    }

    private bool TryMapBorrowedReturnOrigins(
        BoundFunction called,
        IReadOnlySet<string> returnOrigins,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        var parameters = FunctionParameters(called);
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var returnOrigin in returnOrigins)
        {
            var ordinal = parameters.FindIndex(parameter =>
                StringComparer.Ordinal.Equals(parameter, returnOrigin));
            if (ordinal < 0 || ordinal >= arguments.Count
                || !TryInferBorrowedTextOrigins(arguments[ordinal], functions, locals, out var argumentOrigins))
            {
                origins = EmptyBorrowOrigins();
                return false;
            }
            union.UnionWith(argumentOrigins);
        }
        origins = union;
        return union.Count > 0;
    }

    private static List<string> FunctionParameters(BoundFunction function)
    {
        var parameters = new List<string>();
        if (function.InputType is not null)
        {
            parameters.Add(function.InputName ?? "it");
        }
        parameters.AddRange((function.AdditionalParameters ?? []).Select(static parameter => parameter.Name));
        return parameters;
    }

    private bool TryGetBorrowedTextCallOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (expression is StringExpression text
            && _deferredTextOrigins.TryGetValue(text, out origins!))
        {
            return origins.Count > 0;
        }
        if (expression is NameExpression name
            && _activeBorrowedTextOrigins.TryGetValue(name.Name, out origins!))
        {
            return true;
        }

        if (expression is StructLiteralExpression structure)
        {
            return TryUnionCallSiteBorrowedOrigins(
                structure.Fields.Select(static field => field.Value),
                functions,
                bindings,
                out origins);
        }
        if (expression is ProductExpression product)
        {
            return TryUnionCallSiteBorrowedOrigins(
                product.Elements.Select(static element => element.Value),
                functions,
                bindings,
                out origins);
        }
        if (expression is BranchExpression branch)
        {
            return TryUnionCallSiteBorrowedOrigins(
                branch.Arms.Select(arm => (Expression)new FlowExpression(
                    branch.Source,
                    arm.Targets,
                    arm.Line,
                    arm.Column)),
                functions,
                bindings,
                out origins);
        }
        if (expression is TapExpression tap)
        {
            return TryGetBorrowedTextCallOrigins(tap.Source, functions, bindings, out origins);
        }
        if (expression is PartitionExpression partition)
        {
            return TryGetBorrowedTextCallOrigins(partition.Source, functions, bindings, out origins);
        }
        if (expression is StreamJoinExpression join)
        {
            return TryGetBorrowedTextCallOrigins(join.Source, functions, bindings, out origins);
        }

        if (expression is ArrayLiteralExpression array)
        {
            return TryUnionCallSiteBorrowedOrigins(array.Elements, functions, bindings, out origins);
        }

        if (expression is ArrayRepeatExpression repeat)
        {
            return TryGetBorrowedTextCallOrigins(repeat.Value, functions, bindings, out origins);
        }

        if (expression is DictionaryLiteralExpression dictionary)
        {
            return TryUnionCallSiteBorrowedOrigins(
                dictionary.Entries.SelectMany(static entry => new[] { entry.Key, entry.Value }),
                functions,
                bindings,
                out origins);
        }

        if (expression is FieldAccessExpression field)
        {
            return TryGetBorrowedTextCallOrigins(field.Source, functions, bindings, out origins);
        }

        if (expression is IndexExpression index)
        {
            return TryGetBorrowedTextCallOrigins(index.Source, functions, bindings, out origins);
        }

        if (expression is TryExpression attempted)
        {
            return TryGetBorrowedTextCallOrigins(attempted.Value, functions, bindings, out origins);
        }

        if (expression is BoxExpression boxed)
        {
            return TryGetBorrowedTextCallOrigins(boxed.Value, functions, bindings, out origins);
        }

        if (TryGetBorrowedTextEnumPayload(expression, out var enumPayload))
        {
            return TryGetBorrowedTextCallOrigins(
                enumPayload,
                functions,
                bindings,
                out origins);
        }

        if (expression is CallExpression call
            && TryGetBorrowedCallSiteFunction(call, call.Path, functions, out var called))
        {
            if (IsBorrowedStorageViewIntrinsic(called.Kind))
            {
                if (call.Arguments.Count > 0)
                {
                    return TryGetBorrowedSourceCallSiteOrigins(
                        call.Arguments[0], functions, bindings, out origins);
                }
                origins = EmptyBorrowOrigins();
                return false;
            }
            if (_borrowedTextReturnOrigins.TryGetValue(called, out var returnOrigins))
            {
                return TryMapCallSiteBorrowedOrigins(
                    called, returnOrigins, call.Arguments, functions, bindings, out origins);
            }
        }

        if (expression is FlowExpression flow)
        {
            if (flow.Targets.Count == 0)
                return TryGetBorrowedTextCallOrigins(flow.Source, functions, bindings, out origins);

            var target = flow.Targets[^1];
            var current = BorrowOriginFlowReceiver(flow);
            if (target.Path.Count == 1 && target.Path[0] == "materialize"
                && target.Arguments.Count == 1)
                return TryGetConcreteBorrowOrigins(target.Arguments[0], bindings, out origins);
            if (target.Path.Count == 1 && target.Path[0] == "slice")
                return TryGetBorrowedTextCallOrigins(current, functions, bindings, out origins)
                    || TryGetConcreteBorrowOrigins(current, bindings, out origins);
            if (TryGetBorrowedCallSiteFunction(target, target.Path, functions, out var targetFunction))
            {
                if (IsBorrowedStorageViewIntrinsic(targetFunction.Kind))
                    return TryGetBorrowedSourceCallSiteOrigins(current, functions, bindings, out origins);
                if (_borrowedTextReturnOrigins.TryGetValue(targetFunction, out var flowedReturnOrigins))
                {
                    var arguments = new Expression[] { current }.Concat(target.Arguments).ToArray();
                    return TryMapCallSiteBorrowedOrigins(
                        targetFunction, flowedReturnOrigins, arguments, functions, bindings, out origins);
                }
            }
        }

        if (expression is IfExpression conditional && conditional.Else is not null)
        {
            return TryUnionBlockCallSiteBorrowedOrigins(
                new[] { conditional.Then, conditional.Else },
                functions,
                bindings,
                out origins);
        }
        if (expression is WhenExpression when)
        {
            return TryUnionBlockCallSiteBorrowedOrigins(
                when.Arms.Select(static arm => arm.Body).Append(when.Else),
                functions,
                bindings,
                out origins);
        }
        if (expression is EnumMatchExpression match)
        {
            var blocks = match.Arms.Select(static arm => arm.Body);
            if (match.Else is not null)
            {
                blocks = blocks.Append(match.Else);
            }
            return TryUnionBlockCallSiteBorrowedOrigins(
                blocks,
                functions,
                bindings,
                out origins);
        }

        origins = EmptyBorrowOrigins();
        return false;
    }

    private bool TryGetReadonlyReferenceCallOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (TryGetActiveReadonlyReferenceCarrierOrigins(expression, out origins))
        {
            return true;
        }

        if (expression is StructLiteralExpression structure)
        {
            return TryUnionReadonlyReferenceCallOrigins(
                structure.Fields.Select(static field => field.Value),
                functions,
                bindings,
                out origins);
        }
        if (expression is ProductExpression product)
        {
            return TryUnionReadonlyReferenceCallOrigins(
                product.Elements.Select(static element => element.Value),
                functions,
                bindings,
                out origins);
        }
        if (expression is BranchExpression branch)
        {
            return TryUnionReadonlyReferenceCallOrigins(
                branch.Arms.Select(arm => (Expression)new FlowExpression(
                    branch.Source,
                    arm.Targets,
                    arm.Line,
                    arm.Column)),
                functions,
                bindings,
                out origins);
        }
        if (expression is TapExpression tap)
        {
            return TryGetReadonlyReferenceCallOrigins(tap.Source, functions, bindings, out origins);
        }
        if (expression is PartitionExpression partition)
        {
            return TryGetReadonlyReferenceCallOrigins(partition.Source, functions, bindings, out origins);
        }
        if (expression is StreamJoinExpression join)
        {
            return TryGetReadonlyReferenceCallOrigins(join.Source, functions, bindings, out origins);
        }

        if (expression is ArrayLiteralExpression array)
        {
            return TryUnionReadonlyReferenceCallOrigins(
                array.Elements,
                functions,
                bindings,
                out origins);
        }

        if (expression is DictionaryLiteralExpression dictionary)
        {
            return TryUnionReadonlyReferenceCallOrigins(
                dictionary.Entries.SelectMany(static entry => new[] { entry.Key, entry.Value }),
                functions,
                bindings,
                out origins);
        }

        if (expression is CallExpression enumConstructor
            && TryGetBorrowCarrierEnumConstructor(
                enumConstructor,
                out _,
                out var enumVariant,
                out var enumPayload)
            && enumVariant.PayloadType is { } enumPayloadType
            && TypeContainsReadonlyReference(enumPayloadType))
        {
            return TryGetReadonlyReferenceCallOrigins(
                enumPayload,
                functions,
                bindings,
                out origins);
        }

        if (expression is CallExpression call
            && TryGetFunction(call.Path, functions, out var called)
            && TypeContainsReadonlyReference(called.ReturnType))
        {
            return TryMapReadonlyReferenceCallOrigins(
                called,
                call.Arguments,
                functions,
                bindings,
                out origins);
        }

        if (expression is FlowExpression flow
            && flow.Targets.Count > 0)
        {
            var target = flow.Targets[^1];
            if (TryGetFunction(target.Path, functions, out var flowed)
                && TypeContainsReadonlyReference(flowed.ReturnType))
            {
                var arguments = new Expression[] { BorrowOriginFlowReceiver(flow) }
                    .Concat(target.Arguments)
                    .ToArray();
                return TryMapReadonlyReferenceCallOrigins(
                    flowed,
                    arguments,
                    functions,
                    bindings,
                    out origins);
            }
        }

        origins = EmptyBorrowOrigins();
        return false;
    }

    private bool TryGetActiveReadonlyReferenceCarrierOrigins(
        Expression expression,
        out IReadOnlySet<string> origins)
    {
        if (!TryGetBorrowPlace(expression, out var place))
        {
            origins = EmptyBorrowOrigins();
            return false;
        }

        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var carrier in _activeReadonlyReferenceBindings)
        {
            if ((StringComparer.Ordinal.Equals(carrier, place)
                    || carrier.StartsWith(place + ".", StringComparison.Ordinal)
                    || carrier.StartsWith(place + "[", StringComparison.Ordinal))
                && _activeBorrowedTextOrigins.TryGetValue(carrier, out var carrierOrigins))
            {
                union.UnionWith(carrierOrigins);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private IReadOnlyDictionary<string, IReadOnlySet<string>> GetReadonlyReferenceCarrierOrigins(
        Expression expression,
        BoundType type,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        var result = new Dictionary<string, IReadOnlySet<string>>(StringComparer.Ordinal);
        Collect(expression, type, "");
        return result;

        void Collect(Expression value, BoundType valueType, string path)
        {
            if (_types.IsReference(valueType))
            {
                if (TryGetReadonlyReferenceCallOrigins(value, functions, bindings, out var origins))
                {
                    result[path] = origins;
                }
                return;
            }

            if (_types.IsStruct(valueType))
            {
                IReadOnlyDictionary<string, Expression>? initializers = value switch
                {
                    StructLiteralExpression structure => structure.Fields.ToDictionary(
                        static field => field.Name,
                        static field => field.Value,
                        StringComparer.Ordinal),
                    ProductExpression product => product.Elements
                        .Select((element, index) => (Name: element.Label ?? $"_{index}", element.Value))
                        .ToDictionary(
                            static element => element.Name,
                            static element => element.Value,
                            StringComparer.Ordinal),
                    _ => null
                };
                if (initializers is not null)
                {
                    foreach (var field in _types.GetStruct(valueType).Fields)
                    {
                        if (TypeContainsReadonlyReference(field.Type)
                            && initializers.TryGetValue(field.Name, out var initializer))
                        {
                            Collect(initializer, field.Type, path + "." + field.Name);
                        }
                    }
                    return;
                }
            }

            if (_types.IsEnum(valueType)
                && value is CallExpression enumConstructor
                && TryGetBorrowCarrierEnumConstructor(
                    enumConstructor,
                    out var enumType,
                    out var enumVariant,
                    out var enumPayload)
                && enumType == valueType
                && enumVariant.PayloadType is { } enumPayloadType
                && TypeContainsReadonlyReference(enumPayloadType))
            {
                Collect(
                    enumPayload,
                    enumPayloadType,
                    path + "[" + enumVariant.Name + "]");
                return;
            }

            if (value is NameExpression name)
            {
                var prefix = CanonicalBorrowOriginName(name.Name);
                foreach (var carrier in _activeReadonlyReferenceBindings)
                {
                    if (!carrier.StartsWith(prefix + ".", StringComparison.Ordinal)
                        && !carrier.StartsWith(prefix + "[", StringComparison.Ordinal))
                    {
                        continue;
                    }
                    if (_activeBorrowedTextOrigins.TryGetValue(carrier, out var origins))
                    {
                        result[path + carrier[prefix.Length..]] = origins;
                    }
                }
                if (result.Count > 0)
                {
                    return;
                }
            }

            if (!TryGetReadonlyReferenceCallOrigins(value, functions, bindings, out var aggregateOrigins))
            {
                return;
            }
            foreach (var leaf in ReadonlyReferenceLeafPaths(valueType))
            {
                result[path + leaf] = aggregateOrigins;
            }
        }
    }

    private bool TryGetBorrowedTextEnumPayload(Expression expression, out Expression payload)
    {
        payload = null!;
        return expression is CallExpression enumConstructor
            && TryGetBorrowCarrierEnumConstructor(
                enumConstructor,
                out _,
                out var variant,
                out payload)
            && variant.PayloadType is { } payloadType
            && TypeCanCarryBorrowedTextOrigin(payloadType);
    }

    private bool TryGetBorrowCarrierEnumConstructor(
        CallExpression expression,
        out BoundType enumType,
        out BoundEnumVariant variant,
        out Expression payload)
    {
        enumType = default;
        variant = null!;
        payload = null!;
        if (expression.Path.Count < 2 || expression.Arguments.Count != 1)
        {
            return false;
        }

        var typeName = string.Join('.', expression.Path.Take(expression.Path.Count - 1));
        if (!_types.TryResolve(typeName, out enumType))
        {
            if (!typeName.StartsWith("Option<", StringComparison.Ordinal)
                && !typeName.StartsWith("Result<", StringComparison.Ordinal))
            {
                return false;
            }
            enumType = ParseType(typeName, expression.Line, expression.Column);
        }
        if (!_types.IsEnum(enumType))
        {
            return false;
        }

        variant = _types.GetEnum(enumType).Variants.FirstOrDefault(candidate =>
            StringComparer.Ordinal.Equals(candidate.Name, expression.Path[^1]))!;
        if (variant?.PayloadType is null)
        {
            return false;
        }
        payload = expression.Arguments[0];
        return true;
    }

    private IReadOnlyList<string> InstallReadonlyReferenceEnumPatternOrigins(
        Expression subject,
        BoundEnumVariant variant,
        string bindingName)
    {
        if (!TryGetBorrowPlace(subject, out var subjectPlace))
        {
            return [];
        }

        var variantPlace = subjectPlace + "[" + variant.Name + "]";
        var installed = new List<string>();
        foreach (var carrier in _activeReadonlyReferenceBindings.ToArray())
        {
            if (!TryGetBorrowPlaceRelativeSuffix(variantPlace, carrier, out var suffix))
            {
                continue;
            }
            if (!_activeBorrowedTextOrigins.TryGetValue(carrier, out var origins))
            {
                continue;
            }

            var projected = bindingName + suffix;
            _activeBorrowedTextOrigins[projected] = origins;
            _activeReadonlyReferenceBindings.Add(projected);
            installed.Add(projected);
        }
        return installed;
    }

    private void RemoveReadonlyReferencePatternOrigins(IEnumerable<string> bindings)
    {
        foreach (var binding in bindings)
        {
            _activeBorrowedTextOrigins.Remove(binding);
            _activeReadonlyReferenceBindings.Remove(binding);
        }
    }

    private IEnumerable<string> ReadonlyReferenceLeafPaths(BoundType type)
    {
        if (_types.IsReference(type))
        {
            yield return "";
            yield break;
        }
        if (_types.IsStruct(type))
        {
            foreach (var field in _types.GetStruct(type).Fields)
            {
                foreach (var nested in ReadonlyReferenceLeafPaths(field.Type))
                {
                    yield return "." + field.Name + nested;
                }
            }
            yield break;
        }
        if (_types.IsEnum(type))
        {
            foreach (var variant in _types.GetEnum(type).Variants)
            {
                if (variant.PayloadType is not { } payload)
                {
                    continue;
                }
                foreach (var nested in ReadonlyReferenceLeafPaths(payload))
                {
                    yield return "[" + variant.Name + "]" + nested;
                }
            }
            yield break;
        }
        if (_types.IsStaticArray(type))
        {
            foreach (var nested in ReadonlyReferenceLeafPaths(_types.GetStaticArray(type).ElementType))
            {
                yield return "[*]" + nested;
            }
            yield break;
        }
        if (_types.IsDynamicArray(type))
        {
            foreach (var nested in ReadonlyReferenceLeafPaths(_types.GetDynamicArray(type).ElementType))
            {
                yield return "[*]" + nested;
            }
            yield break;
        }
        if (_types.IsDictionary(type))
        {
            // Dictionary keys are lookup-only values in the safe surface. A
            // value reference is tied to the Swiss-table entry and therefore
            // uses a wildcard slot: probing and rehashing can move it.
            foreach (var nested in ReadonlyReferenceLeafPaths(_types.GetDictionary(type).ValueType))
            {
                yield return "[*]" + nested;
            }
        }
    }

    private static bool TryGetBorrowPlace(Expression expression, out string place)
    {
        switch (expression)
        {
            case NameExpression name:
                place = CanonicalBorrowOriginName(name.Name);
                return true;
            case FieldAccessExpression field when TryGetBorrowPlace(field.Source, out var source):
                place = source + "." + field.FieldName;
                return true;
            case IndexExpression index when TryGetBorrowPlace(index.Source, out var source):
                place = source + BorrowOriginIndexProjection(index.Index);
                return true;
            default:
                place = "";
                return false;
        }
    }

    private static bool TryGetBorrowPlaceRelativeSuffix(
        string prefix,
        string candidate,
        out string suffix)
    {
        var prefixParts = SplitBorrowPlace(prefix);
        var candidateParts = SplitBorrowPlace(candidate);
        if (candidateParts.Count < prefixParts.Count
            || !StringComparer.Ordinal.Equals(candidateParts[0], prefixParts[0]))
        {
            suffix = "";
            return false;
        }

        for (var index = 1; index < prefixParts.Count; index++)
        {
            var expected = prefixParts[index];
            var actual = candidateParts[index];
            if (StringComparer.Ordinal.Equals(expected, actual))
            {
                continue;
            }
            if (expected.Length > 1 && actual.Length > 1
                && expected[0] == '[' && actual[0] == '['
                && (expected == "[*]" || actual == "[*]"))
            {
                continue;
            }

            suffix = "";
            return false;
        }

        suffix = string.Concat(candidateParts.Skip(prefixParts.Count));
        return true;
    }

    private bool TryUnionReadonlyReferenceCallOrigins(
        IEnumerable<Expression> expressions,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var expression in expressions)
        {
            if (TryGetReadonlyReferenceCallOrigins(expression, functions, bindings, out var nested))
            {
                union.UnionWith(nested);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private bool TypeContainsReadonlyReference(BoundType type) =>
        TypeContainsReadonlyReference(type, new HashSet<BoundType>());

    private bool TypeContainsReadonlyReference(BoundType type, HashSet<BoundType> visiting)
    {
        if (_types.IsReference(type))
        {
            return true;
        }
        if (!visiting.Add(type))
        {
            return false;
        }
        try
        {
            if (_types.IsStruct(type))
            {
                return _types.GetStruct(type).Fields.Any(field =>
                    TypeContainsReadonlyReference(field.Type, visiting));
            }
            if (_types.IsEnum(type))
            {
                return _types.GetEnum(type).Variants.Any(variant =>
                    variant.PayloadType is { } payload
                    && TypeContainsReadonlyReference(payload, visiting));
            }
            if (_types.IsStaticArray(type))
            {
                return TypeContainsReadonlyReference(
                    _types.GetStaticArray(type).ElementType,
                    visiting);
            }
            if (_types.IsDynamicArray(type))
            {
                return TypeContainsReadonlyReference(
                    _types.GetDynamicArray(type).ElementType,
                    visiting);
            }
            if (_types.IsDictionary(type))
            {
                var dictionary = _types.GetDictionary(type);
                return TypeContainsReadonlyReference(dictionary.KeyType, visiting)
                    || TypeContainsReadonlyReference(dictionary.ValueType, visiting);
            }
            if (_types.IsBox(type))
            {
                return TypeContainsReadonlyReference(_types.GetBox(type).ElementType, visiting);
            }
            return false;
        }
        finally
        {
            visiting.Remove(type);
        }
    }

    private bool TryMapReadonlyReferenceCallOrigins(
        BoundFunction called,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (!_readonlyReferenceReturnOrigins.TryGetValue(called, out var returnOrigins))
        {
            origins = EmptyBorrowOrigins();
            return false;
        }

        var parameters = FunctionParameters(called);
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var returnOrigin in returnOrigins)
        {
            var index = parameters.FindIndex(parameter =>
                StringComparer.Ordinal.Equals(parameter, returnOrigin));
            if (index < 0 || index >= arguments.Count)
            {
                continue;
            }

            if (TryGetReadonlyReferenceCallOrigins(
                    arguments[index],
                    functions,
                    bindings,
                    out var propagated))
            {
                union.UnionWith(propagated);
            }
            else if (TryGetConcreteBorrowOrigins(arguments[index], bindings, out var concrete))
            {
                union.UnionWith(concrete);
            }
        }

        origins = union;
        return union.Count > 0;
    }

    private bool TryUnionCallSiteBorrowedOrigins(
        IEnumerable<Expression> expressions,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var expression in expressions)
        {
            if (TryGetBorrowedTextCallOrigins(expression, functions, bindings, out var nested))
            {
                union.UnionWith(nested);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private bool TryMapCallSiteBorrowedOrigins(
        BoundFunction called,
        IReadOnlySet<string> returnOrigins,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        var parameters = FunctionParameters(called);
        var parameterTypes = FunctionParameterTypes(called);
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var returnOrigin in returnOrigins)
        {
            var ordinal = parameters.FindIndex(parameter =>
                StringComparer.Ordinal.Equals(parameter, returnOrigin));
            if (ordinal < 0 || ordinal >= arguments.Count || ordinal >= parameterTypes.Count)
            {
                origins = EmptyBorrowOrigins();
                return false;
            }

            // A moved owner carried into the result is not a loan from the caller frame.
            // Existing upstream Text loans still propagate through the ordinary branch.
            var ownership = called.InputType is not null && ordinal == 0
                ? called.InputOwnership
                : (called.AdditionalParameters ?? [])[ordinal - (called.InputType is null ? 0 : 1)].Ownership;
            if (parameterTypes[ordinal] is BoundType.SourceText or BoundType.Arena
                || (IsBorrowedTextByteStorage(parameterTypes[ordinal])
                    && (parameterTypes[ordinal] == TypeId.DynamicUInt8Array
                        || ownership != BoundFunctionInputOwnership.Move)
                    && !ReturnsTransferredBorrowedTextOwner(called, ordinal, functions)))
            {
                if (!TryGetBorrowedSourceCallSiteOrigins(
                        arguments[ordinal], functions, bindings, out var sourceOrigins))
                {
                    origins = EmptyBorrowOrigins();
                    return false;
                }
                union.UnionWith(sourceOrigins);
            }
            else if (TryGetBorrowedTextCallOrigins(
                         arguments[ordinal],
                         functions,
                         bindings,
                         out var propagatedOrigins))
            {
                union.UnionWith(propagatedOrigins);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private bool ReturnsTransferredBorrowedTextOwner(
        BoundFunction function, int ordinal, IReadOnlyDictionary<string, BoundFunction> functions) =>
        ReturnsTransferredBorrowedTextOwner(function, ordinal, functions,
            new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance));

    private bool ReturnsTransferredBorrowedTextOwner(
        BoundFunction function, int ordinal, IReadOnlyDictionary<string, BoundFunction> functions,
        HashSet<BoundFunction> visited)
    {
        if (!visited.Add(function))
            return false;
        var parameters = FunctionParameters(function);
        var parameterTypes = FunctionParameterTypes(function);
        if (ordinal < 0 || ordinal >= parameters.Count || ordinal >= parameterTypes.Count
            || function.Body is null || FunctionControlFlowFacts.HasEarlyReturn(function)
            || function.LocalFunctions.Count > 0 || function.GenericParameterName is not null
            || function.GenericParameters?.Count > 0)
            return false;
        var ownership = function.InputType is not null && ordinal == 0
            ? function.InputOwnership
            : (function.AdditionalParameters ?? [])[ordinal - (function.InputType is null ? 0 : 1)].Ownership;
        if (ownership != BoundFunctionInputOwnership.Move
            || !_types.ContainsOwnedStorage(parameterTypes[ordinal]))
            return false;

        var parameterName = parameters[ordinal];
        // A later binding with the same spelling is not proof of transferring the formal.
        if (function.BlockBody.Any(statement => statement switch
            {
                BindingStatement binding => StringComparer.Ordinal.Equals(binding.Name, parameterName),
                BlockFunctionCallStatement block => StringComparer.Ordinal.Equals(block.ResultName, parameterName),
                BlockFunctionPipelineStatement pipeline => pipeline.Calls.Any(block =>
                    StringComparer.Ordinal.Equals(block.ResultName, parameterName)),
                _ => false
            }))
            return false;

        // Compose only an exact final whole-owner forwarding call. The ordinary
        // origin mapper still propagates upstream loans and other arguments.
        var proofLocals = new BorrowOriginInferenceLocals(function, []);
        Expression? forwardingReceiver = null;
        object? callSite = null;
        IReadOnlyList<string>? callPath = null;
        IReadOnlyList<Expression>? callArguments = null;
        if (function.Body is CallExpression directCall)
        {
            callSite = directCall;
            callPath = directCall.Path;
            callArguments = directCall.Arguments;
        }
        else if (function.Body is FlowExpression { Targets.Count: 1 } forwarding)
        {
            forwardingReceiver = forwarding.Source;
            callSite = forwarding.Targets[0];
            callPath = forwarding.Targets[0].Path;
            callArguments = new Expression[] { forwarding.Source }
                .Concat(forwarding.Targets[0].Arguments).ToArray();
        }
        if (callSite is not null && callPath is not null && callArguments is not null
            && !function.BlockBody.Any(statement => ReferencesBorrowCarrier(statement, parameterName)))
        {
            var previousForwardModule = _currentModuleName;
            _currentModuleName = function.ModuleName;
            try
            {
                if ((forwardingReceiver is null
                        || TryGetBorrowOriginInferenceType(forwardingReceiver, functions, proofLocals, out _))
                    && !(forwardingReceiver is null && callPath.Count == 2
                        && proofLocals.Types.ContainsKey(callPath[0]))
                    && TryGetBorrowOriginInferenceFunction(callSite, callPath, forwardingReceiver,
                        functions, proofLocals, out var callee)
                    && callee.ReturnType == function.ReturnType)
                {
                    var calleeTypes = FunctionParameterTypes(callee);
                    var matchingArguments = callArguments.Select((argument, index) => (argument, index))
                        .Where(item => ReferencesBorrowCarrier(item.argument, parameterName)).ToArray();
                    if (matchingArguments.Length == 1
                        && matchingArguments[0] is { argument: NameExpression argument, index: var calleeOrdinal }
                        && argument.Name == parameterName && calleeOrdinal < calleeTypes.Count
                        && calleeTypes[calleeOrdinal] == parameterTypes[ordinal]
                        && ReturnsTransferredBorrowedTextOwner(callee, calleeOrdinal, functions, visited))
                        return true;
                }
            }
            finally { _currentModuleName = previousForwardModule; }
        }

        var formalBindings = new Dictionary<string, BoundType>(StringComparer.Ordinal);
        for (var index = 0; index < parameters.Count && index < parameterTypes.Count; index++)
            formalBindings[parameters[index]] = parameterTypes[index];
        var transfers = new List<OwnedLiteralTransfer>();
        CollectOwnedLiteralSourceNames(function.Body, function.ReturnType, formalBindings, transfers);
        if (transfers.Any(transfer => transfer.FieldPath.Count == 0
            && StringComparer.Ordinal.Equals(transfer.OwnerName, parameterName)))
            return true;
        if (function.Body is not NameExpression finalOwner)
            return false;
        var ownerBindings = function.BlockBody.Select((statement, index) => (statement, index))
            .Where(item => item.statement is BindingStatement binding
                && StringComparer.Ordinal.Equals(binding.Name, finalOwner.Name)).ToArray();
        if (ownerBindings.Length != 1 || ownerBindings[0].statement is not BindingStatement ownerBinding)
            return false;
        transfers.Clear();
        CollectOwnedLiteralSourceNames(ownerBinding.Value, function.ReturnType, formalBindings, transfers);
        if (!transfers.Any(transfer => transfer.FieldPath.Count == 0
                && StringComparer.Ordinal.Equals(transfer.OwnerName, parameterName)))
            return false;
        // Record only direct destination slots proven by the authoritative transfer collector.
        var retainedFields = ownerBinding.Value switch
        {
            NameExpression name when name.Name == parameterName => new HashSet<string>([""], StringComparer.Ordinal),
            StructLiteralExpression literal when _types.IsStruct(function.ReturnType) =>
                literal.Fields.Where(initializer => initializer.Value is NameExpression name
                        && name.Name == parameterName
                        && _types.GetStruct(function.ReturnType).Fields.Any(field =>
                            field.Name == initializer.Name && field.Type == parameterTypes[ordinal]))
                    .Select(initializer => initializer.Name).ToHashSet(StringComparer.Ordinal),
            _ => new HashSet<string>(StringComparer.Ordinal)
        };
        if (retainedFields.Count == 0)
            return false;
        var previousModule = _currentModuleName;
        _currentModuleName = function.ModuleName;
        try
        {
            return function.BlockBody.Skip(ownerBindings[0].index + 1).All(statement =>
                PreservesTransferredOwner(statement, finalOwner.Name, retainedFields, function.ReturnType, functions));
        }
        finally { _currentModuleName = previousModule; }
    }

    private bool PreservesTransferredOwner(
        Statement statement, string owner, IReadOnlySet<string> fields, BoundType ownerType,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (statement is BindingStatement declaredBinding && declaredBinding.Name == owner
            || statement is BlockFunctionCallStatement declaredCall && (declaredCall.ItemName == owner || declaredCall.ResultName == owner
                || (declaredCall.AdditionalItemNames ?? []).Contains(owner, StringComparer.Ordinal))
            || statement is BlockFunctionPipelineStatement declaredPipeline && declaredPipeline.Calls.Any(call =>
                call.ItemName == owner || call.ResultName == owner
                || (call.AdditionalItemNames ?? []).Contains(owner, StringComparer.Ordinal)))
            return false;
        if (statement is FieldAssignmentStatement assignment && assignment.Name == owner)
            return !fields.Contains("") && !fields.Contains(assignment.FieldName)
                && _types.IsStruct(ownerType)
                && _types.GetStruct(ownerType).Fields.Any(field => field.Name == assignment.FieldName)
                && PreservesTransferredOwnerRead(assignment.Value, owner, ownerType, functions);
        if (!ReferencesBorrowCarrier(statement, owner))
            return true;
        return statement switch
        {
            BindingStatement binding => PreservesTransferredOwnerRead(binding.Value, owner, ownerType, functions),
            ExpressionStatement expression => PreservesTransferredOwnerRead(expression.Expression, owner, ownerType, functions),
            BlockFunctionCallStatement block => block.ItemName != owner && block.ResultName != owner
                && !ReferencesBorrowCarrier(block.Source, owner)
                && !(block.Arguments ?? []).Any(argument => ReferencesBorrowCarrier(argument, owner))
                && block.Body.All(child => PreservesTransferredOwner(child, owner, fields, ownerType, functions)),
            BlockFunctionPipelineStatement pipeline => pipeline.Calls.All(block =>
                PreservesTransferredOwner(block, owner, fields, ownerType, functions)),
            _ => false
        };
    }

    private bool PreservesTransferredOwnerRead(
        Expression expression, string owner, BoundType ownerType,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (!ReferencesBorrowCarrier(expression, owner))
            return true;
        bool BlockPreserves(BlockBody block) => block.Statements.All(statement =>
                PreservesTransferredOwner(statement, owner, new HashSet<string>([""], StringComparer.Ordinal), ownerType, functions))
            && (block.Value is null || PreservesTransferredOwnerRead(block.Value, owner, ownerType, functions));
        bool CallPreserves(object site, IReadOnlyList<string> path, IReadOnlyList<Expression> arguments)
        {
            if (!TryGetBorrowedCallSiteFunction(site, path, functions, out var called)
                || called.GenericParameterName is not null || called.GenericParameters?.Count > 0)
                return false;
            var types = FunctionParameterTypes(called);
            for (var index = 0; index < arguments.Count; index++)
            {
                var argument = arguments[index];
                if (!ReferencesBorrowCarrier(argument, owner)) continue;
                if (index >= types.Count) return false;
                var ownership = called.InputType is not null && index == 0
                    ? called.InputOwnership
                    : (called.AdditionalParameters ?? [])[index - (called.InputType is null ? 0 : 1)].Ownership;
                if (index >= types.Count || argument is not NameExpression name || name.Name != owner
                    || ownership != BoundFunctionInputOwnership.Default || !_types.IsReference(types[index])
                    || _types.GetReference(types[index]).ElementType != ownerType)
                    return false;
            }
            return true;
        }
        return expression switch
        {
            CallExpression call => CallPreserves(call, call.Path, call.Arguments),
            FlowExpression flow when flow.Targets.Count == 1 => CallPreserves(flow.Targets[0],
                flow.Targets[0].Path, new Expression[] { flow.Source }.Concat(flow.Targets[0].Arguments).ToArray()),
            AndExpression logical => PreservesTransferredOwnerRead(logical.Left, owner, ownerType, functions)
                && PreservesTransferredOwnerRead(logical.Right, owner, ownerType, functions),
            IfExpression conditional => PreservesTransferredOwnerRead(conditional.Condition, owner, ownerType, functions)
                && BlockPreserves(conditional.Then) && (conditional.Else is null || BlockPreserves(conditional.Else)),
            _ => false
        };
    }

    private bool TryUnionBlockCallSiteBorrowedOrigins(
        IEnumerable<BlockBody> blocks,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var block in blocks)
        {
            if (block.Value is not null
                && TryGetBorrowedTextCallOrigins(block.Value, functions, bindings, out var nested))
            {
                union.UnionWith(nested);
            }
        }
        origins = union;
        return union.Count > 0;
    }

    private bool TryGetEachItemBorrowedTextOrigins(
        Expression source,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        // The item carries the source's payload loan, including a known-empty
        // loan for static Text. Only an untracked source needs concrete-place
        // recovery; the callback's local item name is never a new owner.
        return TryGetBorrowedTextCallOrigins(source, functions, bindings, out origins)
            || TryGetBorrowedSourceCallSiteOrigins(source, functions, bindings, out origins);
    }

    private bool TryGetBorrowedSourceCallSiteOrigins(
        Expression source,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (source is IndexExpression { Source: NameExpression carrier }
            && bindings.TryGetValue(carrier.Name, out var carrierType))
        {
            // Name reads a reference once. The selected Text payload borrows its
            // backing bytes, not the array/Arguments descriptor storing the span.
            if (_types.IsReference(carrierType))
                carrierType = _types.GetReference(carrierType).ElementType;
            if (carrierType == BoundType.Arguments)
            {
                // Arguments is a process-lifetime view; only the runtime owns
                // its UTF-8 bytes, so the local count descriptor is not an origin.
                origins = EmptyBorrowOrigins();
                return true;
            }
            if (TryGetContextualArrayElementType(carrierType, out var elementType)
                && elementType == BoundType.Text
                && _activeBorrowedTextOrigins.TryGetValue(carrier.Name, out origins!))
                return true;
        }

        if (TryGetConcreteBorrowOrigins(source, bindings, out origins))
        {
            return true;
        }
        return TryGetBorrowedTextCallOrigins(source, functions, bindings, out origins);
    }

    private bool TryGetBorrowedCallSiteFunction(
        object callSite,
        IReadOnlyList<string> path,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out BoundFunction function)
    {
        return _resolvedGenericCalls.TryGetValue(callSite, out function!)
            || TryGetFunction(path, functions, out function);
    }

    private void RejectLocalBorrowedTextReturnEscape(
        Expression value,
        BoundType returnType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlyDictionary<string, BoundType> returnOuterBindings)
    {
        if (!TypeCanCarryBorrowedTextOrigin(returnType)
            || !TryGetBorrowedTextCallOrigins(value, functions, bindings, out var origins))
        {
            return;
        }

        foreach (var origin in origins)
        {
            var root = SplitBorrowPlace(origin)[0];
            if (returnOuterBindings.TryGetValue(root, out var outerType)
                && (!(_currentMoveInputNames.Contains(root) && _types.ContainsOwnedStorage(outerType))
                    || TextPayloadSurvivesMovedOwner(origin, outerType)))
            {
                continue;
            }
            throw Error(
                value.Line,
                value.Column,
                $"borrowed origin '{origin}' cannot escape function '{_currentFunctionName}' through its return value");
        }
    }

    private bool TextPayloadSurvivesMovedOwner(string origin, BoundType ownerType)
    {
        var type = ownerType;
        foreach (var projection in SplitBorrowPlace(origin).Skip(1))
        {
            if (_types.IsReference(type))
                type = _types.GetReference(type).ElementType;
            if (projection.StartsWith('.') && _types.IsStruct(type))
            {
                var field = _types.GetStruct(type).Fields.FirstOrDefault(field =>
                    StringComparer.Ordinal.Equals(field.Name, projection[1..]));
                if (field is null) return false;
                type = field.Type;
            }
            else if (projection.StartsWith('[') && TryGetContextualArrayElementType(type, out var element))
                type = element;
            else if (projection.StartsWith('[') && _types.IsDictionary(type))
                type = _types.IsBoundedDictionary(type)
                    ? _types.GetBoundedDictionary(type).ValueType
                    : _types.GetDictionary(type).ValueType;
            else if (projection.StartsWith('[') && _types.IsEnum(type))
            {
                var variant = _types.GetEnum(type).Variants.FirstOrDefault(variant =>
                    StringComparer.Ordinal.Equals(variant.Name, projection[1..^1]));
                if (variant?.PayloadType is not { } payload) return false;
                type = payload;
            }
            else
                return false;
        }
        // Text elements store spans, not their backing bytes. Moving/dropping
        // their carrier must retain the caller's upstream payload loan instead
        // of turning the carrier's descriptor allocation into the byte owner.
        return TypeContains(type, BoundType.Text)
            && HasOnlyExternalTextPayloads(type, []);
    }

    private bool HasOnlyExternalTextPayloads(BoundType type, HashSet<BoundType> visiting)
    {
        if (type == BoundType.Text || _types.IsReference(type)) return true;
        if (type is BoundType.SourceText or BoundType.Arena or BoundType.MappedBytes or BoundType.MutableMappedBytes)
            return false;
        if (!visiting.Add(type)) return true;
        try
        {
            if (TryGetContextualArrayElementType(type, out var element))
                return element != BoundType.UInt8 && HasOnlyExternalTextPayloads(element, visiting);
            if (_types.IsDictionary(type))
            {
                var (key, value) = _types.IsBoundedDictionary(type)
                    ? (_types.GetBoundedDictionary(type).KeyType, _types.GetBoundedDictionary(type).ValueType)
                    : (_types.GetDictionary(type).KeyType, _types.GetDictionary(type).ValueType);
                return HasOnlyExternalTextPayloads(key, visiting)
                    && HasOnlyExternalTextPayloads(value, visiting);
            }
            if (_types.IsBox(type))
                return HasOnlyExternalTextPayloads(_types.GetBox(type).ElementType, visiting);
            if (_types.IsStruct(type))
            {
                var structure = _types.GetStruct(type);
                return structure.NativeHandle is null && structure.ComInterface is null
                    && structure.Fields.All(field => HasOnlyExternalTextPayloads(field.Type, visiting));
            }
            if (_types.IsEnum(type))
                return _types.GetEnum(type).Variants.All(variant =>
                    variant.PayloadType is not { } payload || HasOnlyExternalTextPayloads(payload, visiting));
            return !_types.ContainsOwnedStorage(type);
        }
        finally { visiting.Remove(type); }
    }

    private static List<BoundType> FunctionParameterTypes(BoundFunction function)
    {
        var parameters = new List<BoundType>();
        if (function.InputType is { } inputType)
        {
            parameters.Add(inputType);
        }
        parameters.AddRange((function.AdditionalParameters ?? []).Select(static parameter => parameter.Type));
        return parameters;
    }

    private bool TryGetConcreteBorrowOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        return TryGetConcreteBorrowOrigins(expression, bindings, out origins, out _);
    }

    private bool TryGetConcreteBorrowOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins,
        out bool isOwnedPlace)
    {
        if (expression is NameExpression name)
        {
            if (_activeBorrowedTextOrigins.TryGetValue(name.Name, out origins!))
            {
                if (origins.Count == 0
                    && bindings.TryGetValue(name.Name, out var bindingType)
                    && (TypeContains(bindingType, BoundType.SourceText)
                        || _types.ContainsOwnedStorage(bindingType)))
                {
                    // A known-empty loan does not erase an owned storage place.
                    // Borrowed views of that owner still depend on its lifetime;
                    // an actual nonempty upstream loan remains authoritative.
                    origins = new HashSet<string>(
                        [CanonicalBorrowOriginName(name.Name)],
                        StringComparer.Ordinal);
                    isOwnedPlace = true;
                    return true;
                }
                isOwnedPlace = false;
                return true;
            }
            if (bindings.ContainsKey(name.Name))
            {
                origins = new HashSet<string>(
                    [CanonicalBorrowOriginName(name.Name)],
                    StringComparer.Ordinal);
                isOwnedPlace = true;
                return true;
            }
        }

        if (expression is FieldAccessExpression field
            && TryGetConcreteBorrowOrigins(field.Source, bindings, out var fieldOrigins, out isOwnedPlace))
        {
            // An aggregate's Text loans do not describe its separately owned
            // field storage. Borrow that exact place, retaining borrowed Text
            // and reference fields on their existing upstream-loan path.
            if (TryGetOwnedFieldBorrowPlace(field, bindings, out var ownedField))
            {
                origins = new HashSet<string>([ownedField], StringComparer.Ordinal);
                isOwnedPlace = true;
                return true;
            }
            origins = isOwnedPlace
                ? AppendBorrowProjection(fieldOrigins, $".{field.FieldName}")
                : fieldOrigins;
            return true;
        }

        if (expression is IndexExpression index
            && TryGetConcreteBorrowOrigins(index.Source, bindings, out var indexOrigins, out isOwnedPlace))
        {
            origins = isOwnedPlace
                ? AppendBorrowProjection(indexOrigins, BorrowOriginIndexProjection(index.Index))
                : indexOrigins;
            return true;
        }

        origins = EmptyBorrowOrigins();
        isOwnedPlace = false;
        return false;
    }

    private bool TryGetOwnedFieldBorrowPlace(
        FieldAccessExpression field,
        IReadOnlyDictionary<string, BoundType> bindings,
        out string place)
    {
        if (TryGetOwnedPlaceType(field, out var fieldType)
            && _types.ContainsOwnedStorage(fieldType)
            && !TypeCanCarryBorrowedTextOrigin(fieldType)
            && !TypeContainsReadonlyReference(fieldType)
            && TryGetBorrowPlace(field, out place))
        {
            return true;
        }
        place = string.Empty;
        return false;

        bool TryGetOwnedPlaceType(Expression value, out BoundType type)
        {
            if (value is NameExpression name
                && bindings.TryGetValue(name.Name, out type)
                && !_types.IsReference(type)
                && _types.ContainsOwnedStorage(type))
            {
                return true;
            }
            if (value is FieldAccessExpression selected
                && TryGetOwnedPlaceType(selected.Source, out var owner)
                && _types.IsStruct(owner))
            {
                var declaration = _types.GetStruct(owner).Fields.FirstOrDefault(candidate =>
                    StringComparer.Ordinal.Equals(candidate.Name, selected.FieldName));
                if (declaration is not null && !_types.IsReference(declaration.Type))
                {
                    type = declaration.Type;
                    return true;
                }
            }
            type = default;
            return false;
        }
    }

    private static IReadOnlySet<string> AppendBorrowProjection(
        IReadOnlySet<string> origins,
        string projection) => origins
        .Select(origin => origin + projection)
        .ToHashSet(StringComparer.Ordinal);

    private void RejectBorrowedTextOriginInvalidation(
        string? first,
        string? second,
        IReadOnlyList<string> consumed,
        IReadOnlyList<string> transferred,
        string? rebound,
        bool isRebind,
        int line,
        int column)
    {
        if (first is not null)
        {
            RejectBorrowedTextOriginMutation(first, line, column);
        }
        if (second is not null)
        {
            RejectBorrowedTextOriginMutation(second, line, column);
        }
        foreach (var name in consumed)
        {
            RejectBorrowedTextOriginMutation(name, line, column);
        }
        foreach (var name in transferred)
        {
            RejectBorrowedTextOriginMutation(name, line, column);
        }
        if (isRebind && rebound is not null)
        {
            RejectBorrowedTextOriginMutation(rebound, line, column);
        }
    }

    private void ExpireBorrowedTextOriginsBeforeStatement(
        IReadOnlyList<Statement> statements,
        int statementIndex,
        Expression? result,
        IReadOnlySet<string>? continuationNames,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        CaptureLoopBorrowExpiration(statements, statementIndex, result, continuationNames, bindings);
        foreach (var binding in _activeBorrowedTextOrigins.Keys.ToArray())
        {
            var isLive = continuationNames?.Contains(binding) == true;
            for (var index = statementIndex; index < statements.Count; index++)
            {
                if (ReferencesTrackedBorrow(statements[index], binding, bindings))
                {
                    isLive = true;
                    break;
                }
            }

            if (!isLive
                && result is not null
                && ReferencesTrackedBorrow(result, binding, bindings))
            {
                isLive = true;
            }

            if (!isLive)
            {
                _activeBorrowedTextOrigins.Remove(binding);
                _activeReadonlyReferenceBindings.Remove(binding);
            }
        }
    }

    private HashSet<string> BorrowedTextContinuationAfterStatement(
        IReadOnlyList<Statement> statements,
        int statementIndex,
        Expression? result,
        IReadOnlySet<string>? continuationNames,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        var live = continuationNames is null
            ? new HashSet<string>(StringComparer.Ordinal)
            : new HashSet<string>(continuationNames, StringComparer.Ordinal);
        // An untracked formal can acquire a carrier loan inside the next
        // region. Retain its actual future uses without asserting known-empty
        // provenance or changing the origin registry.
        var carriers = _activeBorrowedTextOrigins.Keys.Concat(bindings
            .Where(pair => TypeCanCarryBorrowedTextOrigin(pair.Value)
                || TypeContainsReadonlyReference(pair.Value))
            .Select(static pair => pair.Key)).Distinct(StringComparer.Ordinal);
        foreach (var binding in carriers)
        {
            for (var index = statementIndex + 1; index < statements.Count; index++)
            {
                if (ReferencesTrackedBorrow(statements[index], binding, bindings))
                {
                    live.Add(binding);
                    break;
                }
            }

            if (result is not null && ReferencesTrackedBorrow(result, binding, bindings))
            {
                live.Add(binding);
            }
        }
        return live;
    }

    private bool ReferencesTrackedBorrow(
        Statement statement,
        string binding,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (_activeReadonlyReferenceBindings.Contains(binding))
            return ReferencesBorrowCarrier(statement, binding);
        var carriers = BorrowedTextLivenessCarriers(binding, bindings);
        return carriers is null
            ? StoragePlacementAnalyzer.ReferencesName(statement, binding)
            : carriers.Any(carrier => ReferencesBorrowCarrier(statement, carrier));
    }

    private bool ReferencesTrackedBorrow(
        Expression expression,
        string binding,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (_activeReadonlyReferenceBindings.Contains(binding))
            return ReferencesBorrowCarrier(expression, binding);
        var carriers = BorrowedTextLivenessCarriers(binding, bindings);
        return carriers is null
            ? StoragePlacementAnalyzer.ReferencesName(expression, binding)
            : carriers.Any(carrier => ReferencesBorrowCarrier(expression, carrier));
    }

    private IReadOnlyList<string>? BorrowedTextLivenessCarriers(
        string binding,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (!bindings.TryGetValue(binding, out var type) || !_types.IsStruct(type))
            return null;
        var path = new HashSet<BoundType>();
        var carriers = Collect(type, CanonicalBorrowOriginName(binding)).ToArray();
        // Unknown shape must retain the aggregate loan, never erase it.
        return carriers.Length > 0 ? carriers : null;

        IEnumerable<string> Collect(BoundType current, string place)
        {
            if (!TypeCanCarryBorrowedTextOrigin(current) && !TypeContainsReadonlyReference(current))
                yield break;
            // Enum payloads, arrays, references and recursive shapes remain
            // conservative at their containing place; only structs split fields.
            if (!_types.IsStruct(current) || !path.Add(current))
            {
                yield return place;
                yield break;
            }
            foreach (var field in _types.GetStruct(current).Fields)
                foreach (var nested in Collect(field.Type, place + "." + field.Name))
                    yield return nested;
            path.Remove(current);
        }
    }

    private static bool ReferencesBorrowCarrier(Statement statement, string carrier) => statement switch
    {
        BindingStatement binding => ReferencesBorrowCarrier(binding.Value, carrier),
        IndexAssignmentStatement assignment =>
            BorrowPlacesConflict(BorrowOriginIndexedPlace(assignment.Name, assignment.Index), carrier)
            || ReferencesBorrowCarrier(assignment.Index, carrier)
            || ReferencesBorrowCarrier(assignment.Value, carrier),
        FieldAssignmentStatement assignment =>
            BorrowPlacesConflict(
                CanonicalBorrowOriginName(assignment.Name) + "." + assignment.FieldName,
                carrier)
            || ReferencesBorrowCarrier(assignment.Value, carrier),
        BlockFunctionCallStatement block => ReferencesBorrowCarrier(block.Source, carrier)
            || (block.Arguments ?? []).Any(argument => ReferencesBorrowCarrier(argument, carrier))
            || ReferencesBorrowCarrier(block.Body, carrier),
        BlockFunctionPipelineStatement pipeline => pipeline.Calls.Any(
            block => ReferencesBorrowCarrier(block.Source, carrier)
                || (block.Arguments ?? []).Any(argument => ReferencesBorrowCarrier(argument, carrier))
                || ReferencesBorrowCarrier(block.Body, carrier)),
        ExpressionStatement expression => ReferencesBorrowCarrier(expression.Expression, carrier),
        ReturnStatement { Value: { } value } => ReferencesBorrowCarrier(value, carrier),
        GuardLoopControlStatement guard => ReferencesBorrowCarrier(guard.Condition, carrier),
        _ => false
    };

    private static bool ReferencesBorrowCarrier(BlockBody body, string carrier) =>
        body.Statements.Any(statement => ReferencesBorrowCarrier(statement, carrier))
        || (body.Value is not null && ReferencesBorrowCarrier(body.Value, carrier));

    private static bool ReferencesBorrowCarrier(
        IReadOnlyList<Statement> statements,
        string carrier) => statements.Any(statement =>
            ReferencesBorrowCarrier(statement, carrier));

    private static bool ReferencesBorrowCarrier(Expression expression, string carrier)
    {
        if (expression is FieldAccessExpression field)
        {
            return (TryGetBorrowPlace(field, out var place) && BorrowPlacesConflict(place, carrier))
                || ReferencesBorrowProjectionEvaluation(field.Source, carrier);
        }
        if (expression is IndexExpression index)
        {
            return (TryGetBorrowPlace(index, out var place) && BorrowPlacesConflict(place, carrier))
                || ReferencesBorrowCarrier(index.Index, carrier)
                || ReferencesBorrowProjectionEvaluation(index.Source, carrier);
        }
        if (expression is NameExpression name)
        {
            return BorrowPlacesConflict(CanonicalBorrowOriginName(name.Name), carrier);
        }

        return expression switch
        {
            StringExpression text => text.Segments.OfType<InterpolationSegment>()
                .Any(segment => ReferencesBorrowCarrier(segment.Expression, carrier)),
            AddExpression add => ReferencesBorrowCarrier(add.Left, carrier)
                || ReferencesBorrowCarrier(add.Right, carrier),
            SubtractExpression subtract => ReferencesBorrowCarrier(subtract.Left, carrier)
                || ReferencesBorrowCarrier(subtract.Right, carrier),
            MultiplyExpression multiply => ReferencesBorrowCarrier(multiply.Left, carrier)
                || ReferencesBorrowCarrier(multiply.Right, carrier),
            DivideExpression divide => ReferencesBorrowCarrier(divide.Left, carrier)
                || ReferencesBorrowCarrier(divide.Right, carrier),
            ModuloExpression modulo => ReferencesBorrowCarrier(modulo.Left, carrier)
                || ReferencesBorrowCarrier(modulo.Right, carrier),
            NegateExpression negate => ReferencesBorrowCarrier(negate.Value, carrier),
            CompareExpression compare => ReferencesBorrowCarrier(compare.Left, carrier)
                || ReferencesBorrowCarrier(compare.Right, carrier),
            AndExpression and => ReferencesBorrowCarrier(and.Left, carrier)
                || ReferencesBorrowCarrier(and.Right, carrier),
            OrExpression or => ReferencesBorrowCarrier(or.Left, carrier)
                || ReferencesBorrowCarrier(or.Right, carrier),
            NotExpression not => ReferencesBorrowCarrier(not.Value, carrier),
            RangeExpression range => ReferencesBorrowCarrier(range.Start, carrier)
                || ReferencesBorrowCarrier(range.End, carrier),
            FoldExpression fold => ReferencesBorrowCarrier(fold.Source, carrier)
                || ReferencesBorrowCarrier(fold.Initial, carrier)
                || ReferencesBorrowCarrier(fold.Body, carrier),
            IfExpression conditional => ReferencesBorrowCarrier(conditional.Condition, carrier)
                || ReferencesBorrowCarrier(conditional.Then, carrier)
                || (conditional.Else is not null
                    && ReferencesBorrowCarrier(conditional.Else, carrier)),
            WhenExpression selection =>
                (selection.Subject is not null
                    && ReferencesBorrowCarrier(selection.Subject, carrier))
                || selection.Arms.Any(arm =>
                    ReferencesBorrowCarrier(arm.Condition, carrier)
                    || ReferencesBorrowCarrier(arm.Body, carrier))
                || ReferencesBorrowCarrier(selection.Else, carrier),
            EnumMatchExpression match => ReferencesBorrowCarrier(match.Subject, carrier)
                || match.Arms.Any(arm => ReferencesBorrowCarrier(arm.Body, carrier))
                || (match.Else is not null && ReferencesBorrowCarrier(match.Else, carrier)),
            SubjectCompareExpression subject => ReferencesBorrowCarrier(subject.Right, carrier),
            SubjectRangeExpression subject => ReferencesBorrowCarrier(subject.Start, carrier)
                || ReferencesBorrowCarrier(subject.End, carrier),
            FlowExpression flow => ReferencesBorrowCarrier(flow.Source, carrier)
                || flow.Targets.Any(target => target.Arguments.Any(argument =>
                    ReferencesBorrowCarrier(argument, carrier))),
            BranchExpression branch => ReferencesBorrowCarrier(branch.Source, carrier)
                || branch.Arms.SelectMany(static arm => arm.Targets).Any(target =>
                    target.Arguments.Any(argument => ReferencesBorrowCarrier(argument, carrier))),
            TapExpression tap => ReferencesBorrowCarrier(tap.Source, carrier)
                || tap.Targets.Any(target => target.Arguments.Any(argument =>
                    ReferencesBorrowCarrier(argument, carrier))),
            PartitionExpression partition => ReferencesBorrowCarrier(partition.Source, carrier)
                || partition.Arms.Any(arm => arm.Condition is not null
                    && ReferencesBorrowCarrier(arm.Condition, carrier)),
            StreamJoinExpression join => ReferencesBorrowCarrier(join.Source, carrier),
            CallExpression call => call.Arguments.Any(argument =>
                ReferencesBorrowCarrier(argument, carrier)),
            ArrayLiteralExpression array => array.Elements.Any(element =>
                ReferencesBorrowCarrier(element, carrier)),
            ArrayRepeatExpression repeat => ReferencesBorrowCarrier(repeat.Value, carrier),
            StructLiteralExpression structure => structure.Fields.Any(field =>
                ReferencesBorrowCarrier(field.Value, carrier)),
            ProductExpression product => product.Elements.Any(element =>
                ReferencesBorrowCarrier(element.Value, carrier)),
            BoxExpression box => ReferencesBorrowCarrier(box.Value, carrier),
            DictionaryLiteralExpression dictionary => dictionary.Entries.Any(entry =>
                ReferencesBorrowCarrier(entry.Key, carrier)
                || ReferencesBorrowCarrier(entry.Value, carrier)),
            TryExpression attempt => ReferencesBorrowCarrier(attempt.Value, carrier),
            MapExpression map => ReferencesBorrowCarrier(map.Path, carrier)
                || (map.Offset is not null && ReferencesBorrowCarrier(map.Offset, carrier))
                || (map.Length is not null && ReferencesBorrowCarrier(map.Length, carrier))
                || (map.FileSize is not null && ReferencesBorrowCarrier(map.FileSize, carrier)),
            _ => false
        };
    }

    private static bool ReferencesBorrowProjectionEvaluation(Expression expression, string carrier) =>
        expression switch
        {
            // A known lexical base is already compared as the exact projected
            // place. Reading an owned sibling field does not consume its loan.
            NameExpression => false,
            FieldAccessExpression field => ReferencesBorrowProjectionEvaluation(field.Source, carrier),
            IndexExpression index => ReferencesBorrowCarrier(index.Index, carrier)
                || ReferencesBorrowProjectionEvaluation(index.Source, carrier),
            // Calls, flows and conditional receivers must still be evaluated.
            _ => ReferencesBorrowCarrier(expression, carrier)
        };

    private BorrowOriginState CaptureBorrowedTextOriginState() => new(
        new Dictionary<string, IReadOnlySet<string>>(
            _activeBorrowedTextOrigins,
            StringComparer.Ordinal),
        new HashSet<string>(
            _activeReadonlyReferenceBindings,
            StringComparer.Ordinal));

    private void RestoreBorrowedTextOriginState(BorrowOriginState state)
    {
        _activeBorrowedTextOrigins.Clear();
        foreach (var pair in state.Origins)
        {
            _activeBorrowedTextOrigins.Add(pair.Key, pair.Value);
        }
        _activeReadonlyReferenceBindings.Clear();
        _activeReadonlyReferenceBindings.UnionWith(state.ReadonlyReferenceBindings);
    }

    private static BorrowOriginState MergeBorrowedTextOriginStates(
        IEnumerable<BorrowOriginState> states)
    {
        var merged = new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
        var readonlyReferenceBindings = new HashSet<string>(StringComparer.Ordinal);
        foreach (var state in states)
        {
            foreach (var pair in state.Origins)
            {
                if (!merged.TryGetValue(pair.Key, out var origins))
                {
                    origins = new HashSet<string>(StringComparer.Ordinal);
                    merged.Add(pair.Key, origins);
                }
                origins.UnionWith(pair.Value);
            }
            readonlyReferenceBindings.UnionWith(state.ReadonlyReferenceBindings);
        }
        return new BorrowOriginState(
            merged.ToDictionary(
                static pair => pair.Key,
                static pair => (IReadOnlySet<string>)pair.Value,
                StringComparer.Ordinal),
            readonlyReferenceBindings);
    }

    private static bool BorrowBlockMayReachContinuation(BlockBody body) =>
        (BorrowControlExits(body) & BorrowControlExit.Fallthrough) != 0;

    private static bool BorrowLoopMayReachBackEdge(IReadOnlyList<Statement> statements)
    {
        var exits = BorrowControlExits(statements, result: null);
        return (exits & (BorrowControlExit.Fallthrough | BorrowControlExit.Continue)) != 0;
    }

    private static BorrowControlExit BorrowControlExits(BlockBody body) =>
        BorrowControlExits(body.Statements, body.Value);

    private static BorrowControlExit BorrowControlExits(
        IReadOnlyList<Statement> statements,
        Expression? result)
    {
        var exits = BorrowControlExit.Fallthrough;
        foreach (var statement in statements)
        {
            if ((exits & BorrowControlExit.Fallthrough) == 0)
            {
                break;
            }
            exits = (exits & ~BorrowControlExit.Fallthrough) | BorrowControlExits(statement);
        }

        if ((exits & BorrowControlExit.Fallthrough) != 0 && result is not null)
        {
            exits = (exits & ~BorrowControlExit.Fallthrough) | BorrowControlExits(result);
        }
        return exits;
    }

    private static BorrowControlExit BorrowControlExits(Statement statement) => statement switch
    {
        ReturnStatement => BorrowControlExit.Return,
        LoopControlStatement { Kind: LoopControlKind.Break } => BorrowControlExit.Break,
        LoopControlStatement { Kind: LoopControlKind.Continue } => BorrowControlExit.Continue,
        GuardLoopControlStatement { Kind: LoopControlKind.Break } =>
            BorrowControlExit.Fallthrough | BorrowControlExit.Break,
        GuardLoopControlStatement { Kind: LoopControlKind.Continue } =>
            BorrowControlExit.Fallthrough | BorrowControlExit.Continue,
        BindingStatement binding => BorrowControlExits(binding.Value),
        IndexAssignmentStatement assignment =>
            BorrowControlExits(assignment.Index) | BorrowControlExits(assignment.Value),
        FieldAssignmentStatement assignment => BorrowControlExits(assignment.Value),
        ExpressionStatement expression => BorrowControlExits(expression.Expression),
        BlockFunctionCallStatement block =>
            BorrowControlExit.Fallthrough | (BorrowControlExits(block.Body, result: null) & BorrowControlExit.Return),
        BlockFunctionPipelineStatement pipeline => pipeline.Calls.Aggregate(
            BorrowControlExit.Fallthrough,
            static (exits, block) => exits | (BorrowControlExits(block.Body, result: null) & BorrowControlExit.Return)),
        _ => BorrowControlExit.Fallthrough
    };

    private static BorrowControlExit BorrowControlExits(Expression expression) => expression switch
    {
        IfExpression conditional => BorrowControlExits(conditional.Then)
            | (conditional.Else is null
                ? BorrowControlExit.Fallthrough
                : BorrowControlExits(conditional.Else)),
        WhenExpression whenExpression => whenExpression.Arms
            .Select(arm => BorrowControlExits(arm.Body))
            .Aggregate(BorrowControlExit.None, static (left, right) => left | right)
            | BorrowControlExits(whenExpression.Else),
        EnumMatchExpression match => match.Arms
            .Select(arm => BorrowControlExits(arm.Body))
            .Aggregate(BorrowControlExit.None, static (left, right) => left | right)
            | (match.Else is null
                ? BorrowControlExit.None
                : BorrowControlExits(match.Else)),
        _ => BorrowControlExit.Fallthrough
    };

    private void RejectBorrowedTextOriginMutation(string name, int line, int column)
    {
        name = CanonicalBorrowOriginName(name);
        CaptureLoopBorrowMutation(name, line, column);
        CheckBorrowedTextOriginMutation(_activeBorrowedTextOrigins, _activeReadonlyReferenceBindings, name, line, column);
    }

    private void CheckBorrowedTextOriginMutation(
        IReadOnlyDictionary<string, IReadOnlySet<string>> origins,
        IReadOnlySet<string> readonlyBindings,
        string name, int line, int column)
    {
        var borrowed = origins
            .FirstOrDefault(pair => pair.Value.Any(origin => BorrowPlacesConflict(origin, name)));
        if (borrowed.Value is null)
        {
            return;
        }

        var origin = borrowed.Value.First(candidate => BorrowPlacesConflict(candidate, name));

        if (readonlyBindings.Contains(borrowed.Key))
        {
            throw Error(
                line,
                column,
                $"cannot move or mutate owner '{origin}' while readonly reference '{borrowed.Key}' is live in this scope");
        }

        throw Error(
            line,
            column,
            $"cannot move or mutate origin '{origin}' while borrowed Text view '{borrowed.Key}' is live in this scope");
    }

    private static bool BorrowPlacesConflict(string left, string right)
    {
        var leftParts = SplitBorrowPlace(left);
        var rightParts = SplitBorrowPlace(right);
        if (!StringComparer.Ordinal.Equals(leftParts[0], rightParts[0]))
        {
            return false;
        }

        var shared = Math.Min(leftParts.Count, rightParts.Count);
        for (var index = 1; index < shared; index++)
        {
            if (StringComparer.Ordinal.Equals(leftParts[index], rightParts[index]))
            {
                continue;
            }

            if (leftParts[index][0] == '.' && rightParts[index][0] == '.')
            {
                return false;
            }

            if (leftParts[index][0] == '['
                && rightParts[index][0] == '['
                && leftParts[index] != "[*]"
                && rightParts[index] != "[*]")
            {
                return false;
            }

            return true;
        }

        return true;
    }

    private static List<string> SplitBorrowPlace(string place)
    {
        var parts = new List<string>();
        var projectionStart = place.IndexOfAny(['.', '[']);
        if (projectionStart < 0)
        {
            parts.Add(place);
            return parts;
        }

        parts.Add(place[..projectionStart]);
        var index = projectionStart;
        while (index < place.Length)
        {
            var next = index + 1;
            if (place[index] == '[')
            {
                next = place.IndexOf(']', next);
                if (next < 0)
                {
                    next = place.Length - 1;
                }
                next++;
            }
            else
            {
                while (next < place.Length && place[next] is not ('.' or '['))
                {
                    next++;
                }
            }
            parts.Add(place[index..next]);
            index = next;
        }
        return parts;
    }

    private static string BorrowOriginIndexedPlace(string name, Expression index) =>
        CanonicalBorrowOriginName(name) + BorrowOriginIndexProjection(index);

    private static string BorrowOriginIndexProjection(Expression index) => index switch
    {
        NumberExpression number when IsIntegerLiteralExpression(number) =>
            BorrowOriginConstantIndexProjection(number, negative: false),
        NegateExpression { Value: NumberExpression number } when IsIntegerLiteralExpression(index) =>
            BorrowOriginConstantIndexProjection(number, negative: true),
        _ => "[*]"
    };

    private static string BorrowOriginConstantIndexProjection(NumberExpression number, bool negative)
    {
        var value = BigInteger.Parse(
            number.Text.Replace("_", string.Empty, StringComparison.Ordinal),
            CultureInfo.InvariantCulture);
        if (negative)
        {
            value = -value;
        }
        return $"[{value.ToString(CultureInfo.InvariantCulture)}]";
    }

    private static IReadOnlySet<string> EmptyBorrowOrigins() =>
        new HashSet<string>(StringComparer.Ordinal);

    private static string CanonicalBorrowOriginName(string name) => name.TrimEnd('!');
}
