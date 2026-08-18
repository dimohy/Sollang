using System.Globalization;
using System.Numerics;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private SollangProgram _program;
    private readonly TypeDefinitionTable _types;
    private readonly IReadOnlyDictionary<string, BoundTraitDefinition> _traits;
    private readonly Dictionary<object, BoundFunction> _resolvedGenericCalls = new(ReferenceEqualityComparer.Instance);
    private string? _currentFunctionName;
    private readonly Dictionary<object, BoundDynTraitConversion> _dynTraitConversions = new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<object, BoundDynTraitDispatch> _dynTraitDispatches = new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<ProductExpression, BoundType> _productExpressionTypes =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<PartitionExpression, (BoundType ElementType, bool IsEvent)> _partitionExpressionSources =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<StreamJoinExpression, BoundStreamJoin> _streamJoins =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<BranchExpression, BoundParallelBranch> _parallelBranches =
        new(ReferenceEqualityComparer.Instance);
    private readonly HashSet<FlowTarget> _resolvedContainerFlowTargets =
        new(ReferenceEqualityComparer.Instance);
    private readonly HashSet<BoundFunction> _validatingGenericSpecializations = new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<BoundFunction, IReadOnlyDictionary<string, BoundType>> _functionBindings =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<BoundFunction, IReadOnlyDictionary<string, BoundType>> _functionCapturedBindings =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<BoundFunction, IReadOnlySet<string>> _borrowedTextReturnOrigins =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<BoundFunction, IReadOnlySet<string>> _readonlyReferenceReturnOrigins =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<string, IReadOnlySet<string>> _activeBorrowedTextOrigins =
        new(StringComparer.Ordinal);
    private readonly HashSet<Statement> _deferredStreamDeclarations =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<Statement, BlockFunctionPipelineStatement> _deferredStreamConsumers =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<Statement, BoundEventStreamPipeline> _eventStreamConsumers =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<Statement, BoundPartitionPipeline> _partitionConsumers =
        new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<Statement, BoundStreamJoinPipeline> _streamJoinConsumers =
        new(ReferenceEqualityComparer.Instance);
    private Dictionary<string, DeferredStreamPlan> _currentDeferredStreams =
        new(StringComparer.Ordinal);
    private Dictionary<string, PendingPartitionPlan> _currentPartitions =
        new(StringComparer.Ordinal);
    private Dictionary<string, PendingStreamJoinPlan> _currentStreamJoins =
        new(StringComparer.Ordinal);
    private readonly HashSet<string> _activeReadonlyReferenceBindings =
        new(StringComparer.Ordinal);
    private IReadOnlySet<string> _borrowedTextContinuationNames =
        new HashSet<string>(StringComparer.Ordinal);
    private Dictionary<string, BoundFunction>? _boundFunctions;
    private string _currentModuleName = "";
    private string? _currentTypeScopeName;
    private BoundType? _currentFunctionReturnType;
    private IReadOnlySet<string> _currentMoveInputNames = new HashSet<string>(StringComparer.Ordinal);
    private IReadOnlyDictionary<string, BoundType>? _currentFunctionOuterBindings;
    private bool _currentFunctionAllowsEarlyReturn;
    private bool _currentFunctionIsAsync;
    private IReadOnlySet<string>? _currentFunctionEffects;
    private BoundType? _currentBlockYieldResultType;
    private IReadOnlyList<BoundType> _currentBlockAdditionalYieldInputTypes = [];
    private BoundType? _currentStreamElementType;
    private bool _allowStreamStop;
    private IReadOnlyDictionary<string, BoundType> _activeGenericTypeArguments =
        new Dictionary<string, BoundType>(StringComparer.Ordinal);
    private HashSet<string>? _collectingLocalCalls;
    private readonly int _pointerBitWidth;
    private int _loopDepth;
    private int _conditionalDepth;
    private readonly List<SemanticWarning> _warnings = [];
    private readonly HashSet<(string Code, string ModuleName, int Line, int Column)> _warningLocations = [];
    private List<MutableBindingDeclaration>? _currentMutableDeclarations;
    private Dictionary<string, MutableBindingDeclaration>? _currentMutableDeclarationsByName;
    private Dictionary<string, FixedLengthArrayCandidate>? _currentFixedLengthArrayCandidates;
    private HashSet<BoundType>? _currentUsedTypes;
    private readonly HashSet<int> _reservedReuseStaticArrayIds = [];

    private sealed record MutableBindingDeclaration(string Name, int Line, int Column)
    {
        public bool IsMutated { get; set; }
    }
    private sealed class FixedLengthArrayCandidate(string name, int line, int column, int initialLength)
    {
        public string Name { get; } = name;
        public int Line { get; } = line;
        public int Column { get; } = column;
        public int Length { get; set; } = initialLength;
        public bool IsLengthUnknown { get; set; }
        public bool RequiresGrowableType { get; set; }
    }

    private sealed record DeferredStreamPlan(
        IReadOnlyList<BlockFunctionCallStatement> Calls,
        BoundType ElementType,
        int Line,
        int Column,
        bool IsEvent = false,
        Expression? EventSource = null,
        BoundType? EventSourceElementType = null);

    private sealed class PendingPartitionPlan(
        BindingStatement declaration,
        PartitionExpression expression,
        BoundType sourceElementType,
        bool isEvent)
    {
        public BindingStatement Declaration { get; } = declaration;
        public PartitionExpression Expression { get; } = expression;
        public BoundType SourceElementType { get; } = sourceElementType;
        public bool IsEvent { get; } = isEvent;
        public Dictionary<string, (Statement Statement, BlockFunctionPipelineStatement Pipeline)> Consumers { get; } =
            new(StringComparer.Ordinal);
    }

    private sealed record DeferredFlowScope(
        Dictionary<string, DeferredStreamPlan> Streams,
        Dictionary<string, PendingPartitionPlan> Partitions,
        Dictionary<string, PendingStreamJoinPlan> Joins);

    private sealed record PendingStreamJoinPlan(
        BindingStatement Declaration,
        StreamJoinExpression Expression,
        BoundStreamJoin Join);

    public SemanticCompiler(SollangProgram program, int pointerBitWidth)
    {
        _program = program;
        _pointerBitWidth = pointerBitWidth;
        _types = BuildTypeDefinitions(program.Structs, program.Enums);
        ValidateAbiStructDefinitions();
        _traits = BindTraits(program.Traits);
    }

    public BoundProgram Compile(SemanticReusePlan? reusePlan = null)
    {
        _program = InferPrivateFunctionSignatures(_program);
        var functions = DeclareFunctions();
        DiscoverBorrowedTextReturnOrigins(functions);
        DiscoverReadonlyReferenceReturnOrigins(functions);
        var declarationFingerprint = SemanticStableIdentity.DeclarationFingerprint(
            _types,
            _traits.Values,
            functions.Values);
        var activeReuse = reusePlan is not null
            && reusePlan.DeclarationFingerprint.AsSpan().SequenceEqual(declarationFingerprint)
                ? reusePlan
                : null;
        if (activeReuse is not null)
        {
            try
            {
                ReserveReusedStaticArrays(activeReuse);
            }
            catch (Exception error) when (error is InvalidDataException or InvalidOperationException)
            {
                activeReuse = null;
            }
        }
        if (activeReuse is not null)
        {
            foreach (var warning in activeReuse.Warnings)
            {
                if (_warningLocations.Add((warning.Code, warning.ModuleName, warning.Line, warning.Column)))
                {
                    _warnings.Add(warning);
                }
            }
        }
        var declaredFunctionIdentities = SemanticStableIdentity.IndexFunctions(
            _types,
            functions.Values,
            []);
        var syntaxCallSiteIdentities = SemanticStableIdentity.IndexSyntaxCallSites(
            functions.Values,
            _program.Statements,
            declaredFunctionIdentities);
        var syntaxCallsByIdentity = syntaxCallSiteIdentities.ToDictionary(
            static pair => pair.Value,
            static pair => pair.Key,
            StringComparer.Ordinal);
        var declaredFunctionsByIdentity = declaredFunctionIdentities.ToDictionary(
            static pair => pair.Value,
            static pair => pair.Key,
            StringComparer.Ordinal);
        var (reusedSemanticFunctions, totalSemanticFunctions) =
            ValidateFunctionBodies(
                functions,
                activeReuse,
                syntaxCallsByIdentity,
                declaredFunctionsByIdentity);
        IReadOnlyDictionary<string, BoundType>? restoredMainBindings = null;
        var reusedMainSemantics = activeReuse is not null
            && TryRestoreMainSemantics(
                activeReuse,
                syntaxCallsByIdentity,
                declaredFunctionsByIdentity,
                out restoredMainBindings);
        var mainBindings = reusedMainSemantics
            ? restoredMainBindings!
            : BindMain(functions);
        var storagePlacement = StoragePlacementAnalyzer.Analyze(_program, functions);
        var stableFunctionIdentities = SemanticStableIdentity.IndexFunctions(
            _types,
            functions.Values,
            _resolvedGenericCalls.Values);
        var stableCallSiteIdentities = new Dictionary<object, string>(ReferenceEqualityComparer.Instance);
        foreach (var callSite in _resolvedGenericCalls.Keys)
        {
            if (!syntaxCallSiteIdentities.TryGetValue(callSite, out var identity))
            {
                throw new InvalidOperationException(
                    $"resolved call site '{callSite.GetType().Name}' was not indexed by the stable syntax traversal");
            }
            stableCallSiteIdentities.Add(callSite, identity);
        }
        if (activeReuse is not null)
        {
            RegisterReusedStaticArrays(activeReuse);
        }
        return new BoundProgram(
            _types,
            _traits,
            functions,
            _resolvedGenericCalls,
            _dynTraitConversions,
            _dynTraitDispatches,
            _program.Statements,
            mainBindings,
            _functionBindings,
            _functionCapturedBindings,
            storagePlacement.MainFrame,
            storagePlacement.FunctionFrames,
            stableFunctionIdentities,
            stableCallSiteIdentities,
            declarationFingerprint,
            reusedSemanticFunctions,
            totalSemanticFunctions,
            reusedMainSemantics,
            _deferredStreamDeclarations,
            _deferredStreamConsumers,
            _eventStreamConsumers,
            _partitionConsumers,
            _streamJoinConsumers,
            _streamJoins,
            _parallelBranches,
            _warnings);
    }

    private void ReserveReusedStaticArrays(SemanticReusePlan reusePlan)
    {
        foreach (var array in reusePlan.StaticArrays.OrderBy(static array => array.Id))
        {
            if (_types.TryReserveStaticArray(
                    (BoundType)array.Id,
                    (BoundType)SemanticStableIdentity.ResolveType(_types, array.ElementType),
                    array.Length))
            {
                _reservedReuseStaticArrayIds.Add(array.Id);
            }
        }
    }

    private void RegisterReusedStaticArrays(SemanticReusePlan reusePlan)
    {
        var definitions = reusePlan.StaticArrays
            .Where(array => _reservedReuseStaticArrayIds.Contains(array.Id))
            .ToDictionary(
            array => (BoundType)array.Id,
            array => (
                (BoundType)SemanticStableIdentity.ResolveType(_types, array.ElementType),
                array.Length));
        _types.RegisterStaticArrays(definitions);
    }

    private IReadOnlyDictionary<string, BoundTraitDefinition> BindTraits(
        IReadOnlyList<TraitDeclaration> declarations)
    {
        var traits = new Dictionary<string, BoundTraitDefinition>(StringComparer.Ordinal);
        foreach (var declaration in declarations)
        {
            _currentModuleName = declaration.ModuleName;
            if (IsReservedName(declaration.Name))
            {
                throw Error(declaration.Line, declaration.Column, $"trait name '{declaration.Name}' is reserved");
            }
            if (_types.TryResolve(declaration.Name, out _) || traits.ContainsKey(declaration.Name))
            {
                throw Error(declaration.Line, declaration.Column, $"trait '{declaration.Name}' already exists");
            }

            var methods = new List<BoundTraitMethod>(declaration.Methods.Count);
            var associatedTypes = declaration.AssociatedTypes
                .Select(type => new BoundTraitAssociatedType(type.Name, type.Line, type.Column))
                .ToArray();
            var methodNames = new HashSet<string>(StringComparer.Ordinal);
            foreach (var method in declaration.Methods)
            {
                if (!methodNames.Add(method.Name))
                {
                    throw Error(
                        method.Line,
                        method.Column,
                        $"trait method '{declaration.Name}.{method.Name}' already exists");
                }

                var returnAssociatedType = declaration.AssociatedTypes
                    .FirstOrDefault(type => type.Name == method.ReturnType);
                methods.Add(new BoundTraitMethod(
                    method.Name,
                    method.SelfOwnership switch
                    {
                        FunctionInputOwnership.Default => BoundFunctionInputOwnership.Default,
                        FunctionInputOwnership.Move => BoundFunctionInputOwnership.Move,
                        FunctionInputOwnership.MutableBorrow => BoundFunctionInputOwnership.MutableBorrow,
                        _ => throw new InvalidOperationException("unsupported trait receiver ownership")
                    },
                    returnAssociatedType is null
                        ? ParseType(method.ReturnType, method.Line, method.Column)
                        : null,
                    returnAssociatedType?.Name,
                    method.Line,
                    method.Column));
            }

            traits.Add(
                declaration.Name,
                new BoundTraitDefinition(
                    declaration.Name,
                    associatedTypes,
                    methods,
                    declaration.Line,
                    declaration.Column,
                    declaration.ModuleName,
                    declaration.IsPublic));
        }

        return traits;
    }

    private void ValidateTraitImplementations(IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var implementations = new Dictionary<(string Trait, BoundType Type), HashSet<string>>();
        foreach (var function in functions.Values)
        {
            _currentModuleName = function.ModuleName;
            if (function.TraitName is null)
            {
                continue;
            }

            if (!_traits.TryGetValue(function.TraitName, out var trait))
            {
                throw Error(function.Line, function.Column, $"unknown trait '{function.TraitName}'");
            }
            EnsureTraitVisible(trait, function.Line, function.Column);
            if (function.InputType is not { } inputType
                || (!_types.IsStruct(inputType) && !_types.IsEnum(inputType)))
            {
                throw Error(function.Line, function.Column, "trait methods require a user type self receiver");
            }

            var associatedBindings = function.ImplAssociatedTypes
                ?? new Dictionary<string, TypeId>(StringComparer.Ordinal);
            var unknownAssociatedType = associatedBindings.Keys
                .FirstOrDefault(name => !trait.AssociatedTypes.Any(type => type.Name == name));
            if (unknownAssociatedType is not null)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"trait '{trait.Name}' has no associated type '{unknownAssociatedType}'");
            }
            var missingAssociatedType = trait.AssociatedTypes
                .FirstOrDefault(type => !associatedBindings.ContainsKey(type.Name));
            if (missingAssociatedType is not null)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"impl {trait.Name} requires associated type '{missingAssociatedType.Name}'");
            }

            var methodName = function.Name[(function.Name.LastIndexOf('.') + 1)..];
            var requirement = trait.Methods.FirstOrDefault(method => method.Name == methodName)
                ?? throw Error(
                    function.Line,
                    function.Column,
                    $"trait '{trait.Name}' has no method '{methodName}'");
            var requiredReturnType = requirement.ReturnType
                ?? associatedBindings[requirement.ReturnAssociatedTypeName!];
            if (function.InputOwnership != requirement.SelfOwnership
                || function.ReturnType != requiredReturnType)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"trait method '{trait.Name}.{methodName}' signature does not match its declaration");
            }

            var key = (trait.Name, inputType);
            if (!implementations.TryGetValue(key, out var methods))
            {
                methods = new HashSet<string>(StringComparer.Ordinal);
                implementations.Add(key, methods);
            }
            methods.Add(methodName);
        }

        foreach (var ((traitName, type), methods) in implementations)
        {
            var trait = _traits[traitName];
            var missing = trait.Methods.FirstOrDefault(method => !methods.Contains(method.Name));
            if (missing is not null)
            {
                var typeName = _types.IsStruct(type) ? _types.GetStruct(type).Name : _types.GetEnum(type).Name;
                throw Error(
                    trait.Line,
                    trait.Column,
                    $"impl {traitName} for {typeName} is missing method '{missing.Name}'");
            }
        }
    }

    private IReadOnlyDictionary<string, BoundFunction> DeclareFunctions()
    {
        var functions = new Dictionary<string, BoundFunction>(StringComparer.Ordinal);
        _boundFunctions = functions;
        foreach (var declaration in _program.Functions)
        {
            if (functions.ContainsKey(declaration.Name))
            {
                throw Error(declaration.Line, declaration.Column, $"function '{declaration.Name}' already exists");
            }

            var function = BindFunctionDeclaration(declaration, isLocal: false);
            functions.Add(function.Name, function);
        }

        ValidateTraitImplementations(functions);
        AddGlobalAliases(functions);
        ValidateMemberNameCollisions(functions);

        return functions;
    }

    private (int Reused, int Total) ValidateFunctionBodies(
        IReadOnlyDictionary<string, BoundFunction> functions,
        SemanticReusePlan? reusePlan,
        IReadOnlyDictionary<string, object> syntaxCallsByIdentity,
        IReadOnlyDictionary<string, BoundFunction> declaredFunctionsByIdentity)
    {
        var checkedFunctions = new HashSet<string>(StringComparer.Ordinal);
        var reused = 0;
        var total = 0;
        foreach (var function in functions.Values.ToArray())
        {
            if (function.Kind is not (BoundFunctionKind.User or BoundFunctionKind.UserBlock)
                || (function.GenericParameterName is not null
                    && function.SpecializedType is null
                    && function.SpecializedValue is null)
                || !checkedFunctions.Add(function.Name))
            {
                continue;
            }

            total++;
            if (reusePlan is not null
                && TryRestoreFunctionTree(
                    function,
                    reusePlan,
                    syntaxCallsByIdentity,
                    declaredFunctionsByIdentity))
            {
                reused++;
                continue;
            }

            ValidateUserFunction(
                function,
                functions,
                new Dictionary<string, BoundType>(StringComparer.Ordinal));
        }

        return (reused, total);
    }

    private bool TryRestoreFunctionTree(
        BoundFunction root,
        SemanticReusePlan reusePlan,
        IReadOnlyDictionary<string, object> syntaxCallsByIdentity,
        IReadOnlyDictionary<string, BoundFunction> declaredFunctionsByIdentity)
    {
        var tree = new List<(BoundFunction Function, SemanticFunctionReuse Reuse)>();
        if (!CollectReusableFunctionTree(root, parentIdentity: null, reusePlan, tree))
            return false;
        Dictionary<BoundFunction, (IReadOnlyDictionary<string, BoundType> Bindings,
            IReadOnlyDictionary<string, BoundType> Captured)> materialized;
        try
        {
            materialized = new Dictionary<BoundFunction, (
                IReadOnlyDictionary<string, BoundType> Bindings,
                IReadOnlyDictionary<string, BoundType> Captured)>(ReferenceEqualityComparer.Instance);
            foreach (var item in tree)
            {
                materialized.Add(
                    item.Function,
                    (RestoreBindings(item.Reuse.Bindings),
                        RestoreBindings(item.Reuse.CapturedBindings)));
            }
        }
        catch (InvalidDataException)
        {
            return false;
        }
        if (!TryRestoreOwnerCalls(
                tree.Select(static item => item.Reuse.Identity).ToArray(),
                reusePlan,
                syntaxCallsByIdentity,
                declaredFunctionsByIdentity))
            return false;
        foreach (var (function, bindings) in materialized)
        {
            _functionBindings[function] = bindings.Bindings;
            _functionCapturedBindings[function] = bindings.Captured;
        }
        return true;
    }

    private bool TryRestoreOwnerCalls(
        IReadOnlyCollection<string> ownerIdentities,
        SemanticReusePlan reusePlan,
        IReadOnlyDictionary<string, object> syntaxCallsByIdentity,
        IReadOnlyDictionary<string, BoundFunction> declaredFunctionsByIdentity)
    {
        if (_boundFunctions is null)
            throw new InvalidOperationException("semantic call restoration requires bound functions");

        var originalFunctionNames = _boundFunctions.Keys.ToHashSet(StringComparer.Ordinal);
        var originalCalls = new Dictionary<object, BoundFunction>(
            _resolvedGenericCalls,
            ReferenceEqualityComparer.Instance);
        var restoredBindings = new Dictionary<BoundFunction, SemanticFunctionReuse>(
            ReferenceEqualityComparer.Instance);
        try
        {
            var pendingOwners = new SortedSet<string>(ownerIdentities, StringComparer.Ordinal);
            var restoredOwners = new HashSet<string>(StringComparer.Ordinal);
            while (pendingOwners.Count > 0)
            {
                var owner = pendingOwners.Min!;
                pendingOwners.Remove(owner);
                if (!restoredOwners.Add(owner))
                    continue;
                var calls = reusePlan.ResolvedCalls
                    .Where(pair => pair.Key.StartsWith(owner + "/call:", StringComparison.Ordinal))
                    .OrderBy(static pair => pair.Key, StringComparer.Ordinal);
                foreach (var call in calls)
                {
                    if (!syntaxCallsByIdentity.TryGetValue(call.Key, out var syntaxNode)
                        || !TryResolveReusableCallTarget(
                            call.Value,
                            syntaxNode,
                            reusePlan,
                            declaredFunctionsByIdentity,
                            out var target))
                    {
                        RollBackRestoredCalls(originalFunctionNames, originalCalls);
                        return false;
                    }

                    _resolvedGenericCalls[syntaxNode] = target;
                    if (reusePlan.Specializations.TryGetValue(call.Value, out var specialization)
                        && specialization.TemplateIdentity is { } templateOwner)
                        pendingOwners.Add(templateOwner);
                    if (target.Kind is BoundFunctionKind.User or BoundFunctionKind.UserBlock
                        && !declaredFunctionsByIdentity.ContainsKey(call.Value))
                    {
                        if (!reusePlan.Functions.TryGetValue(call.Value, out var reusable)
                            || !StringComparer.Ordinal.Equals(reusable.ModuleName, target.ModuleName))
                        {
                            RollBackRestoredCalls(originalFunctionNames, originalCalls);
                            return false;
                        }
                        restoredBindings[target] = reusable;
                    }
                }
            }

            var materializedBindings = new Dictionary<BoundFunction, (
                IReadOnlyDictionary<string, BoundType> Bindings,
                IReadOnlyDictionary<string, BoundType> Captured)>(ReferenceEqualityComparer.Instance);
            foreach (var pair in restoredBindings)
            {
                materializedBindings.Add(
                    pair.Key,
                    (RestoreBindings(pair.Value.Bindings),
                        RestoreBindings(pair.Value.CapturedBindings)));
            }
            foreach (var (function, bindings) in materializedBindings)
            {
                _functionBindings[function] = bindings.Bindings;
                _functionCapturedBindings[function] = bindings.Captured;
            }
            return true;
        }
        catch (Exception error) when (error is InvalidDataException
                                      or InvalidOperationException
                                      or SollangException
                                      or KeyNotFoundException)
        {
            RollBackRestoredCalls(originalFunctionNames, originalCalls);
            return false;
        }
    }

    private bool TryResolveReusableCallTarget(
        string identity,
        object syntaxNode,
        SemanticReusePlan reusePlan,
        IReadOnlyDictionary<string, BoundFunction> declaredFunctionsByIdentity,
        out BoundFunction target)
    {
        if (declaredFunctionsByIdentity.TryGetValue(identity, out target!))
            return true;
        if (_boundFunctions is null
            || !reusePlan.Specializations.TryGetValue(identity, out var recipe))
        {
            target = null!;
            return false;
        }

        if (recipe.TemplateIdentity is { } templateIdentity)
        {
            if (!declaredFunctionsByIdentity.TryGetValue(templateIdentity, out var template))
            {
                target = null!;
                return false;
            }
            if (recipe.SpecializedValue is { } value)
            {
                if (recipe.InputType is null)
                {
                    target = null!;
                    return false;
                }
                target = ResolveValueGenericSpecialization(
                    template,
                    (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.InputType),
                    value,
                    syntaxNode,
                    validateSpecialization: false);
            }
            else
            {
                if (recipe.SpecializedType is null)
                {
                    target = null!;
                    return false;
                }
                target = ResolveGenericSpecialization(
                    template,
                    (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.SpecializedType),
                    _boundFunctions,
                    syntaxNode,
                    recipe.InputType is null
                        ? null
                        : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.InputType),
                    recipe.SpecializedSecondaryType is null
                        ? null
                        : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.SpecializedSecondaryType),
                    recipe.SpecializedTertiaryType is null
                        ? null
                        : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.SpecializedTertiaryType),
                    validateSpecialization: false);
            }
        }
        else
        {
            target = new BoundFunction(
                recipe.Name,
                recipe.InputName,
                recipe.InputType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.InputType),
                recipe.InputOwnership,
                (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.ReturnType),
                recipe.BlockInputName,
                recipe.BlockInputType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.BlockInputType),
                new Dictionary<string, BoundFunction>(StringComparer.Ordinal),
                Body: null,
                BlockBody: [],
                Line: 0,
                Column: 0,
                recipe.Kind,
                recipe.IsStandardLibrary,
                recipe.IsLocal,
                SpecializedType: recipe.SpecializedType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.SpecializedType),
                SpecializedSecondaryType: recipe.SpecializedSecondaryType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.SpecializedSecondaryType),
                SpecializedTertiaryType: recipe.SpecializedTertiaryType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.SpecializedTertiaryType),
                SpecializedValue: recipe.SpecializedValue,
                ModuleName: recipe.ModuleName,
                IsPublic: recipe.IsPublic,
                IsAsync: recipe.IsAsync,
                BlockResultType: recipe.BlockResultType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.BlockResultType),
                StreamElementType: recipe.StreamElementType is null
                    ? null
                    : (BoundType)SemanticStableIdentity.ResolveType(_types, recipe.StreamElementType));
        }

        return StringComparer.Ordinal.Equals(
            SemanticStableIdentity.Function(_types, target, parentIdentity: null),
            identity);
    }

    private void RollBackRestoredCalls(
        IReadOnlySet<string> originalFunctionNames,
        IReadOnlyDictionary<object, BoundFunction> originalCalls)
    {
        if (_boundFunctions is null)
            return;
        foreach (var name in _boundFunctions.Keys.Where(name => !originalFunctionNames.Contains(name)).ToArray())
            _boundFunctions.Remove(name);
        _resolvedGenericCalls.Clear();
        foreach (var call in originalCalls)
            _resolvedGenericCalls.Add(call.Key, call.Value);
    }

    private bool CollectReusableFunctionTree(
        BoundFunction function,
        string? parentIdentity,
        SemanticReusePlan reusePlan,
        ICollection<(BoundFunction Function, SemanticFunctionReuse Reuse)> tree)
    {
        var identity = SemanticStableIdentity.Function(_types, function, parentIdentity);
        if (!reusePlan.Functions.TryGetValue(identity, out var reusable)
            || !StringComparer.Ordinal.Equals(reusable.ModuleName, function.ModuleName))
            return false;
        tree.Add((function, reusable));
        foreach (var local in function.LocalFunctions.Values
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            if (!CollectReusableFunctionTree(local, identity, reusePlan, tree))
                return false;
        }
        return true;
    }

    private IReadOnlyDictionary<string, BoundType> RestoreBindings(
        IReadOnlyDictionary<string, string> bindings)
    {
        return bindings.ToDictionary(
            static pair => pair.Key,
            pair => (BoundType)SemanticStableIdentity.ResolveType(_types, pair.Value),
            StringComparer.Ordinal);
    }

    private bool TryRestoreMainSemantics(
        SemanticReusePlan reusePlan,
        IReadOnlyDictionary<string, object> syntaxCallsByIdentity,
        IReadOnlyDictionary<string, BoundFunction> declaredFunctionsByIdentity,
        out IReadOnlyDictionary<string, BoundType>? bindings)
    {
        bindings = null;
        if (reusePlan.MainBindings is null)
            return false;
        try
        {
            bindings = RestoreBindings(reusePlan.MainBindings);
        }
        catch (InvalidDataException)
        {
            return false;
        }
        if (TryRestoreOwnerCalls(
                ["main"],
                reusePlan,
                syntaxCallsByIdentity,
                declaredFunctionsByIdentity))
            return true;
        bindings = null;
        return false;
    }

    private void ValidateMemberNameCollisions(IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var seen = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in functions.Values)
        {
            if (!seen.Add(function))
            {
                continue;
            }

            var definition = function.InputType is { } inputType && _types.IsStruct(inputType)
                ? _types.GetStruct(inputType)
                : _types.Structs.FirstOrDefault(structure =>
                    function.Name.StartsWith(structure.Name + ".", StringComparison.Ordinal));
            if (definition is null)
            {
                continue;
            }

            var memberName = function.Name[(function.Name.LastIndexOf('.') + 1)..];
            if (definition.Fields.Any(field => field.Name == memberName))
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"member '{definition.Name}.{memberName}' conflicts with a stored field of the same name");
            }
        }
    }

    private BoundFunction BindFunctionDeclaration(FunctionDeclaration function, bool isLocal)
    {
        _currentModuleName = function.ModuleName;
        _currentTypeScopeName = ResolveFunctionTypeScope(function.Name);
        ValidateFunctionDeclaration(function, isLocal);
        var genericParameterNames = (function.GenericParameters ?? [])
            .Select(parameter => parameter.Name)
            .ToArray();
        if (genericParameterNames.Length == 0 && function.GenericParameterName is not null)
        {
            genericParameterNames =
            [
                function.GenericParameterName,
                .. new[] { function.SecondaryGenericParameterName, function.TertiaryGenericParameterName }
                    .OfType<string>()
            ];
        }

        if (function.GenericTraitBound is not null
            && !function.IsValueGeneric
            && !_traits.ContainsKey(function.GenericTraitBound))
        {
            throw Error(function.Line, function.Column, $"unknown trait bound '{function.GenericTraitBound}'");
        }

        if (function.GenericAssociatedTypeName is not null && function.GenericTraitBound is null)
        {
            throw Error(function.Line, function.Column, "associated type equality requires a trait bound");
        }
        if (function.GenericTraitBound is { } constrainedTraitName
            && function.GenericAssociatedTypeName is { } constrainedAssociatedTypeName)
        {
            var constrainedTrait = _traits[constrainedTraitName];
            EnsureTraitVisible(constrainedTrait, function.Line, function.Column);
            if (!constrainedTrait.AssociatedTypes.Any(type => type.Name == constrainedAssociatedTypeName))
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"trait '{constrainedTrait.Name}' has no associated type '{constrainedAssociatedTypeName}'");
            }
        }

        var isParallelRole = function.Name is "sys.runtime.parallel" or "sys.runtime.tryParallel";
        var hasCompositeGenericInput = function.GenericParameterName is not null
            && function.InputType is not null
            && !genericParameterNames.Contains(function.InputType, StringComparer.Ordinal)
            && TypeSyntaxReferencesAnyParameter(function.InputType, genericParameterNames);
        var inputTypeTemplate = (isParallelRole || function.HasValueGenericFixedArrayInput || hasCompositeGenericInput)
            && function.InputType is not null
            && (function.HasValueGenericFixedArrayInput
                || (!genericParameterNames.Contains(function.InputType, StringComparer.Ordinal)
                    && TypeSyntaxReferencesAnyParameter(function.InputType, genericParameterNames)))
                ? function.InputType
                : null;
        var inputType = function.InputType is null || inputTypeTemplate is not null
            ? (BoundType?)null
            : ParseFunctionType(
                function.InputType,
                function.GenericParameterName,
                function.SecondaryGenericParameterName,
                function.TertiaryGenericParameterName,
                function.Line,
                function.Column,
                genericParameterNames);
        if (function.InputOwnership == FunctionInputOwnership.Default
            && inputType == BoundType.IntDictionary)
        {
            inputType = BoundType.IntDictionaryView;
        }

        var returnTypeTemplate = (isParallelRole
                || function.ReturnType.StartsWith('[', StringComparison.Ordinal))
            && function.GenericParameterName is not null
            && !genericParameterNames.Contains(function.ReturnType, StringComparer.Ordinal)
            && TypeSyntaxReferencesAnyParameter(function.ReturnType, genericParameterNames)
                ? function.ReturnType
                : null;
        var returnType = returnTypeTemplate is null
            ? ParseFunctionType(
                function.ReturnType,
                function.GenericParameterName,
                function.SecondaryGenericParameterName,
                function.TertiaryGenericParameterName,
                function.Line,
                function.Column,
                genericParameterNames)
            : BoundType.Unit;
        var nativeSuccessType = function.NativeSuccessType is null
            ? (BoundType?)null
            : ParseFunctionType(
                function.NativeSuccessType,
                function.GenericParameterName,
                function.SecondaryGenericParameterName,
                function.TertiaryGenericParameterName,
                function.Line,
                function.Column);
        var blockInputTypeTemplate = function.BlockInputType is not null
            && TypeSyntaxReferencesAnyParameter(function.BlockInputType, genericParameterNames)
                ? function.BlockInputType
                : null;
        var blockInputType = function.BlockInputType is null || blockInputTypeTemplate is not null
            ? (BoundType?)null
            : ParseType(function.BlockInputType, function.Line, function.Column);
        var blockResultTypeTemplate = function.BlockResultType is not null
            && TypeSyntaxReferencesAnyParameter(function.BlockResultType, genericParameterNames)
                ? function.BlockResultType
                : null;
        var blockResultType = function.BlockInputType is null
            ? (BoundType?)null
            : function.BlockResultType is null
                ? BoundType.Unit
                : ParseFunctionType(
                    function.BlockResultType,
                    function.GenericParameterName,
                    function.SecondaryGenericParameterName,
                    function.TertiaryGenericParameterName,
                    function.Line,
                    function.Column,
                    genericParameterNames);
        var streamElementTypeTemplate = function.StreamElementType is not null
            && TypeSyntaxReferencesAnyParameter(function.StreamElementType, genericParameterNames)
                ? function.StreamElementType
                : null;
        var streamElementType = function.StreamElementType is null
            ? (BoundType?)null
            : ParseFunctionType(
                function.StreamElementType,
                function.GenericParameterName,
                function.SecondaryGenericParameterName,
                function.TertiaryGenericParameterName,
                function.Line,
                function.Column,
                genericParameterNames);
        var genericAssociatedTypeConstraint = function.GenericAssociatedTypeConstraint is null
            ? (TypeId?)null
            : ParseFunctionType(
                function.GenericAssociatedTypeConstraint,
                function.GenericParameterName,
                function.SecondaryGenericParameterName,
                function.TertiaryGenericParameterName,
                function.Line,
                function.Column,
                genericParameterNames);
        IReadOnlyDictionary<string, TypeId>? implAssociatedTypes = function.ImplAssociatedTypes is null
            ? null
            : function.ImplAssociatedTypes.ToDictionary(
                static pair => pair.Key,
                pair => (TypeId)ParseType(pair.Value, function.Line, function.Column),
                StringComparer.Ordinal);
        if (function.TraitName is null && implAssociatedTypes is { Count: > 0 })
        {
            throw Error(function.Line, function.Column, "associated type bindings require a trait impl");
        }
        var inputOwnership = BindFunctionInputOwnership(function, inputType);
        var additionalParameters = (function.AdditionalParameters ?? [])
            .Select(parameter =>
            {
                var parameterTypeTemplate = function.GenericParameterName is not null
                    && TypeSyntaxReferencesAnyParameter(parameter.TypeName, genericParameterNames)
                    && !genericParameterNames.Contains(parameter.TypeName, StringComparer.Ordinal)
                        ? parameter.TypeName
                        : null;
                var parameterType = parameterTypeTemplate is null
                    ? ParseFunctionType(
                        parameter.TypeName,
                        function.GenericParameterName,
                        function.SecondaryGenericParameterName,
                        function.TertiaryGenericParameterName,
                        parameter.Line,
                        parameter.Column,
                        genericParameterNames)
                    : BoundType.Unit;
                if (parameter.Ownership == FunctionInputOwnership.Default
                    && parameterType == BoundType.IntDictionary)
                {
                    parameterType = BoundType.IntDictionaryView;
                }
                return new BoundFunctionParameter(
                    parameter.Name,
                    parameterType,
                    parameterTypeTemplate is not null
                        ? parameter.Ownership switch
                        {
                            FunctionInputOwnership.Move => BoundFunctionInputOwnership.Move,
                            FunctionInputOwnership.MutableBorrow => BoundFunctionInputOwnership.MutableBorrow,
                            _ => BoundFunctionInputOwnership.Default
                        }
                        : BindFunctionInputOwnership(
                            parameter.Ownership,
                            parameterType,
                            parameter.Line,
                            parameter.Column),
                    parameter.Line,
                    parameter.Column,
                    parameterTypeTemplate);
            })
            .ToArray();
        var additionalBlockParameters = (function.AdditionalBlockParameters ?? [])
            .Select(parameter => new BoundFunctionParameter(
                parameter.Name,
                ParseFunctionType(
                    parameter.TypeName,
                    function.GenericParameterName,
                    function.SecondaryGenericParameterName,
                    function.TertiaryGenericParameterName,
                    parameter.Line,
                    parameter.Column,
                    genericParameterNames),
                BoundFunctionInputOwnership.Default,
                parameter.Line,
                parameter.Column))
            .ToArray();
        var effects = BindFunctionEffects(function);
        var isAsyncRuntimeIntrinsic = function.IsStandardLibrary
            && function.IsIntrinsic
            && function.Name is "sys.time.sleep"
                or "sys.file.readAsync"
                or "sys.file.openReadAsync"
                or "sys.file.openWriteAsync";
        if (function.IsAsync
            && ((!isAsyncRuntimeIntrinsic && !IsAsyncResultTypeSupported(returnType))
                || (!isAsyncRuntimeIntrinsic && !IsAsyncInputTypeSupported(inputType, inputOwnership))
                || (!isAsyncRuntimeIntrinsic && additionalParameters.Any(parameter =>
                    !IsAsyncInputTypeSupported(parameter.Type, parameter.Ownership)))
                || isLocal
                || (function.IsStandardLibrary && !isAsyncRuntimeIntrinsic)
                || (function.IsIntrinsic && !isAsyncRuntimeIntrinsic)))
        {
            throw Error(
                function.Line,
                function.Column,
                "async functions require a transferable result, a sendable input, and a non-local user declaration; owned inputs must use move");
        }
        var kind = BindFunctionKind(function, inputType, returnType, isLocal);
        if (kind == BoundFunctionKind.Native && function.Com is null)
        {
            if (inputType is { } nativeInputType)
            {
                ValidateNativeAbiParameter(
                    nativeInputType,
                    inputOwnership,
                    "input",
                    function.Line,
                    function.Column);
            }
            foreach (var parameter in additionalParameters)
            {
                ValidateNativeAbiParameter(
                    parameter.Type,
                    parameter.Ownership,
                    $"parameter '{parameter.Name}'",
                    parameter.Line,
                    parameter.Column);
            }
            ValidateNativeAbiResult(
                nativeSuccessType ?? returnType,
                function.Line,
                function.Column);
        }
        if (function.Com is not null)
        {
            ValidateComFunction(
                function,
                inputType,
                inputOwnership,
                returnType,
                additionalParameters);
        }
        if (kind == BoundFunctionKind.RuntimeMouseEvents)
        {
            if (additionalParameters.Length != 1
                || !_types.TryResolve("sys.event.EventOverflowPolicy", out var overflowType)
                || additionalParameters[0].Type != overflowType)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "intrinsic sys.event.mouseEvents must be "
                    + "Int, EventOverflowPolicy -> EventStream<MouseEvent>");
            }
        }
        var localFunctions = BindLocalFunctions(function);

        return new BoundFunction(
            function.Name,
            function.InputName,
            inputType,
            inputOwnership,
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
            isLocal,
            function.TraitName,
            function.GenericParameterName,
            function.SecondaryGenericParameterName,
            function.TertiaryGenericParameterName,
            function.GenericTraitBound,
            function.GenericAssociatedTypeName,
            genericAssociatedTypeConstraint,
            implAssociatedTypes,
            IsValueGeneric: function.IsValueGeneric,
            HasValueGenericFixedArrayInput: function.HasValueGenericFixedArrayInput,
            ModuleName: function.ModuleName,
            IsPublic: function.IsPublic || function.IsStandardLibrary,
            IsAsync: function.IsAsync,
            BlockInputTypeTemplate: blockInputTypeTemplate,
            Effects: effects,
            BlockResultType: blockResultType,
            BlockResultTypeTemplate: blockResultTypeTemplate,
            InputTypeTemplate: inputTypeTemplate,
            ReturnTypeTemplate: returnTypeTemplate,
            AdditionalParameters: additionalParameters,
            AdditionalBlockParameters: additionalBlockParameters,
            StreamElementType: streamElementType,
            StreamElementTypeTemplate: streamElementTypeTemplate,
            NativeLibrary: function.NativeLibrary,
            NativeSymbol: function.NativeSymbol
                ?? function.Name[(function.Name.LastIndexOf('.') + 1)..],
            Com: function.Com,
            NativeError: function.NativeError,
            NativeSuccessType: nativeSuccessType,
            GenericParameters: function.GenericParameters);
    }

    private IReadOnlySet<string> BindFunctionEffects(FunctionDeclaration function)
    {
        string[] supportedEffects = ["Clock", "Console", "Environment", "File", "Network", "Process", "Random"];
        var effects = new HashSet<string>(StringComparer.Ordinal);
        foreach (var effect in function.Effects ?? [])
        {
            if (!supportedEffects.Contains(effect, StringComparer.Ordinal))
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"unknown effect '{effect}'; supported effects: {string.Join(", ", supportedEffects)}");
            }
            if (!effects.Add(effect))
            {
                throw Error(function.Line, function.Column, $"effect '{effect}' is declared more than once");
            }
        }
        return effects;
    }

    private BoundFunctionInputOwnership BindFunctionInputOwnership(
        FunctionDeclaration function,
        BoundType? inputType)
    {
        if (function.IsValueGeneric
            && inputType is null
            && function.InputOwnership == FunctionInputOwnership.MutableBorrow)
        {
            return BoundFunctionInputOwnership.MutableBorrow;
        }
        return BindFunctionInputOwnership(
            function.InputOwnership, inputType, function.Line, function.Column);
    }

    private BoundFunctionInputOwnership BindFunctionInputOwnership(
        FunctionInputOwnership ownership,
        BoundType? inputType,
        int line,
        int column)
    {
        if (ownership == FunctionInputOwnership.Move)
        {
            if (inputType is null)
            {
                throw Error(line, column, "move input requires an input type");
            }

            if (!IsOwnedHeapType(inputType.Value)
                && !_types.IsStruct(inputType.Value)
                && !_types.IsEnum(inputType.Value))
            {
                throw Error(line, column, "move input expects an owned container or user value type");
            }

            return BoundFunctionInputOwnership.Move;
        }

        if (ownership == FunctionInputOwnership.MutableBorrow)
        {
            if (inputType is null)
            {
                throw Error(line, column, "mut input requires an input type");
            }

            if (inputType.Value is not (BoundType.DynamicIntArray or BoundType.IntDictionary or BoundType.Arena)
                && !_types.IsDynamicArray(inputType.Value)
                && !_types.IsStaticArray(inputType.Value)
                && !_types.IsBoundedArray(inputType.Value)
                && !_types.IsDictionary(inputType.Value)
                && !_types.IsStruct(inputType.Value))
            {
                throw Error(line, column, "mut input expects an owned container or struct value");
            }

            return BoundFunctionInputOwnership.MutableBorrow;
        }

        return BoundFunctionInputOwnership.Default;
    }

    private void ValidateFunctionDeclaration(FunctionDeclaration function, bool isLocal)
    {
        if (function.GenericParameterName is not null)
        {
            if (isLocal || function.TraitName is not null)
            {
                throw Error(function.Line, function.Column, "generic local and impl functions are not implemented yet");
            }
            if (!function.IsValueGeneric
                && function.InputType is not null
                && function.InputType != function.GenericParameterName
                && !TypeSyntaxReferencesParameter(function.InputType, function.GenericParameterName)
                && !TypeSyntaxReferencesParameter(function.InputType, function.SecondaryGenericParameterName)
                && !TypeSyntaxReferencesParameter(function.InputType, function.TertiaryGenericParameterName)
                && (function.BlockResultType is null
                    || !TypeSyntaxReferencesParameter(function.BlockResultType, function.GenericParameterName)))
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"generic function input must use its type parameter '{function.GenericParameterName}' in this slice");
            }
            if (function.InputOwnership != FunctionInputOwnership.Default
                && !function.IsValueGeneric)
            {
                throw Error(function.Line, function.Column, "generic function inputs are readonly in this slice");
            }
        }

        if (isLocal && function.Name.Contains('.', StringComparison.Ordinal))
        {
            throw Error(function.Line, function.Column, "local function names cannot be path-qualified");
        }

        if (IsReservedName(function.Name))
        {
            throw Error(function.Line, function.Column, $"function name '{function.Name}' is reserved");
        }

        if (!function.IsStandardLibrary
            && function.TraitName is null
            && function.Name.StartsWith("sys.", StringComparison.Ordinal))
        {
            throw Error(function.Line, function.Column, "the sys namespace is reserved for the standard library");
        }

        if (function.InputName is not null && function.InputType is null)
        {
            throw Error(function.Line, function.Column, "function input name requires an input type");
        }

        if (function.InputName is not null
            && !(function.InputName == "self" && function.Name.Contains('.', StringComparison.Ordinal)))
        {
            ValidateBindingName(function.InputName, function.Line, function.Column);
        }

        var parameterNames = new HashSet<string>(StringComparer.Ordinal);
        if (function.InputType is not null)
        {
            parameterNames.Add(function.InputName ?? "it");
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            ValidateBindingName(parameter.Name, parameter.Line, parameter.Column);
            if (!parameterNames.Add(parameter.Name))
            {
                throw Error(parameter.Line, parameter.Column,
                    $"function parameter '{parameter.Name}' is declared more than once");
            }
        }

        if (function.BlockInputName is not null && function.BlockInputType is null)
        {
            throw Error(function.Line, function.Column, "block input name requires a block input type");
        }

        if (function.BlockInputName is not null)
        {
            ValidateBindingName(function.BlockInputName, function.Line, function.Column);
        }
        var blockParameterNames = new HashSet<string>(StringComparer.Ordinal);
        if (function.BlockInputName is not null)
        {
            blockParameterNames.Add(function.BlockInputName);
        }
        foreach (var parameter in function.AdditionalBlockParameters ?? [])
        {
            ValidateBindingName(parameter.Name, parameter.Line, parameter.Column);
            if (!blockParameterNames.Add(parameter.Name))
            {
                throw Error(parameter.Line, parameter.Column, $"block parameter '{parameter.Name}' is declared more than once");
            }
        }

        if (function.StreamElementType is not null)
        {
            if (function.IsAsync || function.ReturnType != "Unit")
            {
                throw Error(function.Line, function.Column, "stream functions must be synchronous and return Unit");
            }
            if (function.IsIntrinsic)
            {
                throw Error(function.Line, function.Column, "stream functions are user-defined language functions");
            }
        }

        if (function.NativeLibrary is not null)
        {
            if (isLocal)
            {
                throw Error(function.Line, function.Column, "native functions cannot be local");
            }
            if (function.NativeLibrary.Length == 0)
            {
                throw Error(function.Line, function.Column, "native library name must not be empty");
            }
            if (function.IsIntrinsic
                || function.Body is not null
                || function.BlockBody.Count > 0
                || function.BlockInputName is not null
                || function.GenericParameterName is not null
                || function.IsAsync
                || function.StreamElementType is not null)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "native functions must be non-generic synchronous declarations without a body or block");
            }
            ValidateNativeAbiType(function.InputType, "input", function.Line, function.Column);
            foreach (var parameter in function.AdditionalParameters ?? [])
            {
                ValidateNativeAbiType(
                    parameter.TypeName,
                    $"parameter '{parameter.Name}'",
                    parameter.Line,
                    parameter.Column);
            }
            ValidateNativeAbiType(
                function.NativeSuccessType ?? function.ReturnType,
                "result",
                function.Line,
                function.Column);
        }
        if (function.Com is not null)
        {
            if (isLocal)
            {
                throw Error(function.Line, function.Column, "COM functions cannot be local");
            }
            if (function.IsIntrinsic
                || function.Body is not null
                || function.BlockBody.Count > 0
                || function.BlockInputName is not null
                || function.GenericParameterName is not null
                || function.IsAsync
                || function.StreamElementType is not null)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "COM functions must be non-generic synchronous declarations without a body or block");
            }
        }

    }

    private void ValidateNativeAbiType(string? typeName, string role, int line, int column)
    {
        if (typeName is null || typeName is
            "Unit" or
            "Int8" or "Int16" or "Int32" or "Int64" or
            "UInt8" or "UInt16" or "UInt32" or "UInt64" or
            "Float32" or "Float64")
        {
            return;
        }

        if (_types.TryResolve(typeName, out var type)
            && IsNativeAbiValueType(type))
        {
            return;
        }
        if (typeName.StartsWith("ref ", StringComparison.Ordinal)
            && _types.TryResolve(typeName[4..].Trim(), out type)
            && IsNativeAbiStruct(type))
        {
            return;
        }

        throw Error(
            line,
            column,
            $"native function {role} type '{typeName}' is not ABI-safe; "
            + "use a fixed-width scalar or an explicitly declared abi struct");
    }

    private void ValidateNativeAbiParameter(
        BoundType type,
        BoundFunctionInputOwnership ownership,
        string role,
        int line,
        int column)
    {
        if (ownership == BoundFunctionInputOwnership.Move)
        {
            throw Error(line, column, $"native function {role} cannot transfer Sollang ownership");
        }
        if (ownership == BoundFunctionInputOwnership.MutableBorrow)
        {
            if (IsNativeAbiStruct(type))
            {
                return;
            }
            throw Error(line, column, $"native function {role} mut input requires an abi struct");
        }
        if (_types.IsReference(type))
        {
            if (IsNativeAbiStruct(_types.GetReference(type).ElementType))
            {
                return;
            }
            throw Error(line, column, $"native function {role} ref input requires an abi struct");
        }
        if (IsNativeAbiValueType(type))
        {
            return;
        }

        throw Error(line, column, $"native function {role} type '{FormatType(type)}' is not ABI-safe");
    }

    private void ValidateNativeAbiResult(BoundType type, int line, int column)
    {
        if (_types.IsReference(type))
        {
            throw Error(
                line,
                column,
                "native function result cannot borrow foreign memory; use an owned handle API");
        }
        if (!IsNativeAbiValueType(type))
        {
            throw Error(line, column, $"native function result type '{FormatType(type)}' is not ABI-safe");
        }
    }

    private void ValidateComFunction(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundFunctionInputOwnership inputOwnership,
        BoundType returnType,
        IReadOnlyList<BoundFunctionParameter> additionalParameters)
    {
        var metadata = function.Com
            ?? throw new InvalidOperationException("COM metadata is required");
        if (!Guid.TryParse(metadata.ClassId, out _))
        {
            throw Error(function.Line, function.Column, $"invalid COM CLSID '{metadata.ClassId}'");
        }
        if (!Guid.TryParse(metadata.InterfaceId, out _))
        {
            throw Error(function.Line, function.Column, $"invalid COM IID '{metadata.InterfaceId}'");
        }
        if (!_types.TryResolve(metadata.InterfaceType, out var interfaceType)
            || !_types.IsStruct(interfaceType)
            || _types.GetStruct(interfaceType).ComInterface is null)
        {
            throw Error(
                function.Line,
                function.Column,
                $"unknown COM interface type '{metadata.InterfaceType}'");
        }

        if (metadata.Operation == ComFunctionOperation.Activate)
        {
            if (inputType is not null
                || additionalParameters.Count != 0
                || !_types.TryGetResultTypes(returnType, out var activationResult)
                || activationResult.Ok != interfaceType
                || activationResult.Error != BoundType.Int)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "COM activation must return Result<Interface, Int32> without inputs");
            }
            return;
        }

        var receiverInterfaceType = interfaceType;
        if (metadata.Operation == ComFunctionOperation.Query)
        {
            if (metadata.ReceiverInterfaceType is null
                || !_types.TryResolve(metadata.ReceiverInterfaceType, out receiverInterfaceType)
                || !_types.IsStruct(receiverInterfaceType)
                || _types.GetStruct(receiverInterfaceType).ComInterface is null)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"unknown COM receiver interface type '{metadata.ReceiverInterfaceType}'");
            }
        }

        var expectedReference = _types.GetOrAddReference(receiverInterfaceType);
        if (inputType != expectedReference || inputOwnership != BoundFunctionInputOwnership.Default)
        {
            throw Error(
                function.Line,
                function.Column,
                "COM clone, query, and method receivers must be readonly interface references");
        }

        if (metadata.Operation == ComFunctionOperation.Clone)
        {
            if (additionalParameters.Count != 0 || returnType != interfaceType)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "COM clone must return the same interface type without additional inputs");
            }
            return;
        }

        if (metadata.Operation == ComFunctionOperation.Query)
        {
            if (additionalParameters.Count != 0
                || !_types.TryGetResultTypes(returnType, out var queryResult)
                || queryResult.Ok != interfaceType
                || queryResult.Error != BoundType.Int)
            {
                throw Error(
                    function.Line,
                    function.Column,
                    "COM query must return Result<TargetInterface, Int32> without additional inputs");
            }
            return;
        }

        if (metadata.VtableSlot < 3)
        {
            throw Error(function.Line, function.Column, "COM method vtable slots begin at 3");
        }
        foreach (var parameter in additionalParameters)
        {
            if (parameter.Ownership != BoundFunctionInputOwnership.Default
                || !IsNativeAbiValueType(parameter.Type)
                || _types.IsStruct(parameter.Type))
            {
                throw Error(
                    parameter.Line,
                    parameter.Column,
                    $"COM method parameter '{parameter.Name}' must be a fixed-width scalar in this slice");
            }
        }
        if (!_types.TryGetResultTypes(returnType, out var methodResult)
            || methodResult.Error != BoundType.Int
            || !(methodResult.Ok == BoundType.Unit
                || (IsNativeAbiValueType(methodResult.Ok) && !_types.IsStruct(methodResult.Ok))))
        {
            throw Error(
                function.Line,
                function.Column,
                "COM methods must return Result<Unit, Int32> or Result<fixed-width scalar, Int32>");
        }
    }

    private bool IsNativeAbiValueType(BoundType type)
    {
        return type is BoundType.Unit
            or BoundType.Int8 or BoundType.Int16 or BoundType.Int or BoundType.Int64
            or BoundType.UInt8 or BoundType.UInt16 or BoundType.UInt32 or BoundType.UInt64
            or BoundType.Float32 or BoundType.Float64
            || IsNativeAbiStruct(type);
    }

    private bool IsNativeAbiStruct(BoundType type) =>
        _types.IsStruct(type) && _types.GetStruct(type).IsAbi;

    private void ValidateAbiStructDefinitions()
    {
        foreach (var structure in _types.Structs.Where(static value => value.IsAbi))
        {
            if (structure.Fields.Count == 0)
            {
                throw Error(
                    structure.Line,
                    structure.Column,
                    $"abi struct '{structure.Name}' requires at least one field");
            }
            foreach (var field in structure.Fields)
            {
                if (field.Type is BoundType.Int8 or BoundType.Int16 or BoundType.Int or BoundType.Int64
                    or BoundType.UInt8 or BoundType.UInt16 or BoundType.UInt32 or BoundType.UInt64
                    or BoundType.Float32 or BoundType.Float64)
                {
                    continue;
                }
                if (_types.IsStruct(field.Type) && _types.GetStruct(field.Type).IsAbi)
                {
                    continue;
                }

                throw Error(
                    field.Line,
                    field.Column,
                    $"abi struct field '{structure.Name}.{field.Name}' must use a fixed-width scalar or abi struct");
            }
        }
    }

    private IReadOnlyDictionary<string, BoundFunction> BindLocalFunctions(FunctionDeclaration owner)
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

    private IReadOnlyDictionary<string, BoundType> SelectCapturedBindings(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundType> candidates,
        out HashSet<string> calledFunctions)
    {
        calledFunctions = new HashSet<string>(StringComparer.Ordinal);
        if (candidates.Count == 0)
        {
            return candidates;
        }

        var locals = new HashSet<string>(StringComparer.Ordinal);
        if (function.InputName is not null)
        {
            locals.Add(function.InputName);
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            locals.Add(parameter.Name);
        }
        if (function.BlockInputName is not null)
        {
            locals.Add(function.BlockInputName);
        }

        var referenced = new HashSet<string>(StringComparer.Ordinal);
        var previousCalls = _collectingLocalCalls;
        _collectingLocalCalls = calledFunctions;
        CollectCapturedNames(function.BlockBody, locals, candidates, referenced);
        if (function.Body is not null)
        {
            CollectCapturedNames(function.Body, locals, candidates, referenced);
        }
        _collectingLocalCalls = previousCalls;

        return candidates
            .Where(binding => referenced.Contains(binding.Key))
            .ToDictionary(binding => binding.Key, binding => binding.Value, StringComparer.Ordinal);
    }

    private void CollectCapturedNames(
        IReadOnlyList<Statement> statements,
        HashSet<string> locals,
        IReadOnlyDictionary<string, BoundType> candidates,
        HashSet<string> referenced)
    {
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    CollectCapturedNames(binding.Value, locals, candidates, referenced);
                    locals.Add(binding.Name);
                    break;
                case IndexAssignmentStatement assignment:
                    CollectCapturedName(assignment.Name, locals, candidates, referenced);
                    CollectCapturedNames(assignment.Index, locals, candidates, referenced);
                    CollectCapturedNames(assignment.Value, locals, candidates, referenced);
                    break;
                case FieldAssignmentStatement assignment:
                    CollectCapturedName(assignment.Name, locals, candidates, referenced);
                    CollectCapturedNames(assignment.Value, locals, candidates, referenced);
                    break;
                case BlockFunctionCallStatement block:
                    CollectCapturedNames(block.Source, locals, candidates, referenced);
                    if (block.Target.Count == 1)
                    {
                        _collectingLocalCalls?.Add(block.Target[0]);
                    }
                    var blockLocals = new HashSet<string>(locals, StringComparer.Ordinal)
                    {
                        block.ItemName
                    };
                    CollectCapturedNames(block.Body, blockLocals, candidates, referenced);
                    if (block.ResultName is not null)
                    {
                        locals.Add(block.ResultName);
                    }
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    foreach (var block in pipeline.Calls)
                    {
                        CollectCapturedNames(block.Source, locals, candidates, referenced);
                        if (block.Target.Count == 1)
                        {
                            _collectingLocalCalls?.Add(block.Target[0]);
                        }
                        var pipelineBlockLocals = new HashSet<string>(locals, StringComparer.Ordinal)
                        {
                            block.ItemName
                        };
                        CollectCapturedNames(block.Body, pipelineBlockLocals, candidates, referenced);
                        if (block.ResultName is not null)
                        {
                            locals.Add(block.ResultName);
                        }
                    }
                    break;
                case ExpressionStatement expression:
                    CollectCapturedNames(expression.Expression, locals, candidates, referenced);
                    break;
                case GuardLoopControlStatement guard:
                    CollectCapturedNames(guard.Condition, locals, candidates, referenced);
                    break;
                case ReturnStatement { Value: { } value }:
                    CollectCapturedNames(value, locals, candidates, referenced);
                    break;
            }
        }
    }

    private void CollectCapturedNames(
        BlockBody body,
        HashSet<string> locals,
        IReadOnlyDictionary<string, BoundType> candidates,
        HashSet<string> referenced)
    {
        CollectCapturedNames(body.Statements, locals, candidates, referenced);
        if (body.Value is not null)
        {
            CollectCapturedNames(body.Value, locals, candidates, referenced);
        }
    }

    private void CollectCapturedNames(
        Expression expression,
        HashSet<string> locals,
        IReadOnlyDictionary<string, BoundType> candidates,
        HashSet<string> referenced)
    {
        switch (expression)
        {
            case NameExpression name:
                _collectingLocalCalls?.Add(name.Name);
                CollectCapturedName(name.Name, locals, candidates, referenced);
                break;
            case StringExpression text:
                foreach (var interpolation in text.Segments.OfType<InterpolationSegment>())
                {
                    CollectCapturedNames(interpolation.Expression, locals, candidates, referenced);
                }
                break;
            case AddExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case SubtractExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case MultiplyExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case DivideExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case ModuloExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case CompareExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case AndExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case OrExpression binary:
                CollectCapturedBinary(binary.Left, binary.Right, locals, candidates, referenced);
                break;
            case NegateExpression unary:
                CollectCapturedNames(unary.Value, locals, candidates, referenced);
                break;
            case NotExpression unary:
                CollectCapturedNames(unary.Value, locals, candidates, referenced);
                break;
            case RangeExpression range:
                CollectCapturedBinary(range.Start, range.End, locals, candidates, referenced);
                break;
            case CompileTimeEachExpression each:
                CollectCapturedNames(each.Source, locals, candidates, referenced);
                var eachLocals = new HashSet<string>(locals, StringComparer.Ordinal) { each.ItemName };
                CollectCapturedNames(each.Selector, eachLocals, candidates, referenced);
                if (each.DictionaryValueSelector is not null)
                {
                    CollectCapturedNames(each.DictionaryValueSelector, eachLocals, candidates, referenced);
                }
                break;
            case FoldExpression fold:
                CollectCapturedNames(fold.Source, locals, candidates, referenced);
                CollectCapturedNames(fold.Initial, locals, candidates, referenced);
                var foldLocals = new HashSet<string>(locals, StringComparer.Ordinal)
                {
                    fold.AccumulatorName,
                    fold.ItemName
                };
                CollectCapturedNames(fold.Body, foldLocals, candidates, referenced);
                break;
            case IfExpression conditional:
                CollectCapturedNames(conditional.Condition, locals, candidates, referenced);
                CollectCapturedNames(conditional.Then, new HashSet<string>(locals, StringComparer.Ordinal), candidates, referenced);
                if (conditional.Else is not null)
                {
                    CollectCapturedNames(conditional.Else, new HashSet<string>(locals, StringComparer.Ordinal), candidates, referenced);
                }
                break;
            case WhenExpression whenExpression:
                if (whenExpression.Subject is not null)
                {
                    CollectCapturedNames(whenExpression.Subject, locals, candidates, referenced);
                }
                foreach (var arm in whenExpression.Arms)
                {
                    CollectCapturedWhenArm(arm, locals, candidates, referenced);
                }
                CollectCapturedNames(whenExpression.Else, new HashSet<string>(locals, StringComparer.Ordinal), candidates, referenced);
                break;
            case FlowExpression flow:
                CollectCapturedNames(flow.Source, locals, candidates, referenced);
                foreach (var target in flow.Targets)
                {
                    if (target.Path.Count == 1)
                    {
                        _collectingLocalCalls?.Add(target.Path[0]);
                    }
                    foreach (var argument in target.Arguments)
                    {
                        CollectCapturedNames(argument, locals, candidates, referenced);
                    }
                }
                break;
            case BranchExpression branch:
                CollectCapturedNames(branch.Source, locals, candidates, referenced);
                foreach (var target in branch.Arms.SelectMany(static arm => arm.Targets))
                {
                    if (target.Path.Count == 1)
                    {
                        _collectingLocalCalls?.Add(target.Path[0]);
                    }
                    foreach (var argument in target.Arguments)
                    {
                        CollectCapturedNames(argument, locals, candidates, referenced);
                    }
                }
                break;
            case TapExpression tap:
                CollectCapturedNames(tap.Source, locals, candidates, referenced);
                foreach (var target in tap.Targets)
                {
                    if (target.Path.Count == 1)
                    {
                        _collectingLocalCalls?.Add(target.Path[0]);
                    }
                    foreach (var argument in target.Arguments)
                    {
                        CollectCapturedNames(argument, locals, candidates, referenced);
                    }
                }
                break;
            case PartitionExpression partition:
                CollectCapturedNames(partition.Source, locals, candidates, referenced);
                foreach (var arm in partition.Arms)
                {
                    if (arm.Condition is not null)
                    {
                        var routeLocals = new HashSet<string>(locals, StringComparer.Ordinal)
                        {
                            partition.ItemName
                        };
                        CollectCapturedNames(arm.Condition, routeLocals, candidates, referenced);
                    }
                }
                break;
            case StreamJoinExpression join:
                CollectCapturedNames(join.Source, locals, candidates, referenced);
                break;
            case CallExpression call:
                if (call.Path.Count == 1)
                {
                    _collectingLocalCalls?.Add(call.Path[0]);
                }
                foreach (var argument in call.Arguments)
                {
                    CollectCapturedNames(argument, locals, candidates, referenced);
                }
                break;
            case ArrayLiteralExpression array:
                foreach (var element in array.Elements)
                {
                    CollectCapturedNames(element, locals, candidates, referenced);
                }
                break;
            case ArrayRepeatExpression repeat:
                CollectCapturedNames(repeat.Value, locals, candidates, referenced);
                if (repeat.CountParameterName is not null)
                {
                    CollectCapturedName(repeat.CountParameterName, locals, candidates, referenced);
                }
                break;
            case DictionaryLiteralExpression dictionary:
                foreach (var entry in dictionary.Entries)
                {
                    CollectCapturedBinary(entry.Key, entry.Value, locals, candidates, referenced);
                }
                break;
            case IndexExpression index:
                CollectCapturedBinary(index.Source, index.Index, locals, candidates, referenced);
                break;
            case StructLiteralExpression structure:
                foreach (var field in structure.Fields)
                {
                    CollectCapturedNames(field.Value, locals, candidates, referenced);
                }
                break;
            case ProductExpression product:
                foreach (var element in product.Elements)
                {
                    CollectCapturedNames(element.Value, locals, candidates, referenced);
                }
                break;
            case FieldAccessExpression field:
                CollectCapturedNames(field.Source, locals, candidates, referenced);
                break;
            case TryExpression attempt:
                CollectCapturedNames(attempt.Value, locals, candidates, referenced);
                break;
            case BoxExpression box:
                CollectCapturedNames(box.Value, locals, candidates, referenced);
                break;
            case MapExpression map:
                CollectCapturedNames(map.Path, locals, candidates, referenced);
                if (map.Offset is not null) CollectCapturedNames(map.Offset, locals, candidates, referenced);
                if (map.Length is not null) CollectCapturedNames(map.Length, locals, candidates, referenced);
                if (map.FileSize is not null) CollectCapturedNames(map.FileSize, locals, candidates, referenced);
                break;
            case EnumMatchExpression match:
                CollectCapturedNames(match.Subject, locals, candidates, referenced);
                foreach (var arm in match.Arms)
                {
                    CollectCapturedWhenArm(arm, locals, candidates, referenced);
                }
                if (match.Else is not null)
                {
                    CollectCapturedNames(match.Else, new HashSet<string>(locals, StringComparer.Ordinal), candidates, referenced);
                }
                break;
            case SubjectCompareExpression comparison:
                CollectCapturedNames(comparison.Right, locals, candidates, referenced);
                break;
            case SubjectRangeExpression range:
                CollectCapturedBinary(range.Start, range.End, locals, candidates, referenced);
                break;
        }
    }

    private void CollectCapturedWhenArm(
        WhenArm arm,
        HashSet<string> locals,
        IReadOnlyDictionary<string, BoundType> candidates,
        HashSet<string> referenced)
    {
        CollectCapturedNames(arm.Condition, locals, candidates, referenced);
        var armLocals = new HashSet<string>(locals, StringComparer.Ordinal);
        if (arm.Condition is EnumPatternExpression { BindingName: { } bindingName })
        {
            armLocals.Add(bindingName);
        }
        CollectCapturedNames(arm.Body, armLocals, candidates, referenced);
    }

    private void CollectCapturedBinary(
        Expression left,
        Expression right,
        HashSet<string> locals,
        IReadOnlyDictionary<string, BoundType> candidates,
        HashSet<string> referenced)
    {
        CollectCapturedNames(left, locals, candidates, referenced);
        CollectCapturedNames(right, locals, candidates, referenced);
    }

    private void CollectCapturedName(
        string name,
        HashSet<string> locals,
        IReadOnlyDictionary<string, BoundType> candidates,
        HashSet<string> referenced)
    {
        if (!locals.Contains(name) && candidates.ContainsKey(name))
        {
            referenced.Add(name);
        }
    }

    private IReadOnlyDictionary<string, BoundType> SelectParallelCapturedBindings(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> candidates)
    {
        var referenced = new HashSet<string>(StringComparer.Ordinal);
        var calledFunctions = new HashSet<string>(StringComparer.Ordinal);
        var previousCalls = _collectingLocalCalls;
        _collectingLocalCalls = calledFunctions;
        CollectCapturedNames(
            call.Body,
            new HashSet<string>(StringComparer.Ordinal) { call.ItemName },
            candidates,
            referenced);
        _collectingLocalCalls = previousCalls;

        // A parallel body can delegate to a nested local function. Walk those
        // calls transitively so an unsafe outer capture cannot hide behind a
        // helper that is outlined as the native worker callback.
        var pending = new Queue<string>(calledFunctions);
        var visited = new HashSet<BoundFunction>();
        while (pending.TryDequeue(out var calledName))
        {
            if (!functions.TryGetValue(calledName, out var calledFunction)
                || !calledFunction.IsLocal
                || !visited.Add(calledFunction))
            {
                continue;
            }

            var captures = SelectCapturedBindings(calledFunction, candidates, out var nestedCalls);
            referenced.UnionWith(captures.Keys);
            foreach (var nestedCall in nestedCalls)
            {
                pending.Enqueue(nestedCall);
            }
        }

        return candidates
            .Where(binding => referenced.Contains(binding.Key))
            .ToDictionary(binding => binding.Key, binding => binding.Value, StringComparer.Ordinal);
    }

    private void ValidateParallelCapturedBindings(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlySet<string> mutableBindings)
    {
        foreach (var (name, type) in SelectParallelCapturedBindings(call, functions, bindings))
        {
            if (mutableBindings.Contains(name))
            {
                throw Error(
                    call.Line,
                    call.Column,
                    $"parallel callback cannot capture mutable binding '{name}'");
            }

            // Parallel is structured and joins before the enclosing scope can
            // resume. Immutable SourceText is therefore shared read-only like
            // a Sync value, while async still requires transferable Send-like
            // values. Other affine/runtime views remain unsupported.
            if (!IsParallelSharedTypeSupported(type))
            {
                throw Error(
                    call.Line,
                    call.Column,
                    $"parallel callback cannot capture non-sendable binding '{name}' of type {FormatType(type)}");
            }
        }
    }

    private IReadOnlyDictionary<string, BoundType> SelectParallelBranchCapturedBindings(
        IEnumerable<BoundFunction> targets,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> candidates)
    {
        var referenced = new HashSet<string>(StringComparer.Ordinal);
        var pending = new Queue<BoundFunction>(targets.Where(static target => target.IsLocal));
        var visited = new HashSet<BoundFunction>();
        while (pending.TryDequeue(out var target))
        {
            if (!visited.Add(target))
            {
                continue;
            }

            var captures = SelectCapturedBindings(target, candidates, out var nestedCalls);
            referenced.UnionWith(captures.Keys);
            foreach (var nestedCall in nestedCalls)
            {
                if (functions.TryGetValue(nestedCall, out var nestedTarget) && nestedTarget.IsLocal)
                {
                    pending.Enqueue(nestedTarget);
                }
            }
        }

        return candidates
            .Where(binding => referenced.Contains(binding.Key))
            .OrderBy(static binding => binding.Key, StringComparer.Ordinal)
            .ToDictionary(binding => binding.Key, binding => binding.Value, StringComparer.Ordinal);
    }

    private void ValidateUserFunction(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundType> capturedBindings)
    {
        var previousDeclarations = _currentMutableDeclarations;
        var previousDeclarationsByName = _currentMutableDeclarationsByName;
        var previousFixedLengthCandidates = _currentFixedLengthArrayCandidates;
        var previousUsedTypes = _currentUsedTypes;
        _currentMutableDeclarations = [];
        _currentMutableDeclarationsByName = new Dictionary<string, MutableBindingDeclaration>(StringComparer.Ordinal);
        _currentFixedLengthArrayCandidates = new Dictionary<string, FixedLengthArrayCandidate>(StringComparer.Ordinal);
        _currentUsedTypes = [];
        try
        {
            ValidateUserFunctionCore(function, parentFunctions, capturedBindings);
            WarnUnusedMutableBindings();
            WarnFixedLengthGrowableArrays();
        }
        finally
        {
            _currentMutableDeclarations = previousDeclarations;
            _currentMutableDeclarationsByName = previousDeclarationsByName;
            _currentFixedLengthArrayCandidates = previousFixedLengthCandidates;
            _currentUsedTypes = previousUsedTypes;
        }
    }

    private void ValidateUserFunctionCore(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundType> capturedBindings)
    {
        _currentFunctionName = function.Name;
        _currentModuleName = function.ModuleName;
        _currentTypeScopeName = ResolveFunctionTypeScope(function.Name);
        var parentBorrowedTextOrigins = new Dictionary<string, IReadOnlySet<string>>(
            _activeBorrowedTextOrigins,
            StringComparer.Ordinal);
        _activeBorrowedTextOrigins.Clear();
        _activeReadonlyReferenceBindings.Clear();
        var selectedCapturedBindings = SelectCapturedBindings(function, capturedBindings, out var calledFunctions);
        var previousStreamElementType = _currentStreamElementType;
        _functionCapturedBindings[function] = new Dictionary<string, BoundType>(
            selectedCapturedBindings,
            StringComparer.Ordinal);
        _currentModuleName = function.ModuleName;
        _currentTypeScopeName = ResolveFunctionTypeScope(function.Name);
        if (function.Kind == BoundFunctionKind.UserBlock)
        {
            ValidateUserBlockFunction(function, parentFunctions, selectedCapturedBindings);
            _activeBorrowedTextOrigins.Clear();
            _activeReadonlyReferenceBindings.Clear();
            foreach (var pair in parentBorrowedTextOrigins)
            {
                _activeBorrowedTextOrigins[pair.Key] = pair.Value;
            }
            return;
        }

        var bodyBindings = new Dictionary<string, BoundType>(selectedCapturedBindings, StringComparer.Ordinal);
        if (function.InputType is { } inputType)
        {
            bodyBindings[function.InputName ?? "it"] = inputType;
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            bodyBindings[parameter.Name] = parameter.Type;
        }
        if (function.IsValueGeneric
            && function.SpecializedValue is not null
            && function.GenericParameterName is { } valueParameterName)
        {
            bodyBindings[valueParameterName] = BoundType.Int;
        }

        var returnOuterBindings = new Dictionary<string, BoundType>(bodyBindings, StringComparer.Ordinal);

        var scopedFunctions = CreateFunctionScope(parentFunctions, function.LocalFunctions);
        _currentFunctionReturnType = function.ReturnType;
        _currentMoveInputNames = MoveInputNames(function);
        _currentFunctionOuterBindings = returnOuterBindings;
        _currentFunctionAllowsEarlyReturn = true;
        _currentFunctionIsAsync = function.IsAsync;
        _currentFunctionEffects = function.Effects;
        _currentStreamElementType = function.StreamElementType;

        var mutableBindings = new HashSet<string>(StringComparer.Ordinal);
        if (FunctionMutablyBorrowsInput(function))
        {
            mutableBindings.Add(function.InputName ?? "it");
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            if (parameter.Ownership == BoundFunctionInputOwnership.MutableBorrow)
            {
                mutableBindings.Add(parameter.Name);
            }
        }

        var returnedMoveInputName = ReturnedMoveInputName(function);

        if (function.StreamElementType is not null)
        {
            var stateInitializerBindings = new Dictionary<string, BoundType>(
                selectedCapturedBindings,
                StringComparer.Ordinal);
            foreach (var parameter in function.AdditionalParameters ?? [])
            {
                stateInitializerBindings[parameter.Name] = parameter.Type;
            }
            foreach (var stateBinding in function.BlockBody.OfType<BindingStatement>()
                         .Where(static binding => binding.IsStreamState))
            {
                var stateType = InferExpression(
                    stateBinding.Value,
                    scopedFunctions,
                    stateInitializerBindings,
                    allowPrintCall: false,
                    allowReadIntCall: function.IsStandardLibrary,
                    allowFlowBindingTarget: false,
                    mutableBindings: new HashSet<string>(StringComparer.Ordinal));
                if (stateType == BoundType.Unit)
                {
                    throw Error(stateBinding.Line, stateBinding.Column, "stream state cannot be initialized with Unit");
                }
                stateInitializerBindings.Add(stateBinding.Name, stateType);
            }
        }

        var parentDeferredStreams = BeginDeferredStreamScope();
        BindStatements(
            function.BlockBody,
            scopedFunctions,
            bodyBindings,
            mutableBindings,
            allowContainerBindings: true,
            borrowRegionResult: function.Body,
            shortenBorrowRegions: true,
            retainMutableDeclarationScope: true);
        EndDeferredStreamScope(parentDeferredStreams);
        var functionBorrowedTextOrigins = new Dictionary<string, IReadOnlySet<string>>(
            _activeBorrowedTextOrigins,
            StringComparer.Ordinal);
        foreach (var localFunction in function.LocalFunctions.Values)
        {
            ValidateUserFunction(localFunction, scopedFunctions, bodyBindings);
        }
        _activeBorrowedTextOrigins.Clear();
        _activeReadonlyReferenceBindings.Clear();
        foreach (var pair in functionBorrowedTextOrigins)
        {
            _activeBorrowedTextOrigins[pair.Key] = pair.Value;
        }
        var effectiveCapturedBindings = new Dictionary<string, BoundType>(selectedCapturedBindings, StringComparer.Ordinal);
        foreach (var calledFunctionName in calledFunctions)
        {
            if (!scopedFunctions.TryGetValue(calledFunctionName, out var calledFunction)
                || ReferenceEquals(calledFunction, function)
                || !_functionCapturedBindings.TryGetValue(calledFunction, out var calledCaptures))
            {
                continue;
            }
            foreach (var calledCapture in calledCaptures)
            {
                if (capturedBindings.ContainsKey(calledCapture.Key))
                {
                    effectiveCapturedBindings[calledCapture.Key] = calledCapture.Value;
                }
            }
        }
        _functionCapturedBindings[function] = effectiveCapturedBindings;

        // Local functions may capture readonly parent bindings declared in the
        // parent's statement body. Their validation changes the active semantic
        // context, so restore the parent before inferring its final expression.
        _currentModuleName = function.ModuleName;
        _currentTypeScopeName = ResolveFunctionTypeScope(function.Name);
        _currentFunctionReturnType = function.ReturnType;
        _currentMoveInputNames = MoveInputNames(function);
        _currentFunctionOuterBindings = returnOuterBindings;
        _currentFunctionAllowsEarlyReturn = true;
        _currentFunctionIsAsync = function.IsAsync;
        _currentFunctionEffects = function.Effects;
        _currentStreamElementType = function.StreamElementType;
        _loopDepth = 0;
        if (function.Body is not null)
        {
            WarnRedundantNumericType(function.Body, function.ReturnType);
        }
        var bodyType = function.Body switch
        {
            null => BoundType.Unit,
            var numericLiteral when IsIntegerType(function.ReturnType)
                && IsIntegerLiteralExpression(numericLiteral) =>
                InferContextualValue(
                    numericLiteral,
                    function.ReturnType,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary),
            var numericLiteral when IsFloatType(function.ReturnType)
                && IsNumericLiteralExpression(numericLiteral) =>
                InferContextualValue(
                    numericLiteral,
                    function.ReturnType,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary),
            ArrayLiteralExpression array
                when TryGetContextualArrayElementType(function.ReturnType, out _) =>
                InferContextualValue(
                    array,
                    function.ReturnType,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary),
            ArrayRepeatExpression repeat
                when TryGetContextualArrayElementType(function.ReturnType, out _) =>
                InferContextualValue(
                    repeat,
                    function.ReturnType,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary),
            WhenExpression whenExpression when IsNumericType(function.ReturnType) =>
                InferWhenExpression(
                    whenExpression,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary,
                    allowedOwnedOuterResultName: returnedMoveInputName,
                    mutableBindings: mutableBindings,
                    expectedResultType: function.ReturnType),
            EnumMatchExpression enumMatch when IsNumericType(function.ReturnType) =>
                InferEnumMatchExpression(
                    enumMatch,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary,
                    allowedOwnedOuterResultName: returnedMoveInputName,
                    mutableBindings: mutableBindings,
                    expectedResultType: function.ReturnType),
            IfExpression conditional when IsIntegerType(function.ReturnType) =>
                InferIfExpression(
                    conditional,
                    scopedFunctions,
                    bodyBindings,
                    allowReadIntCall: function.IsStandardLibrary,
                    mutableBindings: mutableBindings,
                    expectedResultType: function.ReturnType),
            _ => InferExpression(
                function.Body,
                scopedFunctions,
                bodyBindings,
                allowPrintCall: false,
                allowReadIntCall: function.IsStandardLibrary,
                allowFlowBindingTarget: false,
                yieldInputType: null,
                mutableBindings: mutableBindings,
                allowedOwnedOuterResultName: returnedMoveInputName)
        };
        if (function.Body is not null)
        {
            MarkFixedLengthCandidateRequiresGrowable(function.Body, function.ReturnType, bodyType);
        }
        if (!IsFunctionReturnCompatible(function.Body, bodyType, function.ReturnType, bodyBindings))
        {
            throw Error(
                function.Line,
                function.Column,
                $"function '{function.Name}' returns {FormatType(bodyType)} but declares {FormatType(function.ReturnType)}");
        }
        if (function.ReturnType == BoundType.Text
            && function.Body is not null
            && IsUnmaterializedDeferredText(function.Body))
        {
            throw Error(
                function.Body.Line,
                function.Body.Column,
                $"function '{function.Name}' cannot return deferred interpolation; materialize it into an explicit Arena owner");
        }

        if (TypeContainsReadonlyReference(function.ReturnType)
            && !_readonlyReferenceReturnOrigins.ContainsKey(function))
        {
            throw Error(
                function.Line,
                function.Column,
                $"function '{function.Name}' cannot return a value containing a readonly reference whose origin is not inferred from a reference-bearing input");
        }

        if (BorrowedTextOriginParameterNames(function).Any()
            && TypeContains(function.ReturnType, BoundType.Text)
            && (ContainsSliceFlow(function.BlockBody)
                || (function.Body is not null && ContainsSliceFlow(function.Body))))
        {
            if (!_borrowedTextReturnOrigins.ContainsKey(function))
            {
                throw Error(
                    function.Line,
                    function.Column,
                    $"function '{function.Name}' cannot return Text storage after slicing borrowed SourceText; return a value whose borrowed Text origins can be inferred from its inputs or copy into an owned text type");
            }
        }

        if (function.Body is not null
            && !_types.IsReference(function.ReturnType)
            && IsContainerType(bodyType))
        {
            EnsureOwnedContainerCanLeaveBlock(
                function.Body,
                returnOuterBindings,
                bodyBindings,
                returnedMoveInputName);

            if (returnedMoveInputName is not null)
            {
                EnsureMoveInputReturnCoverage(
                    function.Body,
                    returnedMoveInputName,
                    scopedFunctions);
            }
        }

        _functionBindings[function] = BindingsWithUsedTypes(bodyBindings);

        _activeBorrowedTextOrigins.Clear();
        _activeReadonlyReferenceBindings.Clear();
        foreach (var pair in parentBorrowedTextOrigins)
        {
            _activeBorrowedTextOrigins[pair.Key] = pair.Value;
        }
        _currentStreamElementType = previousStreamElementType;

    }

    private void ValidateGenericSpecialization(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> parentFunctions)
    {
        var previousModuleName = _currentModuleName;
        var previousTypeScopeName = _currentTypeScopeName;
        var previousReturnType = _currentFunctionReturnType;
        var previousMoveInputNames = _currentMoveInputNames;
        var previousOuterBindings = _currentFunctionOuterBindings;
        var previousAllowsEarlyReturn = _currentFunctionAllowsEarlyReturn;
        var previousIsAsync = _currentFunctionIsAsync;
        var previousEffects = _currentFunctionEffects;
        var previousLoopDepth = _loopDepth;
        var previousGenericTypeArguments = _activeGenericTypeArguments;
        try
        {
            var genericTypeArguments = new Dictionary<string, BoundType>(StringComparer.Ordinal);
            if (function.GenericParameterName is { } primaryName
                && function.SpecializedType is { } primaryType)
            {
                genericTypeArguments[primaryName] = primaryType;
            }
            if (function.SecondaryGenericParameterName is { } secondaryName
                && function.SpecializedSecondaryType is { } secondaryType)
            {
                genericTypeArguments[secondaryName] = secondaryType;
            }
            if (function.TertiaryGenericParameterName is { } tertiaryName
                && function.SpecializedTertiaryType is { } tertiaryType)
            {
                genericTypeArguments[tertiaryName] = tertiaryType;
            }
            _activeGenericTypeArguments = genericTypeArguments;
            ValidateUserFunction(
                function,
                parentFunctions,
                new Dictionary<string, BoundType>(StringComparer.Ordinal));
        }
        finally
        {
            _currentModuleName = previousModuleName;
            _currentTypeScopeName = previousTypeScopeName;
            _currentFunctionReturnType = previousReturnType;
            _currentMoveInputNames = previousMoveInputNames;
            _currentFunctionOuterBindings = previousOuterBindings;
            _currentFunctionAllowsEarlyReturn = previousAllowsEarlyReturn;
            _currentFunctionIsAsync = previousIsAsync;
            _currentFunctionEffects = previousEffects;
            _loopDepth = previousLoopDepth;
            _activeGenericTypeArguments = previousGenericTypeArguments;
        }
    }

    private void ValidateUserBlockFunction(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundType> capturedBindings)
    {
        _functionCapturedBindings[function] = new Dictionary<string, BoundType>(
            capturedBindings,
            StringComparer.Ordinal);
        _currentFunctionIsAsync = false;
        var previousBlockYieldResultType = _currentBlockYieldResultType;
        var previousAdditionalYieldInputTypes = _currentBlockAdditionalYieldInputTypes;
        var previousStreamElementType = _currentStreamElementType;
        _currentBlockYieldResultType = function.BlockResultType ?? BoundType.Unit;
        _currentBlockAdditionalYieldInputTypes = (function.AdditionalBlockParameters ?? [])
            .Select(static parameter => parameter.Type)
            .ToArray();
        _currentStreamElementType = function.StreamElementType;
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
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            bodyBindings[parameter.Name] = parameter.Type;
        }

        var scopedFunctions = CreateFunctionScope(parentFunctions, function.LocalFunctions);
        foreach (var localFunction in function.LocalFunctions.Values)
        {
            ValidateUserFunction(localFunction, scopedFunctions, bodyBindings);
        }

        _currentFunctionReturnType = function.ReturnType;
        _currentMoveInputNames = MoveInputNames(function);
        _currentFunctionOuterBindings = new Dictionary<string, BoundType>(bodyBindings, StringComparer.Ordinal);
        _currentFunctionAllowsEarlyReturn = false;
        _currentFunctionEffects = function.Effects;

        var mutableBindings = new HashSet<string>(StringComparer.Ordinal);
        if (FunctionMutablyBorrowsInput(function))
        {
            mutableBindings.Add(function.InputName ?? "it");
        }

        var parentDeferredStreams = BeginDeferredStreamScope();
        BindStatements(
            function.BlockBody,
            scopedFunctions,
            bodyBindings,
            mutableBindings,
            yieldInputType: function.BlockInputType.Value,
            allowContainerBindings: true,
            borrowRegionResult: function.Body,
            shortenBorrowRegions: true);
        EndDeferredStreamScope(parentDeferredStreams);

        var bodyType = function.Body is null
            ? BoundType.Unit
            : InferExpression(
                function.Body,
                scopedFunctions,
                bodyBindings,
                allowPrintCall: false,
                allowReadIntCall: function.IsStandardLibrary,
                allowFlowBindingTarget: false,
                yieldInputType: function.BlockInputType.Value,
                mutableBindings: mutableBindings);
        if (function.Body is not null)
        {
            MarkFixedLengthCandidateRequiresGrowable(function.Body, function.ReturnType, bodyType);
        }
        if (bodyType != function.ReturnType)
        {
            throw Error(
                function.Line,
                function.Column,
                $"block function '{function.Name}' returns {FormatType(bodyType)} but declares {FormatType(function.ReturnType)}");
        }

        if (function.Body is not null
            && !_types.IsReference(function.ReturnType)
            && IsContainerType(bodyType))
        {
            EnsureOwnedContainerCanLeaveBlock(
                function.Body,
                _currentFunctionOuterBindings,
                bodyBindings,
                null);
        }

        _functionBindings[function] = BindingsWithUsedTypes(bodyBindings);
        _currentBlockYieldResultType = previousBlockYieldResultType;
        _currentBlockAdditionalYieldInputTypes = previousAdditionalYieldInputTypes;
        _currentStreamElementType = previousStreamElementType;
    }

    private IReadOnlyDictionary<string, BoundFunction> CreateFunctionScope(
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

    private BoundFunctionKind BindFunctionKind(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        bool isLocal)
    {
        if (function.NativeLibrary is not null || function.Com is not null)
        {
            return BoundFunctionKind.Native;
        }

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
            "sys.runtime.eprintln" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Text,
                BoundType.Unit,
                BoundFunctionKind.RuntimePrintErrorLine),
            "sys.runtime.flushStandardOutput" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Unit,
                BoundFunctionKind.RuntimeFlushStandardOutput),
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
            "sys.runtime.secureRandomBytes" => RequireSecureRandomBytesSignature(
                function,
                inputType,
                returnType),
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
            "sys.runtime.nowMillis" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Int64,
                BoundFunctionKind.RuntimeNowMillis),
            "sys.runtime.parallel" => RequireParallelIntrinsicSignature(function),
            "sys.runtime.tryParallel" => RequireTryParallelIntrinsicSignature(function),
            "sys.runtime.limitParallelWorkers" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                BoundType.Int,
                BoundFunctionKind.RuntimeLimitParallelWorkers),
            "sys.runtime.parallelWorkers" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Int,
                BoundFunctionKind.RuntimeParallelWorkers),
            "sys.runtime.parallelPeakWorkers" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Int,
                BoundFunctionKind.RuntimeParallelPeakWorkers),
            "std.sequence.defer" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Range,
                _types.GetOrAddStream(BoundType.Int),
                BoundFunctionKind.RuntimeRangeStream),
            "sys.event.mouseEvents" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                _types.GetOrAddEventStream(
                    _types.TryResolve("sys.event.MouseEvent", out var mouseEventType)
                        ? mouseEventType
                        : throw Error(function.Line, function.Column, "sys.event.MouseEvent type is missing")),
                BoundFunctionKind.RuntimeMouseEvents),
            "sys.time.sleep" => RequireSleepIntrinsicSignature(
                function,
                inputType,
                returnType),
            "sys.process.arguments" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                expectedInputType: null,
                BoundType.Arguments,
                BoundFunctionKind.RuntimeArguments),
            "sys.process.environment" => RequireEnvironmentIntrinsicSignature(
                function,
                inputType,
                returnType),
            "sys.process.run" => RequireProcessRunIntrinsicSignature(
                function,
                inputType,
                returnType),
            "sys.process.runToFile" => RequireProcessRunToFileIntrinsicSignature(
                function,
                inputType,
                returnType),
            "sys.process.exit" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                BoundType.Int,
                BoundType.Unit,
                BoundFunctionKind.RuntimeExitProcess),
            "sys.file.borrowText" => RequireIntrinsicSignature(
                function, inputType, returnType, BoundType.Text, BoundType.SourceText,
                BoundFunctionKind.RuntimeBorrowSourceText),
            "sys.file.borrowBytes" => RequireIntrinsicSignature(
                function,
                inputType,
                returnType,
                _types.GetOrAddReference(TypeId.DynamicUInt8Array),
                BoundType.SourceText,
                BoundFunctionKind.RuntimeBorrowSourceBytes),
            "sys.file.mapText" => RequireIntrinsicSignature(
                function, inputType, returnType, BoundType.Text, BoundType.SourceText,
                BoundFunctionKind.RuntimeMapSourceText),
            "sys.file.readStandardInput" => RequireIntrinsicSignature(
                function, inputType, returnType, expectedInputType: null, BoundType.SourceText,
                BoundFunctionKind.RuntimeReadStandardInputSourceText),
            "sys.file.readStandardInputChunk" => RequireIntrinsicSignature(
                function, inputType, returnType, BoundType.UIntSize, BoundType.SourceText,
                BoundFunctionKind.RuntimeReadStandardInputChunk),
            "sys.file.mapPath" => RequireIntrinsicSignature(
                function, inputType, returnType, TypeId.Path, BoundType.SourceText,
                BoundFunctionKind.RuntimeMapSourcePath),
            "sys.path.pathText" => RequireIntrinsicSignature(
                function, inputType, returnType, _types.GetOrAddReference(TypeId.Path), BoundType.Text,
                BoundFunctionKind.RuntimePathText),
            "sys.path.nativeStyle" => RequireIntrinsicSignature(
                function, inputType, returnType, expectedInputType: null, TypeId.PathStyle,
                BoundFunctionKind.RuntimePathStyle),
            "sys.path.queryRaw" => RequirePathQuerySignature(
                function,
                inputType,
                returnType),
            "sys.directory.readRaw" => RequireReadDirectorySignature(
                function,
                inputType,
                returnType),
            "sys.directory.create" => RequireCreateDirectorySignature(
                function,
                inputType,
                returnType),
            "sys.file.write" => RequireGenericScalarWriteSignature(
                function,
                inputType,
                returnType),
            "sys.file.read" => RequireGenericScalarReadSignature(
                function,
                inputType,
                returnType,
                isAsync: false),
            "sys.file.readAsync" => RequireGenericScalarReadSignature(
                function,
                inputType,
                returnType,
                isAsync: true),
            "sys.file.openRead" => RequireOpenFileSignature(
                function,
                inputType,
                returnType,
                "sys.file.File",
                BoundFunctionKind.RuntimeOpenFile,
                isAsync: false),
            "sys.file.openReadAsync" => RequireOpenFileSignature(
                function,
                inputType,
                returnType,
                "sys.file.File",
                BoundFunctionKind.RuntimeOpenFileAsync,
                isAsync: true),
            "sys.file.openWrite" => RequireOpenFileSignature(
                function,
                inputType,
                returnType,
                "sys.file.FileWriter",
                BoundFunctionKind.RuntimeOpenWriteFile,
                isAsync: false),
            "sys.file.openWriteAsync" => RequireOpenFileSignature(
                function,
                inputType,
                returnType,
                "sys.file.FileWriter",
                BoundFunctionKind.RuntimeOpenWriteFileAsync,
                isAsync: true),
            "sys.file.sync" => RequireOwnedFileSyncSignature(function, inputType, returnType),
            "sys.file.atomicReplace" => RequireAtomicReplaceSignature(function, inputType, returnType),
            "sys.socket.listen" => RequireSocketListenSignature(function, inputType, returnType),
            "sys.socket.accept" => RequireSocketOwnerResultSignature(
                function, inputType, returnType, "sys.socket.TcpListener", "sys.socket.TcpStream",
                BoundFunctionKind.RuntimeSocketAccept),
            "sys.socket.connect" => RequireSocketConnectSignature(function, inputType, returnType),
            "sys.socket.receive" => RequireSocketReceiveSignature(function, inputType, returnType),
            "sys.socket.send" => RequireSocketSendSignature(function, inputType, returnType, text: false),
            "sys.socket.sendText" => RequireSocketSendSignature(function, inputType, returnType, text: true),
            "sys.socket.shutdown" => RequireSocketUnitResultSignature(function, inputType, returnType),
            "sys.socket.bindDatagram" => RequireSocketBindDatagramSignature(function, inputType, returnType),
            "sys.socket.localPort" => RequireSocketLocalPortSignature(function, inputType, returnType),
            "sys.socket.sendTo" => RequireSocketSendToSignature(function, inputType, returnType),
            "sys.socket.receiveFrom" => RequireSocketReceiveFromSignature(function, inputType, returnType),
            "sys.file.openWriter" => RequireIntrinsicSignature(
                function, inputType, returnType, BoundType.Text, BoundType.Unit,
                BoundFunctionKind.RuntimeOpenIntWriter),
            "sys.file.closeWriter" => RequireIntrinsicSignature(
                function, inputType, returnType, expectedInputType: null, BoundType.Unit,
                BoundFunctionKind.RuntimeCloseIntWriter),
            "sys.file.openReader" => RequireIntrinsicSignature(
                function, inputType, returnType, BoundType.Text, BoundType.Unit,
                BoundFunctionKind.RuntimeOpenIntReader),
            "sys.file.closeReader" => RequireIntrinsicSignature(
                function, inputType, returnType, expectedInputType: null, BoundType.Unit,
                BoundFunctionKind.RuntimeCloseIntReader),
            _ => throw Error(function.Line, function.Column, $"unknown intrinsic function '{function.Name}'")
        };
    }

    private BoundFunctionKind RequireParallelIntrinsicSignature(FunctionDeclaration function)
    {
        if (function.GenericParameterName is null
            || function.SecondaryGenericParameterName is null
            || function.InputType != $"[{function.GenericParameterName}; ~]"
            || function.ReturnType != $"[{function.SecondaryGenericParameterName}; ~]"
            || function.BlockInputType != function.GenericParameterName
            || function.BlockResultType != function.SecondaryGenericParameterName)
        {
            throw Error(
                function.Line,
                function.Column,
                "intrinsic parallel<T, R> must be [T; ~] -> [R; ~] block item: T -> R");
        }

        return BoundFunctionKind.RuntimeParallel;
    }

    private BoundFunctionKind RequireTryParallelIntrinsicSignature(FunctionDeclaration function)
    {
        if (function.GenericParameterName is null
            || function.SecondaryGenericParameterName is null
            || function.TertiaryGenericParameterName is null
            || function.InputType != $"[{function.GenericParameterName}; ~]"
            || function.ReturnType != $"Result<[{function.SecondaryGenericParameterName}; ~], {function.TertiaryGenericParameterName}>"
            || function.BlockInputType != function.GenericParameterName
            || function.BlockResultType != $"Result<{function.SecondaryGenericParameterName}, {function.TertiaryGenericParameterName}>")
        {
            throw Error(
                function.Line,
                function.Column,
                "intrinsic tryParallel<T, R, E> must be [T; ~] -> Result<[R; ~], E> block item: T -> Result<R, E>");
        }

        return BoundFunctionKind.RuntimeTryParallel;
    }

    private BoundFunctionKind RequireSleepIntrinsicSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (!function.IsAsync
            || returnType != BoundType.Unit
            || inputType is not { } durationType
            || !_types.IsStruct(durationType)
            || !string.Equals(
                _types.GetStruct(durationType).Name,
                "sys.time.Duration",
                StringComparison.Ordinal))
        {
            throw Error(
                function.Line,
                function.Column,
                $"intrinsic function '{function.Name}' must be Duration -> async Unit");
        }

        return BoundFunctionKind.RuntimeSleep;
    }

    private BoundFunctionKind RequireEnvironmentIntrinsicSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType != BoundType.Text
            || !_types.TryGetOptionValue(returnType, out var valueType)
            || valueType != BoundType.Text)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature Text -> Option<Text>");
        }
        return BoundFunctionKind.RuntimeEnvironment;
    }

    private BoundFunctionKind RequireSecureRandomBytesSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType != BoundType.UIntSize
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != TypeId.DynamicUInt8Array
            || !_types.IsEnum(resultTypes.Error)
            || _types.GetEnum(resultTypes.Error).Name != "sys.crypto.random.Error")
        {
            throw Error(
                function.Line,
                function.Column,
                $"intrinsic '{function.Name}' must have signature "
                + "UIntSize -> Result<[UInt8; ~], sys.crypto.random.Error>");
        }

        return BoundFunctionKind.RuntimeSecureRandomBytes;
    }

    private BoundFunctionKind RequireReadDirectorySignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } pathType
            || !_types.IsStruct(pathType)
            || _types.GetStruct(pathType).Name != "sys.path.Path"
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !_types.IsStruct(resultTypes.Ok)
            || _types.GetStruct(resultTypes.Ok).Name != "sys.directory.Raw"
            || resultTypes.Error != BoundType.Text)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature Path -> Result<Raw, Text>");
        }

        return BoundFunctionKind.RuntimeReadDirectory;
    }

    private BoundFunctionKind RequireCreateDirectorySignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } pathType
            || !_types.IsStruct(pathType)
            || _types.GetStruct(pathType).Name != "sys.path.Path"
            || returnType != BoundType.Bool)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature Path -> Bool");
        }

        return BoundFunctionKind.RuntimeCreateDirectory;
    }

    private BoundFunctionKind RequirePathQuerySignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } pathType
            || !_types.IsStruct(pathType)
            || _types.GetStruct(pathType).Name != "sys.path.Path"
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !_types.IsStruct(resultTypes.Ok)
            || _types.GetStruct(resultTypes.Ok).Name != "sys.path.RawInfo"
            || resultTypes.Error != BoundType.Text)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature Path -> Result<RawInfo, Text>");
        }

        return BoundFunctionKind.RuntimePathQuery;
    }

    private BoundFunctionKind RequireOwnedFileSyncSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } writerType
            || !_types.IsStruct(writerType)
            || _types.GetStruct(writerType).Name != "sys.file.FileWriter"
            || returnType != BoundType.Bool
            || function.InputOwnership != FunctionInputOwnership.Default)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature FileWriter -> Bool");
        }
        return BoundFunctionKind.RuntimeSyncFile;
    }

    private BoundFunctionKind RequireAtomicReplaceSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } requestType
            || !_types.IsStruct(requestType)
            || _types.GetStruct(requestType) is not { Name: "sys.file.AtomicReplaceRequest" } request
            || request.Fields.Count != 2
            || request.GetField("temporary").Type != BoundType.Text
            || request.GetField("destination").Type != BoundType.Text
            || returnType != BoundType.Bool)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature AtomicReplaceRequest -> Bool");
        }
        return BoundFunctionKind.RuntimeAtomicReplaceFile;
    }

    private BoundFunctionKind RequireSocketListenSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } optionsType
            || !IsNamedStructType(optionsType, "sys.socket.ListenOptions")
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !IsNamedStructType(resultTypes.Ok, "sys.socket.TcpListener")
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature ListenOptions -> Result<TcpListener, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketListen;
    }

    private BoundFunctionKind RequireSocketConnectSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } endpointType
            || !IsNamedStructType(endpointType, "sys.socket.Endpoint")
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !IsNamedStructType(resultTypes.Ok, "sys.socket.TcpStream")
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature Endpoint -> Result<TcpStream, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketConnect;
    }

    private BoundFunctionKind RequireSocketOwnerResultSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        string inputName,
        string resultName,
        BoundFunctionKind kind)
    {
        if (inputType is not { } ownerType
            || !IsNamedStructType(ownerType, inputName)
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !IsNamedStructType(resultTypes.Ok, resultName)
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature {inputName.Split('.').Last()} -> Result<{resultName.Split('.').Last()}, SocketError>");
        }
        return kind;
    }

    private BoundFunctionKind RequireSocketReceiveSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        var parameters = function.AdditionalParameters ?? [];
        if (inputType is not { } streamType
            || !IsNamedStructType(streamType, "sys.socket.TcpStream")
            || parameters.Count != 1
            || parameters[0].TypeName != "UIntSize"
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !_types.IsDynamicArray(resultTypes.Ok)
            || _types.GetDynamicArray(resultTypes.Ok).ElementType != BoundType.UInt8
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature TcpStream, UIntSize -> Result<[UInt8; ~], SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketReceive;
    }

    private BoundFunctionKind RequireSocketSendSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        bool text)
    {
        var parameters = function.AdditionalParameters ?? [];
        var validAdditional = text
            ? parameters.Count == 1 && parameters[0].TypeName == "Text"
            : parameters.Count == 1 && parameters[0].TypeName == "ref [UInt8; ~]";
        if (inputType is not { } streamType
            || !IsNamedStructType(streamType, "sys.socket.TcpStream")
            || !validAdditional
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != BoundType.UIntSize
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            var payload = text ? "Text" : "ref [UInt8; ~]";
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature TcpStream, {payload} -> Result<UIntSize, SocketError>");
        }
        return text ? BoundFunctionKind.RuntimeSocketSendText : BoundFunctionKind.RuntimeSocketSend;
    }

    private BoundFunctionKind RequireSocketUnitResultSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } streamType
            || !IsNamedStructType(streamType, "sys.socket.TcpStream")
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Unit
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature TcpStream -> Result<Unit, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketShutdown;
    }

    private BoundFunctionKind RequireSocketBindDatagramSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } optionsType
            || !IsNamedStructType(optionsType, "sys.socket.DatagramBindOptions")
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !IsNamedStructType(resultTypes.Ok, "sys.socket.UdpSocket")
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature DatagramBindOptions -> Result<UdpSocket, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketBindDatagram;
    }

    private BoundFunctionKind RequireSocketSendToSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        var parameters = function.AdditionalParameters ?? [];
        if (inputType is not { } socketType
            || !IsNamedStructType(socketType, "sys.socket.UdpSocket")
            || parameters.Count != 2
            || parameters[0].TypeName is not ("Endpoint" or "sys.socket.Endpoint")
            || parameters[1].TypeName != "ref [UInt8; ~]"
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != BoundType.UIntSize
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature UdpSocket, Endpoint, ref [UInt8; ~] -> Result<UIntSize, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketSendTo;
    }

    private BoundFunctionKind RequireSocketLocalPortSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } socketType
            || !IsNamedStructType(socketType, "sys.socket.UdpSocket")
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != BoundType.UInt16
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature UdpSocket -> Result<UInt16, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketLocalPort;
    }

    private BoundFunctionKind RequireSocketReceiveFromSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        var parameters = function.AdditionalParameters ?? [];
        if (inputType is not { } socketType
            || !IsNamedStructType(socketType, "sys.socket.UdpSocket")
            || parameters.Count != 1
            || parameters[0].TypeName != "UIntSize"
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !IsNamedStructType(resultTypes.Ok, "sys.socket.Datagram")
            || !IsNamedStructType(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature UdpSocket, UIntSize -> Result<Datagram, SocketError>");
        }
        return BoundFunctionKind.RuntimeSocketReceiveFrom;
    }

    private BoundFunctionKind RequireProcessRunIntrinsicSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } argvType
            || !_types.IsDynamicArray(argvType)
            || _types.GetDynamicArray(argvType).ElementType != BoundType.Text
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Int
            || resultTypes.Error != BoundType.Text)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature [Text; ~] -> Result<Int, Text>");
        }
        return BoundFunctionKind.RuntimeRunProcess;
    }

    private BoundFunctionKind RequireProcessRunToFileIntrinsicSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (inputType is not { } requestType
            || !_types.IsStruct(requestType)
            || _types.GetStruct(requestType) is not { Name: "sys.process.RunToFileRequest" } request)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature RunToFileRequest -> Result<Int, Text>");
        }

        var argvField = request.Fields.FirstOrDefault(static field => field.Name == "argv");
        var outputField = request.Fields.FirstOrDefault(static field => field.Name == "output");
        if (request.Fields.Count != 2
            || argvField is null
            || outputField is null
            || !_types.IsDynamicArray(argvField.Type)
            || _types.GetDynamicArray(argvField.Type).ElementType != BoundType.Text
            || outputField.Type != BoundType.Text
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Int
            || resultTypes.Error != BoundType.Text)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature RunToFileRequest -> Result<Int, Text>");
        }
        return BoundFunctionKind.RuntimeRunProcessToFile;
    }

    private BoundFunctionKind RequireGenericScalarWriteSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType)
    {
        if (function.GenericParameterName is null
            || inputType != BoundType.GenericParameter
            || returnType != BoundType.Unit)
        {
            throw Error(function.Line, function.Column,
                $"intrinsic '{function.Name}' must have signature write<T>: T -> Unit");
        }
        return BoundFunctionKind.RuntimeWriteScalar;
    }

    private BoundFunctionKind RequireGenericScalarReadSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        bool isAsync)
    {
        if (function.GenericParameterName is null
            || inputType is not null
            || function.IsAsync != isAsync
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !_types.TryGetOptionValue(resultTypes.Ok, out var valueType)
            || valueType != BoundType.GenericParameter
            || resultTypes.Error != BoundType.Text)
        {
            throw Error(function.Line, function.Column,
                isAsync
                    ? $"intrinsic '{function.Name}' must have signature readAsync<T>: -> async Result<Option<T>, Text>"
                    : $"intrinsic '{function.Name}' must have signature read<T>: -> Result<Option<T>, Text>");
        }
        return isAsync
            ? BoundFunctionKind.RuntimeReadScalarAsync
            : BoundFunctionKind.RuntimeReadScalar;
    }

    private BoundFunctionKind RequireOpenFileSignature(
        FunctionDeclaration function,
        BoundType? inputType,
        BoundType returnType,
        string expectedTypeName,
        BoundFunctionKind kind,
        bool isAsync)
    {
        if (function.IsAsync != isAsync
            || inputType != BoundType.Text
            || !_types.TryGetResultTypes(returnType, out var resultTypes)
            || !IsNamedStructType(resultTypes.Ok, expectedTypeName)
            || resultTypes.Error != BoundType.Text)
        {
            throw Error(
                function.Line,
                function.Column,
                $"intrinsic '{function.Name}' must have signature Text -> "
                + (isAsync ? "async " : "")
                + $"Result<{expectedTypeName}, Text>");
        }

        return kind;
    }

    private BoundFunctionKind RequireIntrinsicSignature(
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

    private void AddGlobalAliases(Dictionary<string, BoundFunction> functions)
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
        AddGlobalAlias(functions, "nowMillis", "sys.time.nowMillis");
        AddGlobalAlias(functions, "milliseconds", "sys.time.milliseconds");
        AddGlobalAlias(functions, "seconds", "sys.time.seconds");
        AddGlobalAlias(functions, "sleep", "sys.time.sleep");
        AddGlobalAlias(functions, "parallel", "sys.runtime.parallel");
        AddGlobalAlias(functions, "tryParallel", "sys.runtime.tryParallel");
        AddGlobalAlias(functions, "limitParallelWorkers", "sys.runtime.limitParallelWorkers");
        AddGlobalAlias(functions, "parallelWorkers", "sys.runtime.parallelWorkers");
        AddGlobalAlias(functions, "parallelPeakWorkers", "sys.runtime.parallelPeakWorkers");
    }

    private void AddGlobalAlias(
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
        var previousDeclarations = _currentMutableDeclarations;
        var previousDeclarationsByName = _currentMutableDeclarationsByName;
        var previousFixedLengthCandidates = _currentFixedLengthArrayCandidates;
        var previousUsedTypes = _currentUsedTypes;
        _currentMutableDeclarations = [];
        _currentMutableDeclarationsByName = new Dictionary<string, MutableBindingDeclaration>(StringComparer.Ordinal);
        _currentFixedLengthArrayCandidates = new Dictionary<string, FixedLengthArrayCandidate>(StringComparer.Ordinal);
        _currentUsedTypes = [];
        try
        {
            var bindings = BindMainCore(functions);
            WarnUnusedMutableBindings();
            WarnFixedLengthGrowableArrays();
            return BindingsWithUsedTypes(bindings);
        }
        finally
        {
            _currentMutableDeclarations = previousDeclarations;
            _currentMutableDeclarationsByName = previousDeclarationsByName;
            _currentFixedLengthArrayCandidates = previousFixedLengthCandidates;
            _currentUsedTypes = previousUsedTypes;
        }
    }

    private IReadOnlyDictionary<string, BoundType> BindMainCore(IReadOnlyDictionary<string, BoundFunction> functions)
    {
        _currentModuleName = string.Join('.', _program.NamespacePath);
        _currentTypeScopeName = null;
        _currentFunctionReturnType = null;
        _currentMoveInputNames = new HashSet<string>(StringComparer.Ordinal);
        _currentFunctionOuterBindings = null;
        _currentFunctionAllowsEarlyReturn = false;
        _currentFunctionIsAsync = true;
        _currentFunctionEffects = null;
        _activeBorrowedTextOrigins.Clear();
        _activeReadonlyReferenceBindings.Clear();
        var bindings = new Dictionary<string, BoundType>(StringComparer.Ordinal);
        var mutableBindings = new HashSet<string>(StringComparer.Ordinal);
        var parentDeferredStreams = BeginDeferredStreamScope();
        BindStatements(
            _program.Statements,
            functions,
            bindings,
            mutableBindings,
            shortenBorrowRegions: true);
        EndDeferredStreamScope(parentDeferredStreams);
        return bindings;
    }

    private DeferredFlowScope BeginDeferredStreamScope()
    {
        var parent = new DeferredFlowScope(_currentDeferredStreams, _currentPartitions, _currentStreamJoins);
        _currentDeferredStreams = new Dictionary<string, DeferredStreamPlan>(StringComparer.Ordinal);
        _currentPartitions = new Dictionary<string, PendingPartitionPlan>(StringComparer.Ordinal);
        _currentStreamJoins = new Dictionary<string, PendingStreamJoinPlan>(StringComparer.Ordinal);
        return parent;
    }

    private void EndDeferredStreamScope(DeferredFlowScope parent)
    {
        if (_currentDeferredStreams.Count != 0)
        {
            var unconsumed = _currentDeferredStreams.First();
            throw Error(
                unconsumed.Value.Line,
                unconsumed.Value.Column,
                $"{(unconsumed.Value.IsEvent ? "EventStream" : "Stream")} binding '{unconsumed.Key}' "
                + "must be consumed exactly once with each");
        }

        if (_currentPartitions.Count != 0)
        {
            var unconsumed = _currentPartitions.First();
            var missing = unconsumed.Value.Expression.Arms
                .Where(arm => !unconsumed.Value.Consumers.ContainsKey(arm.Label))
                .Select(static arm => arm.Label);
            throw Error(
                unconsumed.Value.Expression.Line,
                unconsumed.Value.Expression.Column,
                $"partition binding '{unconsumed.Key}' must consume every route exactly once; missing: {string.Join(", ", missing)}");
        }
        if (_currentStreamJoins.Count != 0)
        {
            var unconsumed = _currentStreamJoins.First();
            throw Error(
                unconsumed.Value.Expression.Line,
                unconsumed.Value.Expression.Column,
                $"{unconsumed.Value.Join.Policy.ToString().ToLowerInvariant()} binding '{unconsumed.Key}' must be consumed exactly once");
        }

        _currentDeferredStreams = parent.Streams;
        _currentPartitions = parent.Partitions;
        _currentStreamJoins = parent.Joins;
    }

    private void BindStatements(
        IReadOnlyList<Statement> statements,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string>? mutableBindings = null,
        BoundType? yieldInputType = null,
        bool allowContainerBindings = true,
        Expression? borrowRegionResult = null,
        bool shortenBorrowRegions = false,
        IReadOnlySet<string>? borrowRegionContinuation = null,
        bool retainMutableDeclarationScope = false)
    {
        mutableBindings ??= new HashSet<string>(StringComparer.Ordinal);
        var parentMutableDeclarationsByName = _currentMutableDeclarationsByName is null
            ? null
            : new Dictionary<string, MutableBindingDeclaration>(
                _currentMutableDeclarationsByName,
                StringComparer.Ordinal);
        try
        {
        for (var statementIndex = 0; statementIndex < statements.Count; statementIndex++)
        {
            if (shortenBorrowRegions)
            {
                ExpireBorrowedTextOriginsBeforeStatement(
                    statements,
                    statementIndex,
                    borrowRegionResult,
                    borrowRegionContinuation);
            }

            var parentBorrowedTextContinuation = _borrowedTextContinuationNames;
            _borrowedTextContinuationNames = BorrowedTextContinuationAfterStatement(
                statements,
                statementIndex,
                borrowRegionResult,
                borrowRegionContinuation);
            var statement = statements[statementIndex];
            switch (statement)
            {
                case BindingStatement binding:
                    if (binding.IsStreamState)
                    {
                        if (_currentStreamElementType is null)
                        {
                            throw Error(binding.Line, binding.Column, "state bindings are valid only inside stream functions");
                        }
                        if (!binding.IsMutable)
                        {
                            throw Error(binding.Line, binding.Column, "stream state must be mutable; use 'state name! = value'");
                        }
                        if (bindings.ContainsKey(binding.Name))
                        {
                            throw Error(binding.Line, binding.Column, $"stream state '{binding.Name}' is already declared");
                        }
                    }
                    ValidateBindingName(binding.Name, binding.Line, binding.Column);
                    var reboundType = default(BoundType);
                    var isMutableRebind = binding.IsMutable
                        && bindings.TryGetValue(binding.Name, out reboundType)
                        && mutableBindings.Contains(binding.Name)
                        && !IsContainerType(reboundType);
                    if (isMutableRebind)
                    {
                        MarkMutableBindingMutation(binding.Name);
                    }
                    var movedSourceName = GetMoveConsumingContainerSourceName(binding.Value, functions)
                        ?? (binding.Value is NameExpression
                            ? MoveInputNameForExpression(binding.Value)
                            : null);
                    var movedFieldOwnerName = GetMoveConsumingOwnedFieldOwnerName(binding.Value, bindings);
                    var movedFieldOwnerPlace = GetMoveConsumingOwnedFieldPlace(binding.Value, bindings);
                    var consumedSourceNames = GetOwnedParameterConsumedSourceNames(binding.Value, functions, bindings);
                    var bindingMutationConsumedSourceNames = GetOwnedContainerMutationConsumedSourceNames(
                        binding.Value,
                        bindings);
                    var valueType = isMutableRebind
                        ? InferContextualValue(
                            binding.Value,
                            reboundType,
                            functions,
                            bindings,
                            allowReadIntCall: true,
                            mutableBindings,
                            yieldInputType)
                        : InferExpression(
                            binding.Value,
                            functions,
                            bindings,
                            allowPrintCall: false,
                            allowReadIntCall: true,
                            allowFlowBindingTarget: false,
                            yieldInputType: yieldInputType,
                            mutableBindings: mutableBindings);
                    _currentUsedTypes?.Add(valueType);
                    if (valueType == BoundType.Unit)
                    {
                        throw Error(binding.Line, binding.Column, "cannot bind a unit value");
                    }
                    if (valueType == BoundType.Text && IsUnmaterializedDeferredText(binding.Value))
                    {
                        throw Error(
                            binding.Value.Line,
                            binding.Value.Column,
                            "deferred interpolation cannot be stored directly; materialize it into an explicit Arena owner");
                    }
                    var aggregateLiteralSourceNames = GetOwnedAggregateLiteralSourceNames(
                        binding.Value,
                        bindings,
                        valueType);
                    var transferredSourceNames = aggregateLiteralSourceNames
                        .Concat(bindingMutationConsumedSourceNames)
                        .Distinct(StringComparer.Ordinal)
                        .ToArray();
                    RejectBorrowedTextOriginInvalidation(
                        movedSourceName,
                        movedFieldOwnerPlace,
                        consumedSourceNames,
                        transferredSourceNames,
                        binding.Name,
                        isMutableRebind,
                        binding.Line,
                        binding.Column);
                    if (bindings.ContainsKey(binding.Name)
                        && !isMutableRebind
                        && !string.Equals(binding.Name, movedSourceName, StringComparison.Ordinal)
                        && !string.Equals(binding.Name, movedFieldOwnerName, StringComparison.Ordinal)
                        && !consumedSourceNames.Contains(binding.Name, StringComparer.Ordinal)
                        && !aggregateLiteralSourceNames.Contains(binding.Name, StringComparer.Ordinal))
                    {
                        throw Error(binding.Line, binding.Column, $"binding '{binding.Name}' already exists in this scope");
                    }
                    if (isMutableRebind && valueType != reboundType)
                    {
                        throw Error(binding.Line, binding.Column,
                            $"mutable rebind of '{binding.Name}' requires {FormatType(reboundType)} but received {FormatType(valueType)}");
                    }
                    if (valueType == BoundType.MutableMappedBytes && !binding.IsMutable)
                    {
                        throw Error(binding.Line, binding.Column,
                            "map write requires a mutable owner binding; use '=> name!'");
                    }

                    if (IsContainerType(valueType))
                    {
                        if (!allowContainerBindings)
                        {
                            throw Error(
                                binding.Line,
                                binding.Column,
                                "owned containers can only be bound in a scope where the compiler can insert deterministic drops");
                        }

                        if (!IsContainerCreationExpression(binding.Value)
                            && movedSourceName is null
                            && movedFieldOwnerName is null)
                        {
                            throw Error(
                                binding.Line,
                                binding.Column,
                                "owned container values must be created directly at their binding site in the current slice");
                        }
                    }

                    if (movedSourceName is not null)
                    {
                        bindings.Remove(movedSourceName);
                        mutableBindings.Remove(movedSourceName);
                    }
                    if (movedFieldOwnerName is not null)
                    {
                        bindings.Remove(movedFieldOwnerName);
                        mutableBindings.Remove(movedFieldOwnerName);
                    }

                    ValidateOwnedParameterConsumptionExpression(binding.Value, functions, bindings);
                    foreach (var consumedName in consumedSourceNames)
                    {
                        bindings.Remove(consumedName);
                        mutableBindings.Remove(consumedName);
                    }
                    foreach (var transferredName in aggregateLiteralSourceNames)
                    {
                        bindings.Remove(transferredName);
                        mutableBindings.Remove(transferredName);
                    }
                    foreach (var transferredName in bindingMutationConsumedSourceNames)
                    {
                        bindings.Remove(transferredName);
                        mutableBindings.Remove(transferredName);
                    }

                    if (!isMutableRebind)
                    {
                        bindings.Add(binding.Name, valueType);
                    }
                    if (binding.IsMutable)
                    {
                        mutableBindings.Add(binding.Name);
                        if (!isMutableRebind && !binding.IsStreamState)
                        {
                            RegisterMutableBinding(binding.Name, binding.Line, binding.Column);
                        }
                    }
                    RegisterFixedLengthArrayCandidate(binding, valueType);
                    var hasBorrowedTextOrigins = TryGetBorrowedTextCallOrigins(
                        binding.Value,
                        functions,
                        bindings,
                        out var borrowedOrigins);
                    if (isMutableRebind)
                    {
                        // Rebinding a view kills its previous loan. If the new
                        // value is another view, install that origin set below;
                        // an owned/static Text leaves no active origin.
                        _activeBorrowedTextOrigins.Remove(binding.Name);
                        _activeReadonlyReferenceBindings.Remove(binding.Name);
                    }
                    if (hasBorrowedTextOrigins)
                    {
                        _activeBorrowedTextOrigins[binding.Name] = borrowedOrigins;
                    }
                    else
                    {
                        var readonlyReferenceCarriers = GetReadonlyReferenceCarrierOrigins(
                            binding.Value,
                            valueType,
                            functions,
                            bindings);
                        foreach (var carrier in readonlyReferenceCarriers)
                        {
                            var carrierName = binding.Name + carrier.Key;
                            _activeBorrowedTextOrigins[carrierName] = carrier.Value;
                            _activeReadonlyReferenceBindings.Add(carrierName);
                        }
                    }

                    if (binding.Value is PartitionExpression partition)
                    {
                        if (binding.IsMutable)
                        {
                            throw Error(binding.Line, binding.Column, "partition route products are affine and cannot be mutable");
                        }
                        if (!_partitionExpressionSources.TryGetValue(partition, out var partitionSource))
                        {
                            throw new InvalidOperationException("partition source type was not recorded during inference");
                        }
                        _currentPartitions.Add(
                            binding.Name,
                            new PendingPartitionPlan(
                                binding,
                                partition,
                                partitionSource.ElementType,
                                partitionSource.IsEvent));
                        _deferredStreamDeclarations.Add(binding);
                    }
                    if (binding.Value is StreamJoinExpression join)
                    {
                        if (binding.IsMutable)
                        {
                            throw Error(binding.Line, binding.Column, "stream join results are affine and cannot be mutable");
                        }
                        if (!_streamJoins.TryGetValue(join, out var boundJoin))
                        {
                            throw new InvalidOperationException("stream join metadata was not recorded during inference");
                        }
                        _currentStreamJoins.Add(
                            binding.Name,
                            new PendingStreamJoinPlan(binding, join, boundJoin));
                        _deferredStreamDeclarations.Add(binding);
                    }

                    break;
                case IndexAssignmentStatement assignment:
                    MarkMutableBindingMutation(assignment.Name);
                    RejectBorrowedTextOriginMutation(
                        BorrowOriginIndexedPlace(assignment.Name, assignment.Index),
                        assignment.Line,
                        assignment.Column);
                    BindIndexAssignment(assignment, functions, bindings, mutableBindings, yieldInputType);
                    break;
                case FieldAssignmentStatement assignment:
                    MarkMutableBindingMutation(assignment.Name);
                    RejectBorrowedTextOriginMutation(
                        $"{CanonicalBorrowOriginName(assignment.Name)}.{assignment.FieldName}",
                        assignment.Line,
                        assignment.Column);
                    BindFieldAssignment(assignment, functions, bindings, mutableBindings, yieldInputType);
                    break;
                case BlockFunctionCallStatement blockFunctionCall:
                    BindBlockFunctionCall(blockFunctionCall, functions, bindings, mutableBindings, yieldInputType);
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    BindBlockFunctionPipeline(pipeline, functions, bindings, mutableBindings, yieldInputType);
                    break;
                case LoopControlStatement loopControl:
                    if (_loopDepth == 0)
                    {
                        throw Error(
                            loopControl.Line,
                            loopControl.Column,
                            $"'{loopControl.Kind.ToString().ToLowerInvariant()}' is only valid inside a loop");
                    }
                    _borrowedTextContinuationNames = parentBorrowedTextContinuation;
                    return;
                case StreamStopStatement stop:
                    if (_currentStreamElementType is null && !_allowStreamStop)
                    {
                        throw Error(stop.Line, stop.Column, "'stop' is valid only inside a stream function");
                    }
                    break;
                case GuardLoopControlStatement guardLoopControl:
                    if (_loopDepth == 0)
                    {
                        throw Error(
                            guardLoopControl.Line,
                            guardLoopControl.Column,
                            $"'{guardLoopControl.Kind.ToString().ToLowerInvariant()}' guard is only valid inside a loop");
                    }
                    NoteLongControlCondition(
                        guardLoopControl.Condition,
                        guardLoopControl.Line,
                        guardLoopControl.Kind == LoopControlKind.Break ? "if break" : "if continue");
                    var guardType = InferExpression(
                        guardLoopControl.Condition,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall: true,
                        allowFlowBindingTarget: false,
                        yieldInputType: yieldInputType,
                        mutableBindings: mutableBindings);
                    if (guardType != BoundType.Bool)
                    {
                        throw Error(
                            guardLoopControl.Condition.Line,
                            guardLoopControl.Condition.Column,
                            $"loop-control guard requires Bool but received {FormatType(guardType)}");
                    }
                    ValidateOwnedParameterConsumptionExpression(guardLoopControl.Condition, functions, bindings);
                    break;
                case ReturnStatement returnStatement:
                    if (_currentFunctionReturnType is null)
                    {
                        throw Error(
                            returnStatement.Line,
                            returnStatement.Column,
                            "'return' is only valid inside a value or Unit function");
                    }
                    if (_currentFunctionIsAsync)
                    {
                        throw Error(
                            returnStatement.Line,
                            returnStatement.Column,
                            "explicit return in an async function is not supported in the first runtime slice");
                    }
                    if (!_currentFunctionAllowsEarlyReturn)
                    {
                        throw Error(
                            returnStatement.Line,
                            returnStatement.Column,
                            "explicit return from a block function is not supported yet");
                    }

                    var returnType = returnStatement.Value is null
                        ? BoundType.Unit
                        : InferContextualValue(
                            returnStatement.Value,
                            _currentFunctionReturnType.Value,
                            functions,
                            bindings,
                            allowReadIntCall: true,
                            mutableBindings: mutableBindings,
                            yieldInputType: yieldInputType,
                            allowedOwnedOuterResultName: MoveInputNameForExpression(returnStatement.Value));
                    if (returnStatement.Value is not null)
                    {
                        MarkFixedLengthCandidateRequiresGrowable(
                            returnStatement.Value,
                            _currentFunctionReturnType,
                            returnType);
                    }
                    if (!IsFunctionReturnCompatible(
                            returnStatement.Value,
                            returnType,
                            _currentFunctionReturnType.Value,
                            bindings))
                    {
                        throw Error(
                            returnStatement.Line,
                            returnStatement.Column,
                            $"return requires {FormatType(_currentFunctionReturnType.Value)} but received {FormatType(returnType)}");
                    }

                    if (returnStatement.Value is not null)
                    {
                        ValidateOwnedParameterConsumptionExpression(returnStatement.Value, functions, bindings);
                        if (!_types.IsReference(_currentFunctionReturnType.Value)
                            && IsContainerType(returnType))
                        {
                            EnsureOwnedContainerCanLeaveBlock(
                                returnStatement.Value,
                                _currentFunctionOuterBindings
                                    ?? throw new SollangException("missing function return ownership scope"),
                                bindings,
                                MoveInputNameForExpression(returnStatement.Value));
                        }
                    }
                    _borrowedTextContinuationNames = parentBorrowedTextContinuation;
                    return;
                case ExpressionStatement expressionStatement:
                    var movedExpressionSourceName = GetMoveConsumingContainerSourceName(
                        expressionStatement.Expression,
                        functions);
                    var effect = InferExpressionStatement(expressionStatement.Expression, functions, bindings, mutableBindings, yieldInputType);
                    var mutatedContainerSourceNames = GetOwnedContainerMutationConsumedSourceNames(
                        expressionStatement.Expression,
                        bindings);
                    var consumedExpressionSourceNames = GetOwnedParameterConsumedSourceNames(
                        expressionStatement.Expression,
                        functions,
                        bindings);
                    RejectBorrowedTextOriginInvalidation(
                        movedExpressionSourceName,
                        null,
                        consumedExpressionSourceNames,
                        mutatedContainerSourceNames,
                        null,
                        false,
                        expressionStatement.Expression.Line,
                        expressionStatement.Expression.Column);
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
                        if (TryGetBorrowedTextCallOrigins(
                                expressionStatement.Expression,
                                functions,
                                bindings,
                                out var flowBorrowedOrigins))
                        {
                            _activeBorrowedTextOrigins[bindingEffect.Name] = flowBorrowedOrigins;
                        }
                        else if (TryGetReadonlyReferenceCallOrigins(
                                     expressionStatement.Expression,
                                     functions,
                                     bindings,
                                     out var flowReferenceOrigins))
                        {
                            _activeBorrowedTextOrigins[bindingEffect.Name] = flowReferenceOrigins;
                            _activeReadonlyReferenceBindings.Add(bindingEffect.Name);
                        }
                    }

                    ValidateOwnedParameterConsumptionExpression(expressionStatement.Expression, functions, bindings);
                    foreach (var consumedName in consumedExpressionSourceNames)
                    {
                        bindings.Remove(consumedName);
                        mutableBindings.Remove(consumedName);
                    }
                    if (movedExpressionSourceName is not null)
                    {
                        bindings.Remove(movedExpressionSourceName);
                        mutableBindings.Remove(movedExpressionSourceName);
                    }
                    foreach (var transferredSourceName in mutatedContainerSourceNames)
                    {
                        bindings.Remove(transferredSourceName);
                        mutableBindings.Remove(transferredSourceName);
                    }

                    break;
                default:
                    throw new SollangException($"unsupported statement {statement.GetType().Name}");
            }
            _borrowedTextContinuationNames = parentBorrowedTextContinuation;
        }
        }
        finally
        {
            if (!retainMutableDeclarationScope)
            {
                _currentMutableDeclarationsByName = parentMutableDeclarationsByName;
            }
        }
    }

    private void BindFieldAssignment(
        FieldAssignmentStatement assignment,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType)
    {
        if (!bindings.TryGetValue(assignment.Name, out var targetType))
        {
            throw Error(assignment.Line, assignment.Column, $"unknown binding '{assignment.Name}'");
        }

        if (!_types.IsStruct(targetType))
        {
            throw Error(assignment.Line, assignment.Column, "field assignment expects a struct owner");
        }

        if (!mutableBindings.Contains(assignment.Name))
        {
            throw Error(
                assignment.Line,
                assignment.Column,
                $"field assignment requires a mutable owner binding; use '{assignment.Name.TrimEnd('!')}!'");
        }

        var definition = _types.GetStruct(targetType);
        if (definition.ComInterface is not null || definition.NativeHandle is not null)
        {
            throw Error(
                assignment.Line,
                assignment.Column,
                $"opaque handle '{definition.Name}' cannot be mutated directly");
        }
        var field = definition.Fields.FirstOrDefault(candidate => candidate.Name == assignment.FieldName)
            ?? throw Error(
                assignment.Line,
                assignment.Column,
                $"struct '{definition.Name}' has no field '{assignment.FieldName}'");
        var valueType = InferExpression(
            assignment.Value,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false,
            yieldInputType: yieldInputType,
            mutableBindings: mutableBindings);
        if (valueType != field.Type)
        {
            throw Error(
                assignment.Value.Line,
                assignment.Value.Column,
                $"field '{definition.Name}.{field.Name}' expects {FormatType(field.Type)}, got {FormatType(valueType)}");
        }

        var transferred = new HashSet<string>(StringComparer.Ordinal);
        var movedSourceName = GetMoveConsumingContainerSourceName(assignment.Value, functions);
        if (movedSourceName is not null)
        {
            transferred.Add(movedSourceName);
        }
        foreach (var consumedName in GetOwnedParameterConsumedSourceNames(
                     assignment.Value, functions, bindings))
        {
            transferred.Add(consumedName);
        }
        foreach (var fieldSourceName in GetOwnedAggregateLiteralSourceNames(
                     assignment.Value, bindings, field.Type))
        {
            transferred.Add(fieldSourceName);
        }

        if (_types.ContainsOwnedStorage(field.Type)
            && assignment.Value is NameExpression sourceName)
        {
            if (string.Equals(sourceName.Name, assignment.Name, StringComparison.Ordinal))
            {
                throw Error(
                    assignment.Line,
                    assignment.Column,
                    "an owned field cannot be replaced from its containing owner");
            }
            transferred.Add(sourceName.Name);
        }

        if (_types.ContainsOwnedStorage(field.Type)
            && transferred.Count == 0
            && !IsContainerCreationExpression(assignment.Value))
        {
            throw Error(
                assignment.Value.Line,
                assignment.Value.Column,
                $"owned field '{definition.Name}.{field.Name}' requires a fresh value or a named owner transfer");
        }

        foreach (var transferredName in transferred)
        {
            bindings.Remove(transferredName);
            mutableBindings.Remove(transferredName);
        }
    }

    private void BindIndexAssignment(
        IndexAssignmentStatement assignment,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType)
    {
        if (!bindings.TryGetValue(assignment.Name, out var targetType))
        {
            throw Error(assignment.Line, assignment.Column, $"unknown binding '{assignment.Name}'");
        }

        var isDynamicArray = _types.IsDynamicArray(targetType);
        var isStaticArray = _types.IsStaticArray(targetType);
        var isBoundedArray = _types.IsBoundedArray(targetType);
        var isGenericDictionary = _types.IsDictionary(targetType);
        if (targetType is not (BoundType.StaticIntArray or BoundType.DynamicIntArray or BoundType.IntDictionary
            or BoundType.MutableMappedBytes)
            && !isStaticArray && !isDynamicArray && !isBoundedArray && !isGenericDictionary)
        {
            throw Error(assignment.Line, assignment.Column, "indexed assignment expects an array or dictionary owner");
        }

        if (!mutableBindings.Contains(assignment.Name))
        {
            throw Error(
                assignment.Line,
                assignment.Column,
                $"indexed assignment requires a mutable owner binding; use '=> {assignment.Name.TrimEnd('!')}!'");
        }

        var expectedIndexType = targetType == BoundType.MutableMappedBytes
            ? BoundType.UIntSize
            : isGenericDictionary
                ? _types.GetDictionary(targetType).KeyType
                : BoundType.Int;
        var expectedValueType = targetType == BoundType.MutableMappedBytes
            ? BoundType.UInt8
            : isStaticArray
                ? _types.GetStaticArray(targetType).ElementType
                : isBoundedArray
                ? _types.GetBoundedArray(targetType).ElementType
                : isDynamicArray
                ? _types.GetDynamicArray(targetType).ElementType
                : isGenericDictionary
                    ? _types.GetDictionary(targetType).ValueType
                    : BoundType.Int;
        var valueType = InferContextualValue(
            assignment.Value,
            expectedValueType,
            functions,
            bindings,
            allowReadIntCall: true);
        if (valueType != expectedValueType)
        {
            throw Error(assignment.Value.Line, assignment.Value.Column,
                $"indexed assignment value must be {FormatType(expectedValueType)}");
        }

        if (_types.ContainsOwnedStorage(expectedValueType))
        {
            var transferred = new HashSet<string>(StringComparer.Ordinal);
            var movedSourceName = GetMoveConsumingContainerSourceName(assignment.Value, functions);
            if (movedSourceName is not null)
            {
                transferred.Add(movedSourceName);
            }
            foreach (var consumedName in GetOwnedParameterConsumedSourceNames(
                         assignment.Value, functions, bindings))
            {
                transferred.Add(consumedName);
            }
            foreach (var fieldSourceName in GetOwnedAggregateLiteralSourceNames(
                         assignment.Value, bindings, expectedValueType))
            {
                transferred.Add(fieldSourceName);
            }

            if (assignment.Value is NameExpression sourceName)
            {
                if (string.Equals(sourceName.Name, assignment.Name, StringComparison.Ordinal))
                {
                    throw Error(
                        assignment.Line,
                        assignment.Column,
                        "an owned indexed value cannot be replaced from its containing owner");
                }
                transferred.Add(sourceName.Name);
            }

            if (transferred.Count == 0 && !IsContainerCreationExpression(assignment.Value))
            {
                throw Error(
                    assignment.Value.Line,
                    assignment.Value.Column,
                    "owned indexed replacement requires a fresh value or a named owner transfer");
            }

            foreach (var transferredName in transferred)
            {
                bindings.Remove(transferredName);
                mutableBindings.Remove(transferredName);
            }
        }

        var indexType = assignment.Index is NumberExpression && targetType == BoundType.MutableMappedBytes
            ? BoundType.UIntSize
            : assignment.Index is DictionaryLiteralExpression contextualIndex
              && _types.IsStruct(expectedIndexType)
                ? InferContextualStructLiteral(
                    contextualIndex,
                    expectedIndexType,
                    functions,
                    bindings,
                    allowReadIntCall: true)
                : InferExpression(
                    assignment.Index,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall: true,
                    allowFlowBindingTarget: false,
                    yieldInputType: yieldInputType,
                    mutableBindings: mutableBindings);
        if (indexType != expectedIndexType)
        {
            throw Error(assignment.Index.Line, assignment.Index.Column,
                $"indexed assignment index must be {FormatType(expectedIndexType)}");
        }
    }

    private void BindBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType)
    {
        var partitionPipeline = new BlockFunctionPipelineStatement([call], call.Line, call.Column);
        if (TryBindStreamJoinPipeline(
                partitionPipeline,
                functions,
                bindings,
                mutableBindings,
                call))
        {
            return;
        }
        if (TryBindPartitionRoutePipeline(
                partitionPipeline,
                functions,
                bindings,
                mutableBindings,
                call))
        {
            return;
        }
        var target = string.Join('.', call.Target);
        if (call.Source is NameExpression eventSource
            && ((_currentDeferredStreams.TryGetValue(eventSource.Name, out var eventPlan)
                    && eventPlan.EventSource is not null)
                || (bindings.TryGetValue(eventSource.Name, out var eventSourceType)
                    && (_types.IsEventStream(eventSourceType) || _types.IsStream(eventSourceType)))))
        {
            var pipeline = new BlockFunctionPipelineStatement([call], call.Line, call.Column);
            if (TryBindEventStreamingPipeline(
                    pipeline,
                    functions,
                    bindings,
                    mutableBindings,
                    call))
            {
                return;
            }
        }
        if ((call.Source is NameExpression streamSource
                && _currentDeferredStreams.TryGetValue(streamSource.Name, out var streamPlan)
                && streamPlan.EventSource is null)
            || (TryGetFunction(target, functions, out var possibleStreamFunction)
                && (possibleStreamFunction.StreamElementType is not null
                    || possibleStreamFunction.StreamElementTypeTemplate is not null)))
        {
            var pipeline = new BlockFunctionPipelineStatement([call], call.Line, call.Column);
            if (TryBindStreamingPipeline(
                    pipeline,
                    functions,
                    bindings,
                    mutableBindings,
                    call))
            {
                return;
            }
        }

        switch (target)
        {
            case "each":
                RejectBuiltInBlockResult(call, target);
                BindEachBlockFunctionCall(call, functions, bindings, mutableBindings, yieldInputType);
                return;
            case "eachKey":
                RejectBuiltInBlockResult(call, target);
                BindDictionaryEachBlockFunctionCall(call, functions, bindings, mutableBindings, yieldInputType, bindKey: true);
                return;
            case "eachValue":
                RejectBuiltInBlockResult(call, target);
                BindDictionaryEachBlockFunctionCall(call, functions, bindings, mutableBindings, yieldInputType, bindKey: false);
                return;
            case "repeat":
                RejectBuiltInBlockResult(call, target);
                BindRepeatBlockFunctionCall(call, functions, bindings, mutableBindings, yieldInputType);
                return;
            case "while":
                RejectBuiltInBlockResult(call, target);
                BindWhileBlockFunctionCall(call, functions, bindings, mutableBindings, yieldInputType);
                return;
            default:
                if (functions.TryGetValue(target, out var function)
                    && function.Kind is BoundFunctionKind.UserBlock
                        or BoundFunctionKind.RuntimeParallel
                        or BoundFunctionKind.RuntimeTryParallel)
                {
                    BindUserBlockFunctionCall(call, function, functions, bindings, mutableBindings, target);
                    return;
                }

                throw Error(call.Line, call.Column, $"unknown block function '{target}'");
        }
    }

    private void BindBlockFunctionPipeline(
        BlockFunctionPipelineStatement pipeline,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType)
    {
        if (TryBindStreamJoinPipeline(
                pipeline,
                functions,
                bindings,
                mutableBindings,
                pipeline))
        {
            return;
        }
        if (TryBindPartitionRoutePipeline(
                pipeline,
                functions,
                bindings,
                mutableBindings,
                pipeline))
        {
            return;
        }
        if (pipeline.Calls[0].Source is NameExpression eventSource
            && ((_currentDeferredStreams.TryGetValue(eventSource.Name, out var eventPlan)
                    && eventPlan.EventSource is not null)
                || (bindings.TryGetValue(eventSource.Name, out var eventSourceType)
                    && (_types.IsEventStream(eventSourceType) || _types.IsStream(eventSourceType))))
            && TryBindEventStreamingPipeline(
                pipeline,
                functions,
                bindings,
                mutableBindings,
                pipeline))
        {
            return;
        }
        if (TryBindStreamingPipeline(pipeline, functions, bindings, mutableBindings, pipeline))
        {
            return;
        }

        for (var index = 0; index < pipeline.Calls.Count; index++)
        {
            BindBlockFunctionCall(pipeline.Calls[index], functions, bindings, mutableBindings, yieldInputType);
        }
    }

    private bool TryBindStreamJoinPipeline(
        BlockFunctionPipelineStatement pipeline,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        Statement originalStatement)
    {
        PendingStreamJoinPlan plan;
        string? sourceBindingName = null;
        if (pipeline.Calls[0].Source is NameExpression source
            && _currentStreamJoins.TryGetValue(source.Name, out var pending))
        {
            plan = pending;
            sourceBindingName = source.Name;
        }
        else if (pipeline.Calls[0].Source is StreamJoinExpression directJoin
            && _streamJoins.TryGetValue(directJoin, out var directBoundJoin))
        {
            plan = new PendingStreamJoinPlan(
                new BindingStatement("$direct_join", directJoin, directJoin.Line, directJoin.Column, IsMutable: false),
                directJoin,
                directBoundJoin);
        }
        else
        {
            return false;
        }

        var currentElementType = (BoundType)plan.Join.OutputElementType;
        for (var index = 0; index < pipeline.Calls.Count; index++)
        {
            var call = pipeline.Calls[index];
            var target = string.Join('.', call.Target);
            if (target == "each")
            {
                if (index != pipeline.Calls.Count - 1)
                {
                    throw Error(call.Line, call.Column, "each must terminate a stream join pipeline");
                }
                BindEachBlockBody(
                    call,
                    currentElementType,
                    functions,
                    bindings,
                    mutableBindings,
                    allowStreamStop: true);
                break;
            }

            if (!TryGetFunction(target, functions, out var streamFunction)
                || (streamFunction.StreamElementType is null
                    && streamFunction.StreamElementTypeTemplate is null))
            {
                if (index != pipeline.Calls.Count - 1
                    || !TryGetFunction(target, functions, out var terminalFunction)
                    || terminalFunction.Kind != BoundFunctionKind.UserBlock)
                {
                    throw Error(
                        call.Line,
                        call.Column,
                        "a stream join pipeline may end only with each or a Unit block function");
                }
                BindUserBlockFunctionCall(
                    call,
                    terminalFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    terminalFunction.Name,
                    streamedInputType: currentElementType);
                if (terminalFunction.ReturnType != BoundType.Unit)
                {
                    throw Error(call.Line, call.Column, "a stream join terminal must return Unit");
                }
                break;
            }

            if (streamFunction.Kind == BoundFunctionKind.User
                && streamFunction.BlockInputType is null)
            {
                BindBlocklessStreamFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    currentElementType);
            }
            else
            {
                BindUserBlockFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    streamFunction.Name,
                    suppressResultBinding: true,
                    streamedInputType: currentElementType);
            }
            streamFunction = _resolvedGenericCalls.TryGetValue(call, out var specialization)
                ? specialization
                : streamFunction;
            currentElementType = streamFunction.StreamElementType
                ?? throw Error(call.Line, call.Column, "stream join element type was not specialized");
        }

        _streamJoinConsumers.Add(
            originalStatement,
            new BoundStreamJoinPipeline(plan.Expression, plan.Join, pipeline));
        if (sourceBindingName is not null)
        {
            _currentStreamJoins.Remove(sourceBindingName);
            bindings.Remove(sourceBindingName);
            mutableBindings.Remove(sourceBindingName);
        }
        return true;
    }

    private bool TryBindPartitionRoutePipeline(
        BlockFunctionPipelineStatement pipeline,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        Statement originalStatement)
    {
        if (pipeline.Calls[0].Source is not FieldAccessExpression
            {
                Source: NameExpression owner
            } routeAccess
            || !_currentPartitions.TryGetValue(owner.Name, out var partition))
        {
            return false;
        }

        var arm = partition.Expression.Arms.FirstOrDefault(candidate => candidate.Label == routeAccess.FieldName)
            ?? throw Error(
                routeAccess.Line,
                routeAccess.Column,
                $"partition '{owner.Name}' has no route '{routeAccess.FieldName}'");
        if (partition.Consumers.ContainsKey(arm.Label))
        {
            throw Error(
                routeAccess.Line,
                routeAccess.Column,
                $"partition route '{owner.Name}.{arm.Label}' must be consumed exactly once");
        }

        var currentElementType = partition.SourceElementType;
        for (var index = 0; index < pipeline.Calls.Count; index++)
        {
            var call = pipeline.Calls[index];
            var target = string.Join('.', call.Target);
            if (target == "each")
            {
                if (index != pipeline.Calls.Count - 1)
                {
                    throw Error(call.Line, call.Column, "each must terminate a partition route pipeline");
                }
                BindEachBlockBody(
                    call,
                    currentElementType,
                    functions,
                    bindings,
                    mutableBindings,
                    allowStreamStop: true);
                break;
            }

            if (!TryGetFunction(target, functions, out var streamFunction)
                || (streamFunction.StreamElementType is null
                    && streamFunction.StreamElementTypeTemplate is null))
            {
                if (index != pipeline.Calls.Count - 1
                    || !TryGetFunction(target, functions, out var terminalFunction)
                    || terminalFunction.Kind != BoundFunctionKind.UserBlock)
                {
                    throw Error(
                        call.Line,
                        call.Column,
                        "a partition route pipeline may end only with each or a Unit block function");
                }
                BindUserBlockFunctionCall(
                    call,
                    terminalFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    terminalFunction.Name,
                    streamedInputType: currentElementType);
                if (terminalFunction.ReturnType != BoundType.Unit)
                {
                    throw Error(call.Line, call.Column, "a partition route terminal must return Unit");
                }
                break;
            }

            if (streamFunction.Kind == BoundFunctionKind.User
                && streamFunction.BlockInputType is null)
            {
                BindBlocklessStreamFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    currentElementType);
            }
            else
            {
                BindUserBlockFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    streamFunction.Name,
                    suppressResultBinding: true,
                    streamedInputType: currentElementType);
            }
            streamFunction = _resolvedGenericCalls.TryGetValue(call, out var specialization)
                ? specialization
                : streamFunction;
            currentElementType = streamFunction.StreamElementType
                ?? throw Error(call.Line, call.Column, "partition route element type was not specialized");
        }

        partition.Consumers.Add(arm.Label, (originalStatement, pipeline));
        if (partition.Consumers.Count != partition.Expression.Arms.Count)
        {
            _deferredStreamDeclarations.Add(originalStatement);
            return true;
        }

        var routes = partition.Expression.Arms.Select(route =>
        {
            var consumer = partition.Consumers[route.Label];
            return new BoundPartitionRoute(
                route.Label,
                route.Condition,
                consumer.Pipeline,
                route.Line,
                route.Column);
        }).ToArray();
        foreach (var consumer in partition.Consumers.Values)
        {
            if (!ReferenceEquals(consumer.Statement, originalStatement))
            {
                _deferredStreamDeclarations.Add(consumer.Statement);
            }
        }
        _partitionConsumers.Add(
            originalStatement,
            new BoundPartitionPipeline(
                partition.Expression.Source,
                partition.Expression.ItemName,
                routes,
                partition.SourceElementType,
                partition.IsEvent));
        _currentPartitions.Remove(owner.Name);
        bindings.Remove(owner.Name);
        mutableBindings.Remove(owner.Name);
        return true;
    }

    private bool TryBindStreamingPipeline(
        BlockFunctionPipelineStatement pipeline,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        Statement originalStatement,
        bool expandedFromBinding = false)
    {
        var firstCall = pipeline.Calls[0];
        if (firstCall.Source is NameExpression sourceName
            && _currentDeferredStreams.TryGetValue(sourceName.Name, out var upstream))
        {
            if (!bindings.TryGetValue(sourceName.Name, out var sourceType)
                || !_types.TryGetStreamValue(sourceType, out var sourceElementType)
                || sourceElementType != upstream.ElementType)
            {
                throw Error(
                    sourceName.Line,
                    sourceName.Column,
                    $"invalid Stream binding '{sourceName.Name}'");
            }

            _currentDeferredStreams.Remove(sourceName.Name);
            bindings.Remove(sourceName.Name);
            mutableBindings.Remove(sourceName.Name);
            var expanded = new BlockFunctionPipelineStatement(
                [.. upstream.Calls, .. pipeline.Calls],
                upstream.Line,
                upstream.Column);
            return TryBindStreamingPipeline(
                expanded,
                functions,
                bindings,
                mutableBindings,
                originalStatement,
                expandedFromBinding: true);
        }

        if (!TryGetFunction(string.Join('.', firstCall.Target), functions, out var firstFunction)
            || (firstFunction.StreamElementType is null
                && firstFunction.StreamElementTypeTemplate is null))
        {
            return false;
        }

        BoundType? streamedInputType = null;
        for (var index = 0; index < pipeline.Calls.Count; index++)
        {
            var call = pipeline.Calls[index];
            if (string.Join('.', call.Target) == "each")
            {
                if (index != pipeline.Calls.Count - 1 || streamedInputType is null)
                {
                    throw Error(call.Line, call.Column, "each must terminate a streaming pipeline");
                }
                BindEachBlockBody(call, streamedInputType.Value, functions, bindings, mutableBindings);
                if (expandedFromBinding)
                {
                    _deferredStreamConsumers.Add(originalStatement, pipeline);
                }
                return true;
            }

            if (!TryGetFunction(string.Join('.', call.Target), functions, out var streamFunction)
                || (streamFunction.StreamElementType is null
                    && streamFunction.StreamElementTypeTemplate is null))
            {
                if (index != pipeline.Calls.Count - 1
                    || !TryGetFunction(string.Join('.', call.Target), functions, out var terminalFunction)
                    || terminalFunction.Kind != BoundFunctionKind.UserBlock)
                {
                    throw Error(call.Line, call.Column, "a streaming pipeline may end only with each or a Unit block function");
                }
                BindUserBlockFunctionCall(
                    call,
                    terminalFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    terminalFunction.Name,
                    streamedInputType: streamedInputType);
                if (terminalFunction.ReturnType != BoundType.Unit)
                {
                    throw Error(call.Line, call.Column, "a terminal streaming block function must return Unit");
                }
                if (expandedFromBinding)
                {
                    _deferredStreamConsumers.Add(originalStatement, pipeline);
                }
                return true;
            }

            if (streamFunction.Kind == BoundFunctionKind.User
                && streamFunction.BlockInputType is null)
            {
                if (streamedInputType is null)
                {
                    throw Error(call.Line, call.Column, "a stateful stream function must follow a stream-producing function");
                }
                BindBlocklessStreamFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    streamedInputType.Value);
            }
            else
            {
                BindUserBlockFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    streamFunction.Name,
                    suppressResultBinding: true,
                    streamedInputType: streamedInputType);
            }
            streamFunction = _resolvedGenericCalls.TryGetValue(call, out var specialization)
                ? specialization
                : streamFunction;
            streamedInputType = streamFunction.StreamElementType
                ?? throw Error(call.Line, call.Column, "stream element type was not specialized");
            if (streamedInputType == BoundType.Unit)
            {
                throw Error(call.Line, call.Column, "stream functions must emit a non-Unit value");
            }
        }

        var lastCall = pipeline.Calls[^1];
        if (lastCall.ResultName is null || lastCall.ResultIsSynthetic)
        {
            throw Error(firstCall.Line, firstCall.Column, "a streaming pipeline must end with each or bind a Stream<T>");
        }
        if (lastCall.ResultIsMutable)
        {
            throw Error(lastCall.Line, lastCall.Column, "Stream<T> bindings are affine and cannot be mutable");
        }

        ValidateBindingName(lastCall.ResultName, lastCall.Line, lastCall.Column);
        if (bindings.ContainsKey(lastCall.ResultName))
        {
            throw Error(
                lastCall.Line,
                lastCall.Column,
                $"binding '{lastCall.ResultName}' already exists in this scope");
        }

        var elementType = streamedInputType
            ?? throw Error(lastCall.Line, lastCall.Column, "stream element type was not inferred");
        bindings.Add(lastCall.ResultName, _types.GetOrAddStream(elementType));
        _currentDeferredStreams.Add(
            lastCall.ResultName,
            new DeferredStreamPlan(pipeline.Calls, elementType, lastCall.Line, lastCall.Column));
        _deferredStreamDeclarations.Add(originalStatement);
        return true;
    }

    private bool TryBindEventStreamingPipeline(
        BlockFunctionPipelineStatement pipeline,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        Statement originalStatement)
    {
        if (pipeline.Calls[0].Source is not NameExpression sourceName)
        {
            return false;
        }

        Expression runtimeSource;
        BoundType sourceElementType;
        bool isEvent;
        IReadOnlyList<BlockFunctionCallStatement> calls;
        if (_currentDeferredStreams.TryGetValue(sourceName.Name, out var upstream))
        {
            if (!upstream.IsEvent
                || upstream.EventSource is null
                || upstream.EventSourceElementType is null)
            {
                return false;
            }

            runtimeSource = upstream.EventSource;
            sourceElementType = upstream.EventSourceElementType.Value;
            isEvent = upstream.IsEvent;
            calls = [.. upstream.Calls, .. pipeline.Calls];
            _currentDeferredStreams.Remove(sourceName.Name);
        }
        else
        {
            if (!bindings.TryGetValue(sourceName.Name, out var sourceType))
            {
                return false;
            }
            if (_types.TryGetEventStreamValue(sourceType, out sourceElementType))
            {
                isEvent = true;
            }
            else if (_types.TryGetStreamValue(sourceType, out sourceElementType))
            {
                isEvent = false;
            }
            else
            {
                return false;
            }

            runtimeSource = pipeline.Calls[0].Source;
            calls = pipeline.Calls;
        }

        bindings.Remove(sourceName.Name);
        mutableBindings.Remove(sourceName.Name);
        BoundType currentElementType = sourceElementType;
        for (var index = 0; index < calls.Count; index++)
        {
            var call = calls[index];
            var target = string.Join('.', call.Target);
            if (target == "each")
            {
                if (index != calls.Count - 1)
                {
                    throw Error(call.Line, call.Column, "each must terminate an EventStream<T> pipeline");
                }

                BindEachBlockBody(
                    call,
                    currentElementType,
                    functions,
                    bindings,
                    mutableBindings,
                    allowStreamStop: true);
                _eventStreamConsumers.Add(
                    originalStatement,
                    new BoundEventStreamPipeline(runtimeSource, calls, sourceElementType, isEvent));
                return true;
            }

            if (!TryGetFunction(target, functions, out var streamFunction)
                || (streamFunction.StreamElementType is null
                    && streamFunction.StreamElementTypeTemplate is null))
            {
                if (index != calls.Count - 1
                    || !TryGetFunction(target, functions, out var terminalFunction)
                    || terminalFunction.Kind != BoundFunctionKind.UserBlock)
                {
                    throw Error(
                        call.Line,
                        call.Column,
                        "an EventStream<T> pipeline may end only with each or a Unit block function");
                }

                BindUserBlockFunctionCall(
                    call,
                    terminalFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    terminalFunction.Name,
                    streamedInputType: currentElementType);
                if (terminalFunction.ReturnType != BoundType.Unit)
                {
                    throw Error(call.Line, call.Column, "an EventStream<T> terminal must return Unit");
                }

                _eventStreamConsumers.Add(
                    originalStatement,
                    new BoundEventStreamPipeline(runtimeSource, calls, sourceElementType, isEvent));
                return true;
            }

            if (streamFunction.Kind == BoundFunctionKind.User
                && streamFunction.BlockInputType is null)
            {
                BindBlocklessStreamFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    currentElementType);
            }
            else
            {
                BindUserBlockFunctionCall(
                    call,
                    streamFunction,
                    functions,
                    bindings,
                    mutableBindings,
                    streamFunction.Name,
                    suppressResultBinding: true,
                    streamedInputType: currentElementType);
            }

            streamFunction = _resolvedGenericCalls.TryGetValue(call, out var specialization)
                ? specialization
                : streamFunction;
            currentElementType = streamFunction.StreamElementType
                ?? throw Error(call.Line, call.Column, "EventStream<T> element type was not specialized");
        }

        var lastCall = calls[^1];
        if (lastCall.ResultName is null || lastCall.ResultIsSynthetic)
        {
            throw Error(
                lastCall.Line,
                lastCall.Column,
                "an EventStream<T> pipeline must end with each or bind another EventStream<T>");
        }
        if (lastCall.ResultIsMutable)
        {
            throw Error(lastCall.Line, lastCall.Column, "EventStream<T> bindings are affine and cannot be mutable");
        }

        ValidateBindingName(lastCall.ResultName, lastCall.Line, lastCall.Column);
        if (bindings.ContainsKey(lastCall.ResultName))
        {
            throw Error(
                lastCall.Line,
                lastCall.Column,
                $"binding '{lastCall.ResultName}' already exists in this scope");
        }

        bindings.Add(
            lastCall.ResultName,
            isEvent
                ? _types.GetOrAddEventStream(currentElementType)
                : _types.GetOrAddStream(currentElementType));
        _currentDeferredStreams.Add(
            lastCall.ResultName,
            new DeferredStreamPlan(
                calls,
                currentElementType,
                lastCall.Line,
                lastCall.Column,
                IsEvent: isEvent,
                EventSource: runtimeSource,
                EventSourceElementType: sourceElementType));
        _deferredStreamDeclarations.Add(originalStatement);
        return true;
    }

    private void BindBlocklessStreamFunctionCall(
        BlockFunctionCallStatement call,
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlySet<string> mutableBindings,
        BoundType streamedInputType)
    {
        if (call.Body.Count != 0 || !call.UsesDefaultItemName || (call.AdditionalItemNames?.Count ?? 0) != 0)
        {
            throw Error(call.Line, call.Column, $"stream function '{function.Name}' does not accept a call-site block");
        }
        if (call.ResultName is not null && !call.ResultIsSynthetic)
        {
            throw Error(call.Line, call.Column, $"stream function '{function.Name}' cannot bind a result");
        }

        if (function.GenericParameterName is not null
            && function.SpecializedType is null
            && function.SpecializedValue is null)
        {
            function = ResolveGenericSpecialization(function, streamedInputType, functions, call);
        }
        if (function.InputType != streamedInputType)
        {
            throw Error(
                call.Line,
                call.Column,
                $"stream function '{function.Name}' expects {FormatType(function.InputType ?? BoundType.Unit)} "
                + $"but received {FormatType(streamedInputType)}");
        }

        ValidateAdditionalFunctionArguments(
            function,
            call.Arguments ?? [],
            functions,
            bindings,
            allowReadIntCall: true,
            mutableBindings,
            function.Name);
    }

    private void RejectBuiltInBlockResult(BlockFunctionCallStatement call, string target)
    {
        if (call.ResultName is not null)
        {
            throw Error(call.Line, call.Column, $"Unit block function '{target}' cannot bind a result");
        }
    }

    private void BindWhileBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType)
    {
        if (!call.UsesDefaultItemName)
        {
            throw Error(call.Line, call.Column, "while does not bind an iteration item");
        }

        NoteLongControlCondition(call.Source, call.Line, "while");
        var conditionType = InferExpression(call.Source, functions, bindings,
            allowPrintCall: false, allowReadIntCall: true, allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (conditionType != BoundType.Bool)
        {
            throw Error(call.Source.Line, call.Source.Column, "while condition must be Bool");
        }
        BindLoopStatements(call.Body, functions,
            new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal),
            new HashSet<string>(mutableBindings, StringComparer.Ordinal),
            yieldInputType,
            allowContainerBindings: true);
    }

    private void BindEachBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
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

        var itemType = BoundType.Int;
        if (call.Source is RangeExpression range)
        {
            var startType = InferExpression(
                range.Start,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall: true,
                allowFlowBindingTarget: false,
                mutableBindings: mutableBindings);
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
                allowFlowBindingTarget: false,
                mutableBindings: mutableBindings);
            if (endType != BoundType.Int)
            {
                throw Error(range.End.Line, range.End.Column, "range end must be an integer");
            }
        }
        else
        {
            var sourceType = InferExpression(
                call.Source,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall: true,
                allowFlowBindingTarget: false,
                mutableBindings: mutableBindings);
            itemType = sourceType switch
            {
                BoundType.IntSlice or BoundType.StaticIntArray or BoundType.DynamicIntArray => BoundType.Int,
                BoundType.StaticTextArray => BoundType.Text,
                BoundType.Text => BoundType.CodePoint,
                BoundType.Arguments => BoundType.Text,
                BoundType.Range => BoundType.Int,
                BoundType.MappedBytes or BoundType.MutableMappedBytes => BoundType.UInt8,
                _ when _types.IsSlice(sourceType) => _types.GetSliceElement(sourceType),
                _ when _types.IsStaticArray(sourceType) => _types.GetStaticArray(sourceType).ElementType,
                _ when _types.IsSet(sourceType) => _types.GetSetElement(sourceType),
                _ when _types.IsDynamicArray(sourceType) => _types.GetDynamicArray(sourceType).ElementType,
                _ => BoundType.Unit
            };
            if (itemType == BoundType.Unit)
            {
                throw Error(call.Source.Line, call.Source.Column,
                    "each expects a Range, Text, array, Arguments, or mapped byte view");
            }
        }

        BindEachBlockBody(call, itemType, functions, bindings, mutableBindings, yieldInputType);
    }

    private void BindEachBlockBody(
        BlockFunctionCallStatement call,
        BoundType itemType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType = null,
        bool allowStreamStop = false)
    {
        RejectBuiltInBlockResult(call, "each");
        if (!call.UsesDefaultItemName)
        {
            ValidateBindingName(call.ItemName, call.Line, call.Column);
        }
        if (bindings.ContainsKey(call.ItemName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ItemName}' already exists in this scope");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = itemType
        };
        var previousAllowStreamStop = _allowStreamStop;
        _allowStreamStop = previousAllowStreamStop || allowStreamStop;
        try
        {
            BindLoopStatements(
                call.Body,
                functions,
                bodyBindings,
                new HashSet<string>(mutableBindings, StringComparer.Ordinal),
                yieldInputType,
                allowContainerBindings: true);
        }
        finally
        {
            _allowStreamStop = previousAllowStreamStop;
        }
    }

    private void BindUserBlockFunctionCall(
        BlockFunctionCallStatement call,
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        string target,
        bool suppressResultBinding = false,
        BoundType? streamedInputType = null)
    {
        if (!call.UsesDefaultItemName)
        {
            ValidateBindingName(call.ItemName, call.Line, call.Column);
        }

        if (bindings.ContainsKey(call.ItemName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ItemName}' already exists in this scope");
        }

        var inputType = streamedInputType ?? InferExpression(
            call.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        BoundType? alreadyBoundCallbackResultType = null;
        if (function.Kind is BoundFunctionKind.RuntimeParallel or BoundFunctionKind.RuntimeTryParallel)
        {
            ValidateParallelCapturedBindings(call, functions, bindings, mutableBindings);
        }
        if (function.Kind is BoundFunctionKind.RuntimeParallel or BoundFunctionKind.RuntimeTryParallel
            && function.SpecializedType is null)
        {
            if (!_types.IsDynamicArray(inputType) && inputType != BoundType.DynamicIntArray)
            {
                throw Error(call.Source.Line, call.Source.Column, $"{target} expects a growable array");
            }
            if (call.Body.Count == 0 || call.Body[^1] is not ExpressionStatement parallelResult)
            {
                throw Error(call.Line, call.Column, $"{target} callback must end with a result expression");
            }

            var parallelItemType = inputType == BoundType.DynamicIntArray
                ? BoundType.Int
                : _types.GetDynamicArray(inputType).ElementType;
            var parallelBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
            {
                [call.ItemName] = parallelItemType
            };
            var parallelMutableBindings = new HashSet<string>(mutableBindings, StringComparer.Ordinal);
            BindStatements(
                call.Body.Take(call.Body.Count - 1).ToArray(),
                functions,
                parallelBindings,
                parallelMutableBindings,
                allowContainerBindings: true);
            var parallelResultType = InferExpression(
                parallelResult.Expression,
                functions,
                parallelBindings,
                allowPrintCall: false,
                allowReadIntCall: true,
                allowFlowBindingTarget: false,
                mutableBindings: parallelMutableBindings);
            BoundType parallelValueType;
            BoundType? parallelErrorType = null;
            if (function.Kind == BoundFunctionKind.RuntimeTryParallel)
            {
                if (!_types.TryGetResultTypes(parallelResultType, out var resultTypes))
                {
                    throw Error(
                        parallelResult.Expression.Line,
                        parallelResult.Expression.Column,
                        $"{target} callback must return Result<R, E>");
                }
                parallelValueType = resultTypes.Ok;
                parallelErrorType = resultTypes.Error;
            }
            else
            {
                parallelValueType = parallelResultType;
            }
            function = ResolveGenericSpecialization(
                function,
                parallelItemType,
                functions,
                call,
                specializedInputType: inputType,
                explicitSecondaryType: parallelValueType,
                explicitTertiaryType: parallelErrorType);
        }
        if (function.Kind == BoundFunctionKind.UserBlock
            && function.GenericParameterName is not null
            && function.SpecializedType is null
            && function.SpecializedValue is null
            && (function.InputTypeTemplate is not null
                || function.StreamElementTypeTemplate is not null))
        {
            BoundType? primaryType = null;
            BoundType? secondaryType = null;
            BoundType? tertiaryType = null;
            if (function.InputTypeTemplate is not null)
            {
                InferGenericArgumentsFromTypeTemplate(
                    function.InputTypeTemplate,
                    inputType,
                    function,
                    ref primaryType,
                    ref secondaryType,
                    ref tertiaryType,
                    call.Line,
                    call.Column);
            }
            else
            {
                switch (function.InputType)
                {
                    case BoundType.GenericParameter:
                        primaryType = inputType;
                        break;
                    case BoundType.SecondaryGenericParameter:
                        secondaryType = inputType;
                        break;
                    case BoundType.TertiaryGenericParameter:
                        tertiaryType = inputType;
                        break;
                }
            }

            var genericAdditionalParameters = function.AdditionalParameters ?? [];
            var genericArguments = call.Arguments ?? [];
            if (genericArguments.Count != genericAdditionalParameters.Count)
            {
                throw Error(
                    call.Line,
                    call.Column,
                    $"function '{target}' expects {genericAdditionalParameters.Count} additional argument(s)");
            }
            for (var argumentIndex = 0; argumentIndex < genericArguments.Count; argumentIndex++)
            {
                var parameter = genericAdditionalParameters[argumentIndex];
                var argument = genericArguments[argumentIndex];
                var argumentType = InferExpression(
                    argument,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall: true,
                    allowFlowBindingTarget: false,
                    mutableBindings: mutableBindings);
                if (parameter.TypeTemplate is not null)
                {
                    InferGenericArgumentsFromTypeTemplate(
                        parameter.TypeTemplate,
                        argumentType,
                        function,
                        ref primaryType,
                        ref secondaryType,
                        ref tertiaryType,
                        argument.Line,
                        argument.Column);
                    continue;
                }

                switch (parameter.Type)
                {
                    case BoundType.GenericParameter:
                        AssignInferredGenericType(
                            function.GenericParameterName!,
                            argumentType,
                            ref primaryType,
                            argument.Line,
                            argument.Column);
                        break;
                    case BoundType.SecondaryGenericParameter:
                        AssignInferredGenericType(
                            function.SecondaryGenericParameterName!,
                            argumentType,
                            ref secondaryType,
                            argument.Line,
                            argument.Column);
                        break;
                    case BoundType.TertiaryGenericParameter:
                        AssignInferredGenericType(
                            function.TertiaryGenericParameterName!,
                            argumentType,
                            ref tertiaryType,
                            argument.Line,
                            argument.Column);
                        break;
                }
            }

            if (primaryType is null
                || (function.SecondaryGenericParameterName is not null && secondaryType is null)
                || (function.TertiaryGenericParameterName is not null && tertiaryType is null))
            {
                if (call.Body.Count == 0 || call.Body[^1] is not ExpressionStatement callbackResult)
                {
                    throw Error(call.Line, call.Column, $"{target} callback must end with a result expression");
                }
                var provisionalPrimaryType = primaryType ?? BoundType.Unit;
                var provisionalBlockInputType = function.BlockInputTypeTemplate is null
                    ? function.BlockInputType!.Value switch
                    {
                        BoundType.GenericParameter when primaryType is null => throw Error(
                            call.Line,
                            call.Column,
                            $"generic block function '{target}' cannot infer type parameter '{function.GenericParameterName}'"),
                        BoundType.SecondaryGenericParameter when secondaryType is null => throw Error(
                            call.Line,
                            call.Column,
                            $"generic block function '{target}' cannot infer callback input type"),
                        BoundType.TertiaryGenericParameter when tertiaryType is null => throw Error(
                            call.Line,
                            call.Column,
                            $"generic block function '{target}' cannot infer callback input type"),
                        _ => SubstituteGenericType(
                            function.BlockInputType.Value,
                            provisionalPrimaryType,
                            secondaryType,
                            tertiaryType)
                    }
                    : ParseSpecializedFunctionType(
                        function.BlockInputTypeTemplate,
                        function.GenericParameterName,
                        provisionalPrimaryType,
                        function.SecondaryGenericParameterName,
                        secondaryType,
                        function.TertiaryGenericParameterName,
                        tertiaryType,
                        call.Line,
                        call.Column);
                var provisionalBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
                {
                    [call.ItemName] = provisionalBlockInputType
                };
                var provisionalAdditionalBlockParameters = function.AdditionalBlockParameters ?? [];
                var provisionalAdditionalItemNames = call.AdditionalItemNames ?? [];
                if (provisionalAdditionalItemNames.Count != provisionalAdditionalBlockParameters.Count)
                {
                    throw Error(
                        call.Line,
                        call.Column,
                        $"block function '{target}' expects {1 + provisionalAdditionalBlockParameters.Count} block item name(s)");
                }
                for (var parameterIndex = 0; parameterIndex < provisionalAdditionalBlockParameters.Count; parameterIndex++)
                {
                    provisionalBindings[provisionalAdditionalItemNames[parameterIndex]] = SubstituteGenericType(
                        provisionalAdditionalBlockParameters[parameterIndex].Type,
                        provisionalPrimaryType,
                        secondaryType,
                        tertiaryType);
                }
                var provisionalMutableBindings = new HashSet<string>(mutableBindings, StringComparer.Ordinal);
                BindStatements(
                    call.Body.Take(call.Body.Count - 1).ToArray(),
                    functions,
                    provisionalBindings,
                    provisionalMutableBindings,
                    allowContainerBindings: true);
                alreadyBoundCallbackResultType = InferExpression(
                    callbackResult.Expression,
                    functions,
                    provisionalBindings,
                    allowPrintCall: false,
                    allowReadIntCall: true,
                    allowFlowBindingTarget: false,
                    mutableBindings: provisionalMutableBindings);
                if (function.BlockResultTypeTemplate is null)
                {
                    throw Error(call.Line, call.Column, $"generic block function '{target}' cannot infer callback type parameters");
                }
                InferGenericArgumentsFromTypeTemplate(
                    function.BlockResultTypeTemplate,
                    alreadyBoundCallbackResultType.Value,
                    function,
                    ref primaryType,
                    ref secondaryType,
                    ref tertiaryType,
                    callbackResult.Expression.Line,
                    callbackResult.Expression.Column);
            }

            function = ResolveGenericSpecialization(
                function,
                primaryType ?? throw Error(
                    call.Line,
                    call.Column,
                    $"generic block function '{target}' cannot infer type parameter '{function.GenericParameterName}'"),
                functions,
                call,
                specializedInputType: inputType,
                explicitSecondaryType: secondaryType,
                explicitTertiaryType: tertiaryType);
        }
        if (function.GenericParameterName is not null
            && function.SpecializedType is null
            && function.SpecializedValue is null)
        {
            function = ResolveGenericSpecialization(function, inputType, functions, call);
        }
        if (function.InputType is null || function.BlockInputType is null)
        {
            throw Error(call.Line, call.Column, $"block function '{target}' is not callable");
        }
        if (function.StreamElementType is not null && !suppressResultBinding)
        {
            throw Error(call.Line, call.Column, $"stream function '{target}' must be followed directly by each");
        }
        if (inputType != function.InputType.Value)
        {
            throw Error(
                call.Source.Line,
                call.Source.Column,
                $"block function '{target}' expects {FormatType(function.InputType.Value)} but received {FormatType(inputType)}");
        }

        ValidateAdditionalFunctionArguments(
            function,
            call.Arguments ?? [],
            functions,
            bindings,
            allowReadIntCall: true,
            mutableBindings,
            target);

        var additionalBlockParameters = function.AdditionalBlockParameters ?? [];
        var additionalItemNames = call.AdditionalItemNames ?? [];
        if (additionalItemNames.Count != additionalBlockParameters.Count)
        {
            throw Error(
                call.Line,
                call.Column,
                $"block function '{target}' expects {1 + additionalBlockParameters.Count} block item name(s)");
        }
        foreach (var itemName in additionalItemNames)
        {
            ValidateBindingName(itemName, call.Line, call.Column);
            if (itemName == call.ItemName || bindings.ContainsKey(itemName))
            {
                throw Error(call.Line, call.Column, $"binding '{itemName}' already exists in this scope");
            }
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = function.BlockInputType.Value
        };
        for (var index = 0; index < additionalBlockParameters.Count; index++)
        {
            bodyBindings[additionalItemNames[index]] = additionalBlockParameters[index].Type;
        }
        var callbackMutableBindings = new HashSet<string>(mutableBindings, StringComparer.Ordinal);
        var callbackResultType = function.BlockResultType ?? BoundType.Unit;
        if (callbackResultType == BoundType.Unit)
        {
            BindStatements(
                call.Body,
                functions,
                bodyBindings,
                callbackMutableBindings,
                allowContainerBindings: true);
        }
        else
        {
            if (call.Body.Count == 0 || call.Body[^1] is not ExpressionStatement callbackResult)
            {
                throw Error(
                    call.Line,
                    call.Column,
                    $"block callback for '{target}' must end with {FormatType(callbackResultType)}");
            }

            var actualCallbackResultType = alreadyBoundCallbackResultType ?? InferBlockCallbackResult(
                call,
                callbackResult,
                functions,
                bodyBindings,
                callbackMutableBindings);
            if (actualCallbackResultType != callbackResultType)
            {
                throw Error(
                    callbackResult.Expression.Line,
                    callbackResult.Expression.Column,
                    $"block callback for '{target}' returns {FormatType(actualCallbackResultType)} but expects {FormatType(callbackResultType)}");
            }
        }

        if (suppressResultBinding)
        {
            if (function.ReturnType != BoundType.Unit)
            {
                throw Error(call.Line, call.Column, $"stream function '{target}' must return Unit");
            }
            return;
        }

        if (call.ResultName is null)
        {
            if (function.ReturnType != BoundType.Unit
                && (IsContainerType(function.ReturnType)
                    || _types.ContainsOwnedStorage(function.ReturnType)))
            {
                throw Error(call.Line, call.Column,
                    $"owned result of block function '{target}' must be bound with '=> name'");
            }
            return;
        }

        if (!call.ResultIsSynthetic)
        {
            ValidateBindingName(call.ResultName, call.Line, call.Column);
        }
        if (function.ReturnType == BoundType.Unit)
        {
            throw Error(call.Line, call.Column, $"Unit block function '{target}' cannot bind a result");
        }
        if (bindings.ContainsKey(call.ResultName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ResultName}' already exists in this scope");
        }
        if (function.ReturnType == BoundType.MutableMappedBytes && !call.ResultIsMutable)
        {
            throw Error(call.Line, call.Column,
                "map write requires a mutable owner binding; use '=> name!'");
        }

        bindings.Add(call.ResultName, function.ReturnType);
        if (call.ResultIsMutable)
        {
            mutableBindings.Add(call.ResultName);
            RegisterMutableBinding(call.ResultName, call.Line, call.Column);
        }
    }

    private BoundType InferBlockCallbackResult(
        BlockFunctionCallStatement call,
        ExpressionStatement callbackResult,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bodyBindings,
        HashSet<string> callbackMutableBindings)
    {
        BindStatements(
            call.Body.Take(call.Body.Count - 1).ToArray(),
            functions,
            bodyBindings,
            callbackMutableBindings,
            allowContainerBindings: true);
        return InferExpression(
            callbackResult.Expression,
            functions,
            bodyBindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false,
            mutableBindings: callbackMutableBindings);
    }

    private void InferGenericArgumentsFromTypeTemplate(
        string typeTemplate,
        BoundType actualType,
        BoundFunction function,
        Dictionary<string, BoundType> inferredTypes,
        int line,
        int column)
    {
        typeTemplate = typeTemplate.Trim();
        if (GenericParameterNames(function).Contains(typeTemplate, StringComparer.Ordinal))
        {
            AssignInferredGenericType(typeTemplate, actualType, inferredTypes, line, column);
            return;
        }
        if (typeTemplate.StartsWith('[', StringComparison.Ordinal)
            && typeTemplate.EndsWith("; ~]", StringComparison.Ordinal))
        {
            var elementType = actualType == BoundType.DynamicIntArray
                ? BoundType.Int
                : _types.IsDynamicArray(actualType)
                    ? _types.GetDynamicArray(actualType).ElementType
                    : throw Error(line, column, $"expected a growable array but received {FormatType(actualType)}");
            InferGenericArgumentsFromTypeTemplate(
                typeTemplate[1..^4], elementType, function, inferredTypes, line, column);
            return;
        }
        if (typeTemplate.StartsWith("Option<", StringComparison.Ordinal)
            && typeTemplate.EndsWith('>')
            && _types.TryGetOptionValue(actualType, out var optionValue))
        {
            InferGenericArgumentsFromTypeTemplate(
                typeTemplate[7..^1], optionValue, function, inferredTypes, line, column);
            return;
        }
        if (typeTemplate.StartsWith("Result<", StringComparison.Ordinal)
            && typeTemplate.EndsWith('>')
            && _types.TryGetResultTypes(actualType, out var resultTypes))
        {
            var arguments = typeTemplate[7..^1];
            var separator = FindTopLevelTypeComma(arguments);
            if (separator < 0) throw Error(line, column, "Result requires success and error types");
            InferGenericArgumentsFromTypeTemplate(
                arguments[..separator], resultTypes.Ok, function, inferredTypes, line, column);
            InferGenericArgumentsFromTypeTemplate(
                arguments[(separator + 1)..], resultTypes.Error, function, inferredTypes, line, column);
            return;
        }

        var expectedType = ParseType(typeTemplate, line, column);
        if (expectedType != actualType)
        {
            throw Error(line, column,
                $"generic type pattern {typeTemplate} expects {FormatType(expectedType)} but received {FormatType(actualType)}");
        }
    }

    private void AssignInferredGenericType(
        string parameterName,
        BoundType inferredType,
        Dictionary<string, BoundType> inferredTypes,
        int line,
        int column)
    {
        if (inferredTypes.TryGetValue(parameterName, out var existing) && existing != inferredType)
        {
            throw Error(line, column,
                $"type parameter '{parameterName}' was inferred as both {FormatType(existing)} and {FormatType(inferredType)}");
        }
        inferredTypes[parameterName] = inferredType;
    }

    private void InferGenericArgumentsFromTypeTemplate(
        string typeTemplate,
        BoundType actualType,
        BoundFunction function,
        ref BoundType? primaryType,
        ref BoundType? secondaryType,
        ref BoundType? tertiaryType,
        int line,
        int column)
    {
        typeTemplate = typeTemplate.Trim();
        if (typeTemplate == function.GenericParameterName)
        {
            AssignInferredGenericType(function.GenericParameterName!, actualType, ref primaryType, line, column);
            return;
        }
        if (typeTemplate == function.SecondaryGenericParameterName)
        {
            AssignInferredGenericType(function.SecondaryGenericParameterName!, actualType, ref secondaryType, line, column);
            return;
        }
        if (typeTemplate == function.TertiaryGenericParameterName)
        {
            AssignInferredGenericType(function.TertiaryGenericParameterName!, actualType, ref tertiaryType, line, column);
            return;
        }
        if (typeTemplate.StartsWith('[', StringComparison.Ordinal)
            && typeTemplate.EndsWith("; ~]", StringComparison.Ordinal))
        {
            var elementType = actualType == BoundType.DynamicIntArray
                ? BoundType.Int
                : _types.IsDynamicArray(actualType)
                    ? _types.GetDynamicArray(actualType).ElementType
                    : throw Error(line, column, $"expected a growable array but received {FormatType(actualType)}");
            InferGenericArgumentsFromTypeTemplate(
                typeTemplate[1..^4], elementType, function,
                ref primaryType, ref secondaryType, ref tertiaryType, line, column);
            return;
        }

        var expectedType = ParseType(typeTemplate, line, column);
        if (expectedType != actualType)
        {
            throw Error(
                line,
                column,
                $"generic type pattern {typeTemplate} expects {FormatType(expectedType)} but received {FormatType(actualType)}");
        }
    }

    private void AssignInferredGenericType(
        string parameterName,
        BoundType inferredType,
        ref BoundType? destination,
        int line,
        int column)
    {
        if (destination is { } existing && existing != inferredType)
        {
            throw Error(
                line,
                column,
                $"type parameter '{parameterName}' was inferred as both {FormatType(existing)} and {FormatType(inferredType)}");
        }
        destination = inferredType;
    }

    private void BindDictionaryEachBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType,
        bool bindKey)
    {
        if (!call.UsesDefaultItemName)
        {
            ValidateBindingName(call.ItemName, call.Line, call.Column);
        }
        if (bindings.ContainsKey(call.ItemName))
        {
            throw Error(call.Line, call.Column, $"binding '{call.ItemName}' already exists in this scope");
        }

        var sourceType = InferExpression(
            call.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall: true,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        BoundType itemType;
        if (sourceType is BoundType.IntDictionary or BoundType.IntDictionaryView)
        {
            itemType = BoundType.Int;
        }
        else if (_types.IsDictionary(sourceType))
        {
            var dictionary = _types.GetDictionary(sourceType);
            itemType = bindKey ? dictionary.KeyType : dictionary.ValueType;
        }
        else
        {
            throw Error(call.Source.Line, call.Source.Column,
                $"{(bindKey ? "eachKey" : "eachValue")} expects a dictionary input");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = itemType
        };
        BindLoopStatements(
            call.Body,
            functions,
            bodyBindings,
            new HashSet<string>(mutableBindings, StringComparer.Ordinal),
            yieldInputType,
            allowContainerBindings: true);
    }

    private void BindLoopStatements(
        IReadOnlyList<Statement> statements,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
        BoundType? yieldInputType = null,
        bool allowContainerBindings = true)
    {
        _loopDepth++;
        var loopEntryBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        BorrowOriginState? loopExitBorrowedTextOrigins = null;
        try
        {
            var loopContinuation = new HashSet<string>(
                _borrowedTextContinuationNames,
                StringComparer.Ordinal);
            foreach (var binding in _activeBorrowedTextOrigins.Keys)
            {
                if (BorrowLoopMayReachBackEdge(statements)
                    && statements.Any(statement =>
                        StoragePlacementAnalyzer.ReferencesName(statement, binding)))
                {
                    loopContinuation.Add(binding);
                }
            }
            BindStatements(
                statements,
                functions,
                bindings,
                mutableBindings,
                yieldInputType,
                allowContainerBindings,
                shortenBorrowRegions: true,
                borrowRegionContinuation: loopContinuation);
            loopExitBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        }
        finally
        {
            RestoreBorrowedTextOriginState(loopExitBorrowedTextOrigins is null
                ? loopEntryBorrowedTextOrigins
                : MergeBorrowedTextOriginStates(
                    [loopEntryBorrowedTextOrigins, loopExitBorrowedTextOrigins]));
            _loopDepth--;
        }
    }

    private void BindRepeatBlockFunctionCall(
        BlockFunctionCallStatement call,
        IReadOnlyDictionary<string, BoundFunction> functions,
        Dictionary<string, BoundType> bindings,
        HashSet<string> mutableBindings,
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
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (countType != BoundType.Int)
        {
            throw Error(call.Source.Line, call.Source.Column, "repeat expects an integer input");
        }

        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal)
        {
            [call.ItemName] = BoundType.Int
        };
        BindLoopStatements(
            call.Body,
            functions,
            bodyBindings,
            new HashSet<string>(mutableBindings, StringComparer.Ordinal),
            yieldInputType,
            allowContainerBindings: true);
    }

    private FlowEffect InferExpressionStatement(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlySet<string>? mutableBindings = null,
        BoundType? yieldInputType = null)
    {
        if (expression is NameExpression { Name: "yield" })
        {
            if (!_currentFunctionIsAsync || _currentFunctionReturnType is null)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "bare yield is only valid inside an async function");
            }

            return FlowEffect.None;
        }

        if (expression is FlowExpression flow)
        {
            var result = InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall: true,
                allowFlowBindingTarget: false,
                yieldInputType: yieldInputType,
                mutableBindings: mutableBindings);
            if (result.Type != BoundType.Unit && result.Effect is NoFlowEffect)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "value-flow expression statements must end in a unit-producing call or bind their result with '=>'");
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
            yieldInputType: yieldInputType,
            mutableBindings: mutableBindings);
        if (expressionType != BoundType.Unit)
        {
            throw Error(
                expression.Line,
                expression.Column,
                "only function calls with side effects are valid expression statements");
        }

        return FlowEffect.None;
    }

    private BoundType InferExpression(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowPrintCall,
        bool allowReadIntCall,
        bool allowFlowBindingTarget,
        BoundType? yieldInputType = null,
        IReadOnlySet<string>? mutableBindings = null,
        string? allowedOwnedOuterResultName = null,
        bool allowOwnedElementBorrow = false)
    {
        var type = expression switch
        {
            StringExpression str => InferStringExpression(str, functions, bindings, allowReadIntCall),
            NumberExpression number => number.Text.Contains('.', StringComparison.Ordinal)
                || number.Text.Contains('e', StringComparison.OrdinalIgnoreCase)
                ? BoundType.Float32
                : BoundType.Int,
            BoolExpression => BoundType.Bool,
            NameExpression name => InferNameExpression(name, functions, bindings, allowReadIntCall),
            ArrayLiteralExpression array => InferArrayLiteralExpression(array, functions, bindings, allowReadIntCall),
            TypeApplicationExpression application => InferTypeApplicationExpression(application, functions, allowReadIntCall),
            ArrayRepeatExpression repeat => InferArrayRepeatExpression(repeat, functions, bindings, allowReadIntCall),
            TypedEmptyArrayExpression typedArray => InferTypedEmptyArrayExpression(typedArray),
            DictionaryLiteralExpression dictionary => InferDictionaryLiteralExpression(dictionary, functions, bindings, allowReadIntCall),
            TypedEmptyDictionaryExpression typedDictionary => InferTypedEmptyDictionaryExpression(typedDictionary),
            ProductExpression product => InferProductExpression(product, functions, bindings, allowReadIntCall),
            BranchExpression branch => InferBranchExpression(branch, functions, bindings, allowReadIntCall, mutableBindings),
            TapExpression tap => InferTapExpression(tap, functions, bindings, allowReadIntCall, mutableBindings),
            PartitionExpression partition => InferPartitionExpression(partition, functions, bindings, allowReadIntCall, mutableBindings),
            StreamJoinExpression join => InferStreamJoinExpression(join, functions, bindings, allowReadIntCall, mutableBindings),
            IndexExpression index => InferIndexExpression(
                index,
                functions,
                bindings,
                allowReadIntCall,
                allowOwnedElementBorrow),
            StructLiteralExpression literal => InferStructLiteralExpression(literal, functions, bindings, allowReadIntCall),
            FieldAccessExpression field => InferFieldAccessExpression(
                field,
                functions,
                bindings,
                allowReadIntCall,
                allowOwnedElementBorrow),
            TryExpression attempt => InferTryExpression(
                attempt,
                functions,
                bindings,
                allowReadIntCall,
                mutableBindings),
            BoxExpression box => InferBoxExpression(box, functions, bindings, allowReadIntCall),
            MapExpression mapping => InferMapExpression(mapping, functions, bindings, allowReadIntCall),
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
            IfExpression conditional => InferIfExpression(
                conditional,
                functions,
                bindings,
                allowReadIntCall,
                allowedOwnedOuterResultName,
                mutableBindings),
            WhenExpression whenExpression => InferWhenExpression(
                whenExpression,
                functions,
                bindings,
                allowReadIntCall,
                allowedOwnedOuterResultName,
                mutableBindings),
            EnumMatchExpression enumMatch => InferEnumMatchExpression(
                enumMatch,
                functions,
                bindings,
                allowReadIntCall,
                allowedOwnedOuterResultName,
                mutableBindings),
            EnumPatternExpression => throw Error(
                expression.Line,
                expression.Column,
                "enum patterns are only valid in a subject when arm"),
            SubjectCompareExpression => throw Error(
                expression.Line,
                expression.Column,
                "subject comparison is only valid inside value-flow when"),
            SubjectRangeExpression => throw Error(
                expression.Line,
                expression.Column,
                "subject range is only valid inside value-flow when"),
            FoldExpression fold => InferFoldExpression(fold, functions, bindings, allowReadIntCall),
            RangeExpression range => InferRangeExpression(
                range,
                functions,
                bindings,
                allowReadIntCall,
                mutableBindings),
            CallExpression call => InferCallExpression(call, functions, bindings, allowPrintCall, allowReadIntCall, mutableBindings),
            FlowExpression flow => InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall,
                allowFlowBindingTarget,
                yieldInputType,
                mutableBindings).Type,
            _ => throw Error(expression.Line, expression.Column, "expected an expression value")
        };
        _currentUsedTypes?.Add(type);
        return type;
    }

    private IReadOnlyDictionary<string, BoundType> BindingsWithUsedTypes(
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        var result = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal);
        foreach (var type in _currentUsedTypes ?? [])
        {
            result.TryAdd($"@used-type:{(int)type}", type);
        }
        return result;
    }

    private BoundType InferRangeExpression(
        RangeExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        var startType = InferExpression(
            expression.Start,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (startType != BoundType.Int)
        {
            throw Error(expression.Start.Line, expression.Start.Column, "range start must be an integer");
        }

        var endType = InferExpression(
            expression.End,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (endType != BoundType.Int)
        {
            throw Error(expression.End.Line, expression.End.Column, "range end must be an integer");
        }

        return BoundType.Range;
    }

    private BoundType InferProductExpression(
        ProductExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var fields = new List<(string? Label, BoundType Type)>(expression.Elements.Count);
        foreach (var element in expression.Elements)
        {
            var type = InferExpression(
                element.Value,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
            if (type == BoundType.Unit)
            {
                throw Error(element.Line, element.Column, "product fields must produce values");
            }
            fields.Add((element.Label, type));
        }

        var displayName = "(" + string.Join(", ", fields.Select(field =>
            field.Label is null
                ? FormatType(field.Type)
                : field.Label + ": " + FormatType(field.Type))) + ")";
        var productType = _types.GetOrAddProduct(fields, displayName, expression.Line, expression.Column);
        _productExpressionTypes[expression] = productType;
        return productType;
    }

    private BoundType InferBranchExpression(
        BranchExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        var sourceType = InferExpression(
            expression.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        var sourceOwnsStorage = _types.ContainsOwnedStorage(sourceType);
        if (expression.IsParallel
            && sourceOwnsStorage
            && !IsParallelSharedTypeSupported(sourceType))
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"parallel branch cannot share non-sendable input {FormatType(sourceType)}");
        }
        var consumingArm = -1;
        var mutableArm = -1;
        var fields = new List<(string? Label, BoundType Type)>(expression.Arms.Count);
        var parallelArmTargets = new List<IReadOnlyList<BoundFunction>>(expression.Arms.Count);
        for (var index = 0; index < expression.Arms.Count; index++)
        {
            var arm = expression.Arms[index];
            if (arm.Targets.Count == 0)
            {
                throw Error(arm.Line, arm.Column, $"branch arm '{arm.Label}' requires a flow target");
            }

            var mode = ResolveBranchArmMode(arm, sourceType, functions);
            if (expression.IsParallel
                && mode is BranchInputMode.Move or BranchInputMode.MutableBorrow)
            {
                throw Error(
                    arm.Line,
                    arm.Column,
                    $"parallel branch arm '{arm.Label}' must use a Copy input or readonly ref; {FormatBranchInputMode(mode)} cannot overlap");
            }
            if (mode == BranchInputMode.Move && sourceOwnsStorage)
            {
                if (consumingArm >= 0)
                {
                    throw Error(
                        arm.Line,
                        arm.Column,
                        $"branch arm '{arm.Label}' duplicates an affine input already consumed by arm '{expression.Arms[consumingArm].Label}'");
                }
                consumingArm = index;
            }
            if (mode == BranchInputMode.MutableBorrow)
            {
                if (mutableArm >= 0)
                {
                    throw Error(
                        arm.Line,
                        arm.Column,
                        $"branch arm '{arm.Label}' has an overlapping mutable borrow");
                }
                mutableArm = index;
            }
            if (sourceOwnsStorage && consumingArm >= 0 && index > consumingArm)
            {
                throw Error(
                    arm.Line,
                    arm.Column,
                    $"branch arm '{arm.Label}' starts after affine input consumption in arm '{expression.Arms[consumingArm].Label}'");
            }

            var flow = new FlowExpression(expression.Source, arm.Targets, arm.Line, arm.Column);
            var result = InferFlowExpression(
                flow,
                functions,
                bindings,
                allowReadIntCall,
                allowFlowBindingTarget: false,
                mutableBindings: mutableBindings);
            if (result.Type == BoundType.Unit)
            {
                throw Error(arm.Line, arm.Column, $"branch arm '{arm.Label}' must produce a value");
            }
            if (expression.IsParallel)
            {
                var resolvedTargets = new List<BoundFunction>(arm.Targets.Count);
                foreach (var target in arm.Targets)
                {
                    if (!(_resolvedGenericCalls.TryGetValue(target, out var targetFunction)
                            || TryGetFunction(string.Join('.', target.Path), functions, out targetFunction)
                            || TryResolveInstanceMethod(sourceType, string.Join('.', target.Path), functions, out targetFunction)))
                    {
                        continue;
                    }
                    resolvedTargets.Add(targetFunction);
                    if (targetFunction.IsAsync || (targetFunction.Effects?.Count ?? 0) != 0)
                    {
                        throw Error(
                            target.Line,
                            target.Column,
                            $"parallel branch arm '{arm.Label}' cannot call effectful or async target '{string.Join('.', target.Path)}'");
                    }
                    var unsafeParameter = (targetFunction.AdditionalParameters ?? [])
                        .FirstOrDefault(parameter => parameter.Ownership is
                            BoundFunctionInputOwnership.Move or BoundFunctionInputOwnership.MutableBorrow);
                    if (unsafeParameter is not null)
                    {
                        throw Error(
                            target.Line,
                            target.Column,
                            $"parallel branch arm '{arm.Label}' argument '{unsafeParameter.Name}' must be Copy or readonly ref");
                    }
                }
                if (resolvedTargets.Count != arm.Targets.Count)
                {
                    throw Error(
                        arm.Line,
                        arm.Column,
                        $"parallel branch arm '{arm.Label}' contains an unresolved flow target");
                }
                parallelArmTargets.Add(resolvedTargets);
            }
            fields.Add((arm.Label, result.Type));
        }

        var displayName = "(" + string.Join(", ", fields.Select(field =>
            field.Label + ": " + FormatType(field.Type))) + ")";
        var resultType = _types.GetOrAddProduct(fields, displayName, expression.Line, expression.Column);
        if (expression.IsParallel)
        {
            var captures = SelectParallelBranchCapturedBindings(
                parallelArmTargets.SelectMany(static targets => targets),
                functions,
                bindings);
            foreach (var (name, type) in captures)
            {
                if (mutableBindings?.Contains(name) == true)
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"parallel branch cannot capture mutable binding '{name}'");
                }
                if (!IsParallelSharedTypeSupported(type))
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"parallel branch cannot capture non-sendable binding '{name}' of type {FormatType(type)}");
                }
            }
            _parallelBranches[expression] = new BoundParallelBranch(
                sourceType,
                resultType,
                parallelArmTargets,
                captures);
        }
        return resultType;
    }

    private BoundType InferTapExpression(
        TapExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        var sourceType = InferExpression(
            expression.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (expression.Targets.Count == 0)
        {
            throw Error(expression.Line, expression.Column, "tap requires a side-flow target");
        }
        var first = new BranchArm("tap", BranchInputMode.Default, expression.Targets, expression.Line, expression.Column);
        var mode = ResolveBranchArmMode(first, sourceType, functions);
        if (_types.ContainsOwnedStorage(sourceType) && mode == BranchInputMode.Move)
        {
            throw Error(
                expression.Line,
                expression.Column,
                "tap cannot preserve an affine input after a move; use a readonly or mutable borrow target");
        }
        _ = InferFlowExpression(
            new FlowExpression(expression.Source, expression.Targets, expression.Line, expression.Column),
            functions,
            bindings,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        return sourceType;
    }

    private BoundType InferPartitionExpression(
        PartitionExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        var sourceType = InferExpression(
            expression.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        var isEvent = _types.TryGetEventStreamValue(sourceType, out var elementType);
        if (!isEvent && !_types.TryGetStreamValue(sourceType, out elementType))
        {
            throw Error(
                expression.Source.Line,
                expression.Source.Column,
                $"partition expects Stream<T> or EventStream<T> but received {FormatType(sourceType)}");
        }

        var routeBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal);
        if (!routeBindings.TryAdd(expression.ItemName, elementType))
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"partition item name '{expression.ItemName}' conflicts with an existing binding");
        }
        foreach (var arm in expression.Arms)
        {
            if (arm.Condition is null)
            {
                continue;
            }

            NoteLongControlCondition(arm.Condition, arm.Line, "partition");
            var conditionType = InferExpression(
                arm.Condition,
                functions,
                routeBindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false,
                mutableBindings: mutableBindings);
            if (conditionType != BoundType.Bool)
            {
                throw Error(
                    arm.Condition.Line,
                    arm.Condition.Column,
                    $"partition route '{arm.Label}' predicate must be Bool but received {FormatType(conditionType)}");
            }
            var consumedPredicateSources = GetOwnedParameterConsumedSourceNames(
                arm.Condition,
                functions,
                routeBindings);
            if (consumedPredicateSources.Contains(expression.ItemName, StringComparer.Ordinal))
            {
                throw Error(
                    arm.Condition.Line,
                    arm.Condition.Column,
                    $"partition route '{arm.Label}' predicate cannot consume item '{expression.ItemName}' before routing");
            }
        }

        var fields = expression.Arms
            .Select(arm => ((string?)arm.Label, (BoundType)sourceType))
            .ToArray();
        var displayName = "(" + string.Join(", ", fields.Select(field =>
            field.Item1 + ": " + FormatType(field.Item2))) + ")";
        _partitionExpressionSources[expression] = (elementType, isEvent);
        return _types.GetOrAddProduct(fields, displayName, expression.Line, expression.Column);
    }

    private BoundType InferStreamJoinExpression(
        StreamJoinExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        var sourceType = InferExpression(
            expression.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (!_types.IsProduct(sourceType))
        {
            throw Error(
                expression.Source.Line,
                expression.Source.Column,
                $"{expression.Policy.ToString().ToLowerInvariant()} expects a product of at least two streams");
        }

        var product = _types.GetStruct(sourceType);
        if (product.Fields.Count < 2)
        {
            throw Error(expression.Line, expression.Column, "a stream join requires at least two inputs");
        }
        var inputs = new List<BoundStreamJoinInput>(product.Fields.Count);
        foreach (var field in product.Fields)
        {
            var isEvent = _types.TryGetEventStreamValue(field.Type, out var elementType);
            if (!isEvent && !_types.TryGetStreamValue(field.Type, out elementType))
            {
                throw Error(
                    expression.Source.Line,
                    expression.Source.Column,
                    $"{expression.Policy.ToString().ToLowerInvariant()} input field '{field.Name}' must be Stream<T> or EventStream<T> but received {FormatType(field.Type)}");
            }
            inputs.Add(new BoundStreamJoinInput(field.Name, field.Type, elementType, isEvent));
        }

        TypeId outputElementType;
        if (expression.Policy is StreamJoinPolicy.Merge or StreamJoinPolicy.Concat)
        {
            outputElementType = inputs[0].ElementType;
            var incompatible = inputs.FirstOrDefault(input => input.ElementType != outputElementType);
            if (incompatible is not null)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"{expression.Policy.ToString().ToLowerInvariant()} requires identical element types; field '{incompatible.FieldName}' is {FormatType(incompatible.ElementType)} instead of {FormatType(outputElementType)}");
            }
        }
        else
        {
            var fields = inputs.Select(input =>
            {
                var sourceField = product.GetField(input.FieldName);
                var label = sourceField.Name.StartsWith('_') ? null : sourceField.Name;
                return ((string?)label, input.ElementType);
            }).ToArray();
            var displayName = "(" + string.Join(", ", fields.Select(field =>
                field.Item1 is null
                    ? FormatType(field.ElementType)
                    : field.Item1 + ": " + FormatType(field.ElementType))) + ")";
            outputElementType = _types.GetOrAddProduct(fields, displayName, expression.Line, expression.Column);
            if (expression.Policy == StreamJoinPolicy.Latest
                && inputs.Any(input => _types.ContainsOwnedStorage(input.ElementType)))
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "latest requires Copy element types because every update re-emits the current tuple; clone owned values explicitly before joining");
            }
        }

        var isEventResult = inputs.Any(static input => input.IsEvent)
            || expression.Policy is StreamJoinPolicy.Merge or StreamJoinPolicy.Latest;
        var resultType = isEventResult
            ? _types.GetOrAddEventStream(outputElementType)
            : _types.GetOrAddStream(outputElementType);
        var bufferCapacity = expression.Policy switch
        {
            StreamJoinPolicy.Concat => 0,
            StreamJoinPolicy.Zip => 1,
            StreamJoinPolicy.Merge => 1,
            StreamJoinPolicy.Latest => 1,
            _ => throw new InvalidOperationException("unknown stream join policy")
        };
        _streamJoins[expression] = new BoundStreamJoin(
            expression.Policy,
            sourceType,
            inputs,
            outputElementType,
            resultType,
            isEventResult,
            bufferCapacity);
        return resultType;
    }

    private BranchInputMode ResolveBranchArmMode(
        BranchArm arm,
        BoundType sourceType,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var firstTarget = arm.Targets[0];
        var path = string.Join('.', firstTarget.Path);
        if (!TryGetFunction(path, functions, out var function)
            && !TryResolveInstanceMethod(sourceType, path, functions, out function))
        {
            return arm.InputMode;
        }
        var functionMode = function.InputOwnership switch
        {
            BoundFunctionInputOwnership.Move => BranchInputMode.Move,
            BoundFunctionInputOwnership.MutableBorrow => BranchInputMode.MutableBorrow,
            _ => BranchInputMode.ReadonlyBorrow
        };
        if (arm.InputMode != BranchInputMode.Default && arm.InputMode != functionMode)
        {
            throw Error(
                arm.Line,
                arm.Column,
                $"branch arm '{arm.Label}' declares {FormatBranchInputMode(arm.InputMode)} but target '{path}' requires {FormatBranchInputMode(functionMode)}");
        }
        return arm.InputMode == BranchInputMode.Default ? functionMode : arm.InputMode;
    }

    private static string FormatBranchInputMode(BranchInputMode mode) => mode switch
    {
        BranchInputMode.ReadonlyBorrow => "ref",
        BranchInputMode.MutableBorrow => "mut",
        BranchInputMode.Move => "move",
        _ => "default flow"
    };

    private BoundType InferStringExpression(
        StringExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        foreach (var segment in expression.Segments)
        {
            if (segment is not InterpolationSegment interpolation)
            {
                continue;
            }

            if (!interpolation.IsParenthesized
                && interpolation.Expression is NameExpression name
                && !bindings.ContainsKey(name.Name)
                && !TryGetFunction(name.Name, functions, out _))
            {
                var prefix = bindings.Keys
                    .Where(candidate => name.Name.StartsWith(candidate, StringComparison.Ordinal)
                        && candidate.Length < name.Name.Length)
                    .OrderByDescending(static candidate => candidate.Length)
                    .FirstOrDefault();
                if (prefix is not null)
                {
                    var suffix = name.Name[prefix.Length..];
                    throw Error(
                        name.Line,
                        name.Column,
                        $"unknown binding '{name.Name}'; use '$({prefix}){suffix}' to mark the interpolation boundary");
                }
            }

            var interpolationType = InferExpression(
                interpolation.Expression,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
            EnsureDisplayable(interpolationType, expression.Line, expression.Column, "string interpolation");
        }

        return BoundType.Text;
    }

    private BoundType InferArrayLiteralExpression(
        ArrayLiteralExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        BoundType? contextualElementType = null)
    {
        BoundType? inferredElementType = expression.ElementType is null
            ? contextualElementType
            : ParseType(expression.ElementType, expression.Line, expression.Column);
        foreach (var element in expression.Elements)
        {
            var elementType = inferredElementType is { } expectedElementType
                ? InferContextualValue(
                    element,
                    expectedElementType,
                    functions,
                    bindings,
                    allowReadIntCall)
                : element is DictionaryLiteralExpression contextual
                && inferredElementType is { } inferredContextualElementType
                && _types.IsStruct(inferredContextualElementType)
                    ? InferContextualStructLiteral(
                        contextual,
                        inferredContextualElementType,
                        functions,
                        bindings,
                        allowReadIntCall)
                    : InferExpression(
                        element,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall,
                        allowFlowBindingTarget: false);
            if (elementType == BoundType.Unit
                || elementType is BoundType.IntSlice
                    or BoundType.StaticIntArray
                    or BoundType.StaticTextArray
                    or BoundType.DynamicIntArray
                    or BoundType.IntDictionaryView
                    or BoundType.IntDictionary
                || _types.IsStaticArray(elementType))
            {
                throw Error(element.Line, element.Column, "fixed array elements must be inline scalar or user values");
            }
            if (inferredElementType is not null && inferredElementType != elementType)
            {
                throw Error(
                    element.Line,
                    element.Column,
                    $"array elements must have one type; expected {FormatType(inferredElementType.Value)}, got {FormatType(elementType)}");
            }
            inferredElementType = elementType;
        }

        if (expression.BoundedCapacity is { } boundedCapacity)
        {
            if (expression.Elements.Count > boundedCapacity)
            {
                throw Error(expression.Line, expression.Column,
                    $"bounded array initializer has {expression.Elements.Count} elements but capacity is {boundedCapacity}");
            }
            var elementType = inferredElementType
                ?? throw Error(expression.Line, expression.Column, "bounded array literal requires an element type");
            return _types.GetOrAddBoundedArray(elementType, boundedCapacity);
        }

        if (expression.IsDynamic)
        {
            return inferredElementType switch
            {
                null or BoundType.Int => BoundType.DynamicIntArray,
                var elementType => _types.GetOrAddDynamicArray(elementType.Value)
            };
        }

        return inferredElementType switch
        {
            null or BoundType.Int => BoundType.StaticIntArray,
            BoundType.Text => BoundType.StaticTextArray,
            _ => _types.GetOrAddStaticArray(inferredElementType.Value)
        };
    }

    private BoundType InferArrayRepeatExpression(
        ArrayRepeatExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        BoundType? contextualElementType = null)
    {
        var valueType = contextualElementType is { } expectedElement
            ? InferContextualValue(expression.Value, expectedElement, functions, bindings, allowReadIntCall)
            : InferExpression(
                expression.Value,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
        if (valueType == BoundType.Unit
            || valueType == BoundType.Text
            || IsNestedContainerElementType(valueType)
            || _types.ContainsOwnedStorage(valueType))
        {
            throw Error(
                expression.Value.Line,
                expression.Value.Column,
                "array repeat value must be an inline copyable value");
        }

        if (expression.CountParameterName is { } countParameterName
            && (!bindings.TryGetValue(countParameterName, out var countType) || countType != BoundType.Int))
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"unknown compile-time Int value parameter '{countParameterName}'");
        }

        if (expression.Count is { } concreteCount)
        {
            return _types.GetOrAddFixedStaticArray(valueType, concreteCount);
        }

        return valueType == BoundType.Int
            ? BoundType.StaticIntArray
            : _types.GetOrAddStaticArray(valueType);
    }

    private BoundType InferTypedEmptyArrayExpression(TypedEmptyArrayExpression expression)
    {
        if (expression.BoundedCapacity is { } boundedCapacity)
        {
            var boundedElementType = ParseType(expression.ElementType, expression.Line, expression.Column);
            if (boundedElementType == BoundType.Unit || IsNestedContainerElementType(boundedElementType))
            {
                throw Error(expression.Line, expression.Column, "bounded array elements must be inline scalar or user values");
            }
            return _types.GetOrAddBoundedArray(boundedElementType, boundedCapacity);
        }
        if (expression.ElementType == "Int")
        {
            return BoundType.DynamicIntArray;
        }
        var elementType = ParseType(expression.ElementType, expression.Line, expression.Column);
        if (elementType == BoundType.Unit
            || IsNestedContainerElementType(elementType))
        {
            throw Error(expression.Line, expression.Column, "growable array elements must be inline scalar or user values");
        }
        return _types.GetOrAddDynamicArray(elementType);
    }

    private BoundType InferDictionaryLiteralExpression(
        DictionaryLiteralExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        BoundType? inferredKeyType = expression.KeyType is null
            ? null
            : ParseType(expression.KeyType, expression.Line, expression.Column);
        BoundType? inferredValueType = expression.ValueType is null
            ? null
            : ParseType(expression.ValueType, expression.Line, expression.Column);
        if (inferredKeyType is { } declaredKey && !IsSupportedDictionaryKeyType(declaredKey))
        {
            throw Error(expression.Line, expression.Column,
                $"dictionary key type {FormatType(declaredKey)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
        }
        foreach (var entry in expression.Entries)
        {
            var keyType = entry.Key is DictionaryLiteralExpression contextual
                && inferredKeyType is { } contextualKeyType
                && _types.IsStruct(contextualKeyType)
                    ? InferContextualStructLiteral(
                        contextual,
                        contextualKeyType,
                        functions,
                        bindings,
                        allowReadIntCall)
                    : InferExpression(
                        entry.Key,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall,
                        allowFlowBindingTarget: false);
            if (!IsSupportedDictionaryKeyType(keyType))
            {
                throw Error(entry.Key.Line, entry.Key.Column,
                    $"dictionary key type {FormatType(keyType)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
            }
            if (inferredKeyType is { } expectedKey && keyType != expectedKey)
            {
                throw Error(entry.Key.Line, entry.Key.Column,
                    $"dictionary keys must have one type; expected {FormatType(expectedKey)}, got {FormatType(keyType)}");
            }
            inferredKeyType ??= keyType;

            var valueType = entry.Value is DictionaryLiteralExpression contextualValue
                && inferredValueType is { } contextualValueType
                && _types.IsStruct(contextualValueType)
                    ? InferContextualStructLiteral(
                        contextualValue,
                        contextualValueType,
                        functions,
                        bindings,
                        allowReadIntCall)
                    : InferExpression(
                        entry.Value,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall,
                        allowFlowBindingTarget: false);
            if (valueType == BoundType.Unit)
            {
                throw Error(entry.Value.Line, entry.Value.Column, "dictionary values cannot be Unit");
            }
            if (inferredValueType is { } expectedValue && valueType != expectedValue)
            {
                throw Error(entry.Value.Line, entry.Value.Column,
                    $"dictionary values must have one type; expected {FormatType(expectedValue)}, got {FormatType(valueType)}");
            }
            inferredValueType ??= valueType;
        }

        var key = inferredKeyType ?? throw Error(expression.Line, expression.Column, "dictionary literal requires at least one entry");
        var value = inferredValueType!.Value;
        if (expression.BoundedCapacity is { } boundedCapacity)
        {
            if (expression.Entries.Count > boundedCapacity)
            {
                throw Error(expression.Line, expression.Column,
                    $"bounded dictionary initializer has {expression.Entries.Count} entries but capacity is {boundedCapacity}");
            }
            return _types.GetOrAddBoundedDictionary(key, value, boundedCapacity);
        }
        return key == BoundType.Int && value == BoundType.Int
            ? BoundType.IntDictionary
            : _types.GetOrAddDictionary(key, value);
    }

    private BoundType InferTypedEmptyDictionaryExpression(TypedEmptyDictionaryExpression expression)
    {
        var keyType = ParseType(expression.KeyType, expression.Line, expression.Column);
        var valueType = ParseType(expression.ValueType, expression.Line, expression.Column);
        if (!IsSupportedDictionaryKeyType(keyType))
        {
            throw Error(expression.Line, expression.Column,
                $"dictionary key type {FormatType(keyType)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
        }
        if (expression.BoundedCapacity is { } boundedCapacity)
        {
            return _types.GetOrAddBoundedDictionary(keyType, valueType, boundedCapacity);
        }
        return keyType == BoundType.Int && valueType == BoundType.Int
            ? BoundType.IntDictionary
            : _types.GetOrAddDictionary(keyType, valueType);
    }

    private BoundType InferIndexExpression(
        IndexExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        bool allowOwnedElementBorrow)
    {
        var sourceType = InferExpression(
            expression.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            allowOwnedElementBorrow: allowOwnedElementBorrow);
        if (_types.IsReference(sourceType))
        {
            sourceType = _types.GetReference(sourceType).ElementType;
        }
        if (_types.IsBinaryHeap(sourceType) || _types.IsDeque(sourceType) || _types.IsSet(sourceType))
        {
            throw Error(expression.Source.Line, expression.Source.Column,
                $"{FormatType(sourceType)} preserves its invariant and does not support indexing");
        }
        if (sourceType is not (BoundType.IntSlice
            or BoundType.StaticIntArray
            or BoundType.StaticTextArray
            or BoundType.DynamicIntArray
            or BoundType.IntDictionaryView
            or BoundType.IntDictionary
            or BoundType.Arguments
            or BoundType.MappedBytes
            or BoundType.MutableMappedBytes)
            && !_types.IsStaticArray(sourceType)
            && !_types.IsSlice(sourceType)
            && !_types.IsDynamicArray(sourceType)
            && !_types.IsBoundedArray(sourceType)
            && !_types.IsDictionary(sourceType))
        {
            throw Error(expression.Source.Line, expression.Source.Column,
                "indexing expects an array, dictionary, or mapped byte view");
        }

        var expectedIndexType = sourceType is BoundType.MappedBytes or BoundType.MutableMappedBytes or BoundType.Arguments
            ? BoundType.UIntSize
            : _types.IsDictionary(sourceType)
            ? _types.GetDictionary(sourceType).KeyType
            : BoundType.Int;
        var indexType = expression.Index is NumberExpression
                && sourceType is BoundType.MappedBytes or BoundType.MutableMappedBytes or BoundType.Arguments
            ? BoundType.UIntSize
            : expression.Index is DictionaryLiteralExpression contextual
            && _types.IsStruct(expectedIndexType)
                ? InferContextualStructLiteral(contextual, expectedIndexType, functions, bindings, allowReadIntCall)
                : InferExpression(
                    expression.Index,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
        if (indexType != expectedIndexType)
        {
            throw Error(expression.Index.Line, expression.Index.Column,
                $"index must be {FormatType(expectedIndexType)}");
        }

        if (_types.IsSlice(sourceType))
        {
            return _types.GetSliceElement(sourceType);
        }
        if (_types.IsStaticArray(sourceType))
        {
            var elementType = _types.GetStaticArray(sourceType).ElementType;
            if (_types.ContainsOwnedStorage(elementType) && !allowOwnedElementBorrow)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"indexing owned array element type {FormatType(elementType)} may only borrow it directly for a readonly call; use take to move it out");
            }
            return elementType;
        }
        if (sourceType is BoundType.MappedBytes or BoundType.MutableMappedBytes)
        {
            return BoundType.UInt8;
        }
        if (sourceType == BoundType.Arguments)
        {
            return BoundType.Text;
        }
        if (_types.IsDynamicArray(sourceType))
        {
            var elementType = _types.GetDynamicArray(sourceType).ElementType;
            if (_types.ContainsOwnedStorage(elementType) && !allowOwnedElementBorrow)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"indexing owned array element type {FormatType(elementType)} may only borrow it directly for a readonly call; use take to move it out");
            }
            return elementType;
        }
        if (_types.IsBoundedArray(sourceType))
        {
            var elementType = _types.GetBoundedArray(sourceType).ElementType;
            if (_types.ContainsOwnedStorage(elementType) && !allowOwnedElementBorrow)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"indexing owned array element type {FormatType(elementType)} may only borrow it directly for a readonly call; use take to move it out");
            }
            return elementType;
        }
        if (_types.IsDictionary(sourceType))
        {
            var valueType = _types.GetDictionary(sourceType).ValueType;
            if (_types.ContainsOwnedStorage(valueType) && !allowOwnedElementBorrow)
            {
                throw Error(expression.Line, expression.Column,
                    $"indexing owned dictionary value type {FormatType(valueType)} may only borrow it directly for a readonly call; use take to move it out");
            }
            return valueType;
        }
        return sourceType == BoundType.StaticTextArray ? BoundType.Text : BoundType.Int;
    }

    private BoundType InferContextualStructLiteral(
        DictionaryLiteralExpression expression,
        BoundType expectedType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var definition = _types.GetStruct(expectedType);
        if (definition.ComInterface is not null || definition.NativeHandle is not null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"opaque handle '{definition.Name}' can only be created by its native constructor");
        }
        var initializers = new Dictionary<string, DictionaryEntryExpression>(StringComparer.Ordinal);
        foreach (var entry in expression.Entries)
        {
            if (entry.Key is not NameExpression name)
            {
                throw Error(entry.Key.Line, entry.Key.Column,
                    $"contextual {definition.Name} literal field name must be an identifier");
            }
            if (!initializers.TryAdd(name.Name, entry))
            {
                throw Error(name.Line, name.Column,
                    $"field '{name.Name}' is initialized more than once");
            }
        }

        foreach (var field in definition.Fields)
        {
            if (!initializers.TryGetValue(field.Name, out var initializer))
            {
                throw Error(expression.Line, expression.Column,
                    $"contextual {definition.Name} literal is missing field '{field.Name}'");
            }
            var actualType = InferStructFieldValue(
                initializer.Value, field.Type, functions, bindings, allowReadIntCall);
            MarkFixedLengthCandidateRequiresGrowable(initializer.Value, field.Type, actualType);
            if (actualType != field.Type)
            {
                throw Error(initializer.Value.Line, initializer.Value.Column,
                    $"field '{definition.Name}.{field.Name}' expects {FormatType(field.Type)}, got {FormatType(actualType)}");
            }
        }

        var unknown = initializers.Keys.FirstOrDefault(name =>
            !definition.Fields.Any(field => field.Name == name));
        if (unknown is not null)
        {
            var entry = initializers[unknown];
            throw Error(entry.Key.Line, entry.Key.Column,
                $"struct '{definition.Name}' has no field '{unknown}'");
        }
        return expectedType;
    }

    private BoundType InferStructLiteralExpression(
        StructLiteralExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        if (!_types.TryResolve(expression.TypeName, out var type) || !_types.IsStruct(type))
        {
            throw Error(expression.Line, expression.Column, $"unknown struct type '{expression.TypeName}'");
        }
        EnsureTypeVisible(type, expression.Line, expression.Column);

        var definition = _types.GetStruct(type);
        if (definition.ComInterface is not null || definition.NativeHandle is not null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"opaque handle '{definition.Name}' can only be created by its native constructor");
        }
        var initializers = new Dictionary<string, StructFieldInitializer>(StringComparer.Ordinal);
        foreach (var initializer in expression.Fields)
        {
            if (!initializers.TryAdd(initializer.Name, initializer))
            {
                throw Error(
                    initializer.Line,
                    initializer.Column,
                    $"field '{initializer.Name}' is initialized more than once in '{definition.Name}'");
            }
        }

        foreach (var initializer in expression.Fields)
        {
            var field = definition.Fields.FirstOrDefault(candidate => candidate.Name == initializer.Name);
            if (field is null)
            {
                throw Error(
                    initializer.Line,
                    initializer.Column,
                    $"struct '{definition.Name}' has no field '{initializer.Name}'");
            }

            var actualType = InferStructFieldValue(
                initializer.Value, field.Type, functions, bindings, allowReadIntCall);
            MarkFixedLengthCandidateRequiresGrowable(initializer.Value, field.Type, actualType);
            if (actualType != field.Type)
            {
                throw Error(
                    initializer.Value.Line,
                    initializer.Value.Column,
                    $"field '{field.Name}' expects {FormatType(field.Type)}, got {FormatType(actualType)}");
            }
        }

        var missing = definition.Fields.FirstOrDefault(field => !initializers.ContainsKey(field.Name));
        if (missing is not null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"struct '{definition.Name}' requires field '{missing.Name}' to be initialized");
        }

        return type;
    }

    private BoundType InferStructFieldValue(
        Expression value,
        BoundType expectedType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferContextualValue(
            value,
            expectedType,
            functions,
            bindings,
            allowReadIntCall);
    }

    private BoundType InferContextualValue(
        Expression value,
        BoundType expectedType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings = null,
        BoundType? yieldInputType = null,
        string? allowedOwnedOuterResultName = null)
    {
        WarnRedundantNumericType(value, expectedType);
        if (IsIntegerType(expectedType) && IsIntegerLiteralExpression(value))
        {
            ValidateNumericLiteralConversion(value, expectedType, FormatType(expectedType));
            return expectedType;
        }

        if (IsFloatType(expectedType) && IsNumericLiteralExpression(value))
        {
            return expectedType;
        }

        if (value is WhenExpression whenExpression && IsIntegerType(expectedType))
        {
            return InferWhenExpression(
                whenExpression,
                functions,
                bindings,
                allowReadIntCall,
                allowedOwnedOuterResultName,
                mutableBindings: mutableBindings,
                expectedResultType: expectedType);
        }

        if (value is IfExpression conditional && IsIntegerType(expectedType))
        {
            return InferIfExpression(
                conditional,
                functions,
                bindings,
                allowReadIntCall,
                allowedOwnedOuterResultName,
                mutableBindings: mutableBindings,
                expectedResultType: expectedType);
        }

        if (IsIntegerType(expectedType)
            && TryGetNumericBinaryOperands(value, out var left, out var right, out var operatorText))
        {
            return InferContextualIntegerBinaryExpression(
                left,
                right,
                expectedType,
                operatorText,
                functions,
                bindings,
                allowReadIntCall);
        }

        if (value is DictionaryLiteralExpression structure && _types.IsStruct(expectedType))
        {
            return InferContextualStructLiteral(
                structure,
                expectedType,
                functions,
                bindings,
                allowReadIntCall);
        }

        if (value is ArrayLiteralExpression array
            && TryGetContextualArrayElementType(expectedType, out var elementType))
        {
            var actualType = InferArrayLiteralExpression(
                array,
                functions,
                bindings,
                allowReadIntCall,
                elementType);
            if (_types.IsStaticArray(expectedType)
                && _types.GetStaticArray(expectedType).FixedLength is { } fixedLength)
            {
                if (array.Elements.Count != fixedLength)
                {
                    throw Error(
                        array.Line,
                        array.Column,
                        $"fixed array expects {fixedLength} elements, got {array.Elements.Count}");
                }
                return expectedType;
            }
            if (_types.IsBoundedArray(expectedType))
            {
                var capacity = _types.GetBoundedArray(expectedType).Capacity;
                if (array.Elements.Count > capacity)
                {
                    throw Error(
                        array.Line,
                        array.Column,
                        $"bounded array capacity is {capacity}, got {array.Elements.Count} elements");
                }
                return expectedType;
            }
            if (expectedType == BoundType.DynamicIntArray || _types.IsDynamicArray(expectedType))
            {
                return expectedType;
            }
            return actualType;
        }

        if (value is ArrayRepeatExpression repeat
            && TryGetContextualArrayElementType(expectedType, out var repeatElementType))
        {
            var actualType = InferArrayRepeatExpression(
                repeat,
                functions,
                bindings,
                allowReadIntCall,
                repeatElementType);
            if (_types.IsStaticArray(expectedType)
                && _types.GetStaticArray(expectedType).FixedLength is { } fixedLength)
            {
                if (repeat.Count != fixedLength)
                {
                    throw Error(
                        repeat.Line,
                        repeat.Column,
                        $"fixed array expects {fixedLength} repeated elements, got {repeat.CountParameterName ?? repeat.Count?.ToString() ?? "unknown"}");
                }
                return expectedType;
            }
            if (_types.IsBoundedArray(expectedType))
            {
                var capacity = _types.GetBoundedArray(expectedType).Capacity;
                if (repeat.Count is { } count && count > capacity)
                {
                    throw Error(
                        repeat.Line,
                        repeat.Column,
                        $"bounded array capacity is {capacity}, got {count} repeated elements");
                }
                return expectedType;
            }
            if (expectedType == BoundType.DynamicIntArray || _types.IsDynamicArray(expectedType))
            {
                return expectedType;
            }
            return actualType;
        }

        return InferExpression(
            value,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            yieldInputType: yieldInputType,
            mutableBindings: mutableBindings,
            allowedOwnedOuterResultName: allowedOwnedOuterResultName);
    }

    private bool TryGetContextualArrayElementType(BoundType type, out BoundType elementType)
    {
        if (_types.IsSlice(type))
        {
            elementType = _types.GetSliceElement(type);
            return true;
        }
        if (type == BoundType.StaticIntArray || type == BoundType.DynamicIntArray)
        {
            elementType = BoundType.Int;
            return true;
        }
        if (type == BoundType.StaticTextArray)
        {
            elementType = BoundType.Text;
            return true;
        }
        if (_types.IsStaticArray(type))
        {
            elementType = _types.GetStaticArray(type).ElementType;
            return true;
        }
        if (_types.IsDynamicArray(type))
        {
            elementType = _types.GetDynamicArray(type).ElementType;
            return true;
        }
        if (_types.IsBoundedArray(type))
        {
            elementType = _types.GetBoundedArray(type).ElementType;
            return true;
        }

        elementType = default;
        return false;
    }

    private BoundType InferFieldAccessExpression(
        FieldAccessExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        bool allowOwnedElementBorrow)
    {
        if (expression.Source is NameExpression functionOwner
            && !bindings.ContainsKey(functionOwner.Name)
            && functions.TryGetValue(functionOwner.Name + "." + expression.FieldName, out var zeroArgumentFunction)
            && zeroArgumentFunction.InputType is null)
        {
            EnsureFunctionVisible(zeroArgumentFunction, expression.Line, expression.Column);
            EnsureAsyncRuntimeCallable(
                zeroArgumentFunction,
                expression.Line,
                expression.Column,
                functionOwner.Name + "." + expression.FieldName);
            if (IsMainOnlyRuntimeWrapper(zeroArgumentFunction) && !allowReadIntCall)
            {
                throw Error(expression.Line, expression.Column,
                    $"{zeroArgumentFunction.Name} is only valid in main for the current runtime slice");
            }
            throw Error(
                expression.Line,
                expression.Column,
                $"zero-input function '{functionOwner.Name}.{expression.FieldName}' must be called with parentheses: "
                + $"'{functionOwner.Name}.{expression.FieldName}()'");
        }

        if (expression.Source is NameExpression genericTypeName
            && !bindings.ContainsKey(genericTypeName.Name)
            && (genericTypeName.Name.StartsWith("Option<", StringComparison.Ordinal)
                || genericTypeName.Name.StartsWith("Result<", StringComparison.Ordinal)))
        {
            var genericEnumType = ParseType(genericTypeName.Name, expression.Line, expression.Column);
            var enumeration = _types.GetEnum(genericEnumType);
            var variant = enumeration.Variants.FirstOrDefault(candidate => candidate.Name == expression.FieldName)
                ?? throw Error(expression.Line, expression.Column,
                    $"enum '{FormatType(genericEnumType)}' has no variant '{expression.FieldName}'");
            if (variant.PayloadType is { } genericPayload
                && genericPayload != BoundType.Unit)
            {
                throw Error(expression.Line, expression.Column,
                    $"variant '{FormatType(genericEnumType)}.{variant.Name}' requires a payload argument");
            }
            return genericEnumType;
        }
        if (expression.Source is NameExpression typeName
            && !bindings.ContainsKey(typeName.Name)
            && _types.TryResolve(typeName.Name, out var enumType)
            && _types.IsEnum(enumType))
        {
            EnsureTypeVisible(enumType, expression.Line, expression.Column);
            var enumeration = _types.GetEnum(enumType);
            var variant = enumeration.Variants.FirstOrDefault(candidate => candidate.Name == expression.FieldName)
                ?? throw Error(
                    expression.Line,
                    expression.Column,
                    $"enum '{enumeration.Name}' has no variant '{expression.FieldName}'");
            if (variant.PayloadType is { } payload
                && payload != BoundType.Unit)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"variant '{enumeration.Name}.{variant.Name}' requires a payload argument");
            }

            return enumType;
        }

        if (expression.Source is NameExpression staticTypeName
            && !bindings.ContainsKey(staticTypeName.Name)
            && _types.TryResolve(staticTypeName.Name, out var staticType)
            && _types.IsStruct(staticType))
        {
            EnsureTypeVisible(staticType, expression.Line, expression.Column);
            var memberPath = staticTypeName.Name + "." + expression.FieldName;
            if (functions.TryGetValue(memberPath, out var associated) && associated.InputType is null)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"zero-input associated function '{memberPath}' must be called with parentheses: '{memberPath}()'");
            }

            throw Error(
                expression.Line,
                expression.Column,
                $"type '{staticTypeName.Name}' has no zero-argument associated member '{expression.FieldName}'");
        }

        var sourceType = InferExpression(
            expression.Source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            // Field access keeps an indexed element as a place. The selected
            // field below decides whether an owned value would escape.
            allowOwnedElementBorrow: true);
        if (_types.IsReference(sourceType))
        {
            sourceType = _types.GetReference(sourceType).ElementType;
        }
        if (_types.IsBox(sourceType))
        {
            sourceType = _types.GetBox(sourceType).ElementType;
        }
        if (!_types.IsStruct(sourceType))
        {
            throw Error(expression.Line, expression.Column, "field access expects a struct value");
        }

        var definition = _types.GetStruct(sourceType);
        if (definition.ComInterface is not null || definition.NativeHandle is not null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"opaque handle '{definition.Name}' does not expose its raw value");
        }
        var field = definition.Fields.FirstOrDefault(candidate => candidate.Name == expression.FieldName);
        if (field is not null)
        {
            if (_types.ContainsOwnedStorage(field.Type)
                && !allowOwnedElementBorrow
                && IndexedProjectionRoot(expression.Source) is { } indexedRoot)
            {
                var indexedSourceType = InferExpression(
                    indexedRoot.Source,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false,
                    allowOwnedElementBorrow: true);
                if (_types.IsReference(indexedSourceType))
                {
                    indexedSourceType = _types.GetReference(indexedSourceType).ElementType;
                }

                var indexedElementType = _types.IsDictionary(indexedSourceType)
                    ? _types.GetDictionary(indexedSourceType).ValueType
                    : _types.IsStaticArray(indexedSourceType)
                        ? _types.GetStaticArray(indexedSourceType).ElementType
                        : _types.IsDynamicArray(indexedSourceType)
                            ? _types.GetDynamicArray(indexedSourceType).ElementType
                            : sourceType;
                var containerName = _types.IsDictionary(indexedSourceType)
                    ? "dictionary value"
                    : "array element";
                throw Error(
                    indexedRoot.Line,
                    indexedRoot.Column,
                    $"indexing owned {containerName} type {FormatType(indexedElementType)} may only borrow it directly for a readonly call; use take to move it out");
            }
            return field.Type;
        }

        if (TryResolveInstanceMethod(sourceType, expression.FieldName, functions, out var method)
            && method.InputOwnership == BoundFunctionInputOwnership.Default)
        {
            EnsureFunctionVisible(method, expression.Line, expression.Column);
            EnsureAsyncRuntimeCallable(
                method,
                expression.Line,
                expression.Column,
                expression.FieldName);
            _resolvedGenericCalls[expression] = method;
            return method.ReturnType;
        }

        throw Error(
            expression.Line,
            expression.Column,
            $"struct '{definition.Name}' has no field or readonly computed member '{expression.FieldName}'");
    }

    private static IndexExpression? IndexedProjectionRoot(Expression expression)
    {
        while (expression is FieldAccessExpression field)
        {
            expression = field.Source;
        }
        return expression as IndexExpression;
    }

    private BoundType InferTryExpression(
        TryExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        var operandType = InferExpression(
            expression.Value,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (!_types.TryGetResultTypes(operandType, out var operandResult))
        {
            throw Error(expression.Line, expression.Column,
                $"'?' expects Result<T, E> but received {FormatType(operandType)}");
        }
        if (_currentFunctionReturnType is null
            || !_types.TryGetResultTypes(_currentFunctionReturnType.Value, out var outerResult))
        {
            throw Error(expression.Line, expression.Column,
                "'?' can only be used inside a function returning Result<T, E>");
        }
        if (operandResult.Error != outerResult.Error)
        {
            throw Error(expression.Line, expression.Column,
                $"'?' error type {FormatType(operandResult.Error)} does not match function error type {FormatType(outerResult.Error)}");
        }
        if ((_types.ContainsOwnedStorage(operandResult.Ok)
                || _types.ContainsOwnedStorage(operandResult.Error))
            && !IsConsumableOwnedResultExpression(expression.Value, functions, bindings))
        {
            throw Error(expression.Line, expression.Column,
                "owned Result '?' must consume a temporary Result or the function's explicit move input");
        }
        return operandResult.Ok;
    }

    private bool IsConsumableOwnedResultExpression(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (expression is CallExpression or FlowExpression)
        {
            return true;
        }
        if (expression is NameExpression name)
        {
            return !bindings.ContainsKey(name.Name)
                || _currentMoveInputNames.Contains(name.Name);
        }
        if (expression is FieldAccessExpression field
            && field.Source is NameExpression owner
            && functions.TryGetValue(owner.Name + "." + field.FieldName, out var function)
            && function.InputType is null)
        {
            return true;
        }
        return false;
    }

    private BoundType InferBoxExpression(
        BoxExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var elementType = InferExpression(
            expression.Value,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        var box = _types.Boxes.FirstOrDefault(candidate => candidate.ElementType == elementType)
            ?? throw Error(
                expression.Line,
                expression.Column,
                $"type {FormatType(elementType)} cannot be boxed in this slice");
        return box.Id;
    }

    private BoundType InferMapExpression(
        MapExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        EnsureEffectAllowed("File", expression.Line, expression.Column, "map");
        var pathType = InferExpression(expression.Path, functions, bindings,
            allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
        if (pathType != BoundType.Text)
        {
            throw Error(expression.Path.Line, expression.Path.Column, "map path must be Text");
        }
        ValidateMapContextValue(expression.Offset, BoundType.UInt64, "map offset", functions, bindings, allowReadIntCall);
        ValidateMapContextValue(expression.Length, BoundType.UIntSize, "map length", functions, bindings, allowReadIntCall);
        ValidateMapContextValue(expression.FileSize, BoundType.UInt64, "mapped file size", functions, bindings, allowReadIntCall);
        if (expression.Mode == MapAccessMode.Read && expression.FileSize is not null)
        {
            throw Error(expression.FileSize.Line, expression.FileSize.Column,
                "map read does not accept a file size");
        }
        return expression.Mode == MapAccessMode.Write
            ? BoundType.MutableMappedBytes
            : BoundType.MappedBytes;
    }

    private void ValidateMapContextValue(
        Expression? expression,
        BoundType expectedType,
        string role,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        if (expression is null || expression is NumberExpression)
        {
            return;
        }
        var actualType = InferExpression(expression, functions, bindings,
            allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
        if (actualType != expectedType)
        {
            throw Error(expression.Line, expression.Column,
                $"{role} must be {FormatType(expectedType)} or an integer literal");
        }
    }

    private BoundType InferAddExpression(
        AddExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "+");
    }

    private BoundType InferMultiplyExpression(
        MultiplyExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "*");
    }

    private BoundType InferSubtractExpression(
        SubtractExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "-");
    }

    private BoundType InferDivideExpression(
        DivideExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "/");
    }

    private BoundType InferModuloExpression(
        ModuloExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        return InferIntegerBinaryExpression(expression.Left, expression.Right, functions, bindings, allowReadIntCall, "%");
    }

    private BoundType InferNegateExpression(
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
        if (!IsSignedIntegerType(value) && !IsFloatType(value))
        {
            throw Error(expression.Value.Line, expression.Value.Column, "operand of unary '-' must be a signed numeric value");
        }

        return value;
    }

    private BoundType InferIntegerBinaryExpression(
        Expression leftExpression,
        Expression rightExpression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string operatorText)
    {
        var (left, right) = InferNumericOperands(
            leftExpression,
            rightExpression,
            functions,
            bindings,
            allowReadIntCall);
        if (left == BoundType.CodePoint)
        {
            throw Error(leftExpression.Line, leftExpression.Column,
                $"CodePoint does not support '{operatorText}'; convert it to UInt32 before arithmetic");
        }
        if (!IsNumericType(left) || (operatorText == "%" && !IsIntegerType(left)))
        {
            throw Error(leftExpression.Line, leftExpression.Column, $"left operand of '{operatorText}' must be a compatible numeric value");
        }

        if (right != left)
        {
            throw Error(rightExpression.Line, rightExpression.Column,
                $"operands of '{operatorText}' must have the same numeric type; left is {FormatType(left)}, right is {FormatType(right)}");
        }

        WarnRedundantNumericBinaryOperandTypes(leftExpression, rightExpression, left);

        return left;
    }

    private static bool TryGetNumericBinaryOperands(
        Expression expression,
        out Expression left,
        out Expression right,
        out string operatorText)
    {
        (left, right, operatorText) = expression switch
        {
            AddExpression value => (value.Left, value.Right, "+"),
            SubtractExpression value => (value.Left, value.Right, "-"),
            MultiplyExpression value => (value.Left, value.Right, "*"),
            DivideExpression value => (value.Left, value.Right, "/"),
            ModuloExpression value => (value.Left, value.Right, "%"),
            _ => (null!, null!, "")
        };
        return operatorText.Length != 0;
    }

    private BoundType InferContextualIntegerBinaryExpression(
        Expression left,
        Expression right,
        BoundType expectedType,
        string operatorText,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var leftType = InferContextualValue(left, expectedType, functions, bindings, allowReadIntCall);
        var rightType = InferContextualValue(right, expectedType, functions, bindings, allowReadIntCall);
        if (leftType != expectedType || rightType != expectedType)
        {
            var invalid = leftType != expectedType ? left : right;
            throw Error(
                invalid.Line,
                invalid.Column,
                $"operands of '{operatorText}' must have type {FormatType(expectedType)} in this context");
        }
        return expectedType;
    }

    private BoundType InferCompareExpression(
        CompareExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var (left, right) = InferNumericOperands(
            expression.Left,
            expression.Right,
            functions,
            bindings,
            allowReadIntCall);

        if (!IsNumericType(left))
        {
            throw Error(expression.Left.Line, expression.Left.Column, "left operand of comparison must be numeric");
        }

        if (right != left)
        {
            throw Error(expression.Right.Line, expression.Right.Column,
                $"comparison operands must have the same numeric type; left is {FormatType(left)}, right is {FormatType(right)}");
        }

        WarnRedundantNumericBinaryOperandTypes(expression.Left, expression.Right, left);

        return BoundType.Bool;
    }

    private (BoundType Left, BoundType Right) InferNumericOperands(
        Expression leftExpression,
        Expression rightExpression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        BoundType Infer(Expression expression) => InferExpression(
            expression,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);

        if (IsContextualNumericExpression(rightExpression)
            && !IsContextualNumericExpression(leftExpression))
        {
            var left = Infer(leftExpression);
            var right = InferContextualValue(
                rightExpression, left, functions, bindings, allowReadIntCall);
            return (left, right);
        }
        if (IsContextualNumericExpression(leftExpression)
            && !IsContextualNumericExpression(rightExpression))
        {
            var right = Infer(rightExpression);
            var left = InferContextualValue(
                leftExpression, right, functions, bindings, allowReadIntCall);
            return (left, right);
        }

        return (Infer(leftExpression), Infer(rightExpression));
    }

    private static bool IsContextualNumericExpression(Expression expression) =>
        IsNumericLiteralExpression(expression) || expression is IfExpression or WhenExpression;

    private BoundType InferLogicalExpression(
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

    private BoundType InferNotExpression(
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

    private BoundType InferIfExpression(
        IfExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string? allowedOwnedOuterResultName = null,
        IReadOnlySet<string>? mutableBindings = null,
        BoundType? expectedResultType = null)
    {
        if (expression.Else is not null
            && expression.Then.Statements.Count == 0
            && expression.Then.Value is null)
        {
            AddWarning(
                "S004",
                expression.Line,
                expression.Column,
                "the success branch is empty; replace 'condition -> if {} else { ... }' with 'condition -> unless { ... }'");
        }

        NoteLongControlCondition(
            UnwrapUnlessCondition(expression),
            expression.Line,
            IsUnlessCondition(expression) ? "unless" : "if");

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

        var branchEntryBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        var outerBorrowedContinuation = _borrowedTextContinuationNames;
        BoundType InferBranch(BlockBody body)
        {
            var previousContinuation = _borrowedTextContinuationNames;
            _conditionalDepth++;
            try
            {
                _borrowedTextContinuationNames = BorrowBlockMayReachContinuation(body)
                    ? outerBorrowedContinuation
                    : new HashSet<string>(StringComparer.Ordinal);
                return InferBlockBody(
                    body,
                    functions,
                    bindings,
                    allowReadIntCall,
                    allowedOwnedOuterResultName,
                    mutableBindings,
                    expectedResultType);
            }
            finally
            {
                _conditionalDepth--;
                _borrowedTextContinuationNames = previousContinuation;
            }
        }

        var thenReachesJoin = BorrowBlockMayReachContinuation(expression.Then);
        var thenType = InferBranch(expression.Then);
        var thenBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        RestoreBorrowedTextOriginState(branchEntryBorrowedTextOrigins);
        if (expression.Else is null)
        {
            if (thenType != BoundType.Unit)
            {
                throw Error(expression.Line, expression.Column, "if used as a value requires an else block");
            }

            RestoreBorrowedTextOriginState(MergeBorrowedTextOriginStates(
                thenReachesJoin
                    ? [branchEntryBorrowedTextOrigins, thenBorrowedTextOrigins]
                    : [branchEntryBorrowedTextOrigins]));
            ExpireBorrowedTextOriginsBeforeStatement(
                [],
                0,
                null,
                _borrowedTextContinuationNames);
            return BoundType.Unit;
        }

        var elseReachesJoin = BorrowBlockMayReachContinuation(expression.Else);
        var elseType = InferBranch(expression.Else);
        var elseBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        RestoreBorrowedTextOriginState(MergeBorrowedTextOriginStates(
            (thenReachesJoin, elseReachesJoin) switch
            {
                (true, true) => [thenBorrowedTextOrigins, elseBorrowedTextOrigins],
                (true, false) => [thenBorrowedTextOrigins],
                (false, true) => [elseBorrowedTextOrigins],
                _ => []
            }));
        if (thenReachesJoin && elseReachesJoin && thenType != elseType)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"if branches must return the same type, got {FormatType(thenType)} and {FormatType(elseType)}");
        }

        ExpireBorrowedTextOriginsBeforeStatement(
            [],
            0,
            null,
            _borrowedTextContinuationNames);
        if (thenReachesJoin)
        {
            return thenType;
        }
        if (elseReachesJoin)
        {
            return elseType;
        }
        return expectedResultType ?? BoundType.Unit;
    }

    private BoundType InferWhenExpression(
        WhenExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string? allowedOwnedOuterResultName = null,
        IReadOnlySet<string>? mutableBindings = null,
        BoundType? expectedResultType = null)
    {
        var hasSubjectConditions = expression.Arms.Any(arm => IsSubjectWhenCondition(arm.Condition));
        BoundType? subjectType = null;
        if (expression.Subject is not null)
        {
            subjectType = InferExpression(
                expression.Subject,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false,
                mutableBindings: mutableBindings);
            if (!IsIntegerType(subjectType.Value))
            {
                throw Error(expression.Subject.Line, expression.Subject.Column, "value-flow when subject must be an integer");
            }
        }
        else if (hasSubjectConditions)
        {
            if (!bindings.TryGetValue("it", out var implicitSubject) || !IsIntegerType(implicitSubject))
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "subject-style when without an explicit subject requires the default integer input 'it'");
            }
            subjectType = implicitSubject;
        }

        BoundType? resultType = null;
        var branchEntryBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        var branchExitBorrowedTextOrigins = new List<BorrowOriginState>();
        var outerBorrowedContinuation = _borrowedTextContinuationNames;
        foreach (var arm in expression.Arms)
        {
            RestoreBorrowedTextOriginState(branchEntryBorrowedTextOrigins);
            if (expression.Subject is null && !hasSubjectConditions)
            {
                NoteLongControlCondition(arm.Condition, arm.Body.Line, "when");
            }
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
                    subjectType!.Value,
                    functions,
                    bindings,
                    allowReadIntCall);
            if (condition != BoundType.Bool)
            {
                throw Error(arm.Condition.Line, arm.Condition.Column, "when arm condition must be Bool");
            }

            var armReachesJoin = BorrowBlockMayReachContinuation(arm.Body);
            var previousContinuation = _borrowedTextContinuationNames;
            _conditionalDepth++;
            try
            {
                _borrowedTextContinuationNames = armReachesJoin
                    ? outerBorrowedContinuation
                    : new HashSet<string>(StringComparer.Ordinal);
                var armType = InferBlockBody(
                    arm.Body,
                        functions,
                        bindings,
                        allowReadIntCall,
                        allowedOwnedOuterResultName,
                        mutableBindings,
                        expectedResultType);
                if (armReachesJoin)
                {
                    branchExitBorrowedTextOrigins.Add(CaptureBorrowedTextOriginState());
                }
                if (armReachesJoin)
                {
                    resultType ??= armType;
                    if (armType != resultType)
                    {
                        throw Error(
                            arm.Line,
                            arm.Column,
                            $"when arms must return the same type, got {FormatType(resultType.Value)} and {FormatType(armType)}");
                    }
                }
            }
            finally
            {
                _conditionalDepth--;
                _borrowedTextContinuationNames = previousContinuation;
            }
        }

        RestoreBorrowedTextOriginState(branchEntryBorrowedTextOrigins);
        var elseReachesJoin = BorrowBlockMayReachContinuation(expression.Else);
        var previousElseContinuation = _borrowedTextContinuationNames;
        BoundType elseType;
        _conditionalDepth++;
        try
        {
            _borrowedTextContinuationNames = elseReachesJoin
                ? outerBorrowedContinuation
                : new HashSet<string>(StringComparer.Ordinal);
            elseType = InferBlockBody(
                expression.Else,
                functions,
                bindings,
                allowReadIntCall,
                allowedOwnedOuterResultName,
                mutableBindings,
                expectedResultType);
            if (elseReachesJoin)
            {
                branchExitBorrowedTextOrigins.Add(CaptureBorrowedTextOriginState());
            }
        }
        finally
        {
            _conditionalDepth--;
            _borrowedTextContinuationNames = previousElseContinuation;
        }
        RestoreBorrowedTextOriginState(MergeBorrowedTextOriginStates(
            branchExitBorrowedTextOrigins));
        if (elseReachesJoin)
        {
            resultType ??= elseType;
            if (elseType != resultType)
            {
                throw Error(
                    expression.Else.Line,
                    expression.Else.Column,
                    $"when else must return {FormatType(resultType.Value)} but returns {FormatType(elseType)}");
            }
        }

        ExpireBorrowedTextOriginsBeforeStatement(
            [],
            0,
            null,
            _borrowedTextContinuationNames);
        return resultType ?? expectedResultType ?? BoundType.Unit;
    }

    private bool IsSubjectWhenCondition(Expression condition)
    {
        return condition is SubjectCompareExpression or SubjectRangeExpression;
    }

    private static bool CanTransferOwnedEnumPayload(
        Expression subject,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        return subject switch
        {
            NameExpression => true,
            FieldAccessExpression { Source: NameExpression owner } => !bindings.ContainsKey(owner.Name),
            FieldAccessExpression field => CanTransferOwnedEnumPayload(field.Source, bindings),
            _ => true
        };
    }

    private bool BlockConsumesOwnedBinding(
        BlockBody body,
        string name,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        foreach (var statement in body.Statements)
        {
            var value = statement switch
            {
                BindingStatement binding => binding.Value,
                ReturnStatement { Value: { } returned } => returned,
                ExpressionStatement expression => expression.Expression,
                FieldAssignmentStatement assignment => assignment.Value,
                IndexAssignmentStatement assignment => assignment.Value,
                _ => null
            };
            if (value is not null
                && GetOwnedParameterConsumedSourceNames(value, functions, bindings)
                    .Contains(name, StringComparer.Ordinal))
            {
                return true;
            }
        }

        return body.Value is not null
            && GetOwnedParameterConsumedSourceNames(body.Value, functions, bindings)
                .Contains(name, StringComparer.Ordinal);
    }

    private BoundType InferEnumMatchExpression(
        EnumMatchExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string? allowedOwnedOuterResultName,
        IReadOnlySet<string>? mutableBindings = null,
        BoundType? expectedResultType = null)
    {
        var subjectType = InferExpression(
            expression.Subject,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings);
        if (!_types.IsEnum(subjectType))
        {
            throw Error(expression.Subject.Line, expression.Subject.Column, "enum pattern matching expects an enum subject");
        }

        var definition = _types.GetEnum(subjectType);
        var covered = new HashSet<string>(StringComparer.Ordinal);
        BoundType? resultType = null;
        var branchEntryBorrowedTextOrigins = CaptureBorrowedTextOriginState();
        var branchExitBorrowedTextOrigins = new List<BorrowOriginState>();
        var outerBorrowedContinuation = _borrowedTextContinuationNames;
        foreach (var arm in expression.Arms)
        {
            RestoreBorrowedTextOriginState(branchEntryBorrowedTextOrigins);
            var pattern = (EnumPatternExpression)arm.Condition;
            var patternType = subjectType;
            if (pattern.TypeName.Length > 0
                && !_types.TryResolve(pattern.TypeName, out patternType)
                && (pattern.TypeName.StartsWith("Option<", StringComparison.Ordinal)
                    || pattern.TypeName.StartsWith("Result<", StringComparison.Ordinal)))
            {
                patternType = ParseType(pattern.TypeName, pattern.Line, pattern.Column);
            }
            if (patternType != subjectType)
            {
                throw Error(
                    pattern.Line,
                    pattern.Column,
                    $"pattern type '{pattern.TypeName}' does not match enum '{definition.Name}'");
            }

            var variant = definition.Variants.FirstOrDefault(candidate => candidate.Name == pattern.VariantName)
                ?? throw Error(
                    pattern.Line,
                    pattern.Column,
                    $"enum '{definition.Name}' has no variant '{pattern.VariantName}'");
            if (!covered.Add(variant.Name))
            {
                throw Error(pattern.Line, pattern.Column, $"variant '{definition.Name}.{variant.Name}' is matched more than once");
            }

            var armBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal);
            IReadOnlyList<string> patternReferenceBindings = [];
            if (variant.PayloadType is { } payloadType)
            {
                if (pattern.BindingName is null)
                {
                    throw Error(
                        pattern.Line,
                        pattern.Column,
                        $"variant '{definition.Name}.{variant.Name}' requires a payload binding");
                }

                ValidateBindingName(pattern.BindingName, pattern.Line, pattern.Column);
                armBindings[pattern.BindingName] = payloadType;
                if (TypeContainsReadonlyReference(payloadType))
                {
                    patternReferenceBindings = InstallReadonlyReferenceEnumPatternOrigins(
                        expression.Subject,
                        variant,
                        pattern.BindingName);
                }
            }
            else if (pattern.BindingName is not null)
            {
                throw Error(
                    pattern.Line,
                    pattern.Column,
                    $"variant '{definition.Name}.{variant.Name}' has no payload to bind");
            }

            var armReachesJoin = BorrowBlockMayReachContinuation(arm.Body);
            var previousContinuation = _borrowedTextContinuationNames;
            BoundType armType;
            try
            {
                _borrowedTextContinuationNames = armReachesJoin
                    ? outerBorrowedContinuation
                    : new HashSet<string>(StringComparer.Ordinal);
                armType = InferBlockBody(
                    arm.Body,
                    functions,
                    armBindings,
                    allowReadIntCall,
                    allowedOwnedOuterResultName,
                    mutableBindings,
                    expectedResultType);
                if (variant.PayloadType is { } ownedPayloadType
                    && _types.ContainsOwnedStorage(ownedPayloadType)
                    && pattern.BindingName is { } ownedPayloadName
                    && BlockConsumesOwnedBinding(
                        arm.Body,
                        ownedPayloadName,
                        functions,
                        armBindings)
                    && !CanTransferOwnedEnumPayload(expression.Subject, bindings))
                {
                    throw Error(
                        pattern.Line,
                        pattern.Column,
                        $"owned enum payload '{ownedPayloadName}' is borrowed from the matched subject and cannot be moved; match a named owner or an owned temporary to transfer the payload");
                }
                RemoveReadonlyReferencePatternOrigins(patternReferenceBindings);
                if (armReachesJoin)
                {
                    branchExitBorrowedTextOrigins.Add(CaptureBorrowedTextOriginState());
                }
            }
            finally
            {
                RemoveReadonlyReferencePatternOrigins(patternReferenceBindings);
                _borrowedTextContinuationNames = previousContinuation;
            }
            if (armReachesJoin)
            {
                resultType ??= armType;
                if (armType != resultType)
                {
                    throw Error(
                        arm.Line,
                        arm.Column,
                        $"enum when arms must return the same type, got {FormatType(resultType.Value)} and {FormatType(armType)}");
                }
            }
        }

        RestoreBorrowedTextOriginState(branchEntryBorrowedTextOrigins);
        if (expression.Else is null)
        {
            var missing = definition.Variants.Where(variant => !covered.Contains(variant.Name)).ToArray();
            if (missing.Length > 0)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"non-exhaustive enum when; missing {string.Join(", ", missing.Select(variant => definition.Name + "." + variant.Name))}");
            }
        }
        else
        {
            if (covered.Count == definition.Variants.Count)
            {
                throw Error(expression.Else.Line, expression.Else.Column, "enum when else arm is unreachable because all variants are covered");
            }

            var elseReachesJoin = BorrowBlockMayReachContinuation(expression.Else);
            var previousContinuation = _borrowedTextContinuationNames;
            BoundType elseType;
            try
            {
                _borrowedTextContinuationNames = elseReachesJoin
                    ? outerBorrowedContinuation
                    : new HashSet<string>(StringComparer.Ordinal);
                elseType = InferBlockBody(
                    expression.Else,
                    functions,
                    bindings,
                    allowReadIntCall,
                    allowedOwnedOuterResultName,
                    mutableBindings,
                    expectedResultType);
                if (elseReachesJoin)
                {
                    branchExitBorrowedTextOrigins.Add(CaptureBorrowedTextOriginState());
                }
            }
            finally
            {
                _borrowedTextContinuationNames = previousContinuation;
            }
            if (elseReachesJoin)
            {
                resultType ??= elseType;
                if (elseType != resultType)
                {
                    throw Error(
                        expression.Else.Line,
                        expression.Else.Column,
                        $"enum when else must return {FormatType(resultType.Value)} but returns {FormatType(elseType)}");
                }
            }
        }

        RestoreBorrowedTextOriginState(MergeBorrowedTextOriginStates(branchExitBorrowedTextOrigins));
        ExpireBorrowedTextOriginsBeforeStatement(
            [],
            0,
            null,
            _borrowedTextContinuationNames);
        return resultType ?? expectedResultType ?? BoundType.Unit;
    }

    private BoundType InferSubjectWhenCondition(
        Expression condition,
        BoundType subjectType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        if (condition is SubjectCompareExpression compare)
        {
            var right = IsNumericLiteralExpression(compare.Right)
                ? InferContextualValue(compare.Right, subjectType, functions, bindings, allowReadIntCall)
                : InferExpression(
                    compare.Right,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
            if (right != subjectType)
            {
                throw Error(compare.Right.Line, compare.Right.Column,
                    $"right operand of value-flow when comparison must match subject type {FormatType(subjectType)}");
            }

            return BoundType.Bool;
        }

        if (condition is not SubjectRangeExpression range)
        {
            throw Error(condition.Line, condition.Column, "value-flow when arm must start with a comparison operator or range");
        }

        var start = IsNumericLiteralExpression(range.Start)
            ? InferContextualValue(range.Start, subjectType, functions, bindings, allowReadIntCall)
            : InferExpression(
                range.Start,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
        if (start != subjectType)
        {
            throw Error(range.Start.Line, range.Start.Column,
                $"range start of value-flow when arm must match subject type {FormatType(subjectType)}");
        }

        var end = IsNumericLiteralExpression(range.End)
            ? InferContextualValue(range.End, subjectType, functions, bindings, allowReadIntCall)
            : InferExpression(
                range.End,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
        if (end != subjectType)
        {
            throw Error(range.End.Line, range.End.Column,
                $"range end of value-flow when arm must match subject type {FormatType(subjectType)}");
        }

        return BoundType.Bool;
    }

    private BoundType InferFoldExpression(
        FoldExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        ValidateBindingName(expression.AccumulatorName, expression.Line, expression.Column);
        if (expression.ItemName != "it")
        {
            ValidateBindingName(expression.ItemName, expression.Line, expression.Column);
        }
        if (expression.AccumulatorName == expression.ItemName)
        {
            throw Error(expression.Line, expression.Column, "fold accumulator and item names must be different");
        }

        if (bindings.ContainsKey(expression.AccumulatorName))
        {
            throw Error(expression.Line, expression.Column, $"binding '{expression.AccumulatorName}' already exists in this scope");
        }

        if (expression.ItemName != "it" && bindings.ContainsKey(expression.ItemName))
        {
            throw Error(expression.Line, expression.Column, $"binding '{expression.ItemName}' already exists in this scope");
        }

        if (expression.Source is RangeExpression range)
        {
            var startType = InferExpression(
                range.Start,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
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
                allowReadIntCall,
                allowFlowBindingTarget: false);
            if (endType != BoundType.Int)
            {
                throw Error(range.End.Line, range.End.Column, "range end must be an integer");
            }
        }
        else
        {
            var sourceType = InferExpression(
                expression.Source,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
            if (!IsReadonlyIntViewCompatible(sourceType))
            {
                throw Error(expression.Source.Line, expression.Source.Column, "fold expects a range or Int array input");
            }
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

    private BoundType InferBlockBody(
        BlockBody body,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        string? allowedOwnedOuterResultName = null,
        IReadOnlySet<string>? mutableBindings = null,
        BoundType? expectedResultType = null)
    {
        var parentMutableDeclarationsByName = _currentMutableDeclarationsByName is null
            ? null
            : new Dictionary<string, MutableBindingDeclaration>(
                _currentMutableDeclarationsByName,
                StringComparer.Ordinal);
        try
        {
        var bodyBindings = new Dictionary<string, BoundType>(bindings, StringComparer.Ordinal);
        var bodyMutableBindings = mutableBindings is null
            ? new HashSet<string>(StringComparer.Ordinal)
            : new HashSet<string>(mutableBindings, StringComparer.Ordinal);
        BindStatements(
            body.Statements,
            functions,
            bodyBindings,
            bodyMutableBindings,
            allowContainerBindings: true,
            borrowRegionResult: body.Value,
            shortenBorrowRegions: true,
            borrowRegionContinuation: _borrowedTextContinuationNames,
            retainMutableDeclarationScope: true);
        if (body.Value is null)
        {
            return BoundType.Unit;
        }

        ExpireBorrowedTextOriginsBeforeStatement(
            [],
            0,
            body.Value,
            _borrowedTextContinuationNames);

        var resultType = expectedResultType is { } expected
            && IsIntegerType(expected)
            && IsContextualNumericExpression(body.Value)
                ? InferContextualValue(
                    body.Value,
                    expected,
                    functions,
                    bodyBindings,
                    allowReadIntCall,
                    bodyMutableBindings)
                : InferExpression(
                    body.Value,
                    functions,
                    bodyBindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false,
                    mutableBindings: bodyMutableBindings,
                    allowedOwnedOuterResultName: allowedOwnedOuterResultName);
        if (resultType == BoundType.StaticIntArray)
        {
            throw Error(
                body.Value.Line,
                body.Value.Column,
                "static array block results are not supported yet; use a growable array or keep the static array inside the block");
        }

        if (IsContainerType(resultType))
        {
            EnsureOwnedContainerCanLeaveBlock(
                body.Value,
                bindings,
                bodyBindings,
                allowedOwnedOuterResultName);
        }

        return resultType;
        }
        finally
        {
            _currentMutableDeclarationsByName = parentMutableDeclarationsByName;
        }
    }

    private FlowResult InferFlowExpression(
        FlowExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        bool allowFlowBindingTarget,
        BoundType? yieldInputType = null,
        IReadOnlySet<string>? mutableBindings = null)
    {
        var firstTargetReadonlyBorrows = expression.Targets.Count > 0
            && ((expression.Targets[0].Path.Count == 1
                    && expression.Targets[0].Path[0] is "len" or "byte" or "slice")
                || (TryGetFunction(expression.Targets[0].Path, functions, out var firstFunction)
                    && firstFunction.InputType is not null
                    && firstFunction.InputOwnership == BoundFunctionInputOwnership.Default));
        var firstTargetConsumesOwned = expression.Targets.Count > 0
            && TryGetFunction(expression.Targets[0].Path, functions, out var consumingFunction)
            && consumingFunction.InputType is not null
            && consumingFunction.InputOwnership == BoundFunctionInputOwnership.Move;
        var currentType = InferFlowSource(
            expression.Source,
            functions,
            bindings,
            allowReadIntCall,
            mutableBindings,
            firstTargetReadonlyBorrows);
        if (IsOwnedHeapType(currentType)
            && IsAnonymousOwnedHeapContainerExpression(expression.Source)
            && !firstTargetReadonlyBorrows
            && !firstTargetConsumesOwned)
        {
            throw Error(
                expression.Source.Line,
                expression.Source.Column,
                "owned heap containers must be bound directly so the compiler can prove and insert their drop");
        }

        for (var i = 0; i < expression.Targets.Count; i++)
        {
            var target = expression.Targets[i];
            var isLast = i == expression.Targets.Count - 1;
            var path = string.Join('.', target.Path);

            if (path == "dyn")
            {
                currentType = InferDynTraitConversion(target, currentType, functions);
                continue;
            }

            if (_types.IsDynTrait(currentType))
            {
                currentType = InferDynTraitDispatch(target, path, currentType);
                continue;
            }

            if (TryInferContainerFlowTarget(
                expression,
                target,
                path,
                currentType,
                functions,
                bindings,
                mutableBindings,
                allowReadIntCall,
                isLast,
                out var containerFlowResult))
            {
                _resolvedContainerFlowTargets.Add(target);
                if (containerFlowResult.Type == BoundType.Unit)
                {
                    return containerFlowResult;
                }

                currentType = containerFlowResult.Type;
                continue;
            }

            if (path == "yield")
            {
                if (target.Arguments.Count != _currentBlockAdditionalYieldInputTypes.Count)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"yield expects {_currentBlockAdditionalYieldInputTypes.Count} additional argument(s)");
                }

                if (yieldInputType is null)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"yield() is only valid inside a block function; current function is '{_currentFunctionName ?? "main"}'");
                }

                if (!isLast
                    && (expression.Targets[i + 1].Path.Count != 1
                        || expression.Targets[i + 1].Path[0] != "emit"))
                {
                    throw Error(target.Line, target.Column, "yield may only flow onward to emit");
                }

                if (currentType != yieldInputType.Value)
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"yield expects {FormatType(yieldInputType.Value)} but received {FormatType(currentType)}");
                }

                for (var argumentIndex = 0; argumentIndex < target.Arguments.Count; argumentIndex++)
                {
                    var argument = target.Arguments[argumentIndex];
                    var actualArgumentType = InferExpression(
                        argument,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall,
                        allowFlowBindingTarget: false,
                        mutableBindings: mutableBindings);
                    var expectedArgumentType = _currentBlockAdditionalYieldInputTypes[argumentIndex];
                    if (actualArgumentType != expectedArgumentType)
                    {
                        throw Error(
                            argument.Line,
                            argument.Column,
                            $"yield argument {argumentIndex + 1} expects {FormatType(expectedArgumentType)} "
                            + $"but received {FormatType(actualArgumentType)}");
                    }
                }

                currentType = _currentBlockYieldResultType ?? BoundType.Unit;
                if (isLast)
                {
                    return new FlowResult(currentType, FlowEffect.None);
                }
                continue;
            }

            if (path == "emit" && _currentStreamElementType is not null)
            {
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "emit must be the final value-flow target");
                }
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "emit does not accept arguments");
                }
                if (currentType != _currentStreamElementType.Value)
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"emit expects {FormatType(_currentStreamElementType.Value)} but received {FormatType(currentType)}");
                }
                return new FlowResult(BoundType.Unit, FlowEffect.None);
            }

            if (TryGetFunction(path, functions, out var function)
                || TryResolveInstanceMethod(currentType, path, functions, out function))
            {
                EnsureFunctionVisible(function, target.Line, target.Column);
                EnsureAsyncRuntimeCallable(function, target.Line, target.Column, path);
                if (function.Kind is not (
                        BoundFunctionKind.User
                        or BoundFunctionKind.Native
                        or BoundFunctionKind.RuntimeMouseEvents
                        or BoundFunctionKind.RuntimeSocketReceive
                        or BoundFunctionKind.RuntimeSocketSend
                        or BoundFunctionKind.RuntimeSocketSendText)
                    && target.Arguments.Count != 0)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"function value-flow target '{path}' does not accept additional arguments in this slice");
                }
                if (i == 0
                    && function.InputType is { } contextualInput
                    && expression.Source is (ArrayLiteralExpression
                        or ArrayRepeatExpression
                        or DictionaryLiteralExpression))
                {
                    currentType = InferContextualValue(
                        expression.Source,
                        contextualInput,
                        functions,
                        bindings,
                        allowReadIntCall,
                        mutableBindings);
                }
                else if (i == 0
                    && function.InputType is { } numericContextualInput
                    && IsIntegerType(numericContextualInput)
                    && IsIntegerLiteralExpression(expression.Source))
                {
                    ValidateNumericLiteralConversion(
                        expression.Source,
                        numericContextualInput,
                        FormatType(numericContextualInput));
                    currentType = numericContextualInput;
                }

                if (TryGetDisplayPrinterKind(function, out var printerKind))
                {
                    if (!isLast)
                    {
                        throw Error(expression.Line, expression.Column, $"{path} must be the final value-flow target");
                    }

                    if (printerKind == BoundFunctionKind.RuntimePrintErrorLine
                        && currentType != BoundType.Text)
                    {
                        throw Error(
                            expression.Line,
                            expression.Column,
                            $"{path} expects Text but received {FormatType(currentType)}");
                    }
                    EnsureDisplayable(currentType, expression.Line, expression.Column, path);
                    if (printerKind == BoundFunctionKind.RuntimePrintErrorLine)
                    {
                        _resolvedGenericCalls[target] = function;
                    }
                    return new FlowResult(BoundType.Unit, FlowEffect.None);
                }

                switch (function.Kind)
                {
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
                    case BoundFunctionKind.RuntimeWriteScalar:
                        function = ResolveGenericSpecialization(function, currentType, functions, target);
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
                    case BoundFunctionKind.RuntimeSecureRandomBytes:
                    case BoundFunctionKind.RuntimeClosestInt:
                    case BoundFunctionKind.RuntimeLimitParallelWorkers:
                    case BoundFunctionKind.RuntimeReadStandardInputChunk:
                        EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeCloseIntWriter:
                    case BoundFunctionKind.RuntimeCloseIntReader:
                    case BoundFunctionKind.RuntimeFlushStandardOutput:
                        throw Error(expression.Line, expression.Column, $"{path} does not accept a flowed input");
                    case BoundFunctionKind.RuntimeEnvironment:
                    case BoundFunctionKind.RuntimeBorrowSourceText:
                    case BoundFunctionKind.RuntimeMapSourceText:
                    case BoundFunctionKind.RuntimeOpenFile:
                    case BoundFunctionKind.RuntimeOpenWriteFile:
                        if (currentType != BoundType.Text)
                        {
                            throw Error(expression.Line, expression.Column,
                                $"{path} expects Text but received {FormatType(currentType)}");
                        }
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeBorrowSourceBytes:
                        if (currentType != TypeId.DynamicUInt8Array)
                        {
                            throw Error(expression.Line, expression.Column,
                                $"{path} expects [UInt8; ~] but received {FormatType(currentType)}");
                        }
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeMapSourcePath:
                    case BoundFunctionKind.RuntimePathText:
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeOpenFileAsync:
                    case BoundFunctionKind.RuntimeOpenWriteFileAsync:
                        if (currentType != BoundType.Text)
                        {
                            throw Error(expression.Line, expression.Column,
                                $"{path} expects Text but received {FormatType(currentType)}");
                        }
                        _resolvedGenericCalls[target] = function;
                        currentType = AsyncCallType(function);
                        continue;
                    case BoundFunctionKind.RuntimeRunProcess:
                    case BoundFunctionKind.RuntimeRunProcessToFile:
                    case BoundFunctionKind.RuntimeReadDirectory:
                    case BoundFunctionKind.RuntimeCreateDirectory:
                    case BoundFunctionKind.RuntimePathQuery:
                    case BoundFunctionKind.RuntimeSyncFile:
                    case BoundFunctionKind.RuntimeAtomicReplaceFile:
                    case BoundFunctionKind.RuntimeRangeStream:
                        MarkFixedLengthCandidateRequiresGrowable(
                            expression.Source,
                            function.InputType,
                            currentType);
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeMouseEvents:
                        EnsureRuntimeIntrinsicAllowed(
                            function,
                            allowReadIntCall,
                            expression.Line,
                            expression.Column,
                            path);
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        ValidateMouseEventCapacityLiteral(expression.Source);
                        ValidateAdditionalFunctionArguments(
                            function,
                            target.Arguments,
                            functions,
                            bindings,
                            allowReadIntCall,
                            mutableBindings,
                            path);
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeSocketListen:
                    case BoundFunctionKind.RuntimeSocketAccept:
                    case BoundFunctionKind.RuntimeSocketConnect:
                    case BoundFunctionKind.RuntimeSocketReceive:
                    case BoundFunctionKind.RuntimeSocketSend:
                    case BoundFunctionKind.RuntimeSocketSendText:
                    case BoundFunctionKind.RuntimeSocketShutdown:
                    case BoundFunctionKind.RuntimeSocketBindDatagram:
                    case BoundFunctionKind.RuntimeSocketLocalPort:
                    case BoundFunctionKind.RuntimeSocketSendTo:
                    case BoundFunctionKind.RuntimeSocketReceiveFrom:
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        ValidateAdditionalFunctionArguments(
                            function,
                            target.Arguments,
                            functions,
                            bindings,
                            allowReadIntCall,
                            mutableBindings,
                            path);
                        _resolvedGenericCalls[target] = function;
                        currentType = function.ReturnType;
                        continue;
                    case BoundFunctionKind.RuntimeExitProcess:
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        if (!isLast)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} must be the final value-flow target");
                        }
                        return new FlowResult(BoundType.Unit, FlowEffect.None);
                    case BoundFunctionKind.RuntimeSleep:
                        EnsureRuntimeInput(currentType, function, expression.Line, expression.Column, path);
                        currentType = AsyncCallType(function);
                        continue;
                    case BoundFunctionKind.User:
                    case BoundFunctionKind.Native:
                        if (function.GenericParameterName is not null
                            && function.SpecializedType is null
                            && function.SpecializedValue is null)
                        {
                            function = function.IsValueGeneric
                                ? ResolveValueGenericSpecialization(function, currentType, target.CompileTimeValueArgument, target)
                                : ResolveGenericSpecialization(function, currentType, functions, target);
                        }
                        else if (target.CompileTimeValueArgument is not null)
                        {
                            throw Error(
                                target.Line,
                                target.Column,
                                $"function '{path}' does not declare a compile-time value parameter");
                        }

                        if (IsMainOnlyRuntimeWrapper(function) && !allowReadIntCall)
                        {
                            throw Error(expression.Line, expression.Column, $"{path} is only valid in main for the current runtime slice");
                        }

                        if (function.InputType is null)
                        {
                            throw Error(expression.Line, expression.Column, $"function '{path}' does not accept a flowed input");
                        }

                        ValidateAdditionalFunctionArguments(
                            function,
                            target.Arguments,
                            functions,
                            bindings,
                            allowReadIntCall,
                            mutableBindings,
                            path);

                        if (currentType != function.InputType)
                        {
                            if (!CanPassFunctionArgument(currentType, function.InputType.Value))
                            {
                                throw Error(
                                    expression.Line,
                                    expression.Column,
                                    $"function '{path}' expects {FormatType(function.InputType.Value)} but received {FormatType(currentType)}");
                            }
                        }

                        MarkFixedLengthCandidateRequiresGrowable(
                            expression.Source,
                            function.InputType,
                            currentType);

                        if (_types.IsReference(function.InputType.Value)
                            && !_types.IsReference(currentType))
                        {
                            EnsureReferenceArgumentPlace(expression.Source, bindings, mutableBindings, path);
                        }

                        if (FunctionMovesOwnedHeapInput(function))
                        {
                            EnsureOwnedParameterFlowSource(expression.Source, path);
                        }

                        if (FunctionMutablyBorrowsInput(function))
                        {
                            EnsureMutableBorrowFlowSource(expression.Source, path, mutableBindings);
                        }

                        // Value-flow method and free-function calls need the
                        // same resolved declaration record as direct calls.
                        // Reachability cannot reconstruct instance or generic
                        // dispatch from the target's textual spelling alone.
                        _resolvedGenericCalls[target] = function;
                        currentType = AsyncCallType(function);
                        continue;
                    default:
                        throw Error(expression.Line, expression.Column, $"unsupported function kind '{function.Kind}'");
                }
            }

            throw Error(target.Line, target.Column, $"unknown value-flow target '{path}'");
        }

        return new FlowResult(currentType, FlowEffect.None);
    }

    private BoundType InferDynTraitConversion(
        FlowTarget target,
        BoundType concreteType,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (target.TypeArgument is null
            || target.CompileTimeValueArgument is not null
            || target.Arguments.Count != 0
            || target.UsesCallSyntax)
        {
            throw Error(target.Line, target.Column,
                "dyn conversion requires the form 'value -> dyn<Trait>'");
        }
        if (!_types.IsStruct(concreteType) && !_types.IsEnum(concreteType))
        {
            throw Error(target.Line, target.Column,
                $"dyn conversion requires a user value but received {FormatType(concreteType)}");
        }
        if (_types.ContainsOwnedStorage(concreteType))
        {
            throw Error(target.Line, target.Column,
                "dyn conversion of values with nested owned storage is not supported until move transfer is explicit");
        }

        var trait = ResolveDynTrait(target.TypeArgument, target.Line, target.Column);
        EnsureDynCompatible(trait, target.Line, target.Column);
        var canonicalTraitName = CanonicalTraitName(trait);
        var methods = new List<BoundFunction>(trait.Methods.Count);
        foreach (var requirement in trait.Methods)
        {
            var implementations = functions.Values
                .Where(function => function.InputType == concreteType
                    && function.TraitName is { } implementedTrait
                    && (implementedTrait == trait.Name || implementedTrait == canonicalTraitName)
                    && function.Name.EndsWith("." + requirement.Name, StringComparison.Ordinal))
                .Distinct()
                .ToArray();
            if (implementations.Length != 1)
            {
                throw Error(target.Line, target.Column,
                    $"{FormatType(concreteType)} must provide exactly one implementation of "
                    + $"'{canonicalTraitName}.{requirement.Name}' for dyn conversion");
            }
            var implementation = implementations[0];
            if (implementation.IsLocal
                || (implementation.AdditionalParameters?.Count ?? 0) != 0
                || implementation.IsAsync)
            {
                throw Error(target.Line, target.Column,
                    $"implementation '{implementation.Name}' is not dyn-compatible");
            }
            methods.Add(implementation);
        }

        var dynType = _types.GetOrAddDynTrait(canonicalTraitName);
        _dynTraitConversions[target] = new BoundDynTraitConversion(
            dynType, concreteType, trait, methods);
        return dynType;
    }

    private BoundType InferDynTraitDispatch(FlowTarget target, string path, BoundType dynType)
    {
        if (target.TypeArgument is not null
            || target.CompileTimeValueArgument is not null
            || target.Arguments.Count != 0
            || target.UsesCallSyntax)
        {
            throw Error(target.Line, target.Column,
                "dyn trait methods currently take only the erased self receiver");
        }

        var definition = _types.GetDynTrait(dynType);
        var trait = ResolveDynTrait(definition.TraitName, target.Line, target.Column);
        var separator = path.LastIndexOf('.');
        var requestedTrait = separator < 0 ? "" : path[..separator];
        var methodName = separator < 0 ? path : path[(separator + 1)..];
        if (requestedTrait.Length > 0
            && requestedTrait != trait.Name
            && requestedTrait != CanonicalTraitName(trait))
        {
            throw Error(target.Line, target.Column,
                $"dyn {definition.TraitName} cannot dispatch '{path}'");
        }
        var methodIndex = trait.Methods
            .Select((method, index) => (method, index))
            .FirstOrDefault(item => item.method.Name == methodName);
        if (methodIndex.method is null)
        {
            throw Error(target.Line, target.Column,
                $"trait '{CanonicalTraitName(trait)}' has no method '{methodName}'");
        }
        if (methodIndex.method.ReturnType is not { } returnType)
        {
            throw Error(target.Line, target.Column,
                $"associated return type method '{methodName}' is not dyn-compatible");
        }
        _dynTraitDispatches[target] = new BoundDynTraitDispatch(
            dynType, trait, methodIndex.method, methodIndex.index);
        return returnType;
    }

    private BoundTraitDefinition ResolveDynTrait(string requestedName, int line, int column)
    {
        var candidates = _traits.Values
            .Where(trait => trait.Name == requestedName
                || CanonicalTraitName(trait) == requestedName)
            .Distinct()
            .ToArray();
        if (candidates.Length == 0)
        {
            throw Error(line, column, $"unknown trait '{requestedName}'");
        }
        if (candidates.Length > 1)
        {
            throw Error(line, column, $"ambiguous trait '{requestedName}'; use its qualified name");
        }
        EnsureTraitVisible(candidates[0], line, column);
        return candidates[0];
    }

    private void EnsureDynCompatible(BoundTraitDefinition trait, int line, int column)
    {
        if (trait.AssociatedTypes.Count != 0)
        {
            throw Error(line, column,
                $"trait '{CanonicalTraitName(trait)}' is not dyn-compatible because it declares associated types");
        }
        var incompatible = trait.Methods.FirstOrDefault(method =>
            method.SelfOwnership != BoundFunctionInputOwnership.Default
            || method.ReturnType != BoundType.Int);
        if (incompatible is not null)
        {
            throw Error(line, column,
                $"trait method '{CanonicalTraitName(trait)}.{incompatible.Name}' is not dyn-compatible; "
                + "the current dyn slice requires readonly self and an Int return type");
        }
    }

    private static string CanonicalTraitName(BoundTraitDefinition trait) =>
        trait.ModuleName.Length == 0 ? trait.Name : trait.ModuleName + "." + trait.Name;

    private bool TryInferContainerFlowTarget(
        FlowExpression expression,
        FlowTarget target,
        string path,
        BoundType currentType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlySet<string>? mutableBindings,
        bool allowReadIntCall,
        bool isLast,
        out FlowResult result)
    {
        result = new FlowResult(BoundType.Unit, FlowEffect.None);

        if (IsFileWriterType(currentType) && path == "syncAsync")
        {
            if (target.TypeArgument is not null
                || target.CompileTimeValueArgument is not null
                || target.Arguments.Count != 0)
            {
                throw Error(target.Line, target.Column, "syncAsync takes no arguments or type arguments");
            }

            var returnType = _types.GetOrAddResult(
                BoundType.Unit,
                BoundType.Text,
                "Result<Unit, Text>");
            var function = new BoundFunction(
                Name: "sys.file.syncAsync",
                InputName: "writer",
                InputType: currentType,
                InputOwnership: BoundFunctionInputOwnership.Default,
                ReturnType: returnType,
                BlockInputName: null,
                BlockInputType: null,
                LocalFunctions: new Dictionary<string, BoundFunction>(StringComparer.Ordinal),
                Body: null,
                BlockBody: [],
                Line: target.Line,
                Column: target.Column,
                Kind: BoundFunctionKind.RuntimeSyncFileAsync,
                IsStandardLibrary: true,
                IsLocal: false,
                ModuleName: "sys.file",
                IsPublic: true,
                IsAsync: true);
            _resolvedGenericCalls[target] = function;
            result = new FlowResult(_types.GetOrAddTask(returnType), FlowEffect.None);
            return true;
        }

        if (IsFileWriterType(currentType) && path is "writeAt" or "writeAtAsync")
        {
            if (target.CompileTimeValueArgument is not null || target.Arguments.Count != 2)
            {
                throw Error(
                    target.Line,
                    target.Column,
                    $"{path} expects a scalar value and one UInt64 byte offset");
            }

            BoundType scalarType;
            if (target.TypeArgument is not null)
            {
                scalarType = ParseType(target.TypeArgument, target.Line, target.Column);
                ValidateMapContextValue(
                    target.Arguments[0],
                    scalarType,
                    "file scalar value",
                    functions,
                    bindings,
                    allowReadIntCall);
            }
            else
            {
                scalarType = InferExpression(
                    target.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
            }
            if (scalarType != BoundType.Bool
                && !IsNumericType(scalarType)
                && scalarType != BoundType.CodePoint)
            {
                throw Error(
                    target.Arguments[0].Line,
                    target.Arguments[0].Column,
                    $"{path} supports Bool, CodePoint, and numeric scalars; got {FormatType(scalarType)}");
            }
            ValidateMapContextValue(
                target.Arguments[1],
                BoundType.UInt64,
                "file offset",
                functions,
                bindings,
                allowReadIntCall);

            var returnType = _types.GetOrAddResult(
                BoundType.Unit,
                BoundType.Text,
                "Result<Unit, Text>");
            var isAsync = path == "writeAtAsync";
            var specialization = new BoundFunction(
                Name: $"sys.file.{path}${(int)scalarType}",
                InputName: "writer",
                InputType: currentType,
                InputOwnership: BoundFunctionInputOwnership.Default,
                ReturnType: returnType,
                BlockInputName: null,
                BlockInputType: null,
                LocalFunctions: new Dictionary<string, BoundFunction>(StringComparer.Ordinal),
                Body: null,
                BlockBody: [],
                Line: target.Line,
                Column: target.Column,
                Kind: isAsync
                    ? BoundFunctionKind.RuntimeWriteScalarAtAsync
                    : BoundFunctionKind.RuntimeWriteScalarAt,
                IsStandardLibrary: true,
                IsLocal: false,
                SpecializedType: scalarType,
                ModuleName: "sys.file",
                IsPublic: true,
                IsAsync: isAsync);
            _resolvedGenericCalls[target] = specialization;
            result = new FlowResult(
                isAsync ? _types.GetOrAddTask(returnType) : returnType,
                FlowEffect.None);
            return true;
        }

        if (IsFileType(currentType) && path is "readAt" or "readAtAsync")
        {
            if (target.TypeArgument is null || target.CompileTimeValueArgument is not null)
            {
                throw Error(
                    target.Line,
                    target.Column,
                    $"{path} requires an explicit scalar type, for example '{path}<UInt16>(offset)'");
            }
            if (target.Arguments.Count != 1)
            {
                throw Error(target.Line, target.Column, $"{path} expects exactly one UInt64 byte offset");
            }

            var scalarType = ParseType(target.TypeArgument, target.Line, target.Column);
            if (scalarType != BoundType.Bool
                && !IsNumericType(scalarType)
                && scalarType != BoundType.CodePoint)
            {
                throw Error(
                    target.Line,
                    target.Column,
                    $"{path} supports Bool, CodePoint, and fixed-width numeric scalars; got {FormatType(scalarType)}");
            }
            ValidateMapContextValue(
                target.Arguments[0],
                BoundType.UInt64,
                "file offset",
                functions,
                bindings,
                allowReadIntCall);

            var optionType = _types.GetOrAddOption(scalarType, $"Option<{FormatType(scalarType)}>");
            var returnType = _types.GetOrAddResult(
                optionType,
                BoundType.Text,
                $"Result<Option<{FormatType(scalarType)}>, Text>");
            var isAsync = path == "readAtAsync";
            var specialization = new BoundFunction(
                Name: $"sys.file.{path}${(int)scalarType}",
                InputName: "file",
                InputType: currentType,
                InputOwnership: BoundFunctionInputOwnership.Default,
                ReturnType: returnType,
                BlockInputName: null,
                BlockInputType: null,
                LocalFunctions: new Dictionary<string, BoundFunction>(StringComparer.Ordinal),
                Body: null,
                BlockBody: [],
                Line: target.Line,
                Column: target.Column,
                Kind: isAsync
                    ? BoundFunctionKind.RuntimeReadScalarAsync
                    : BoundFunctionKind.RuntimeReadScalar,
                IsStandardLibrary: true,
                IsLocal: false,
                SpecializedType: scalarType,
                ModuleName: "sys.file",
                IsPublic: true,
                IsAsync: isAsync);
            _resolvedGenericCalls[target] = specialization;
            result = new FlowResult(
                isAsync ? _types.GetOrAddTask(returnType) : returnType,
                FlowEffect.None);
            return true;
        }

        switch (path)
        {
            case "await" when _types.TryGetTaskValue(currentType, out var awaitedType):
                if (!_currentFunctionIsAsync)
                {
                    throw Error(target.Line, target.Column, "await is only valid in async functions or main");
                }
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "await does not accept arguments");
                }
                result = new FlowResult(awaitedType, FlowEffect.None);
                return true;
            case "cancel" when _types.IsTask(currentType):
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "cancel does not accept arguments");
                }
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "cancel must be the final flow target");
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "flush" when currentType == BoundType.MutableMappedBytes:
                if (!isLast || target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "flush must be final and takes no arguments");
                }
                EnsureEffectAllowed("File", target.Line, target.Column, "flush");
                EnsureMutableContainerSource(expression.Source, "flush", mutableBindings);
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "used" when currentType == BoundType.Arena:
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "used does not accept arguments");
                }
                result = new FlowResult(BoundType.UIntSize, FlowEffect.None);
                return true;
            case "alloc" when currentType == BoundType.Arena:
                if (!isLast || target.Arguments.Count != 2)
                {
                    throw Error(target.Line, target.Column,
                        "arena alloc must be final and expects byte-count and alignment arguments");
                }
                EnsureMutableContainerSource(expression.Source, "alloc", mutableBindings);
                if (expression.Source is NameExpression allocationOwnerName)
                {
                    RejectBorrowedTextOriginMutation(
                        allocationOwnerName.Name,
                        target.Line,
                        target.Column);
                }
                foreach (var argument in target.Arguments)
                {
                    var argumentType = InferExpression(argument, functions, bindings,
                        allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                    if (argumentType is not (BoundType.Int or BoundType.UIntSize))
                    {
                        throw Error(argument.Line, argument.Column,
                            "arena alloc byte-count and alignment must be Int or UIntSize");
                    }
                }
                if (target.Arguments[1] is NumberExpression alignmentLiteral
                    && long.TryParse(alignmentLiteral.Text, NumberStyles.None, CultureInfo.InvariantCulture, out var literalAlignment)
                    && (literalAlignment <= 0 || (literalAlignment & (literalAlignment - 1)) != 0))
                {
                    throw Error(alignmentLiteral.Line, alignmentLiteral.Column,
                        "arena alignment must be a nonzero power of two");
                }
                result = new FlowResult(BoundType.UIntSize, FlowEffect.None);
                return true;
            case "store" when currentType == BoundType.Arena:
                if (!isLast || target.Arguments.Count != 2)
                {
                    throw Error(target.Line, target.Column,
                        "arena store must be final and expects offset and UInt8 value arguments");
                }
                EnsureMutableContainerSource(expression.Source, "store", mutableBindings);
                if (expression.Source is NameExpression storeOwnerName)
                {
                    RejectBorrowedTextOriginMutation(
                        storeOwnerName.Name,
                        target.Line,
                        target.Column);
                }
                var storeOffsetType = InferExpression(target.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                var storeValueType = InferExpression(target.Arguments[1], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                if (storeOffsetType != BoundType.UIntSize || storeValueType != BoundType.UInt8)
                {
                    throw Error(target.Line, target.Column, "arena store expects UIntSize offset and UInt8 value");
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "load" when currentType == BoundType.Arena:
                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "arena load expects one UIntSize offset");
                }
                var loadOffsetType = InferExpression(target.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                if (loadOffsetType != BoundType.UIntSize)
                {
                    throw Error(target.Arguments[0].Line, target.Arguments[0].Column,
                        "arena load offset must be UIntSize");
                }
                result = new FlowResult(BoundType.UInt8, FlowEffect.None);
                return true;
            case "reset" when currentType == BoundType.Arena:
                if (!isLast || target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "arena reset must be final and takes no arguments");
                }
                EnsureMutableContainerSource(expression.Source, "reset", mutableBindings);
                if (expression.Source is NameExpression resetOwnerName)
                {
                    RejectBorrowedTextOriginMutation(
                        resetOwnerName.Name,
                        target.Line,
                        target.Column);
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "materialize" when currentType == BoundType.Text:
                if (target.Arguments.Count != 1)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        "Text materialize expects one mutable Arena owner");
                }
                var materializeOwner = target.Arguments[0];
                var materializeOwnerType = InferExpression(
                    materializeOwner,
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
                if (materializeOwnerType != BoundType.Arena)
                {
                    throw Error(
                        materializeOwner.Line,
                        materializeOwner.Column,
                        $"Text materialize expects Arena but received {FormatType(materializeOwnerType)}");
                }
                EnsureMutableBorrowCallArgument(materializeOwner, "materialize", mutableBindings);
                if (materializeOwner is NameExpression materializeOwnerName)
                {
                    RejectBorrowedTextOriginMutation(
                        materializeOwnerName.Name,
                        materializeOwner.Line,
                        materializeOwner.Column);
                }
                result = new FlowResult(BoundType.Text, FlowEffect.None);
                return true;
            case "len":
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "len does not accept arguments");
                }

                if (currentType is not (BoundType.Text
                    or BoundType.SourceText
                    or BoundType.IntSlice
                    or BoundType.StaticIntArray
                    or BoundType.StaticTextArray
                    or BoundType.DynamicIntArray
                    or BoundType.IntDictionaryView
                    or BoundType.IntDictionary
                    or BoundType.Arguments
                    or BoundType.MappedBytes
                    or BoundType.MutableMappedBytes)
                    && !_types.IsStaticArray(currentType)
                    && !_types.IsSlice(currentType)
                    && !_types.IsDynamicArray(currentType)
                    && !_types.IsBoundedArray(currentType)
                    && !_types.IsDictionary(currentType)
                    && !_types.IsBitSet(currentType))
                {
                    return false;
                }

                result = new FlowResult(
                    currentType is BoundType.Text or BoundType.SourceText or BoundType.MappedBytes or BoundType.MutableMappedBytes or BoundType.Arguments
                        ? BoundType.UIntSize
                        : BoundType.Int,
                    FlowEffect.None);
                return true;
            case "count" when _types.IsBitSet(currentType):
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "BitSet count does not accept arguments");
                }
                result = new FlowResult(BoundType.Int, FlowEffect.None);
                return true;
            case "contains" when _types.IsBitSet(currentType):
                ValidateBitSetIndexArgument(target, functions, bindings, allowReadIntCall);
                result = new FlowResult(BoundType.Bool, FlowEffect.None);
                return true;
            case "contains" when _types.IsSet(currentType):
                ValidateSetElementArgument(target, functions, bindings, allowReadIntCall);
                result = new FlowResult(BoundType.Bool, FlowEffect.None);
                return true;
            case "insert" or "remove" when _types.IsSet(currentType):
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, $"Set {path} must be the final value-flow target");
                }
                EnsureMutableContainerSource(expression.Source, path, mutableBindings);
                ValidateSetElementArgument(target, functions, bindings, allowReadIntCall);
                result = new FlowResult(BoundType.Bool, FlowEffect.None);
                return true;
            case "set" or "clear" when _types.IsBitSet(currentType):
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, $"BitSet {path} must be the final value-flow target");
                }
                EnsureMutableContainerSource(expression.Source, path, mutableBindings);
                ValidateBitSetIndexArgument(target, functions, bindings, allowReadIntCall);
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "byte" when currentType is BoundType.Text or BoundType.SourceText:
                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "Text byte expects one UIntSize index");
                }
                var byteIndexType = target.Arguments[0] is NumberExpression
                    ? BoundType.UIntSize
                    : InferExpression(target.Arguments[0], functions, bindings,
                        allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                if (byteIndexType != BoundType.UIntSize)
                {
                    throw Error(target.Arguments[0].Line, target.Arguments[0].Column,
                        "Text byte index must be UIntSize");
                }
                result = new FlowResult(BoundType.UInt8, FlowEffect.None);
                return true;
            case "slice" when currentType is BoundType.Text or BoundType.SourceText:
                if (target.Arguments.Count != 2)
                {
                    throw Error(target.Line, target.Column,
                        "Text slice expects UIntSize start and byte length");
                }
                foreach (var argument in target.Arguments)
                {
                    var argumentType = argument is NumberExpression
                        ? BoundType.UIntSize
                        : InferExpression(argument, functions, bindings,
                            allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                    if (argumentType != BoundType.UIntSize)
                    {
                        throw Error(argument.Line, argument.Column,
                            "Text slice start and length must be UIntSize");
                    }
                }
                result = new FlowResult(BoundType.Text, FlowEffect.None);
                return true;
            case "capacity":
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "capacity does not accept arguments");
                }

                if (currentType is not (BoundType.DynamicIntArray
                    or BoundType.IntDictionaryView
                    or BoundType.IntDictionary
                    or BoundType.Arena)
                    && !_types.IsDynamicArray(currentType)
                    && !_types.IsBoundedArray(currentType)
                    && !_types.IsDictionary(currentType))
                {
                    return false;
                }

                MarkFixedLengthCandidateRequiresGrowableOperation(expression.Source);

                result = new FlowResult(
                    currentType is BoundType.Arena or BoundType.MappedBytes or BoundType.MutableMappedBytes
                        ? BoundType.UIntSize
                        : BoundType.Int,
                    FlowEffect.None);
                return true;
            case "reserve":
                if (currentType is not (BoundType.DynamicIntArray or BoundType.IntDictionary)
                    && !_types.IsDynamicArray(currentType)
                    && !_types.IsBoundedArray(currentType)
                    && !_types.IsDictionary(currentType))
                {
                    return false;
                }
                if (_types.IsBoundedArray(currentType) || _types.IsBoundedDictionary(currentType))
                {
                    throw Error(target.Line, target.Column,
                        "reserve is not available on bounded inline collections; their capacity is part of the type");
                }
                MarkFixedLengthCandidateRequiresGrowableOperation(expression.Source);
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "reserve must be the final value-flow target");
                }
                EnsureMutableContainerSource(expression.Source, "reserve", mutableBindings);
                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "reserve expects one nonnegative Int capacity");
                }
                var reserveType = InferExpression(
                    target.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                if (reserveType != BoundType.Int)
                {
                    throw Error(target.Arguments[0].Line, target.Arguments[0].Column,
                        "reserve capacity must be Int");
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "pushAll":
                if (currentType != BoundType.DynamicIntArray
                    && (!_types.IsDynamicArray(currentType)
                        || _types.IsBinaryHeap(currentType)
                        || _types.IsDeque(currentType)))
                {
                    return false;
                }
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "pushAll must be the final value-flow target");
                }
                EnsureMutableContainerSource(expression.Source, "pushAll", mutableBindings);
                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "pushAll expects one fixed-array source");
                }
                var bulkSourceType = InferExpression(
                    target.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                var targetElementType = currentType == BoundType.DynamicIntArray
                    ? BoundType.Int
                    : _types.GetDynamicArray(currentType).ElementType;
                BoundType? bulkElementType = bulkSourceType switch
                {
                    BoundType.StaticIntArray => BoundType.Int,
                    BoundType.StaticTextArray => BoundType.Text,
                    _ when _types.IsStaticArray(bulkSourceType) => _types.GetStaticArray(bulkSourceType).ElementType,
                    _ => null
                };
                if (bulkElementType is null || bulkElementType.Value != targetElementType)
                {
                    throw Error(target.Arguments[0].Line, target.Arguments[0].Column,
                        $"pushAll expects a fixed array of {FormatType(targetElementType)}");
                }
                if (_types.ContainsOwnedStorage(targetElementType))
                {
                    throw Error(target.Line, target.Column,
                        "pushAll currently requires copyable elements; owned elements require an explicit move bulk operation");
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "push":
                if (_types.IsDeque(currentType))
                {
                    return false;
                }
                if (currentType != BoundType.DynamicIntArray
                    && !_types.IsDynamicArray(currentType)
                    && !_types.IsBoundedArray(currentType))
                {
                    return false;
                }

                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "push must be the final value-flow target");
                }

                EnsureMutableContainerSource(expression.Source, "push", mutableBindings);

                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "push expects exactly one argument");
                }

                var expectedPushedType = currentType == BoundType.DynamicIntArray
                    ? BoundType.Int
                    : _types.IsBoundedArray(currentType)
                        ? _types.GetBoundedArray(currentType).ElementType
                    : _types.GetDynamicArray(currentType).ElementType;
                var pushedArgument = target.Arguments[0];
                var pushedType = InferContextualValue(
                    pushedArgument,
                    expectedPushedType,
                    functions,
                    bindings,
                    allowReadIntCall);
                if (pushedType != expectedPushedType)
                {
                    throw Error(
                        target.Arguments[0].Line,
                        target.Arguments[0].Column,
                        $"push expects {FormatType(expectedPushedType)}, got {FormatType(pushedType)}");
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "peek" when _types.IsBinaryHeap(currentType):
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "BinaryHeap peek does not accept arguments");
                }
                result = new FlowResult(_types.GetBinaryHeapElement(currentType), FlowEffect.None);
                return true;
            case "pushFront" or "pushBack" when _types.IsDeque(currentType):
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, $"Deque {path} must be the final value-flow target");
                }
                EnsureMutableContainerSource(expression.Source, path, mutableBindings);
                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, $"Deque {path} expects exactly one argument");
                }
                var dequeElementType = _types.GetDequeElement(currentType);
                var dequeArgumentType = InferContextualValue(
                    target.Arguments[0],
                    dequeElementType,
                    functions,
                    bindings,
                    allowReadIntCall);
                if (dequeArgumentType != dequeElementType)
                {
                    throw Error(target.Arguments[0].Line, target.Arguments[0].Column,
                        $"Deque {path} expects {FormatType(dequeElementType)}, got {FormatType(dequeArgumentType)}");
                }
                result = new FlowResult(BoundType.Unit, FlowEffect.None);
                return true;
            case "front" or "back" when _types.IsDeque(currentType):
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, $"Deque {path} does not accept arguments");
                }
                result = new FlowResult(_types.GetDequeElement(currentType), FlowEffect.None);
                return true;
            case "popFront" or "popBack" when _types.IsDeque(currentType):
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, $"Deque {path} must be the final value-flow target");
                }
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, $"Deque {path} does not accept arguments");
                }
                EnsureMutableContainerSource(expression.Source, path, mutableBindings);
                result = new FlowResult(_types.GetDequeElement(currentType), FlowEffect.None);
                return true;
            case "pop" when _types.IsBinaryHeap(currentType):
                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "BinaryHeap pop must be the final value-flow target");
                }
                if (target.Arguments.Count != 0)
                {
                    throw Error(target.Line, target.Column, "BinaryHeap pop does not accept arguments");
                }
                EnsureMutableContainerSource(expression.Source, "pop", mutableBindings);
                result = new FlowResult(_types.GetBinaryHeapElement(currentType), FlowEffect.None);
                return true;
            case "take":
                if (_types.IsBinaryHeap(currentType) || _types.IsDeque(currentType) || _types.IsSet(currentType))
                {
                    return false;
                }
                if (currentType != BoundType.DynamicIntArray
                    && currentType != BoundType.IntDictionary
                    && !_types.IsDynamicArray(currentType)
                    && !_types.IsBoundedArray(currentType)
                    && !_types.IsDictionary(currentType))
                {
                    return false;
                }

                EnsureMutableContainerSource(expression.Source, "take", mutableBindings, allowProjection: true);
                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "take expects exactly one index or key argument");
                }

                var takeArgument = target.Arguments[0];
                var expectedTakeArgumentType = _types.IsDictionary(currentType)
                    ? _types.GetDictionary(currentType).KeyType
                    : BoundType.Int;
                var takeArgumentType = takeArgument is DictionaryLiteralExpression contextualTakeKey
                    && _types.IsStruct(expectedTakeArgumentType)
                        ? InferContextualStructLiteral(
                            contextualTakeKey,
                            expectedTakeArgumentType,
                            functions,
                            bindings,
                            allowReadIntCall)
                        : InferExpression(
                            takeArgument,
                            functions,
                            bindings,
                            allowPrintCall: false,
                            allowReadIntCall,
                            allowFlowBindingTarget: false);
                if (takeArgumentType != expectedTakeArgumentType)
                {
                    throw Error(
                        takeArgument.Line,
                        takeArgument.Column,
                        $"take expects {FormatType(expectedTakeArgumentType)} as its index or key");
                }

                var takenType = currentType == BoundType.DynamicIntArray
                    ? BoundType.Int
                    : currentType == BoundType.IntDictionary
                        ? BoundType.Int
                        : _types.IsDynamicArray(currentType)
                            ? _types.GetDynamicArray(currentType).ElementType
                            : _types.IsBoundedArray(currentType)
                                ? _types.GetBoundedArray(currentType).ElementType
                            : _types.GetDictionary(currentType).ValueType;
                result = new FlowResult(takenType, FlowEffect.None);
                return true;
            case "append":
                if (currentType != BoundType.DynamicIntArray)
                {
                    return false;
                }

                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "append must be bound directly with '=>'");
                }

                EnsureMoveContainerSource(expression.Source, "append");

                if (target.Arguments.Count != 1)
                {
                    throw Error(target.Line, target.Column, "append expects exactly one Int argument");
                }

                var appendedType = InferExpression(
                    target.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
                if (appendedType != BoundType.Int)
                {
                    throw Error(target.Arguments[0].Line, target.Arguments[0].Column, "append expects an Int value");
                }

                result = new FlowResult(BoundType.DynamicIntArray, FlowEffect.None);
                return true;
            case "put" or "putIfAbsent":
                if (_types.IsSet(currentType))
                {
                    return false;
                }
                if (currentType == BoundType.IntDictionaryView)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"{path} is not available on a readonly dictionary parameter; use 'mut {{Int: Int}}'");
                }

                if (currentType != BoundType.IntDictionary && !_types.IsDictionary(currentType))
                {
                    return false;
                }

                if (!isLast)
                {
                    throw Error(target.Line, target.Column, $"{path} must be the final value-flow target");
                }

                EnsureMutableContainerSource(expression.Source, path, mutableBindings);

                if (target.Arguments.Count != 2)
                {
                    throw Error(target.Line, target.Column, $"{path} expects key and value arguments");
                }

                var putKeyType = currentType == BoundType.IntDictionary
                    ? BoundType.Int
                    : _types.GetDictionary(currentType).KeyType;
                var putValueType = currentType == BoundType.IntDictionary
                    ? BoundType.Int
                    : _types.GetDictionary(currentType).ValueType;
                var expectedPutTypes = new[] { putKeyType, putValueType };
                for (var argumentIndex = 0; argumentIndex < target.Arguments.Count; argumentIndex++)
                {
                    var argument = target.Arguments[argumentIndex];
                    var expectedArgumentType = expectedPutTypes[argumentIndex];
                    var argumentType = argument is DictionaryLiteralExpression contextualArgument
                        && _types.IsStruct(expectedArgumentType)
                            ? InferContextualStructLiteral(
                                contextualArgument,
                                expectedArgumentType,
                                functions,
                                bindings,
                                allowReadIntCall)
                            : InferExpression(
                                argument,
                                functions,
                                bindings,
                                allowPrintCall: false,
                                allowReadIntCall,
                                allowFlowBindingTarget: false);
                    if (argumentType != expectedPutTypes[argumentIndex])
                    {
                        throw Error(argument.Line, argument.Column,
                            $"{path} expects {FormatType(putKeyType)} key and {FormatType(putValueType)} value arguments");
                    }
                }

                result = new FlowResult(path == "putIfAbsent" ? BoundType.Bool : BoundType.Unit, FlowEffect.None);
                return true;
            case "updated":
                if (currentType == BoundType.IntDictionaryView)
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        "updated consumes a dictionary owner and is not available on a readonly dictionary parameter; use 'move {Int: Int}'");
                }

                if (currentType is not (BoundType.DynamicIntArray or BoundType.IntDictionary))
                {
                    return false;
                }

                if (!isLast)
                {
                    throw Error(target.Line, target.Column, "updated must be bound directly with '=>'");
                }

                EnsureMoveContainerSource(expression.Source, "updated");

                if (target.Arguments.Count != 2)
                {
                    throw Error(target.Line, target.Column, "updated expects two Int arguments");
                }

                foreach (var argument in target.Arguments)
                {
                    var argumentType = InferExpression(
                        argument,
                        functions,
                        bindings,
                        allowPrintCall: false,
                        allowReadIntCall,
                        allowFlowBindingTarget: false);
                    if (argumentType != BoundType.Int)
                    {
                        throw Error(argument.Line, argument.Column, "updated expects Int arguments");
                    }
                }

                result = new FlowResult(currentType, FlowEffect.None);
                return true;
            default:
                if (path == "await")
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"await expects Task<T> but received {FormatType(currentType)}");
                }
                if (path == "cancel")
                {
                    throw Error(
                        target.Line,
                        target.Column,
                        $"cancel expects Task<T> but received {FormatType(currentType)}");
                }
                return false;
        }

        void ValidateBitSetIndexArgument(
            FlowTarget bitSetTarget,
            IReadOnlyDictionary<string, BoundFunction> availableFunctions,
            IReadOnlyDictionary<string, BoundType> availableBindings,
            bool allowRead)
        {
            if (bitSetTarget.Arguments.Count != 1)
            {
                throw Error(bitSetTarget.Line, bitSetTarget.Column,
                    "BitSet operation expects exactly one Int bit index");
            }
            var indexType = InferExpression(bitSetTarget.Arguments[0], availableFunctions, availableBindings,
                allowPrintCall: false, allowReadIntCall: allowRead, allowFlowBindingTarget: false);
            if (indexType != BoundType.Int)
            {
                throw Error(bitSetTarget.Arguments[0].Line, bitSetTarget.Arguments[0].Column,
                    $"BitSet index must be Int, got {FormatType(indexType)}");
            }
        }

        void ValidateSetElementArgument(
            FlowTarget setTarget,
            IReadOnlyDictionary<string, BoundFunction> availableFunctions,
            IReadOnlyDictionary<string, BoundType> availableBindings,
            bool allowRead)
        {
            if (setTarget.Arguments.Count != 1)
            {
                throw Error(setTarget.Line, setTarget.Column,
                    $"Set {string.Join('.', setTarget.Path)} expects exactly one element");
            }
            var expected = _types.GetSetElement(currentType);
            var argument = setTarget.Arguments[0];
            var actual = argument is DictionaryLiteralExpression contextualSetElement
                && _types.IsStruct(expected)
                    ? InferContextualStructLiteral(
                        contextualSetElement, expected, availableFunctions, availableBindings, allowRead)
                    : InferExpression(argument, availableFunctions, availableBindings,
                        allowPrintCall: false, allowReadIntCall: allowRead,
                        allowFlowBindingTarget: false);
            if (actual != expected)
            {
                throw Error(argument.Line, argument.Column,
                    $"Set element must be {FormatType(expected)}, got {FormatType(actual)}");
            }
        }
    }

    private BoundType InferFlowSource(
        Expression source,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings,
        bool allowOwnedElementBorrow = false)
    {
        return InferExpression(
            source,
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false,
            mutableBindings: mutableBindings,
            allowOwnedElementBorrow: allowOwnedElementBorrow);
    }

    private BoundType InferCallExpression(
        CallExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowPrintCall,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings)
    {
        if (TryInferEnumConstructor(expression, functions, bindings, allowReadIntCall, out var enumType))
        {
            return enumType;
        }

        if (TryInferArenaConstructor(expression, functions, bindings, allowReadIntCall, out var arenaType))
        {
            return arenaType;
        }

        if (TryInferNumericConversion(expression, functions, bindings, allowReadIntCall, out var numericType))
        {
            return numericType;
        }

        var path = string.Join('.', expression.Path);
        string? receiverName = null;
        BoundType? receiverType = null;
        if (!TryGetFunction(path, functions, out var function))
        {
            if (!TryResolveInstanceMethodCall(
                expression.Path,
                functions,
                bindings,
                out function,
                out receiverName,
                out receiverType))
            {
                throw Error(expression.Line, expression.Column, $"unknown function or method '{path}'");
            }
        }

        EnsureFunctionVisible(function, expression.Line, expression.Column);
        EnsureAsyncRuntimeCallable(function, expression.Line, expression.Column, path);

        if (expression.Arguments.Count == 0
            && (function.Kind == BoundFunctionKind.RuntimePrintLine
                || (function.IsStandardLibrary && function.Name == "sys.io.println")))
        {
            return BoundType.Unit;
        }

        if (TryGetDisplayPrinterKind(function, out var printerKind))
        {
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
            if (printerKind == BoundFunctionKind.RuntimePrintErrorLine
                && valueType != BoundType.Text)
            {
                throw Error(
                    expression.Arguments[0].Line,
                    expression.Arguments[0].Column,
                    $"{path} expects Text but received {FormatType(valueType)}");
            }
            EnsureDisplayable(valueType, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
            if (printerKind == BoundFunctionKind.RuntimePrintErrorLine)
            {
                _resolvedGenericCalls[expression] = function;
            }
            return BoundType.Unit;
        }

        switch (function.Kind)
        {
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

                return function.ReturnType;
            case BoundFunctionKind.RuntimeEnvironment:
            case BoundFunctionKind.RuntimeBorrowSourceText:
            case BoundFunctionKind.RuntimeMapSourceText:
            case BoundFunctionKind.RuntimeOpenFile:
            case BoundFunctionKind.RuntimeOpenWriteFile:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one Text argument");
                }
                var textArgumentType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                if (textArgumentType != BoundType.Text)
                {
                    throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                        $"{path} expects Text but received {FormatType(textArgumentType)}");
                }
                return function.ReturnType;
            case BoundFunctionKind.RuntimeBorrowSourceBytes:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one ref [UInt8; ~] argument");
                }
                var byteOwnerType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false,
                    allowOwnedElementBorrow: true);
                if (byteOwnerType != TypeId.DynamicUInt8Array)
                {
                    throw Error(expression.Line, expression.Column,
                        $"{path} expects [UInt8; ~] but received {FormatType(byteOwnerType)}");
                }
                return function.ReturnType;
            case BoundFunctionKind.RuntimeMapSourcePath:
            case BoundFunctionKind.RuntimePathText:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one Path argument");
                }
                var sourcePathType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false,
                    allowOwnedElementBorrow: function.Kind == BoundFunctionKind.RuntimePathText);
                if (function.Kind == BoundFunctionKind.RuntimePathText
                    && _types.IsReference(function.InputType!.Value)
                    && sourcePathType == _types.GetReference(function.InputType.Value).ElementType)
                {
                    EnsureReferenceArgumentPlace(expression.Arguments[0], bindings, mutableBindings, path);
                }
                else
                {
                    EnsureRuntimeInput(sourcePathType, function, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
                }
                return function.ReturnType;
            case BoundFunctionKind.RuntimeOpenFileAsync:
            case BoundFunctionKind.RuntimeOpenWriteFileAsync:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one Text argument");
                }
                var asyncPathType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                if (asyncPathType != BoundType.Text)
                {
                    throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                        $"{path} expects Text but received {FormatType(asyncPathType)}");
                }
                _resolvedGenericCalls[expression] = function;
                return AsyncCallType(function);
            case BoundFunctionKind.RuntimeRunProcess:
            case BoundFunctionKind.RuntimeRunProcessToFile:
            case BoundFunctionKind.RuntimeSyncFile:
            case BoundFunctionKind.RuntimeAtomicReplaceFile:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one request");
                }
                var argvType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                EnsureRuntimeInput(argvType, function, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
                return function.ReturnType;
            case BoundFunctionKind.RuntimeReadDirectory:
            case BoundFunctionKind.RuntimeCreateDirectory:
            case BoundFunctionKind.RuntimePathQuery:
            case BoundFunctionKind.RuntimeRangeStream:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one argument");
                }
                var directoryPathType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                EnsureRuntimeInput(directoryPathType, function, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
                return function.ReturnType;
            case BoundFunctionKind.RuntimeExitProcess:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one Int exit code");
                }
                var exitCodeType = InferExpression(
                    expression.Arguments[0], functions, bindings,
                    allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
                EnsureRuntimeInput(exitCodeType, function, expression.Arguments[0].Line, expression.Arguments[0].Column, path);
                return BoundType.Unit;
            case BoundFunctionKind.RuntimeSeedRandom:
            case BoundFunctionKind.RuntimeRandomBelow:
            case BoundFunctionKind.RuntimeSecureRandomBytes:
            case BoundFunctionKind.RuntimeOpenIntWriter:
            case BoundFunctionKind.RuntimeWriteInt:
            case BoundFunctionKind.RuntimeOpenIntReader:
            case BoundFunctionKind.RuntimeClosestInt:
            case BoundFunctionKind.RuntimeLimitParallelWorkers:
            case BoundFunctionKind.RuntimeReadStandardInputChunk:
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
            case BoundFunctionKind.RuntimeNowMillis:
            case BoundFunctionKind.RuntimePathStyle:
            case BoundFunctionKind.RuntimeParallelWorkers:
            case BoundFunctionKind.RuntimeParallelPeakWorkers:
            case BoundFunctionKind.RuntimeReadStandardInputSourceText:
                EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                if (expression.Arguments.Count != 0)
                {
                    throw Error(expression.Line, expression.Column, $"{path} does not accept arguments");
                }

                return function.ReturnType;
            case BoundFunctionKind.RuntimeFlushStandardOutput:
                if (expression.Arguments.Count != 0)
                {
                    throw Error(expression.Line, expression.Column, $"{path} does not accept arguments");
                }

                return BoundType.Unit;
            case BoundFunctionKind.RuntimeArguments:
                if (expression.Arguments.Count != 0)
                {
                    throw Error(expression.Line, expression.Column, $"{path} does not accept arguments");
                }

                return function.ReturnType;
            case BoundFunctionKind.RuntimeMouseEvents:
                EnsureRuntimeIntrinsicAllowed(function, allowReadIntCall, expression.Line, expression.Column, path);
                if (expression.Arguments.Count != 2)
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"{path} expects capacity and overflow arguments");
                }
                var capacityType = InferExpression(
                    expression.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false,
                    mutableBindings: mutableBindings);
                EnsureRuntimeInput(
                    capacityType,
                    function,
                    expression.Arguments[0].Line,
                    expression.Arguments[0].Column,
                    path);
                ValidateMouseEventCapacityLiteral(expression.Arguments[0]);
                ValidateAdditionalFunctionArguments(
                    function,
                    expression.Arguments.Skip(1).ToArray(),
                    functions,
                    bindings,
                    allowReadIntCall,
                    mutableBindings,
                    path);
                return function.ReturnType;
            case BoundFunctionKind.RuntimeSleep:
                if (expression.Arguments.Count != 1)
                {
                    throw Error(expression.Line, expression.Column, $"{path} expects exactly one Duration argument");
                }

                var durationType = InferExpression(
                    expression.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false);
                EnsureRuntimeInput(
                    durationType,
                    function,
                    expression.Arguments[0].Line,
                    expression.Arguments[0].Column,
                    path);
                return AsyncCallType(function);
            case BoundFunctionKind.RuntimeWriteScalar:
                return InferGenericCallExpression(
                    expression, function, functions, bindings, allowReadIntCall);
            case BoundFunctionKind.RuntimeSocketListen:
            case BoundFunctionKind.RuntimeSocketAccept:
            case BoundFunctionKind.RuntimeSocketConnect:
            case BoundFunctionKind.RuntimeSocketReceive:
            case BoundFunctionKind.RuntimeSocketSend:
            case BoundFunctionKind.RuntimeSocketSendText:
            case BoundFunctionKind.RuntimeSocketShutdown:
            case BoundFunctionKind.RuntimeSocketBindDatagram:
            case BoundFunctionKind.RuntimeSocketLocalPort:
            case BoundFunctionKind.RuntimeSocketSendTo:
            case BoundFunctionKind.RuntimeSocketReceiveFrom:
                var socketArgumentCount = 1 + (function.AdditionalParameters?.Count ?? 0);
                if (expression.Arguments.Count != socketArgumentCount)
                {
                    throw Error(
                        expression.Line,
                        expression.Column,
                        $"{path} expects {socketArgumentCount} argument(s)");
                }
                var socketOwnerType = expression.Arguments[0] is DictionaryLiteralExpression
                    && function.InputType is { } socketInputType
                    && _types.IsStruct(socketInputType)
                        ? InferContextualValue(
                            expression.Arguments[0],
                            socketInputType,
                            functions,
                            bindings,
                            allowReadIntCall,
                            mutableBindings)
                        : InferExpression(
                            expression.Arguments[0],
                            functions,
                            bindings,
                            allowPrintCall: false,
                            allowReadIntCall,
                            allowFlowBindingTarget: false,
                            mutableBindings: mutableBindings);
                EnsureRuntimeInput(
                    socketOwnerType,
                    function,
                    expression.Arguments[0].Line,
                    expression.Arguments[0].Column,
                    path);
                ValidateAdditionalFunctionArguments(
                    function,
                    expression.Arguments.Skip(1).ToArray(),
                    functions,
                    bindings,
                    allowReadIntCall,
                    mutableBindings,
                    path);
                _resolvedGenericCalls[expression] = function;
                return function.ReturnType;
            case BoundFunctionKind.User:
            case BoundFunctionKind.Native:
                if (function.GenericParameterName is not null
                    && function.SpecializedType is null
                    && function.SpecializedValue is null)
                {
                    if (function.IsValueGeneric)
                    {
                        throw Error(
                            expression.Line,
                            expression.Column,
                            $"value-generic function '{function.Name}' requires fluent syntax with an explicit value argument, for example 'value -> {function.Name}[4]'");
                    }
                    return InferGenericCallExpression(
                        expression,
                        function,
                        functions,
                        bindings,
                        allowReadIntCall);
                }

                if (receiverName is not null && receiverType is not null)
                {
                    var additionalParameters = function.AdditionalParameters ?? [];
                    if (additionalParameters.Count == 0 && expression.Arguments.Count == 0)
                    {
                        throw Error(
                            expression.Line,
                            expression.Column,
                            $"zero-argument method '{receiverName}.{expression.Path[^1]}' uses property syntax "
                            + $"without parentheses: '{receiverName}.{expression.Path[^1]}'");
                    }
                    if (expression.Arguments.Count != additionalParameters.Count)
                    {
                        throw Error(expression.Line, expression.Column,
                            $"method '{path}' expects {additionalParameters.Count} argument(s)");
                    }
                    if (function.InputType is null
                        || !CanPassFunctionArgument(receiverType.Value, function.InputType.Value))
                    {
                        throw Error(expression.Line, expression.Column,
                            $"method '{path}' cannot receive {FormatType(receiverType.Value)}");
                    }
                    ValidateAdditionalFunctionArguments(
                        function,
                        expression.Arguments,
                        functions,
                        bindings,
                        allowReadIntCall,
                        mutableBindings,
                        path);
                    // Instance-method syntax is resolved from the receiver's
                    // static type rather than from its textual path. Preserve
                    // that semantic result for code generation and reachability
                    // analysis just like generic and runtime calls.
                    _resolvedGenericCalls[expression] = function;
                    return AsyncCallType(function);
                }

                return InferUserCallExpression(expression, function, functions, bindings, allowReadIntCall, mutableBindings, path);
            default:
                throw Error(expression.Line, expression.Column, $"unsupported function kind '{function.Kind}'");
        }
    }

    private BoundType InferGenericCallExpression(
        CallExpression expression,
        BoundFunction template,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall)
    {
        var expectedArgumentCount = 1 + (template.AdditionalParameters?.Count ?? 0);
        if (expression.Arguments.Count != expectedArgumentCount)
        {
            throw Error(expression.Line, expression.Column,
                $"generic function '{template.Name}' expects {expectedArgumentCount} argument(s)");
        }

        var inferredTypes = new Dictionary<string, BoundType>(StringComparer.Ordinal);
        var parameterNames = GenericParameterNames(template);
        var actualType = InferExpression(
            expression.Arguments[0],
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        InferGenericArgument(
            template.InputTypeTemplate,
            template.InputType,
            actualType,
            template,
            inferredTypes,
            expression.Arguments[0].Line,
            expression.Arguments[0].Column);
        var additionalParameters = template.AdditionalParameters ?? [];
        for (var index = 0; index < additionalParameters.Count; index++)
        {
            var argument = expression.Arguments[index + 1];
            var argumentType = InferExpression(
                argument,
                functions,
                bindings,
                allowPrintCall: false,
                allowReadIntCall,
                allowFlowBindingTarget: false);
            InferGenericArgument(
                additionalParameters[index].TypeTemplate,
                additionalParameters[index].Type,
                argumentType,
                template,
                inferredTypes,
                argument.Line,
                argument.Column);
        }
        var missing = parameterNames.FirstOrDefault(parameter => !inferredTypes.ContainsKey(parameter));
        if (missing is not null)
        {
            throw Error(expression.Line, expression.Column,
                $"generic function '{template.Name}' cannot infer type parameter '{missing}'");
        }
        var specialization = ResolveGenericSpecialization(
            template,
            inferredTypes[parameterNames[0]],
            functions,
            expression,
            explicitGenericTypes: inferredTypes);
        return InferUserCallExpression(
            expression,
            specialization,
            functions,
            bindings,
            allowReadIntCall,
            mutableBindings: null,
            template.Name);
    }

    private void InferGenericArgument(
        string? typeTemplate,
        BoundType? parameterType,
        BoundType actualType,
        BoundFunction function,
        Dictionary<string, BoundType> inferredTypes,
        int line,
        int column)
    {
        if (typeTemplate is not null)
        {
            InferGenericArgumentsFromTypeTemplate(
                typeTemplate, actualType, function, inferredTypes, line, column);
            return;
        }
        if (parameterType is null) return;
        var names = GenericParameterNames(function);
        for (var index = 0; index < names.Count; index++)
        {
            if ((int)parameterType.Value == (int)BoundType.GenericParameter + index)
            {
                AssignInferredGenericType(names[index], actualType, inferredTypes, line, column);
                return;
            }
        }
        if (!CanPassFunctionArgument(actualType, parameterType.Value))
        {
            throw Error(line, column,
                $"generic argument expects {FormatType(parameterType.Value)} but received {FormatType(actualType)}");
        }
    }

    private BoundFunction ResolveGenericSpecialization(
        BoundFunction template,
        BoundType actualType,
        IReadOnlyDictionary<string, BoundFunction> functions,
        object callSite,
        BoundType? specializedInputType = null,
        BoundType? explicitSecondaryType = null,
        BoundType? explicitTertiaryType = null,
        IReadOnlyDictionary<string, BoundType>? explicitGenericTypes = null,
        bool validateSpecialization = true)
    {
        var genericParameterNames = GenericParameterNames(template);
        var specializedGenericTypes = new Dictionary<string, BoundType>(StringComparer.Ordinal);
        if (genericParameterNames.Count > 0)
        {
            specializedGenericTypes[genericParameterNames[0]] = actualType;
        }
        if (genericParameterNames.Count > 1 && explicitSecondaryType is { } secondaryExplicit)
        {
            specializedGenericTypes[genericParameterNames[1]] = secondaryExplicit;
        }
        if (genericParameterNames.Count > 2 && explicitTertiaryType is { } tertiaryExplicit)
        {
            specializedGenericTypes[genericParameterNames[2]] = tertiaryExplicit;
        }
        foreach (var pair in explicitGenericTypes ?? new Dictionary<string, BoundType>())
        {
            specializedGenericTypes[pair.Key] = pair.Value;
        }
        if (template.Kind is BoundFunctionKind.RuntimeWriteScalar
                or BoundFunctionKind.RuntimeReadScalar
                or BoundFunctionKind.RuntimeReadScalarAsync
            && actualType != BoundType.Bool
            && !IsNumericType(actualType)
            && actualType != BoundType.CodePoint)
        {
            var operation = template.Kind is BoundFunctionKind.RuntimeReadScalar
                or BoundFunctionKind.RuntimeReadScalarAsync ? "read" : "write";
            throw new SollangException(
                $"generic file {operation} supports Bool, CodePoint, and fixed-width numeric scalars; got {FormatType(actualType)}");
        }
        if (actualType is BoundType.Unit
            or BoundType.IntSlice
            or BoundType.StaticIntArray
            or BoundType.DynamicIntArray
            or BoundType.IntDictionaryView
            or BoundType.IntDictionary)
        {
            throw new SollangException(
                $"generic function '{template.Name}' does not yet support {FormatType(actualType)} specialization");
        }

        BoundFunction? traitImplementation = null;
        if (template.GenericTraitBound is { } traitBound
            && !TryFindTraitImplementation(functions, traitBound, actualType, out traitImplementation))
        {
            throw new SollangException(
                $"type {FormatType(actualType)} does not implement trait '{traitBound}' required by '{template.Name}'");
        }
        foreach (var parameter in template.GenericParameters ?? [])
        {
            if (!specializedGenericTypes.TryGetValue(parameter.Name, out var parameterType))
            {
                continue;
            }
            BoundFunction? parameterTraitImplementation = null;
            string? parameterTraitName = null;
            foreach (var constraint in parameter.Constraints)
            {
                if (constraint.TraitName is { } requiredTrait && requiredTrait != "Int")
                {
                    parameterTraitName = requiredTrait;
                    if (!TryFindTraitImplementation(functions, requiredTrait, parameterType, out parameterTraitImplementation))
                    {
                        throw new SollangException(
                            $"type {FormatType(parameterType)} does not implement trait '{requiredTrait}' required by '{template.Name}'");
                    }
                }
            }
            foreach (var constraint in parameter.Constraints)
            {
                if (constraint.AssociatedTypeName is not { } associatedName
                    || constraint.EqualTypeName is not { } equalTypeName)
                {
                    continue;
                }
                if (parameterTraitName is null || parameterTraitImplementation is null)
                {
                    throw new SollangException(
                        $"associated type equality '{parameter.Name}.{associatedName}' requires a trait bound");
                }
                if (parameterTraitImplementation.ImplAssociatedTypes is not { } associatedTypes
                    || !associatedTypes.TryGetValue(associatedName, out var actualAssociatedType))
                {
                    throw new SollangException(
                        $"trait '{parameterTraitName}' has no associated type binding '{associatedName}' for {FormatType(parameterType)}");
                }
                BoundType expectedAssociatedType;
                if (genericParameterNames.Contains(equalTypeName, StringComparer.Ordinal))
                {
                    if (!specializedGenericTypes.TryGetValue(equalTypeName, out expectedAssociatedType))
                    {
                        expectedAssociatedType = actualAssociatedType;
                        specializedGenericTypes[equalTypeName] = actualAssociatedType;
                    }
                }
                else
                {
                    expectedAssociatedType = ParseType(equalTypeName, template.Line, template.Column);
                }
                if (actualAssociatedType != expectedAssociatedType)
                {
                    throw new SollangException(
                        $"type {FormatType(parameterType)} does not satisfy associated type constraint "
                        + $"'{parameter.Name}.{associatedName} == {equalTypeName}' required by '{template.Name}'");
                }
            }
        }
        BoundType? inferredSecondaryType = explicitSecondaryType;
        BoundType? inferredTertiaryType = explicitTertiaryType;
        if (template.GenericTraitBound is { } constrainedTrait
            && template.GenericAssociatedTypeName is { } associatedTypeName
            && template.GenericAssociatedTypeConstraint is { } associatedTypeConstraint)
        {
            var actualAssociatedType = default(BoundType);
            var hasAssociatedType = traitImplementation?.ImplAssociatedTypes is { } associatedTypes
                && associatedTypes.TryGetValue(associatedTypeName, out actualAssociatedType);
            var satisfiesConstraint = hasAssociatedType
                && (associatedTypeConstraint == BoundType.SecondaryGenericParameter
                    || actualAssociatedType == associatedTypeConstraint);
            if (!satisfiesConstraint)
            {
                throw new SollangException(
                    $"type {FormatType(actualType)} does not satisfy associated type constraint "
                    + $"'{constrainedTrait}<{associatedTypeName} = {FormatType(associatedTypeConstraint)}>' required by '{template.Name}'");
            }
            if (associatedTypeConstraint == BoundType.SecondaryGenericParameter
                && inferredSecondaryType is null)
            {
                inferredSecondaryType = actualAssociatedType;
            }
        }
        if (template.SecondaryGenericParameterName is not null && inferredSecondaryType is null
            && specializedGenericTypes.TryGetValue(template.SecondaryGenericParameterName, out var inferredSecondaryFromMap))
        {
            inferredSecondaryType = inferredSecondaryFromMap;
        }
        if (template.SecondaryGenericParameterName is not null && inferredSecondaryType is null)
        {
            throw new SollangException(
                $"generic function '{template.Name}' cannot infer type parameter '{template.SecondaryGenericParameterName}'");
        }
        if (template.TertiaryGenericParameterName is not null && inferredTertiaryType is null
            && specializedGenericTypes.TryGetValue(template.TertiaryGenericParameterName, out var inferredTertiaryFromMap))
        {
            inferredTertiaryType = inferredTertiaryFromMap;
        }
        if (template.TertiaryGenericParameterName is not null && inferredTertiaryType is null)
        {
            throw new SollangException(
                $"generic function '{template.Name}' cannot infer type parameter '{template.TertiaryGenericParameterName}'");
        }

        if (template.SecondaryGenericParameterName is not null && inferredSecondaryType is { } inferredSecondary)
            specializedGenericTypes[template.SecondaryGenericParameterName] = inferredSecondary;
        if (template.TertiaryGenericParameterName is not null && inferredTertiaryType is { } inferredTertiary)
            specializedGenericTypes[template.TertiaryGenericParameterName] = inferredTertiary;
        var missingGenericParameter = genericParameterNames
            .FirstOrDefault(parameter => !specializedGenericTypes.ContainsKey(parameter));
        if (missingGenericParameter is not null)
        {
            throw new SollangException(
                $"generic function '{template.Name}' cannot infer type parameter '{missingGenericParameter}'");
        }

        var specializedName = template.Name + "$" + string.Join(
            "_",
            genericParameterNames.Select(parameter =>
                ((int)specializedGenericTypes[parameter]).ToString(System.Globalization.CultureInfo.InvariantCulture)));
        if (_boundFunctions is null)
        {
            throw new InvalidOperationException("generic specialization requires bound functions");
        }

        if (!_boundFunctions.TryGetValue(specializedName, out var specialization))
        {
            specialization = template with
            {
                Name = specializedName,
                Kind = template.Kind == BoundFunctionKind.User
                    && template.BlockInputName is not null
                        ? BoundFunctionKind.UserBlock
                        : template.Kind,
                InputType = template.InputTypeTemplate is null
                    ? template.InputType is null ? null : specializedInputType ?? actualType
                    : ParseSpecializedFunctionType(
                        template.InputTypeTemplate, specializedGenericTypes, template.Line, template.Column),
                ReturnType = template.ReturnTypeTemplate is null
                    ? SubstituteGenericType(template.ReturnType, template, specializedGenericTypes)
                    : ParseSpecializedFunctionType(
                        template.ReturnTypeTemplate, specializedGenericTypes, template.Line, template.Column),
                AdditionalParameters = (template.AdditionalParameters ?? [])
                    .Select(parameter => parameter with
                    {
                        Type = parameter.TypeTemplate is null
                            ? SubstituteGenericType(parameter.Type, template, specializedGenericTypes)
                            : ParseSpecializedFunctionType(
                                parameter.TypeTemplate, specializedGenericTypes, parameter.Line, parameter.Column)
                    })
                    .ToArray(),
                AdditionalBlockParameters = (template.AdditionalBlockParameters ?? [])
                    .Select(parameter => parameter with
                    {
                        Type = SubstituteGenericType(parameter.Type, template, specializedGenericTypes)
                    })
                    .ToArray(),
                BlockInputType = template.BlockInputTypeTemplate is null
                    ? template.BlockInputType is null
                        ? null
                        : SubstituteGenericType(template.BlockInputType.Value, template, specializedGenericTypes)
                    : ParseSpecializedFunctionType(
                        template.BlockInputTypeTemplate, specializedGenericTypes, template.Line, template.Column),
                BlockResultType = template.BlockResultTypeTemplate is null
                    ? template.BlockResultType
                    : ParseSpecializedFunctionType(
                        template.BlockResultTypeTemplate, specializedGenericTypes, template.Line, template.Column),
                StreamElementType = template.StreamElementTypeTemplate is null
                    ? template.StreamElementType
                    : ParseSpecializedFunctionType(
                        template.StreamElementTypeTemplate, specializedGenericTypes, template.Line, template.Column),
                SpecializedType = actualType,
                SpecializedSecondaryType = inferredSecondaryType,
                SpecializedTertiaryType = inferredTertiaryType,
                SpecializedGenericTypes = specializedGenericTypes
            };
            _boundFunctions.Add(specializedName, specialization);
            if (validateSpecialization
                && specialization.Kind is (BoundFunctionKind.User or BoundFunctionKind.UserBlock)
                && _validatingGenericSpecializations.Add(specialization))
            {
                ValidateGenericSpecialization(specialization, _boundFunctions);
            }
        }

        _resolvedGenericCalls[callSite] = specialization;
        return specialization;
    }

    private BoundType SubstituteGenericType(
        BoundType type,
        BoundType primaryType,
        BoundType? secondaryType,
        BoundType? tertiaryType)
    {
        if (type == BoundType.GenericParameter) return primaryType;
        if (type == BoundType.SecondaryGenericParameter) return secondaryType!.Value;
        if (type == BoundType.TertiaryGenericParameter) return tertiaryType!.Value;
        if (_types.TryGetOptionValue(type, out var optionValue))
        {
            var value = SubstituteGenericType(optionValue, primaryType, secondaryType, tertiaryType);
            return _types.GetOrAddOption(value, $"Option<{FormatType(value)}>");
        }
        if (_types.TryGetResultTypes(type, out var resultTypes))
        {
            var ok = SubstituteGenericType(resultTypes.Ok, primaryType, secondaryType, tertiaryType);
            var error = SubstituteGenericType(resultTypes.Error, primaryType, secondaryType, tertiaryType);
            return _types.GetOrAddResult(ok, error, $"Result<{FormatType(ok)}, {FormatType(error)}>");
        }
        if (_types.TryGetTaskValue(type, out var taskValue))
        {
            var value = SubstituteGenericType(taskValue, primaryType, secondaryType, tertiaryType);
            return _types.GetOrAddTask(value);
        }
        if (_types.TryGetStreamValue(type, out var streamValue))
        {
            var value = SubstituteGenericType(streamValue, primaryType, secondaryType, tertiaryType);
            return _types.GetOrAddStream(value);
        }
        if (_types.TryGetEventStreamValue(type, out var eventStreamValue))
        {
            var value = SubstituteGenericType(eventStreamValue, primaryType, secondaryType, tertiaryType);
            return _types.GetOrAddEventStream(value);
        }
        if (_types.IsReference(type))
        {
            var element = SubstituteGenericType(
                _types.GetReference(type).ElementType,
                primaryType,
                secondaryType,
                tertiaryType);
            return _types.GetOrAddReference(element);
        }
        return type;
    }

    private static IReadOnlyList<string> GenericParameterNames(BoundFunction function)
    {
        if (function.GenericParameters is { Count: > 0 } parameters)
        {
            return parameters.Select(parameter => parameter.Name).ToArray();
        }
        return new[] {
            function.GenericParameterName,
            function.SecondaryGenericParameterName,
            function.TertiaryGenericParameterName
        }.OfType<string>().ToArray();
    }

    private BoundType SubstituteGenericType(
        BoundType type,
        BoundFunction template,
        IReadOnlyDictionary<string, BoundType> specializedTypes)
    {
        var parameterNames = GenericParameterNames(template);
        for (var index = 0; index < parameterNames.Count; index++)
        {
            if ((int)type == (int)BoundType.GenericParameter + index)
            {
                return specializedTypes[parameterNames[index]];
            }
        }
        if (_types.TryGetOptionValue(type, out var optionValue))
        {
            var value = SubstituteGenericType(optionValue, template, specializedTypes);
            return _types.GetOrAddOption(value, $"Option<{FormatType(value)}>");
        }
        if (_types.TryGetResultTypes(type, out var resultTypes))
        {
            var ok = SubstituteGenericType(resultTypes.Ok, template, specializedTypes);
            var error = SubstituteGenericType(resultTypes.Error, template, specializedTypes);
            return _types.GetOrAddResult(ok, error, $"Result<{FormatType(ok)}, {FormatType(error)}>");
        }
        if (_types.TryGetTaskValue(type, out var taskValue))
        {
            return _types.GetOrAddTask(SubstituteGenericType(taskValue, template, specializedTypes));
        }
        if (_types.TryGetStreamValue(type, out var streamValue))
        {
            return _types.GetOrAddStream(SubstituteGenericType(streamValue, template, specializedTypes));
        }
        if (_types.TryGetEventStreamValue(type, out var eventStreamValue))
        {
            return _types.GetOrAddEventStream(SubstituteGenericType(eventStreamValue, template, specializedTypes));
        }
        if (_types.IsReference(type))
        {
            return _types.GetOrAddReference(SubstituteGenericType(
                _types.GetReference(type).ElementType,
                template,
                specializedTypes));
        }
        return type;
    }

    private BoundType InferTypeApplicationExpression(
        TypeApplicationExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        bool allowRuntimeCall)
    {
        var path = string.Join('.', expression.Path);
        if (path == "BitSet")
        {
            if ((expression.Arguments?.Count ?? 0) != 0
                || expression.AdditionalTypeArguments is { Count: > 0 }
                || !int.TryParse(expression.TypeArgument, out var bitCount)
                || bitCount <= 0)
            {
                throw Error(expression.Line, expression.Column,
                    "BitSet requires one positive compile-time size and no runtime arguments");
            }
            return _types.GetOrAddBitSet(bitCount);
        }
        if (path == "BinaryHeap")
        {
            if (expression.AdditionalTypeArguments is { Count: > 0 }
                || (expression.Arguments?.Count ?? 0) != 1)
            {
                throw Error(expression.Line, expression.Column,
                    "BinaryHeap<T>(capacity) requires one element type and one Int capacity");
            }
            var elementType = ParseType(expression.TypeArgument, expression.Line, expression.Column);
            if (!IsNumericType(elementType) && elementType != BoundType.CodePoint)
            {
                throw Error(expression.Line, expression.Column,
                    $"BinaryHeap ordering currently requires a numeric or CodePoint element, got {FormatType(elementType)}");
            }
            if (expression.Arguments![0] is not NumberExpression capacity
                || !long.TryParse(capacity.Text, out var capacityValue)
                || capacityValue <= 0)
            {
                throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                    "BinaryHeap capacity must currently be a positive Int literal");
            }
            return _types.GetOrAddBinaryHeap(elementType);
        }
        if (path == "Deque")
        {
            if (expression.AdditionalTypeArguments is { Count: > 0 }
                || (expression.Arguments?.Count ?? 0) != 1)
            {
                throw Error(expression.Line, expression.Column,
                    "Deque<T>(capacity) requires one element type and one Int capacity");
            }
            var elementType = ParseType(expression.TypeArgument, expression.Line, expression.Column);
            if (elementType == BoundType.Unit || IsNestedContainerElementType(elementType))
            {
                throw Error(expression.Line, expression.Column,
                    "Deque elements must be inline scalar or user values");
            }
            if (expression.Arguments![0] is not NumberExpression capacity
                || !long.TryParse(capacity.Text, out var capacityValue)
                || capacityValue <= 0)
            {
                throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                    "Deque capacity must currently be a positive Int literal");
            }
            return _types.GetOrAddDeque(elementType);
        }
        if (path == "Set")
        {
            if (expression.AdditionalTypeArguments is { Count: > 0 }
                || (expression.Arguments?.Count ?? 0) != 1)
            {
                throw Error(expression.Line, expression.Column,
                    "Set<T>(capacity) requires one element type and one Int capacity");
            }
            var elementType = ParseType(expression.TypeArgument, expression.Line, expression.Column);
            if (!IsSupportedDictionaryKeyType(elementType))
            {
                throw Error(expression.Line, expression.Column,
                    $"set element type {FormatType(elementType)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
            }
            if (expression.Arguments![0] is not NumberExpression capacity
                || !long.TryParse(capacity.Text, out var capacityValue)
                || capacityValue <= 0)
            {
                throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                    "Set capacity must currently be a positive Int literal");
            }
            return _types.GetOrAddSet(elementType);
        }
        if (!TryGetFunction(path, functions, out var template))
        {
            throw Error(expression.Line, expression.Column, $"unknown generic function '{path}'");
        }
        EnsureFunctionVisible(template, expression.Line, expression.Column);
        EnsureAsyncRuntimeCallable(template, expression.Line, expression.Column, path);
        if (template.GenericParameterName is null || template.SpecializedType is not null)
        {
            throw Error(expression.Line, expression.Column, $"function '{path}' is not generic");
        }
        if (template.InputType is not null)
        {
            throw Error(expression.Line, expression.Column,
                $"generic function '{path}' expects an argument and must use call or flow syntax");
        }
        if ((expression.Arguments?.Count ?? 0) != 0)
        {
            throw Error(expression.Line, expression.Column,
                $"generic function '{path}' does not accept direct arguments in this syntax slice");
        }
        if (IsMainOnlyRuntimeWrapper(template) && !allowRuntimeCall)
        {
            throw Error(expression.Line, expression.Column,
                $"{path} is only valid in main for the current runtime slice");
        }
        var parameterNames = GenericParameterNames(template);
        var typeArgumentSyntaxes = new[] { expression.TypeArgument }
            .Concat(expression.AdditionalTypeArguments ?? [])
            .ToArray();
        if (typeArgumentSyntaxes.Length != parameterNames.Count)
        {
            throw Error(expression.Line, expression.Column,
                $"generic function '{path}' expects {parameterNames.Count} type argument(s)");
        }
        var specializedTypes = parameterNames
            .Select((parameter, index) => new
            {
                Parameter = parameter,
                Type = ParseType(typeArgumentSyntaxes[index], expression.Line, expression.Column)
            })
            .ToDictionary(item => item.Parameter, item => item.Type, StringComparer.Ordinal);
        var actualType = specializedTypes[parameterNames[0]];
        return AsyncCallType(ResolveGenericSpecialization(
            template,
            actualType,
            functions,
            expression,
            explicitGenericTypes: specializedTypes));
    }

    private BoundFunction ResolveValueGenericSpecialization(
        BoundFunction template,
        BoundType actualType,
        int? valueArgument,
        object callSite,
        bool validateSpecialization = true)
    {
        if (valueArgument is null)
        {
            throw new SollangException(
                $"value-generic function '{template.Name}' requires an explicit compile-time Int argument");
        }
        BoundType? fixedArrayElementType = null;
        if (template.HasValueGenericFixedArrayInput)
        {
            fixedArrayElementType = FixedArrayElementType(actualType);
            if (fixedArrayElementType is null)
            {
                throw new SollangException(
                    $"value-generic function '{template.Name}' requires a fixed array input");
            }

            var elementTypeSyntax = FixedArrayElementTypeSyntax(template.InputTypeTemplate!);
            if (elementTypeSyntax == template.SecondaryGenericParameterName)
            {
                // The fixed array itself is sufficient to infer the element type;
                // callers only spell the compile-time length argument.
            }
            else if (elementTypeSyntax == template.TertiaryGenericParameterName)
            {
                // Kept symmetric with the existing three-parameter generic model.
            }
            else
            {
                var expectedElementType = ParseType(elementTypeSyntax, template.Line, template.Column);
                if (expectedElementType != fixedArrayElementType.Value)
                {
                    throw new SollangException(
                        $"function '{template.Name}' expects [{FormatType(expectedElementType)}; {valueArgument}] "
                        + $"but received [{FormatType(fixedArrayElementType.Value)}; N]");
                }
            }
        }
        if (!template.HasValueGenericFixedArrayInput
            && !CanPassFunctionArgument(actualType, template.InputType!.Value))
        {
            throw new SollangException(
                $"function '{template.Name}' expects {FormatType(template.InputType!.Value)} but received {FormatType(actualType)}");
        }
        if (_boundFunctions is null)
        {
            throw new InvalidOperationException("generic specialization requires bound functions");
        }

        var specializedName = template.Name
            + "$v"
            + valueArgument.Value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        if (fixedArrayElementType is { } specializedElementType)
        {
            specializedName += "$t" + ((int)specializedElementType).ToString(
                System.Globalization.CultureInfo.InvariantCulture);
        }
        if (!_boundFunctions.TryGetValue(specializedName, out var specialization))
        {
            var secondaryType = template.SecondaryGenericParameterName is { } secondaryName
                && FixedArrayElementTypeSyntax(template.InputTypeTemplate!) == secondaryName
                    ? fixedArrayElementType
                    : null;
            var tertiaryType = template.TertiaryGenericParameterName is { } tertiaryName
                && FixedArrayElementTypeSyntax(template.InputTypeTemplate!) == tertiaryName
                    ? fixedArrayElementType
                    : null;
            specialization = template with
            {
                Name = specializedName,
                InputType = template.HasValueGenericFixedArrayInput ? actualType : template.InputType,
                ReturnType = SubstituteGenericType(
                    template.ReturnType,
                    fixedArrayElementType ?? BoundType.Int,
                    secondaryType,
                    tertiaryType),
                SpecializedType = fixedArrayElementType,
                SpecializedSecondaryType = secondaryType,
                SpecializedTertiaryType = tertiaryType,
                SpecializedValue = valueArgument.Value
            };
            _boundFunctions.Add(specializedName, specialization);
            if (validateSpecialization && _validatingGenericSpecializations.Add(specialization))
            {
                ValidateGenericSpecialization(specialization, _boundFunctions);
            }
        }

        _resolvedGenericCalls[callSite] = specialization;
        return specialization;
    }

    private BoundType? FixedArrayElementType(BoundType type)
    {
        if (type == BoundType.StaticIntArray) return BoundType.Int;
        if (type == BoundType.StaticTextArray) return BoundType.Text;
        return _types.IsStaticArray(type) ? _types.GetStaticArray(type).ElementType : null;
    }

    private static string FixedArrayElementTypeSyntax(string inputTypeTemplate)
    {
        var separator = inputTypeTemplate.LastIndexOf(';');
        if (inputTypeTemplate.Length < 4 || inputTypeTemplate[0] != '[' || separator <= 1)
        {
            throw new InvalidOperationException($"invalid fixed-array input template '{inputTypeTemplate}'");
        }
        return inputTypeTemplate[1..separator].Trim();
    }

    private bool TryInferArenaConstructor(
        CallExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        out BoundType type)
    {
        type = default;
        if (expression.Path.Count != 1 || expression.Path[0] != "Arena")
        {
            return false;
        }
        if (expression.Arguments.Count != 1)
        {
            throw Error(expression.Line, expression.Column, "Arena expects one initial byte-capacity argument");
        }
        var capacityType = InferExpression(
            expression.Arguments[0], functions, bindings,
            allowPrintCall: false, allowReadIntCall, allowFlowBindingTarget: false);
        if (capacityType is not (BoundType.Int or BoundType.UIntSize))
        {
            throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                $"Arena capacity must be Int or UIntSize, got {FormatType(capacityType)}");
        }
        type = BoundType.Arena;
        return true;
    }

    private bool TryInferNumericConversion(
        CallExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        out BoundType type)
    {
        type = default;
        if (expression.Path.Count != 1
            || !_types.TryResolve(expression.Path[0], out var targetType)
            || !IsNumericType(targetType))
        {
            return false;
        }
        if (expression.Arguments.Count != 1)
        {
            throw Error(expression.Line, expression.Column,
                $"numeric conversion '{expression.Path[0]}' expects exactly one argument");
        }
        var sourceType = InferExpression(
            expression.Arguments[0],
            functions,
            bindings,
            allowPrintCall: false,
            allowReadIntCall,
            allowFlowBindingTarget: false);
        if (!IsNumericType(sourceType))
        {
            throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                $"numeric conversion '{expression.Path[0]}' expects a numeric value, got {FormatType(sourceType)}");
        }
        if (targetType == BoundType.CodePoint && IsFloatType(sourceType))
        {
            throw Error(expression.Arguments[0].Line, expression.Arguments[0].Column,
                "CodePoint conversion requires an integer Unicode scalar value");
        }
        ValidateNumericLiteralConversion(expression.Arguments[0], targetType, expression.Path[0]);
        type = targetType;
        return true;
    }

    private void ValidateNumericLiteralConversion(Expression argument, BoundType targetType, string targetName)
    {
        var negative = argument is NegateExpression;
        var number = argument switch
        {
            NumberExpression direct => direct,
            NegateExpression { Value: NumberExpression negated } => negated,
            _ => null
        };
        if (number is null)
        {
            return;
        }
        var text = negative ? "-" + number.Text : number.Text;
        if (IsIntegerType(targetType))
        {
            if (number.Text.Contains('.', StringComparison.Ordinal)
                || number.Text.Contains('e', StringComparison.OrdinalIgnoreCase))
            {
                throw Error(
                    argument.Line,
                    argument.Column,
                    $"numeric literal {text} is not an integer for {targetName}");
            }
            var value = BigInteger.Parse(text, CultureInfo.InvariantCulture);
            var bits = targetType switch
            {
                BoundType.Int8 or BoundType.UInt8 => 8,
                BoundType.Int16 or BoundType.UInt16 => 16,
                BoundType.Int or BoundType.UInt32 => 32,
                BoundType.Size or BoundType.UIntSize => _pointerBitWidth,
                _ => 64
            };
            var signed = IsSignedIntegerType(targetType);
            var minimum = signed ? -(BigInteger.One << (bits - 1)) : BigInteger.Zero;
            var maximum = targetType == BoundType.CodePoint
                ? new BigInteger(0x10FFFF)
                : signed ? (BigInteger.One << (bits - 1)) - 1 : (BigInteger.One << bits) - 1;
            if (value < minimum || value > maximum)
            {
                throw Error(argument.Line, argument.Column,
                    $"numeric literal {text} is out of range for {targetName} ({minimum}..{maximum})");
            }
            if (targetType == BoundType.CodePoint && value >= 0xD800 && value <= 0xDFFF)
            {
                throw Error(argument.Line, argument.Column,
                    $"numeric literal {text} is a Unicode surrogate and cannot be a CodePoint");
            }
            return;
        }
        if (!double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var floating)
            || double.IsInfinity(floating)
            || (targetType == BoundType.Float32 && Math.Abs(floating) > float.MaxValue))
        {
            throw Error(argument.Line, argument.Column, $"numeric literal {text} is out of range for {targetName}");
        }
    }

    private static bool IsIntegerType(BoundType type) => type is
        BoundType.Int or BoundType.Int8 or BoundType.Int16 or BoundType.Int64
        or BoundType.UInt8 or BoundType.UInt16 or BoundType.UInt32 or BoundType.UInt64
        or BoundType.Size or BoundType.UIntSize or BoundType.CodePoint;

    private static bool IsSignedIntegerType(BoundType type) => type is
        BoundType.Int or BoundType.Int8 or BoundType.Int16 or BoundType.Int64 or BoundType.Size;

    private static bool IsFloatType(BoundType type) => type is BoundType.Float32 or BoundType.Float64;

    private static bool IsNumericType(BoundType type) => IsIntegerType(type) || IsFloatType(type);

    private bool TryInferEnumConstructor(
        CallExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        out BoundType type)
    {
        type = default;
        if (expression.Path.Count < 2)
        {
            return false;
        }
        var typeName = string.Join('.', expression.Path.Take(expression.Path.Count - 1));
        if (!_types.TryResolve(typeName, out type))
        {
            if (!typeName.StartsWith("Option<", StringComparison.Ordinal)
                && !typeName.StartsWith("Result<", StringComparison.Ordinal))
            {
                return false;
            }
            type = ParseType(typeName, expression.Line, expression.Column);
        }
        if (!_types.IsEnum(type))
        {
            return false;
        }
        EnsureTypeVisible(type, expression.Line, expression.Column);

        var definition = _types.GetEnum(type);
        var variantName = expression.Path[^1];
        var variant = definition.Variants.FirstOrDefault(candidate => candidate.Name == variantName)
            ?? throw Error(
                expression.Line,
                expression.Column,
                $"enum '{definition.Name}' has no variant '{variantName}'");
        if (variant.PayloadType is null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"payload-free variant '{definition.Name}.{variant.Name}' uses member syntax without parentheses");
        }

        var expectedCount = variant.PayloadType is null ? 0 : 1;
        if (expression.Arguments.Count != expectedCount)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"variant '{definition.Name}.{variant.Name}' expects {expectedCount} payload argument(s)");
        }

        if (variant.PayloadType is { } payloadType)
        {
            if (payloadType == BoundType.Text
                && IsUnmaterializedDeferredText(expression.Arguments[0]))
            {
                throw Error(
                    expression.Arguments[0].Line,
                    expression.Arguments[0].Column,
                    $"variant '{definition.Name}.{variant.Name}' cannot store deferred interpolation; "
                    + "materialize it into an explicit Arena owner");
            }
            var actualType = InferContextualValue(
                expression.Arguments[0],
                payloadType,
                functions,
                bindings,
                allowReadIntCall);
            MarkFixedLengthCandidateRequiresGrowable(expression.Arguments[0], payloadType, actualType);
            if (actualType != payloadType)
            {
                throw Error(
                    expression.Arguments[0].Line,
                    expression.Arguments[0].Column,
                    $"variant '{definition.Name}.{variant.Name}' expects {FormatType(payloadType)}, got {FormatType(actualType)}");
            }
        }

        return true;
    }

    private BoundType InferUserMethodCallExpression(
        CallExpression expression,
        BoundFunction function,
        string receiverName,
        BoundType receiverType,
        string path)
    {
        if (expression.Arguments.Count != 0)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"method '{path}' does not accept additional arguments in this slice");
        }

        if (function.InputType != receiverType)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"method '{path}' cannot be called on {FormatType(receiverType)} value '{receiverName}'");
        }

        return function.ReturnType;
    }

    private bool TryResolveInstanceMethodCall(
        IReadOnlyList<string> path,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out BoundFunction function,
        out string? receiverName,
        out BoundType? receiverType)
    {
        function = null!;
        receiverName = null;
        receiverType = null;
        if (path.Count != 2 || !bindings.TryGetValue(path[0], out var type))
        {
            return false;
        }

        if (!TryResolveInstanceMethod(type, path[1], functions, out function))
        {
            return false;
        }

        receiverName = path[0];
        receiverType = type;
        return true;
    }

    private bool TryResolveInstanceMethod(
        BoundType receiverType,
        string methodName,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out BoundFunction function)
    {
        function = null!;
        if (!_types.IsStruct(receiverType))
        {
            return false;
        }

        var typeName = _types.GetStruct(receiverType).Name;
        if (methodName.Contains('.', StringComparison.Ordinal))
        {
            var separator = methodName.LastIndexOf('.');
            var traitName = methodName[..separator];
            var memberName = methodName[(separator + 1)..];
            return functions.TryGetValue(traitName + "." + typeName + "." + memberName, out function!)
                && function.InputType == receiverType;
        }

        var inherentName = typeName + "." + methodName;
        if (functions.TryGetValue(inherentName, out function!) && function.InputType == receiverType)
        {
            return true;
        }

        var candidates = functions.Values
            .Where(candidate => candidate.TraitName is not null
                && candidate.InputType == receiverType
                && candidate.Name.EndsWith("." + methodName, StringComparison.Ordinal))
            .Distinct()
            .ToArray();
        if (candidates.Length > 1)
        {
            throw new SollangException(
                $"ambiguous trait member '{typeName}.{methodName}'; use 'value -> Trait.{methodName}'");
        }
        if (candidates.Length == 1)
        {
            function = candidates[0];
            return true;
        }

        return false;
    }

    private static bool TryFindTraitImplementation(
        IReadOnlyDictionary<string, BoundFunction> functions,
        string traitName,
        BoundType receiverType,
        out BoundFunction? implementation)
    {
        implementation = functions.Values
            .Where(candidate => candidate.TraitName == traitName
                && candidate.InputType == receiverType)
            .Distinct()
            .FirstOrDefault();
        return implementation is not null;
    }

    private BoundType InferUserCallExpression(
        CallExpression expression,
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings,
        string path)
    {
        if (IsMainOnlyRuntimeWrapper(function) && !allowReadIntCall)
        {
            throw Error(expression.Line, expression.Column, $"{path} is only valid in main for the current runtime slice");
        }

        var additionalParameters = function.AdditionalParameters ?? [];
        if (function.InputType is null)
        {
            if (expression.Arguments.Count != additionalParameters.Count)
            {
                throw Error(expression.Line, expression.Column,
                    $"function '{path}' expects {additionalParameters.Count} argument(s)");
            }
            ValidateAdditionalFunctionArguments(function, expression.Arguments, functions, bindings,
                allowReadIntCall, mutableBindings, path);
            return AsyncCallType(function);
        }

        if (expression.Arguments.Count != 1 + additionalParameters.Count)
        {
            throw Error(expression.Line, expression.Column,
                $"function '{path}' expects {1 + additionalParameters.Count} argument(s)");
        }

        var argumentType = expression.Arguments[0] is DictionaryLiteralExpression
            && _types.IsStruct(function.InputType.Value)
                ? InferContextualValue(
                    expression.Arguments[0],
                    function.InputType.Value,
                    functions,
                    bindings,
                    allowReadIntCall,
                    mutableBindings)
            : expression.Arguments[0] is ArrayLiteralExpression or ArrayRepeatExpression
                && TryGetContextualArrayElementType(function.InputType.Value, out _)
                ? InferContextualValue(
                    expression.Arguments[0],
                    function.InputType.Value,
                    functions,
                    bindings,
                    allowReadIntCall)
            : IsNumericType(function.InputType.Value)
                ? InferContextualValue(
                    expression.Arguments[0],
                    function.InputType.Value,
                    functions,
                    bindings,
                    allowReadIntCall,
                    mutableBindings)
                : InferExpression(
                    expression.Arguments[0],
                    functions,
                    bindings,
                    allowPrintCall: false,
                    allowReadIntCall,
                    allowFlowBindingTarget: false,
                    allowOwnedElementBorrow:
                        function.InputOwnership == BoundFunctionInputOwnership.Default);
        WarnRedundantNumericType(expression.Arguments[0], function.InputType.Value);
        if (argumentType == function.InputType.Value
            && IsNumericLiteralExpression(expression.Arguments[0]))
        {
            ValidateNumericLiteralConversion(
                expression.Arguments[0],
                function.InputType.Value,
                FormatType(function.InputType.Value));
        }
        if (!CanPassFunctionArgument(argumentType, function.InputType.Value))
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"function '{path}' expects {FormatType(function.InputType.Value)} but received {FormatType(argumentType)}");
        }
        MarkFixedLengthCandidateRequiresGrowable(
            expression.Arguments[0],
            function.InputType,
            argumentType);
        if (_types.IsReference(function.InputType.Value)
            && !_types.IsReference(argumentType))
        {
            EnsureReferenceArgumentPlace(expression.Arguments[0], bindings, mutableBindings, path);
        }

        if (FunctionMovesOwnedHeapInput(function))
        {
            EnsureOwnedParameterCallArgument(expression.Arguments[0], path);
        }

        if (FunctionMutablyBorrowsInput(function))
        {
            EnsureMutableBorrowCallArgument(expression.Arguments[0], path, mutableBindings);
        }

        if (FunctionReadonlyBorrowsHeapInput(function, argumentType))
        {
            EnsureReadonlyBorrowCallArgument(expression.Arguments[0], path);
        }

        ValidateAdditionalFunctionArguments(
            function,
            expression.Arguments.Skip(1).ToArray(),
            functions,
            bindings,
            allowReadIntCall,
            mutableBindings,
            path);

        return AsyncCallType(function);
    }

    private void ValidateAdditionalFunctionArguments(
        BoundFunction function,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowReadIntCall,
        IReadOnlySet<string>? mutableBindings,
        string path)
    {
        var parameters = function.AdditionalParameters ?? [];
        if (arguments.Count != parameters.Count)
        {
            throw Error(function.Line, function.Column,
                $"function '{path}' expects {parameters.Count} additional argument(s)");
        }

        for (var index = 0; index < parameters.Count; index++)
        {
            var parameter = parameters[index];
            var argument = arguments[index];
            var actualType = argument is DictionaryLiteralExpression
                && _types.IsStruct(parameter.Type)
                    ? InferContextualValue(
                        argument,
                        parameter.Type,
                        functions,
                        bindings,
                        allowReadIntCall,
                        mutableBindings)
                : argument is ArrayLiteralExpression or ArrayRepeatExpression
                    && TryGetContextualArrayElementType(parameter.Type, out _)
                    ? InferContextualValue(
                        argument,
                        parameter.Type,
                        functions,
                        bindings,
                        allowReadIntCall)
                : IsNumericType(parameter.Type)
                    ? InferContextualValue(
                        argument,
                        parameter.Type,
                        functions,
                        bindings,
                        allowReadIntCall,
                        mutableBindings)
                    : InferExpression(argument, functions, bindings, allowPrintCall: false,
                    allowReadIntCall, allowFlowBindingTarget: false,
                    allowOwnedElementBorrow: parameter.Ownership == BoundFunctionInputOwnership.Default);
            WarnRedundantNumericType(argument, parameter.Type);
            if (actualType == parameter.Type && IsNumericLiteralExpression(argument))
            {
                ValidateNumericLiteralConversion(argument, parameter.Type, FormatType(parameter.Type));
            }
            if (!CanPassFunctionArgument(actualType, parameter.Type))
            {
                throw Error(argument.Line, argument.Column,
                    $"function '{path}' parameter '{parameter.Name}' expects {FormatType(parameter.Type)} "
                    + $"but received {FormatType(actualType)}");
            }
            MarkFixedLengthCandidateRequiresGrowable(argument, parameter.Type, actualType);
            if (_types.IsReference(parameter.Type)
                && !_types.IsReference(actualType))
            {
                EnsureReferenceArgumentPlace(argument, bindings, mutableBindings, path);
            }
            if (parameter.Ownership == BoundFunctionInputOwnership.Move)
            {
                EnsureOwnedParameterCallArgument(argument, path);
            }
            else if (parameter.Ownership == BoundFunctionInputOwnership.MutableBorrow)
            {
                EnsureMutableBorrowCallArgument(argument, path, mutableBindings);
            }
            else if (_types.ContainsOwnedStorage(parameter.Type))
            {
                EnsureReadonlyBorrowCallArgument(argument, path);
            }
        }
    }

    private BoundType AsyncCallType(BoundFunction function) =>
        function.IsAsync ? _types.GetOrAddTask(function.ReturnType) : function.ReturnType;

    private void EnsureDisplayable(BoundType type, int line, int column, string path)
    {
        if (type != BoundType.Text && !IsIntegerType(type))
        {
            throw Error(line, column, $"{path} expects Text or Int but received {FormatType(type)}");
        }
    }

    private static bool TryGetDisplayPrinterKind(BoundFunction function, out BoundFunctionKind kind)
    {
        if (function.Kind is BoundFunctionKind.RuntimePrint
            or BoundFunctionKind.RuntimePrintLine
            or BoundFunctionKind.RuntimePrintErrorLine)
        {
            kind = function.Kind;
            return true;
        }

        if (function.IsStandardLibrary && function.Name == "sys.io.print")
        {
            kind = BoundFunctionKind.RuntimePrint;
            return true;
        }

        if (function.IsStandardLibrary && function.Name == "sys.io.println")
        {
            kind = BoundFunctionKind.RuntimePrintLine;
            return true;
        }

        kind = default;
        return false;
    }

    private bool IsMainOnlyRuntimeWrapper(BoundFunction function)
    {
        return function.Name is "sys.io.readInt"
            or "sys.random.seed"
            or "sys.random.below"
            or "sys.file.openIntWriter"
            or "sys.file.writeInt"
            or "sys.file.closeIntWriter"
            or "sys.file.openIntReader"
            or "sys.file.closestInt"
            or "sys.file.closeIntReader"
            or "sys.time.nowMillis";
    }

    private void EnsureRuntimeIntrinsicAllowed(
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

    private void EnsureRuntimeInput(
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

    private BoundType ResolveBindingType(
        string name,
        IReadOnlyDictionary<string, BoundType> bindings,
        int line,
        int column)
    {
        return bindings.TryGetValue(name, out var type)
            ? type
            : throw Error(line, column, $"unknown binding '{name}'");
    }

    private BoundType InferNameExpression(
        NameExpression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        bool allowRuntimeCall)
    {
        if (bindings.TryGetValue(expression.Name, out var type))
        {
            return _types.IsReference(type)
                ? _types.GetReference(type).ElementType
                : type;
        }

        if (TryGetFunction(expression.Name, functions, out var function))
        {
            EnsureFunctionVisible(function, expression.Line, expression.Column);
            EnsureAsyncRuntimeCallable(function, expression.Line, expression.Column, expression.Name);
            if (function.InputType is not null)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"function '{expression.Name}' expects an argument and must use call or flow syntax");
            }
            throw Error(
                expression.Line,
                expression.Column,
                $"zero-input function '{expression.Name}' must be called with parentheses: '{expression.Name}()'");
        }

        throw Error(expression.Line, expression.Column, $"unknown binding '{expression.Name}'");
    }

    private void ValidateBindingName(string name, int line, int column)
    {
        if (IsReservedName(name))
        {
            throw Error(line, column, $"binding name '{name}' is reserved");
        }
    }

    private void EnsureAsyncRuntimeCallable(BoundFunction function, int line, int column, string path)
    {
        EnsureFunctionEffects(function, line, column, path);
        if (!_currentFunctionIsAsync || _currentFunctionReturnType is null)
        {
            return;
        }

        if ((function.Kind == BoundFunctionKind.User
                && (!function.IsStandardLibrary
                    || function.Name is "sys.time.milliseconds" or "sys.time.seconds"))
            || function.Kind is BoundFunctionKind.RuntimeSleep
                or BoundFunctionKind.RuntimeReadScalarAsync
                or BoundFunctionKind.RuntimeOpenFile
                or BoundFunctionKind.RuntimeOpenWriteFile
                or BoundFunctionKind.RuntimeOpenFileAsync
                or BoundFunctionKind.RuntimeOpenWriteFileAsync)
        {
            return;
        }

        throw Error(
            line,
            column,
            $"async function '{path}' is outside the CPU-pure first runtime slice");
    }

    private void EnsureFunctionEffects(BoundFunction function, int line, int column, string path)
    {
        foreach (var required in RequiredEffects(function))
        {
            EnsureEffectAllowed(required, line, column, $"function '{path}'");
        }
    }

    private void EnsureEffectAllowed(string effect, int line, int column, string operation)
    {
        if (_currentFunctionReturnType is null || (_currentFunctionEffects?.Contains(effect) ?? false))
        {
            return;
        }

        throw Error(
            line,
            column,
            $"{operation} requires effect {effect}; add 'uses {effect}' to the caller signature");
    }

    private static IEnumerable<string> RequiredEffects(BoundFunction function)
    {
        if (function.Kind is BoundFunctionKind.User or BoundFunctionKind.UserBlock)
        {
            return function.Effects is { } effects ? effects : Array.Empty<string>();
        }

        return function.Kind switch
        {
            BoundFunctionKind.RuntimePrint
                or BoundFunctionKind.RuntimePrintLine
                or BoundFunctionKind.RuntimePrintErrorLine
                or BoundFunctionKind.RuntimeFlushStandardOutput
                or BoundFunctionKind.RuntimeReadInt => ["Console"],
            BoundFunctionKind.RuntimeSeedRandom
                or BoundFunctionKind.RuntimeRandomBelow
                or BoundFunctionKind.RuntimeSecureRandomBytes => ["Random"],
            BoundFunctionKind.RuntimeNowMillis
                or BoundFunctionKind.RuntimeSleep => ["Clock"],
            BoundFunctionKind.RuntimeArguments
                or BoundFunctionKind.RuntimeRunProcess => ["Process"],
            BoundFunctionKind.RuntimeRunProcessToFile => ["Process", "File"],
            BoundFunctionKind.RuntimeEnvironment => ["Environment"],
            BoundFunctionKind.RuntimeOpenIntWriter
                or BoundFunctionKind.RuntimeWriteInt
                or BoundFunctionKind.RuntimeCloseIntWriter
                or BoundFunctionKind.RuntimeOpenIntReader
                or BoundFunctionKind.RuntimeClosestInt
                or BoundFunctionKind.RuntimeCloseIntReader
                or BoundFunctionKind.RuntimeWriteScalar
                or BoundFunctionKind.RuntimeReadScalar
                or BoundFunctionKind.RuntimeReadScalarAsync
                or BoundFunctionKind.RuntimeOpenFile
                or BoundFunctionKind.RuntimeOpenWriteFile
                or BoundFunctionKind.RuntimeOpenFileAsync
                or BoundFunctionKind.RuntimeOpenWriteFileAsync
                or BoundFunctionKind.RuntimeWriteScalarAt
                or BoundFunctionKind.RuntimeWriteScalarAtAsync
                or BoundFunctionKind.RuntimeSyncFileAsync
                or BoundFunctionKind.RuntimeSyncFile
                or BoundFunctionKind.RuntimeAtomicReplaceFile
                or BoundFunctionKind.RuntimeMapSourceText
                or BoundFunctionKind.RuntimeReadStandardInputSourceText
                or BoundFunctionKind.RuntimeReadStandardInputChunk
                or BoundFunctionKind.RuntimeMapSourcePath => ["File"],
            BoundFunctionKind.RuntimeSocketListen
                or BoundFunctionKind.RuntimeSocketAccept
                or BoundFunctionKind.RuntimeSocketConnect
                or BoundFunctionKind.RuntimeSocketReceive
                or BoundFunctionKind.RuntimeSocketSend
                or BoundFunctionKind.RuntimeSocketSendText
                or BoundFunctionKind.RuntimeSocketShutdown
                or BoundFunctionKind.RuntimeSocketBindDatagram
                or BoundFunctionKind.RuntimeSocketLocalPort
                or BoundFunctionKind.RuntimeSocketSendTo
                or BoundFunctionKind.RuntimeSocketReceiveFrom => ["Network"],
            _ => []
        };
    }

    private bool IsReservedName(string name)
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
            or "nowMillis"
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
            or "stream"
            or "namespace"
            or "import"
            or "public"
            or "struct"
            or "enum"
            or "trait"
            or "impl"
            or "com"
            or "class"
            or "interface"
            or "sta"
            or "mta"
            or "for"
            or "self"
            or "as"
            or "move"
            or "mut";
    }

    private TypeDefinitionTable BuildTypeDefinitions(
        IReadOnlyList<StructDeclaration> structDeclarations,
        IReadOnlyList<EnumDeclaration> enumDeclarations)
    {
        var names = new Dictionary<string, TypeId>(StringComparer.Ordinal)
        {
            ["Unit"] = BoundType.Unit,
            ["Text"] = BoundType.Text,
            ["Int"] = BoundType.Int,
            ["Int8"] = BoundType.Int8,
            ["Int16"] = BoundType.Int16,
            ["Int32"] = BoundType.Int,
            ["Int64"] = BoundType.Int64,
            ["Long"] = BoundType.Int64,
            ["UInt8"] = BoundType.UInt8,
            ["UInt16"] = BoundType.UInt16,
            ["UInt32"] = BoundType.UInt32,
            ["UInt64"] = BoundType.UInt64,
            ["Size"] = BoundType.Size,
            ["UIntSize"] = BoundType.UIntSize,
            ["CodePoint"] = BoundType.CodePoint,
            ["Range"] = BoundType.Range,
            ["std.sequence.Range"] = BoundType.Range,
            ["Arena"] = BoundType.Arena,
            ["SourceText"] = BoundType.SourceText,
            ["Arguments"] = BoundType.Arguments,
            ["MappedBytes"] = BoundType.MappedBytes,
            ["MutableMappedBytes"] = BoundType.MutableMappedBytes,
            ["Float"] = BoundType.Float32,
            ["Float32"] = BoundType.Float32,
            ["Float64"] = BoundType.Float64,
            ["Double"] = BoundType.Float64,
            ["Bool"] = BoundType.Bool,
            ["[Int]"] = BoundType.IntSlice,
            ["[Int; ~]"] = BoundType.DynamicIntArray,
            ["{Int: Int}"] = BoundType.IntDictionary,
            ["[UInt8; ~]"] = TypeId.DynamicUInt8Array
        };
        var structTypes = new Dictionary<StructDeclaration, TypeId>(ReferenceEqualityComparer.Instance);
        var enumTypes = new Dictionary<EnumDeclaration, TypeId>(ReferenceEqualityComparer.Instance);
        var nextTypeId = (int)TypeId.FirstUserDefined;

        foreach (var declaration in structDeclarations)
        {
            _currentModuleName = declaration.ModuleName;
            if (IsReservedName(declaration.Name))
            {
                throw Error(declaration.Line, declaration.Column, $"type name '{declaration.Name}' is reserved");
            }

            var id = string.Equals(
                declaration.Name,
                "sys.time.Duration",
                StringComparison.Ordinal)
                ? TypeId.Duration
                : string.Equals(declaration.Name, "sys.file.File", StringComparison.Ordinal)
                    ? TypeId.File
                    : string.Equals(declaration.Name, "sys.file.FileWriter", StringComparison.Ordinal)
                        ? TypeId.FileWriter
                        : string.Equals(declaration.Name, "sys.file.SourceText", StringComparison.Ordinal)
                            ? TypeId.SourceText
                            : string.Equals(declaration.Name, "sys.process.RunToFileRequest", StringComparison.Ordinal)
                                ? TypeId.RunToFileRequest
                            : string.Equals(declaration.Name, "sys.file.AtomicReplaceRequest", StringComparison.Ordinal)
                                ? TypeId.AtomicReplaceRequest
                                : string.Equals(declaration.Name, "sys.path.Path", StringComparison.Ordinal)
                                    ? TypeId.Path
                                    : string.Equals(declaration.Name, "sys.directory.Raw", StringComparison.Ordinal)
                                        ? TypeId.DirectoryRaw
                                        : string.Equals(declaration.Name, "sys.directory.Entry", StringComparison.Ordinal)
                                            ? TypeId.DirectoryEntry
                                            : string.Equals(declaration.Name, "sys.event.MouseEvent", StringComparison.Ordinal)
                                                ? TypeId.MouseEvent
                                            : (TypeId)nextTypeId++;
            if (!names.TryAdd(declaration.Name, id))
            {
                throw Error(declaration.Line, declaration.Column, $"type '{declaration.Name}' already exists");
            }

            structTypes.Add(declaration, id);
        }

        foreach (var declaration in enumDeclarations)
        {
            _currentModuleName = declaration.ModuleName;
            if (IsReservedName(declaration.Name))
            {
                throw Error(declaration.Line, declaration.Column, $"type name '{declaration.Name}' is reserved");
            }

            var id = string.Equals(declaration.Name, "sys.path.Style", StringComparison.Ordinal)
                ? TypeId.PathStyle
                : string.Equals(declaration.Name, "sys.directory.kind.Kind", StringComparison.Ordinal)
                    ? TypeId.DirectoryEntryKind
                    : string.Equals(declaration.Name, "sys.directory.RawResult", StringComparison.Ordinal)
                        ? TypeId.DirectoryRawResult
                        : string.Equals(declaration.Name, "sys.directory.ReadResult", StringComparison.Ordinal)
                            ? TypeId.DirectoryReadResult
                        : string.Equals(declaration.Name, "sys.event.MouseEventKind", StringComparison.Ordinal)
                            ? TypeId.MouseEventKind
                        : string.Equals(declaration.Name, "sys.event.EventOverflowPolicy", StringComparison.Ordinal)
                            ? TypeId.EventOverflowPolicy
                    : (TypeId)nextTypeId++;
            if (!names.TryAdd(declaration.Name, id))
            {
                throw Error(declaration.Line, declaration.Column, $"type '{declaration.Name}' already exists");
            }

            enumTypes.Add(declaration, id);
        }

        var boxes = new Dictionary<TypeId, BoundBoxDefinition>();
        var predeclaredFixedStaticArrays = new Dictionary<TypeId, (TypeId ElementType, int Length)>
        {
            [TypeId.FixedUInt8Array12] = (TypeId.UInt8, 12),
            [TypeId.FixedUInt8Array16] = (TypeId.UInt8, 16),
            [TypeId.FixedUInt8Array32] = (TypeId.UInt8, 32)
        };
        var predeclaredFixedStaticArraysByShape = new Dictionary<(TypeId ElementType, int Length), TypeId>
        {
            [(TypeId.UInt8, 12)] = TypeId.FixedUInt8Array12,
            [(TypeId.UInt8, 16)] = TypeId.FixedUInt8Array16,
            [(TypeId.UInt8, 32)] = TypeId.FixedUInt8Array32
        };
        var predeclaredDynamicArrays = new Dictionary<TypeId, TypeId>
        {
            [TypeId.DynamicUInt8Array] = TypeId.UInt8,
            [TypeId.DynamicDirectoryEntryArray] = TypeId.DirectoryEntry
        };
        var predeclaredDynamicArraysByElement = new Dictionary<TypeId, TypeId>
        {
            [TypeId.UInt8] = TypeId.DynamicUInt8Array,
            [TypeId.DirectoryEntry] = TypeId.DynamicDirectoryEntryArray
        };
        var predeclaredBoundedArrays = new Dictionary<TypeId, (TypeId ElementType, int Capacity)>();
        var predeclaredBoundedArraysByShape = new Dictionary<(TypeId ElementType, int Capacity), TypeId>();
        var predeclaredBoundedDictionaries = new Dictionary<TypeId, (TypeId KeyType, TypeId ValueType, int MaxEntries)>();
        var predeclaredBoundedDictionariesByShape = new Dictionary<(TypeId KeyType, TypeId ValueType, int MaxEntries), TypeId>();
        var boxableTypes = names
            .Where(item => item.Value is TypeId.Int or TypeId.Bool or TypeId.Text
                || (structTypes.Values.Contains(item.Value)
                    && item.Value is not (TypeId.File or TypeId.FileWriter or TypeId.SourceText))
                    && item.Value is not (TypeId.RunToFileRequest or TypeId.AtomicReplaceRequest)
                || enumTypes.Values.Contains(item.Value))
            .Where(item => item.Value is not (TypeId.Path or TypeId.PathStyle
                or TypeId.DirectoryRaw or TypeId.DirectoryEntryKind or TypeId.DirectoryEntry
                or TypeId.DirectoryRawResult or TypeId.DirectoryReadResult
                or TypeId.MouseEvent or TypeId.MouseEventKind or TypeId.EventOverflowPolicy))
            .OrderBy(item => (int)item.Value)
            .ToArray();
        foreach (var (name, elementType) in boxableTypes)
        {
            var id = elementType == TypeId.Duration
                ? TypeId.BoxDuration
                : (TypeId)nextTypeId++;
            names.Add("box " + name, id);
            boxes.Add(id, new BoundBoxDefinition(id, elementType, Size: 0, Alignment: 1));
        }

        var references = new Dictionary<TypeId, BoundReferenceDefinition>();
        var referencesByElement = new Dictionary<TypeId, TypeId>();

        TypeId ResolveDefinitionType(string typeName, int line, int column)
        {
            if (names.TryGetValue(typeName, out var known))
            {
                return known;
            }
            if (TryResolveDefinitionDynamicArray(typeName, out var dynamicArray))
            {
                return dynamicArray;
            }
            if (TryResolveDefinitionFixedStaticArray(typeName, line, column, out var fixedArray))
            {
                return fixedArray;
            }
            if (TryResolveDefinitionBoundedArray(typeName, line, column, out var boundedArray))
            {
                return boundedArray;
            }
            if (TryResolveDefinitionBoundedDictionary(typeName, line, column, out var boundedDictionary))
            {
                return boundedDictionary;
            }
            if (typeName.StartsWith("ref ", StringComparison.Ordinal))
            {
                var elementName = typeName[4..].Trim();
                if (!names.TryGetValue(elementName, out var elementType)
                    || elementType == BoundType.Unit
                    || references.ContainsKey(elementType))
                {
                    throw Error(line, column, "ref requires a known non-reference value type");
                }
                if (referencesByElement.TryGetValue(elementType, out var existing))
                {
                    names.TryAdd(typeName, existing);
                    return existing;
                }

                var reference = (TypeId)nextTypeId++;
                references.Add(reference, new BoundReferenceDefinition(reference, elementType));
                referencesByElement.Add(elementType, reference);
                names.Add(typeName, reference);
                return reference;
            }

            throw Error(line, column, $"unknown type '{typeName}'");
        }

        var structs = new Dictionary<TypeId, BoundStructDefinition>
        {
            [TypeId.Range] = new BoundStructDefinition(
                TypeId.Range,
                "Range",
                [
                    new BoundStructField("start", TypeId.Int, 0, 0, 0),
                    new BoundStructField("endInclusive", TypeId.Int, 1, 0, 0)
                ],
                0,
                0,
                IsPublic: true)
        };
        foreach (var declaration in structDeclarations)
        {
            _currentModuleName = declaration.ModuleName;
            var fields = new List<BoundStructField>(declaration.Fields.Count);
            var fieldNames = new HashSet<string>(StringComparer.Ordinal);
            for (var index = 0; index < declaration.Fields.Count; index++)
            {
                var field = declaration.Fields[index];
                ValidateBindingName(field.Name, field.Line, field.Column);
                if (!fieldNames.Add(field.Name))
                {
                    throw Error(field.Line, field.Column, $"field '{field.Name}' already exists in struct '{declaration.Name}'");
                }

                var fieldType = ResolveDefinitionType(
                    field.TypeName,
                    field.Line,
                    field.Column);

                if (fieldType is TypeId.Unit
                    or TypeId.IntSlice
                    or TypeId.StaticIntArray
                    or TypeId.IntDictionaryView)
                {
                    throw Error(
                        field.Line,
                        field.Column,
                        $"struct field '{field.Name}' must be an inline value type");
                }

                fields.Add(new BoundStructField(field.Name, fieldType, index, field.Line, field.Column));
            }

            var id = structTypes[declaration];
            structs.Add(id, new BoundStructDefinition(
                id,
                declaration.Name,
                fields,
                declaration.Line,
                declaration.Column,
                declaration.ModuleName,
                declaration.IsPublic,
                declaration.DeclaringTypeName,
                declaration.IsAbi,
                declaration.ComInterface,
                declaration.NativeHandle));
        }

        var enums = new Dictionary<TypeId, BoundEnumDefinition>();
        foreach (var declaration in enumDeclarations)
        {
            _currentModuleName = declaration.ModuleName;
            if (declaration.Variants.Count == 0)
            {
                throw Error(declaration.Line, declaration.Column, $"enum '{declaration.Name}' requires at least one variant");
            }

            var variants = new List<BoundEnumVariant>(declaration.Variants.Count);
            var variantNames = new HashSet<string>(StringComparer.Ordinal);
            for (var tag = 0; tag < declaration.Variants.Count; tag++)
            {
                var variant = declaration.Variants[tag];
                if (!variantNames.Add(variant.Name))
                {
                    throw Error(
                        variant.Line,
                        variant.Column,
                        $"variant '{variant.Name}' already exists in enum '{declaration.Name}'");
                }

                TypeId? payloadType = null;
                if (variant.PayloadType is not null)
                {
                    var resolvedPayloadType = ResolveDefinitionType(
                        variant.PayloadType,
                        variant.Line,
                        variant.Column);

                    if (resolvedPayloadType is TypeId.Unit
                        or TypeId.IntSlice
                        or TypeId.StaticIntArray
                        or TypeId.DynamicIntArray
                        or TypeId.IntDictionaryView
                        or TypeId.IntDictionary)
                    {
                        throw Error(
                            variant.Line,
                            variant.Column,
                            $"enum variant '{variant.Name}' payload must be an inline value type");
                    }

                    payloadType = resolvedPayloadType;
                }

                variants.Add(new BoundEnumVariant(
                    variant.Name,
                    payloadType,
                    tag,
                    variant.Line,
                    variant.Column));
            }

            var id = enumTypes[declaration];
            enums.Add(id, new BoundEnumDefinition(
                id,
                declaration.Name,
                variants,
                PayloadWords: 0,
                declaration.Line,
                declaration.Column,
                declaration.ModuleName,
                declaration.IsPublic));
        }

        ValidateAcyclicValueTypes(structs, enums);
        foreach (var (id, definition) in enums.ToArray())
        {
            var payloadBytes = definition.Variants
                .Where(static variant => variant.PayloadType is not null)
                .Select(variant => InlineSize(variant.PayloadType!.Value, structs, enums, boxes, references,
                    predeclaredFixedStaticArrays, predeclaredDynamicArrays, predeclaredBoundedArrays, predeclaredBoundedDictionaries))
                .DefaultIfEmpty(0)
                .Max();
            enums[id] = definition with { PayloadWords = (payloadBytes + 7) / 8 };
        }

        foreach (var (id, definition) in boxes.ToArray())
        {
            var size = InlineSize(definition.ElementType, structs, enums, boxes, references,
                predeclaredFixedStaticArrays, predeclaredDynamicArrays, predeclaredBoundedArrays, predeclaredBoundedDictionaries);
            boxes[id] = definition with
            {
                Size = size,
                Alignment = Math.Min(Math.Max(size, 1), 8)
            };
        }

        var result = new TypeDefinitionTable(
            names,
            structs,
            enums,
            boxes,
            references,
            _pointerBitWidth / 8);
        result.RegisterFixedStaticArrays(predeclaredFixedStaticArrays);
        result.RegisterDynamicArrays(predeclaredDynamicArrays);
        result.RegisterBoundedArrays(predeclaredBoundedArrays);
        result.RegisterBoundedDictionaries(predeclaredBoundedDictionaries);
        return result;

        bool TryResolveDefinitionFixedStaticArray(
            string typeName,
            int line,
            int column,
            out TypeId type)
        {
            type = default;
            var separator = typeName.LastIndexOf(';');
            if (!typeName.StartsWith('[', StringComparison.Ordinal)
                || !typeName.EndsWith(']')
                || separator <= 1
                || typeName.Contains("; <=", StringComparison.Ordinal)
                || typeName.EndsWith("; ~]", StringComparison.Ordinal))
            {
                return false;
            }

            var elementName = typeName[1..separator].Trim();
            var lengthText = typeName[(separator + 1)..^1].Trim();
            if (!int.TryParse(lengthText, out var length) || length < 0)
            {
                throw Error(line, column, "fixed array length must be a nonnegative integer literal");
            }
            if (!names.TryGetValue(elementName, out var elementType) || elementType == BoundType.Unit)
            {
                return false;
            }
            var shape = (elementType, length);
            if (predeclaredFixedStaticArraysByShape.TryGetValue(shape, out type))
            {
                names.TryAdd(typeName, type);
                return true;
            }

            type = (TypeId)nextTypeId++;
            predeclaredFixedStaticArrays.Add(type, shape);
            predeclaredFixedStaticArraysByShape.Add(shape, type);
            names.TryAdd(typeName, type);
            return true;
        }

        bool TryResolveDefinitionDynamicArray(string typeName, out TypeId type)
        {
            type = default;
            if (!typeName.StartsWith('[', StringComparison.Ordinal)
                || !typeName.EndsWith("; ~]", StringComparison.Ordinal))
            {
                return false;
            }

            var elementName = typeName[1..^4].Trim();
            if (!names.TryGetValue(elementName, out var elementType)
                || elementType == BoundType.Unit)
            {
                return false;
            }
            if (elementType == BoundType.Int)
            {
                type = BoundType.DynamicIntArray;
                return true;
            }
            if (predeclaredDynamicArraysByElement.TryGetValue(elementType, out type))
            {
                return true;
            }

            type = (TypeId)nextTypeId++;
            predeclaredDynamicArrays.Add(type, elementType);
            predeclaredDynamicArraysByElement.Add(elementType, type);
            names.TryAdd(typeName, type);
            return true;
        }

        bool TryResolveDefinitionBoundedArray(string typeName, int line, int column, out TypeId type)
        {
            type = default;
            var separator = typeName.LastIndexOf("; <=", StringComparison.Ordinal);
            if (!typeName.StartsWith('[', StringComparison.Ordinal)
                || !typeName.EndsWith(']')
                || separator <= 1)
            {
                return false;
            }
            var elementName = typeName[1..separator].Trim();
            var capacityText = typeName[(separator + 4)..^1].Trim();
            if (!int.TryParse(capacityText, out var capacity) || capacity <= 0)
            {
                throw Error(line, column, "bounded array capacity must be a positive integer literal");
            }
            if (!names.TryGetValue(elementName, out var elementType) || elementType == BoundType.Unit)
            {
                return false;
            }
            if (predeclaredBoundedArraysByShape.TryGetValue((elementType, capacity), out type))
            {
                return true;
            }
            type = (TypeId)nextTypeId++;
            predeclaredBoundedArrays.Add(type, (elementType, capacity));
            predeclaredBoundedArraysByShape.Add((elementType, capacity), type);
            names.TryAdd(typeName, type);
            return true;
        }

        bool TryResolveDefinitionBoundedDictionary(
            string typeName, int line, int column, out TypeId type)
        {
            type = default;
            if (typeName.Length < 5 || typeName[0] != '{' || typeName[^1] != '}')
            {
                return false;
            }
            var keySeparator = typeName.IndexOf(':', StringComparison.Ordinal);
            var capacitySeparator = typeName.LastIndexOf("; <=", StringComparison.Ordinal);
            if (keySeparator <= 1 || capacitySeparator <= keySeparator)
            {
                return false;
            }
            var keyName = typeName[1..keySeparator].Trim();
            var valueName = typeName[(keySeparator + 1)..capacitySeparator].Trim();
            var capacityText = typeName[(capacitySeparator + 4)..^1].Trim();
            if (!int.TryParse(capacityText, out var capacity) || capacity <= 0)
            {
                throw Error(line, column, "bounded dictionary capacity must be a positive integer literal");
            }
            if (!names.TryGetValue(keyName, out var keyType)
                || !names.TryGetValue(valueName, out var valueType))
            {
                return false;
            }
            var shape = (keyType, valueType, capacity);
            if (predeclaredBoundedDictionariesByShape.TryGetValue(shape, out type))
            {
                return true;
            }
            type = (TypeId)nextTypeId++;
            predeclaredBoundedDictionaries.Add(type, shape);
            predeclaredBoundedDictionariesByShape.Add(shape, type);
            names.TryAdd(typeName, type);
            return true;
        }
    }

    private void ValidateAcyclicValueTypes(
        IReadOnlyDictionary<TypeId, BoundStructDefinition> structs,
        IReadOnlyDictionary<TypeId, BoundEnumDefinition> enums)
    {
        var states = new Dictionary<TypeId, int>();
        foreach (var definition in structs.Values)
        {
            Visit(definition.Id, definition.Name, definition.Line, definition.Column);
        }
        foreach (var definition in enums.Values)
        {
            Visit(definition.Id, definition.Name, definition.Line, definition.Column);
        }

        void Visit(TypeId id, string name, int line, int column)
        {
            if (states.TryGetValue(id, out var state))
            {
                if (state == 1)
                {
                    throw Error(
                        line,
                        column,
                        $"type '{name}' recursively contains itself; recursive values require an explicit heap reference type");
                }

                return;
            }

            states[id] = 1;
            if (structs.TryGetValue(id, out var structure))
            {
                foreach (var field in structure.Fields)
                {
                    VisitDependency(field.Type);
                }
            }
            else if (enums.TryGetValue(id, out var enumeration))
            {
                foreach (var variant in enumeration.Variants)
                {
                    if (variant.PayloadType is { } payloadType)
                    {
                        VisitDependency(payloadType);
                    }
                }
            }

            states[id] = 2;

            void VisitDependency(TypeId dependency)
            {
                if (structs.TryGetValue(dependency, out var nestedStruct))
                {
                    Visit(nestedStruct.Id, nestedStruct.Name, nestedStruct.Line, nestedStruct.Column);
                }
                else if (enums.TryGetValue(dependency, out var nestedEnum))
                {
                    Visit(nestedEnum.Id, nestedEnum.Name, nestedEnum.Line, nestedEnum.Column);
                }
            }
        }
    }

    private int InlineSize(
        TypeId type,
        IReadOnlyDictionary<TypeId, BoundStructDefinition> structs,
        IReadOnlyDictionary<TypeId, BoundEnumDefinition> enums,
        IReadOnlyDictionary<TypeId, BoundBoxDefinition> boxes,
        IReadOnlyDictionary<TypeId, BoundReferenceDefinition> references,
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int Length)> fixedStaticArrays,
        IReadOnlyDictionary<TypeId, TypeId> dynamicArrays,
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int Capacity)> boundedArrays,
        IReadOnlyDictionary<TypeId, (TypeId KeyType, TypeId ValueType, int MaxEntries)> boundedDictionaries)
    {
        if (boxes.ContainsKey(type) || references.ContainsKey(type))
        {
            return 8;
        }
        if (type == TypeId.SourceText)
        {
            return 32;
        }
        if (type is TypeId.MappedBytes or TypeId.MutableMappedBytes)
        {
            return 40;
        }

        if (structs.TryGetValue(type, out var structure))
        {
            var offset = 0;
            var maxAlignment = 1;
            foreach (var field in structure.Fields)
            {
                var size = InlineSize(field.Type, structs, enums, boxes, references,
                    fixedStaticArrays, dynamicArrays, boundedArrays, boundedDictionaries);
                var alignment = Math.Min(Math.Max(size, 1), 8);
                offset = AlignUp(offset, alignment);
                offset += size;
                maxAlignment = Math.Max(maxAlignment, alignment);
            }

            return AlignUp(offset, maxAlignment);
        }

        if (enums.TryGetValue(type, out var enumeration))
        {
            var payloadBytes = enumeration.Variants
                .Where(static variant => variant.PayloadType is not null)
                .Select(variant => InlineSize(variant.PayloadType!.Value, structs, enums, boxes, references,
                    fixedStaticArrays, dynamicArrays, boundedArrays, boundedDictionaries))
                .DefaultIfEmpty(0)
                .Max();
            return 8 + AlignUp(payloadBytes, 8);
        }

        if (dynamicArrays.ContainsKey(type))
        {
            return 3 * (_pointerBitWidth / 8);
        }

        if (fixedStaticArrays.ContainsKey(type))
        {
            return 2 * (_pointerBitWidth / 8);
        }

        if (boundedArrays.TryGetValue(type, out var boundedArray))
        {
            var elementSize = InlineSize(boundedArray.ElementType, structs, enums, boxes, references,
                fixedStaticArrays, dynamicArrays, boundedArrays, boundedDictionaries);
            var alignment = Math.Max(8, Math.Min(Math.Max(elementSize, 1), 8));
            return AlignUp(checked(8 + checked(elementSize * boundedArray.Capacity)), alignment);
        }

        if (boundedDictionaries.TryGetValue(type, out var boundedDictionary))
        {
            var keySize = InlineSize(boundedDictionary.KeyType, structs, enums, boxes, references,
                fixedStaticArrays, dynamicArrays, boundedArrays, boundedDictionaries);
            var valueSize = InlineSize(boundedDictionary.ValueType, structs, enums, boxes, references,
                fixedStaticArrays, dynamicArrays, boundedArrays, boundedDictionaries);
            var keyAlignment = Math.Min(Math.Max(keySize, 1), 8);
            var valueAlignment = Math.Min(Math.Max(valueSize, 1), 8);
            var valueOffset = AlignUp(keySize, valueAlignment);
            var stride = AlignUp(checked(valueOffset + valueSize), Math.Max(keyAlignment, valueAlignment));
            var minimumBuckets = checked((boundedDictionary.MaxEntries * 8 + 6) / 7);
            var buckets = 16;
            while (buckets < minimumBuckets)
            {
                buckets = checked(buckets * 2);
            }
            var entriesOffset = AlignUp(buckets, Math.Max(keyAlignment, valueAlignment));
            return AlignUp(checked(8 + entriesOffset + checked(buckets * stride)), 8);
        }

        return type switch
        {
            TypeId.Bool => 1,
            TypeId.Int8 or TypeId.UInt8 => 1,
            TypeId.Int16 or TypeId.UInt16 => 2,
            TypeId.Int or TypeId.UInt32 or TypeId.Float32 => 4,
            TypeId.CodePoint => 4,
            TypeId.Int64 or TypeId.UInt64 or TypeId.Float64 => 8,
            TypeId.Size or TypeId.UIntSize => _pointerBitWidth / 8,
            TypeId.Text => 16,
            TypeId.Arguments => 8,
            TypeId.Arena => 24,
            TypeId.SourceText => 32,
            TypeId.MappedBytes or TypeId.MutableMappedBytes => 40,
            TypeId.DynamicIntArray or TypeId.IntDictionary => 24,
            _ => throw new InvalidOperationException($"type {type} has no inline size")
        };
    }

    private int AlignUp(int value, int alignment)
    {
        return checked((value + alignment - 1) / alignment * alignment);
    }

    private BoundType ParseType(string typeName, int line, int column)
    {
        if (typeName.StartsWith("BitSet<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var countText = typeName[7..^1].Trim();
            if (!int.TryParse(countText, out var bitCount) || bitCount <= 0)
            {
                throw Error(line, column, "BitSet size must be a positive integer literal");
            }
            return _types.GetOrAddBitSet(bitCount);
        }
        if (typeName.StartsWith("BinaryHeap<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var elementType = ParseType(typeName[11..^1].Trim(), line, column);
            if (!IsNumericType(elementType) && elementType != BoundType.CodePoint)
            {
                throw Error(line, column,
                    $"BinaryHeap ordering currently requires a numeric or CodePoint element, got {FormatType(elementType)}");
            }
            return _types.GetOrAddBinaryHeap(elementType);
        }
        if (typeName.StartsWith("Deque<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var elementType = ParseType(typeName[6..^1].Trim(), line, column);
            if (elementType == BoundType.Unit || IsNestedContainerElementType(elementType))
            {
                throw Error(line, column, "Deque elements must be inline scalar or user values");
            }
            return _types.GetOrAddDeque(elementType);
        }
        if (typeName.StartsWith("Set<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var elementType = ParseType(typeName[4..^1].Trim(), line, column);
            if (!IsSupportedDictionaryKeyType(elementType))
            {
                throw Error(line, column,
                    $"set element type {FormatType(elementType)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
            }
            return _types.GetOrAddSet(elementType);
        }
        if (_activeGenericTypeArguments.TryGetValue(typeName, out var specializedType))
        {
            return specializedType;
        }
        if (typeName.StartsWith('(') && typeName.EndsWith(')'))
        {
            return ParseProductType(typeName, field => ParseType(field, line, column), line, column);
        }
        if (typeName.StartsWith("dyn ", StringComparison.Ordinal))
        {
            var requestedName = typeName[4..].Trim();
            var declarations = _program.Traits
                .Where(trait => trait.Name == requestedName
                    || (trait.ModuleName.Length > 0
                        && trait.ModuleName + "." + trait.Name == requestedName))
                .ToArray();
            if (declarations.Length == 0)
            {
                throw Error(line, column, $"unknown trait '{requestedName}'");
            }
            if (declarations.Length > 1)
            {
                throw Error(line, column, $"ambiguous trait '{requestedName}'; use its qualified name");
            }
            var declaration = declarations[0];
            if (!declaration.IsPublic && declaration.ModuleName != _currentModuleName)
            {
                throw Error(line, column,
                    $"trait '{declaration.Name}' is internal to module '{declaration.ModuleName}'");
            }
            var canonicalName = declaration.ModuleName.Length == 0
                ? declaration.Name
                : declaration.ModuleName + "." + declaration.Name;
            return _types.GetOrAddDynTrait(canonicalName);
        }
        if (typeName.StartsWith("ref ", StringComparison.Ordinal))
        {
            var elementType = ParseType(typeName[4..].Trim(), line, column);
            if (elementType == BoundType.Unit || _types.IsReference(elementType))
            {
                throw Error(line, column, "ref requires a non-reference value type");
            }
            var reference = _types.GetOrAddReference(elementType);
            _types.AddAlias(typeName, reference);
            return reference;
        }
        if (typeName.StartsWith("Option<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var valueName = typeName[7..^1].Trim();
            var valueType = ParseType(valueName, line, column);
            var option = _types.GetOrAddOption(valueType, $"Option<{FormatType(valueType)}>");
            _types.AddAlias(typeName, option);
            return option;
        }
        if (typeName.StartsWith("Stream<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var valueName = typeName[7..^1].Trim();
            var valueType = ParseType(valueName, line, column);
            var stream = _types.GetOrAddStream(valueType);
            _types.AddAlias(typeName, stream);
            return stream;
        }
        if (typeName.StartsWith("EventStream<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var valueName = typeName[12..^1].Trim();
            var valueType = ParseType(valueName, line, column);
            var stream = _types.GetOrAddEventStream(valueType);
            _types.AddAlias(typeName, stream);
            return stream;
        }
        if (typeName.StartsWith("Result<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var arguments = typeName[7..^1];
            var separator = FindTopLevelTypeComma(arguments);
            if (separator < 0)
            {
                throw Error(line, column, "Result requires success and error types");
            }
            var okType = ParseType(arguments[..separator].Trim(), line, column);
            var errorType = ParseType(arguments[(separator + 1)..].Trim(), line, column);
            var result = _types.GetOrAddResult(
                okType,
                errorType,
                $"Result<{FormatType(okType)}, {FormatType(errorType)}>");
            _types.AddAlias(typeName, result);
            return result;
        }
        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith("; ~]", StringComparison.Ordinal))
        {
            var elementName = typeName[1..^4].Trim();
            var elementType = ParseType(elementName, line, column);
            if (elementType == BoundType.Unit || IsNestedContainerElementType(elementType))
            {
                throw Error(line, column, "growable array elements must be inline scalar or user values");
            }
            return elementType == BoundType.Int
                ? BoundType.DynamicIntArray
                : _types.GetOrAddDynamicArray(elementType);
        }
        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith(']')
            && typeName.LastIndexOf(';') is var fixedSeparator
            && fixedSeparator > 1
            && !typeName.Contains("; <=", StringComparison.Ordinal))
        {
            var elementName = typeName[1..fixedSeparator].Trim();
            var lengthText = typeName[(fixedSeparator + 1)..^1].Trim();
            if (!int.TryParse(lengthText, out var length) || length < 0)
            {
                throw Error(line, column, "fixed array length must be a nonnegative integer literal");
            }
            var elementType = ParseType(elementName, line, column);
            if (elementType == BoundType.Unit || IsNestedContainerElementType(elementType))
            {
                throw Error(line, column, "fixed array elements must be inline scalar or user values");
            }
            return _types.GetOrAddFixedStaticArray(elementType, length);
        }
        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith(']')
            && !typeName.Contains(';', StringComparison.Ordinal))
        {
            var elementName = typeName[1..^1].Trim();
            var elementType = ParseType(elementName, line, column);
            if (elementType == BoundType.Unit || IsNestedContainerElementType(elementType))
            {
                throw Error(line, column, "readonly array views require inline scalar or user-value elements");
            }
            return _types.GetOrAddSlice(elementType);
        }
        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith(']')
            && typeName.LastIndexOf("; <=", StringComparison.Ordinal) is var boundedSeparator
            && boundedSeparator > 1)
        {
            var elementName = typeName[1..boundedSeparator].Trim();
            var capacityText = typeName[(boundedSeparator + 4)..^1].Trim();
            if (!int.TryParse(capacityText, out var capacity) || capacity <= 0)
            {
                throw Error(line, column, "bounded array capacity must be a positive integer literal");
            }
            var elementType = ParseType(elementName, line, column);
            if (elementType == BoundType.Unit || IsNestedContainerElementType(elementType))
            {
                throw Error(line, column, "bounded array elements must be inline scalar or user values");
            }
            return _types.GetOrAddBoundedArray(elementType, capacity);
        }
        if (typeName.Length >= 5 && typeName[0] == '{' && typeName[^1] == '}')
        {
            var separator = typeName.IndexOf(':', StringComparison.Ordinal);
            if (separator > 1)
            {
                var keyName = typeName[1..separator].Trim();
                var dictionaryBoundedSeparator = typeName.LastIndexOf("; <=", StringComparison.Ordinal);
                var valueEnd = dictionaryBoundedSeparator > separator ? dictionaryBoundedSeparator : typeName.Length - 1;
                var valueName = typeName[(separator + 1)..valueEnd].Trim();
                var keyType = ParseType(keyName, line, column);
                var valueType = ParseType(valueName, line, column);
                if (!IsSupportedDictionaryKeyType(keyType))
                {
                    throw Error(line, column,
                        $"dictionary key type {FormatType(keyType)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
                }
                if (dictionaryBoundedSeparator > separator)
                {
                    var capacityText = typeName[(dictionaryBoundedSeparator + 4)..^1].Trim();
                    if (!int.TryParse(capacityText, out var capacity) || capacity <= 0)
                    {
                        throw Error(line, column, "bounded dictionary capacity must be a positive integer literal");
                    }
                    return _types.GetOrAddBoundedDictionary(keyType, valueType, capacity);
                }
                return keyType == BoundType.Int && valueType == BoundType.Int
                    ? BoundType.IntDictionary
                    : _types.GetOrAddDictionary(keyType, valueType);
            }
        }
        if (!_types.TryResolve(typeName, out var type))
        {
            throw Error(line, column, $"unknown type '{typeName}'");
        }

        EnsureTypeVisible(type, line, column);
        return type;
    }

    private BoundType ParseFunctionType(
        string typeName,
        string? genericParameterName,
        string? secondaryGenericParameterName,
        string? tertiaryGenericParameterName,
        int line,
        int column,
        IReadOnlyList<string>? genericParameterNames = null)
    {
        if (genericParameterNames is not null)
        {
            var genericIndex = -1;
            for (var index = 0; index < genericParameterNames.Count; index++)
            {
                if (typeName == genericParameterNames[index])
                {
                    genericIndex = index;
                    break;
                }
            }
            if (genericIndex >= 0)
            {
                return (BoundType)((int)BoundType.GenericParameter + genericIndex);
            }
        }
        if (genericParameterName is not null && typeName == genericParameterName)
        {
            return BoundType.GenericParameter;
        }
        if (secondaryGenericParameterName is not null && typeName == secondaryGenericParameterName)
        {
            return BoundType.SecondaryGenericParameter;
        }
        if (tertiaryGenericParameterName is not null && typeName == tertiaryGenericParameterName)
        {
            return BoundType.TertiaryGenericParameter;
        }
        if (genericParameterName is not null && typeName == $"[Int; {genericParameterName}]")
        {
            return BoundType.IntSlice;
        }
        if (typeName.StartsWith('(') && typeName.EndsWith(')'))
        {
            return ParseProductType(
                typeName,
                field => ParseFunctionType(field, genericParameterName,
                    secondaryGenericParameterName, tertiaryGenericParameterName,
                    line, column, genericParameterNames),
                line,
                column);
        }
        if (typeName.StartsWith("Option<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var value = ParseFunctionType(typeName[7..^1].Trim(), genericParameterName,
                secondaryGenericParameterName, tertiaryGenericParameterName, line, column, genericParameterNames);
            return _types.GetOrAddOption(value, $"Option<{FormatType(value)}>");
        }
        if (typeName.StartsWith("Result<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var arguments = typeName[7..^1];
            var separator = FindTopLevelTypeComma(arguments);
            if (separator < 0)
            {
                throw Error(line, column, "Result requires success and error types");
            }
            var ok = ParseFunctionType(arguments[..separator].Trim(), genericParameterName,
                secondaryGenericParameterName, tertiaryGenericParameterName, line, column, genericParameterNames);
            var error = ParseFunctionType(arguments[(separator + 1)..].Trim(), genericParameterName,
                secondaryGenericParameterName, tertiaryGenericParameterName, line, column, genericParameterNames);
            return _types.GetOrAddResult(ok, error, $"Result<{FormatType(ok)}, {FormatType(error)}>");
        }

        return ParseType(typeName, line, column);
    }

    private BoundType ParseSpecializedFunctionType(
        string typeName,
        IReadOnlyDictionary<string, BoundType> specializedTypes,
        int line,
        int column)
    {
        typeName = typeName.Trim();
        if (specializedTypes.TryGetValue(typeName, out var specialized))
        {
            return specialized;
        }
        if (typeName.StartsWith('(') && typeName.EndsWith(')'))
        {
            return ParseProductType(
                typeName,
                field => ParseSpecializedFunctionType(field, specializedTypes, line, column),
                line,
                column);
        }
        if (typeName.StartsWith("Option<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var value = ParseSpecializedFunctionType(typeName[7..^1], specializedTypes, line, column);
            return _types.GetOrAddOption(value, $"Option<{FormatType(value)}>");
        }
        if (typeName.StartsWith("Result<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var arguments = typeName[7..^1];
            var separator = FindTopLevelTypeComma(arguments);
            if (separator < 0) throw Error(line, column, "Result requires success and error types");
            var ok = ParseSpecializedFunctionType(arguments[..separator], specializedTypes, line, column);
            var error = ParseSpecializedFunctionType(arguments[(separator + 1)..], specializedTypes, line, column);
            return _types.GetOrAddResult(ok, error, $"Result<{FormatType(ok)}, {FormatType(error)}>");
        }
        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith("; ~]", StringComparison.Ordinal))
        {
            var element = ParseSpecializedFunctionType(typeName[1..^4], specializedTypes, line, column);
            if (element == BoundType.Unit || IsNestedContainerElementType(element))
                throw Error(line, column, "growable array elements must be inline scalar or user values");
            return element == BoundType.Int
                ? BoundType.DynamicIntArray
                : _types.GetOrAddDynamicArray(element);
        }
        if (typeName.Length >= 5 && typeName[0] == '{' && typeName[^1] == '}')
        {
            var contents = typeName[1..^1];
            var separator = FindTopLevelTypeColon(contents);
            if (separator >= 0)
            {
                var key = ParseSpecializedFunctionType(contents[..separator], specializedTypes, line, column);
                var value = ParseSpecializedFunctionType(contents[(separator + 1)..], specializedTypes, line, column);
                if (!IsSupportedDictionaryKeyType(key))
                    throw Error(line, column,
                        $"dictionary key type {FormatType(key)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
                return key == BoundType.Int && value == BoundType.Int
                    ? BoundType.IntDictionary
                    : _types.GetOrAddDictionary(key, value);
            }
        }
        return ParseType(typeName, line, column);
    }

    private BoundType ParseSpecializedFunctionType(
        string typeName,
        string? genericParameterName,
        BoundType primaryType,
        string? secondaryGenericParameterName,
        BoundType? secondaryType,
        string? tertiaryGenericParameterName,
        BoundType? tertiaryType,
        int line,
        int column)
    {
        typeName = typeName.Trim();
        if (genericParameterName is not null && typeName == genericParameterName)
        {
            return primaryType;
        }
        if (secondaryGenericParameterName is not null && typeName == secondaryGenericParameterName)
        {
            return secondaryType ?? throw Error(
                line,
                column,
                $"cannot infer type parameter '{secondaryGenericParameterName}'");
        }
        if (tertiaryGenericParameterName is not null && typeName == tertiaryGenericParameterName)
        {
            return tertiaryType ?? throw Error(
                line,
                column,
                $"cannot infer type parameter '{tertiaryGenericParameterName}'");
        }
        if (typeName.StartsWith('(') && typeName.EndsWith(')'))
        {
            return ParseProductType(
                typeName,
                field => ParseSpecializedFunctionType(
                    field, genericParameterName, primaryType,
                    secondaryGenericParameterName, secondaryType,
                    tertiaryGenericParameterName, tertiaryType, line, column),
                line,
                column);
        }
        if (typeName.StartsWith("Option<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var value = ParseSpecializedFunctionType(
                typeName[7..^1], genericParameterName, primaryType,
                secondaryGenericParameterName, secondaryType,
                tertiaryGenericParameterName, tertiaryType, line, column);
            return _types.GetOrAddOption(value, $"Option<{FormatType(value)}>");
        }
        if (typeName.StartsWith("Result<", StringComparison.Ordinal) && typeName.EndsWith('>'))
        {
            var arguments = typeName[7..^1];
            var separator = FindTopLevelTypeComma(arguments);
            if (separator < 0)
            {
                throw Error(line, column, "Result requires success and error types");
            }
            var ok = ParseSpecializedFunctionType(
                arguments[..separator], genericParameterName, primaryType,
                secondaryGenericParameterName, secondaryType,
                tertiaryGenericParameterName, tertiaryType, line, column);
            var error = ParseSpecializedFunctionType(
                arguments[(separator + 1)..], genericParameterName, primaryType,
                secondaryGenericParameterName, secondaryType,
                tertiaryGenericParameterName, tertiaryType, line, column);
            return _types.GetOrAddResult(ok, error, $"Result<{FormatType(ok)}, {FormatType(error)}>");
        }
        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith("; ~]", StringComparison.Ordinal))
        {
            var element = ParseSpecializedFunctionType(
                typeName[1..^4], genericParameterName, primaryType,
                secondaryGenericParameterName, secondaryType,
                tertiaryGenericParameterName, tertiaryType, line, column);
            if (element == BoundType.Unit || IsNestedContainerElementType(element))
            {
                throw Error(line, column, "growable array elements must be inline scalar or user values");
            }
            return element == BoundType.Int
                ? BoundType.DynamicIntArray
                : _types.GetOrAddDynamicArray(element);
        }
        if (typeName.Length >= 5 && typeName[0] == '{' && typeName[^1] == '}')
        {
            var separator = FindTopLevelTypeColon(typeName.AsSpan(1, typeName.Length - 2));
            if (separator >= 0)
            {
                var contents = typeName[1..^1];
                var key = ParseSpecializedFunctionType(
                    contents[..separator], genericParameterName, primaryType,
                    secondaryGenericParameterName, secondaryType,
                    tertiaryGenericParameterName, tertiaryType, line, column);
                var value = ParseSpecializedFunctionType(
                    contents[(separator + 1)..], genericParameterName, primaryType,
                    secondaryGenericParameterName, secondaryType,
                    tertiaryGenericParameterName, tertiaryType, line, column);
                if (!IsSupportedDictionaryKeyType(key))
                {
                    throw Error(line, column,
                        $"dictionary key type {FormatType(key)} must implement Hash.hash: self -> Int and Eq.eq: self -> Int");
                }
                return key == BoundType.Int && value == BoundType.Int
                    ? BoundType.IntDictionary
                    : _types.GetOrAddDictionary(key, value);
            }
        }
        return ParseType(typeName, line, column);
    }

    private BoundType ParseProductType(
        string typeName,
        Func<string, BoundType> parseFieldType,
        int line,
        int column)
    {
        var contents = typeName[1..^1];
        var parts = SplitTopLevelProductFields(contents);
        if (parts.Count < 2)
        {
            throw Error(line, column, "product types require at least two fields");
        }

        var labels = new HashSet<string>(StringComparer.Ordinal);
        var fields = new List<(string? Label, BoundType Type)>(parts.Count);
        foreach (var part in parts)
        {
            var separator = FindTopLevelTypeColon(part.AsSpan());
            string? label = null;
            var fieldText = part;
            if (separator >= 0)
            {
                label = part[..separator].Trim();
                fieldText = part[(separator + 1)..].Trim();
                if (label.Length == 0 || !labels.Add(label))
                {
                    throw Error(line, column, $"duplicate or empty product field label '{label}'");
                }
            }
            fields.Add((label, parseFieldType(fieldText)));
        }

        var displayName = "(" + string.Join(", ", fields.Select(field =>
            field.Label is null
                ? FormatType(field.Type)
                : field.Label + ": " + FormatType(field.Type))) + ")";
        return _types.GetOrAddProduct(fields, displayName, line, column);
    }

    private static IReadOnlyList<string> SplitTopLevelProductFields(string text)
    {
        var fields = new List<string>();
        var start = 0;
        var angleDepth = 0;
        var squareDepth = 0;
        var braceDepth = 0;
        var parenDepth = 0;
        for (var index = 0; index < text.Length; index++)
        {
            switch (text[index])
            {
                case '<': angleDepth++; break;
                case '>': angleDepth--; break;
                case '[': squareDepth++; break;
                case ']': squareDepth--; break;
                case '{': braceDepth++; break;
                case '}': braceDepth--; break;
                case '(': parenDepth++; break;
                case ')': parenDepth--; break;
                case ',' when angleDepth == 0 && squareDepth == 0 && braceDepth == 0 && parenDepth == 0:
                    var field = text[start..index].Trim();
                    if (field.Length != 0) fields.Add(field);
                    start = index + 1;
                    break;
            }
        }
        var last = text[start..].Trim();
        if (last.Length != 0) fields.Add(last);
        return fields;
    }

    private static int FindTopLevelTypeColon(ReadOnlySpan<char> text)
    {
        var depth = 0;
        for (var index = 0; index < text.Length; index++)
        {
            depth += text[index] switch
            {
                '[' or '{' or '<' => 1,
                ']' or '}' or '>' => -1,
                _ => 0
            };
            if (text[index] == ':' && depth == 0)
            {
                return index;
            }
        }
        return -1;
    }

    private static bool TypeSyntaxReferencesParameter(string typeName, string? parameterName)
    {
        if (parameterName is null)
        {
            return false;
        }
        for (var index = 0; index <= typeName.Length - parameterName.Length; index++)
        {
            if (!typeName.AsSpan(index, parameterName.Length).SequenceEqual(parameterName))
            {
                continue;
            }
            var startsIdentifier = index > 0
                && (char.IsLetterOrDigit(typeName[index - 1]) || typeName[index - 1] == '_');
            var endsIdentifier = index + parameterName.Length < typeName.Length
                && (char.IsLetterOrDigit(typeName[index + parameterName.Length])
                    || typeName[index + parameterName.Length] == '_');
            if (!startsIdentifier && !endsIdentifier)
            {
                return true;
            }
        }
        return false;
    }

    private static bool TypeSyntaxReferencesAnyParameter(
        string typeName,
        IReadOnlyList<string> parameterNames)
        => parameterNames.Any(parameter => TypeSyntaxReferencesParameter(typeName, parameter));

    private static int FindTopLevelTypeComma(string text)
    {
        var depth = 0;
        for (var index = 0; index < text.Length; index++)
        {
            depth += text[index] switch
            {
                '[' or '{' or '<' => 1,
                ']' or '}' or '>' => -1,
                _ => 0
            };
            if (text[index] == ',' && depth == 0)
            {
                return index;
            }
        }
        return -1;
    }

    private string FormatType(BoundType type)
    {
        if (_types.IsBitSet(type))
        {
            return $"BitSet<{_types.GetBitSet(type).BitCount}>";
        }
        if (_types.IsBinaryHeap(type))
        {
            return $"BinaryHeap<{FormatType(_types.GetBinaryHeapElement(type))}>";
        }
        if (_types.IsDeque(type))
        {
            return $"Deque<{FormatType(_types.GetDequeElement(type))}>";
        }
        if (_types.IsSet(type))
        {
            return $"Set<{FormatType(_types.GetSetElement(type))}>";
        }
        if (_types.IsDynTrait(type))
        {
            return "dyn " + _types.GetDynTrait(type).TraitName;
        }
        if (_types.IsReference(type))
        {
            return "ref " + FormatType(_types.GetReference(type).ElementType);
        }
        if (_types.IsSlice(type))
        {
            return $"[{FormatType(_types.GetSliceElement(type))}]";
        }
        if (_types.TryGetOptionValue(type, out var optionValue))
        {
            return $"Option<{FormatType(optionValue)}>";
        }
        if (_types.TryGetResultTypes(type, out var resultTypes))
        {
            return $"Result<{FormatType(resultTypes.Ok)}, {FormatType(resultTypes.Error)}>";
        }
        if (_types.IsStruct(type))
        {
            return _types.GetStruct(type).Name;
        }

        if (_types.IsEnum(type))
        {
            return _types.GetEnum(type).Name;
        }
        if (_types.IsBox(type))
        {
            return "box " + FormatType(_types.GetBox(type).ElementType);
        }
        if (_types.IsStaticArray(type))
        {
            var definition = _types.GetStaticArray(type);
            return definition.FixedLength is { } length
                ? $"[{FormatType(definition.ElementType)}; {length}]"
                : $"[{FormatType(definition.ElementType)}; N]";
        }
        if (_types.IsDynamicArray(type))
        {
            return $"[{FormatType(_types.GetDynamicArray(type).ElementType)}; ~]";
        }
        if (_types.IsBoundedArray(type))
        {
            var bounded = _types.GetBoundedArray(type);
            return $"[{FormatType(bounded.ElementType)}; <={bounded.Capacity}]";
        }
        if (_types.IsDictionary(type))
        {
            if (_types.IsBoundedDictionary(type))
            {
                var bounded = _types.GetBoundedDictionary(type);
                return $"{{{FormatType(bounded.KeyType)}: {FormatType(bounded.ValueType)}; <={bounded.MaxEntries}}}";
            }
            var dictionary = _types.GetDictionary(type);
            return $"{{{FormatType(dictionary.KeyType)}: {FormatType(dictionary.ValueType)}}}";
        }
        if (_types.TryGetTaskValue(type, out var taskValue))
        {
            return $"Task<{FormatType(taskValue)}>";
        }
        if (_types.TryGetStreamValue(type, out var streamValue))
        {
            return $"Stream<{FormatType(streamValue)}>";
        }
        if (_types.TryGetEventStreamValue(type, out var eventStreamValue))
        {
            return $"EventStream<{FormatType(eventStreamValue)}>";
        }

        return type switch
        {
            BoundType.Unit => "Unit",
            BoundType.Text => "Text",
            BoundType.Int => "Int",
            BoundType.Int8 => "Int8",
            BoundType.Int16 => "Int16",
            BoundType.Int64 => "Long",
            BoundType.UInt8 => "UInt8",
            BoundType.UInt16 => "UInt16",
            BoundType.UInt32 => "UInt32",
            BoundType.UInt64 => "UInt64",
            BoundType.Size => "Size",
            BoundType.UIntSize => "UIntSize",
            BoundType.CodePoint => "CodePoint",
            BoundType.Arena => "Arena",
            BoundType.SourceText => "SourceText",
            BoundType.Arguments => "Arguments",
            BoundType.MappedBytes => "MappedBytes",
            BoundType.MutableMappedBytes => "MutableMappedBytes",
            BoundType.Float32 => "Float",
            BoundType.Float64 => "Double",
            BoundType.Bool => "Bool",
            BoundType.IntSlice => "[Int]",
            BoundType.StaticIntArray => "[Int; N]",
            BoundType.StaticTextArray => "[Text; N]",
            BoundType.DynamicIntArray => "[Int; ~]",
            BoundType.IntDictionaryView => "{Int: Int}",
            BoundType.IntDictionary => "{Int: Int}",
            BoundType.GenericParameter => "generic parameter",
            BoundType.SecondaryGenericParameter => "secondary generic parameter",
            BoundType.TertiaryGenericParameter => "tertiary generic parameter",
            _ => type.ToString()
        };
    }

    private bool IsContainerType(BoundType type)
    {
        if (_types.IsReference(type))
        {
            return false;
        }

        return type is BoundType.StaticIntArray or BoundType.StaticTextArray or BoundType.DynamicIntArray or BoundType.IntDictionary
            || _types.IsStaticArray(type)
            || _types.IsDynamicArray(type)
            || _types.IsBoundedArray(type)
            || _types.IsDictionary(type)
            || _types.ContainsOwnedStorage(type);
    }

    private bool IsNestedContainerElementType(BoundType type)
    {
        return type is BoundType.IntSlice
            or BoundType.StaticIntArray
            or BoundType.StaticTextArray
            or BoundType.DynamicIntArray
            or BoundType.IntDictionaryView
            or BoundType.IntDictionary
            || _types.IsStaticArray(type)
            || _types.IsDynamicArray(type)
            || _types.IsBoundedArray(type)
            || _types.IsDictionary(type);
    }

    private bool IsSupportedDictionaryKeyType(BoundType type)
    {
        if (IsIntegerType(type) || type == BoundType.Text)
        {
            return true;
        }
        if (!_types.IsStruct(type) && !_types.IsEnum(type))
        {
            return false;
        }
        return HasDictionaryKeyTrait(type, "Hash", "hash")
            && HasDictionaryKeyTrait(type, "Eq", "eq");
    }

    private bool HasDictionaryKeyTrait(BoundType type, string traitName, string methodName)
    {
        var definitionModule = _types.IsStruct(type)
            ? _types.GetStruct(type).ModuleName
            : _types.GetEnum(type).ModuleName;
        var typeName = _types.IsStruct(type)
            ? _types.GetStruct(type).Name
            : _types.GetEnum(type).Name;
        var moduleTraitName = definitionModule.Length == 0
            ? traitName
            : definitionModule + "." + traitName;
        return _program.Functions.Any(function =>
            (function.TraitName == traitName || function.TraitName == moduleTraitName)
            && function.InputType == typeName
            && function.Name.EndsWith('.' + methodName, StringComparison.Ordinal)
            && function.ReturnType == "Int"
            && function.InputOwnership == FunctionInputOwnership.Default);
    }

    private bool IsReadonlyIntViewCompatible(BoundType type)
    {
        return type is BoundType.IntSlice or BoundType.StaticIntArray or BoundType.DynamicIntArray;
    }

    private bool CanPassFunctionArgument(BoundType actualType, BoundType expectedType)
    {
        return actualType == expectedType
            || (_types.IsReference(expectedType)
                && actualType == _types.GetReference(expectedType).ElementType)
            || (expectedType == BoundType.IntSlice && IsReadonlyIntViewCompatible(actualType))
            || (_types.IsSlice(expectedType)
                && TryGetContextualArrayElementType(actualType, out var actualElementType)
                && actualElementType == _types.GetSliceElement(expectedType))
            || (_types.IsStaticArray(expectedType)
                && _types.IsStaticArray(actualType)
                && _types.GetStaticArray(actualType).ElementType == _types.GetStaticArray(expectedType).ElementType
                && (_types.GetStaticArray(expectedType).FixedLength is null
                    || _types.GetStaticArray(actualType).FixedLength == _types.GetStaticArray(expectedType).FixedLength))
            || (expectedType == BoundType.IntDictionaryView && actualType == BoundType.IntDictionary);
    }

    private bool IsFunctionReturnCompatible(
        Expression? expression,
        BoundType actualType,
        BoundType declaredType,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (actualType == declaredType)
        {
            return true;
        }
        if (actualType == BoundType.Unit
            && expression is not null
            && FunctionControlFlowFacts.AllPathsReturn(expression))
        {
            return true;
        }
        if (_types.IsSlice(declaredType)
            && TryGetContextualArrayElementType(actualType, out var actualElementType)
            && actualElementType == _types.GetSliceElement(declaredType))
        {
            return true;
        }
        if (expression is null || !_types.IsReference(declaredType))
        {
            return false;
        }
        var elementType = _types.GetReference(declaredType).ElementType;
        if (actualType != elementType)
        {
            return false;
        }
        var root = ReferencePlaceRoot(expression);
        return root is not null
            && bindings.TryGetValue(root, out var rootType)
            && _types.IsReference(rootType);
    }

    private static string? ReferencePlaceRoot(Expression expression) => expression switch
    {
        NameExpression name => name.Name,
        FieldAccessExpression field => ReferencePlaceRoot(field.Source),
        IndexExpression index => ReferencePlaceRoot(index.Source),
        _ => null
    };

    private void EnsureReferenceArgumentPlace(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlySet<string>? mutableBindings,
        string path)
    {
        var root = ReferencePlaceRoot(expression);
        if (root is null || !bindings.ContainsKey(root))
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"function '{path}' requires an addressable owner or reference; literals and temporary values cannot be borrowed");
        }
    }

    private static bool IsIntegerLiteralExpression(Expression expression) => expression switch
    {
        NumberExpression number => !number.Text.Contains('.', StringComparison.Ordinal)
            && !number.Text.Contains('e', StringComparison.OrdinalIgnoreCase),
        NegateExpression { Value: NumberExpression number } =>
            !number.Text.Contains('.', StringComparison.Ordinal)
            && !number.Text.Contains('e', StringComparison.OrdinalIgnoreCase),
        _ => false
    };

    private static bool IsNumericLiteralExpression(Expression expression) => expression is
        NumberExpression or NegateExpression { Value: NumberExpression };

    private void WarnRedundantNumericBinaryOperandTypes(
        Expression left,
        Expression right,
        BoundType operandType)
    {
        var leftConversion = IsExplicitNumericLiteralConversion(left, operandType);
        var rightConversion = IsExplicitNumericLiteralConversion(right, operandType);

        // A non-default numeric expression needs one independently typed operand
        // when no surrounding context supplies its width. Keep that anchor and
        // warn only for conversions whose type is already established elsewhere.
        if (leftConversion
            && !IsContextualNumericExpression(right)
            && !rightConversion)
        {
            WarnRedundantNumericType(left, operandType);
        }
        if (rightConversion && !IsContextualNumericExpression(left))
        {
            WarnRedundantNumericType(right, operandType);
        }
    }

    private bool IsExplicitNumericLiteralConversion(Expression expression, BoundType expectedType) =>
        expression is CallExpression { Path.Count: 1, Arguments.Count: 1 } conversion
        && _types.TryResolve(conversion.Path[0], out var targetType)
        && targetType == expectedType
        && IsNumericLiteralExpression(conversion.Arguments[0]);

    private void WarnRedundantNumericType(Expression expression, BoundType expectedType)
    {
        if (!IsNumericType(expectedType)
            || !IsExplicitNumericLiteralConversion(expression, expectedType)
            || expression is not CallExpression conversion)
        {
            return;
        }

        var literal = conversion.Arguments[0] switch
        {
            NumberExpression number => number.Text,
            NegateExpression { Value: NumberExpression number } => "-" + number.Text,
            _ => "numeric literal"
        };
        AddWarning(
            "S001",
            expression.Line,
            expression.Column,
            $"type '{FormatType(expectedType)}' is inferred here; replace '{conversion.Path[0]}({literal})' with '{literal}'");
    }

    private void AddWarning(string code, int line, int column, string message)
    {
        if (_warningLocations.Add((code, _currentModuleName, line, column)))
        {
            _warnings.Add(new SemanticWarning(code, _currentModuleName, line, column, message));
        }
    }

    private const int ControlConditionInlineLimit = 45;

    private static bool IsUnlessCondition(IfExpression expression)
    {
        return expression.Condition is NotExpression notExpression
            && notExpression.Line == expression.Line
            && notExpression.Column == expression.Column;
    }

    private static Expression UnwrapUnlessCondition(IfExpression expression)
    {
        return IsUnlessCondition(expression)
            ? ((NotExpression)expression.Condition).Value
            : expression.Condition;
    }

    private void NoteLongControlCondition(Expression condition, int controlLine, string role)
    {
        if (condition.Line != controlLine || ConditionSpansMultipleLines(condition))
        {
            return;
        }

        var length = EstimateControlConditionLength(condition);
        if (length < ControlConditionInlineLimit)
        {
            return;
        }

        var continuation = role is "when" or "partition"
            ? $"then write the {role} arm body on the next line"
            : $"then write '-> {role} {{' on the next line";
        AddWarning(
            "N001",
            condition.Line,
            condition.Column,
            $"control condition is {length} characters; keep conditions under {ControlConditionInlineLimit} on the same line as '{role}', or put the condition on its own line and {continuation}");
    }

    private static bool ConditionSpansMultipleLines(Expression expression)
    {
        var line = expression.Line;
        var spanned = false;
        WalkConditionLines(expression, visitedLine =>
        {
            if (visitedLine != line)
            {
                spanned = true;
            }
        });
        return spanned;
    }

    private static void WalkConditionLines(Expression expression, Action<int> visit)
    {
        visit(expression.Line);
        switch (expression)
        {
            case NotExpression notExpression:
                WalkConditionLines(notExpression.Value, visit);
                break;
            case NegateExpression negate:
                WalkConditionLines(negate.Value, visit);
                break;
            case AndExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case OrExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case AddExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case SubtractExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case MultiplyExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case DivideExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case ModuloExpression binary:
                WalkConditionLines(binary.Left, visit);
                WalkConditionLines(binary.Right, visit);
                break;
            case CompareExpression compare:
                WalkConditionLines(compare.Left, visit);
                WalkConditionLines(compare.Right, visit);
                break;
            case RangeExpression range:
                WalkConditionLines(range.Start, visit);
                WalkConditionLines(range.End, visit);
                break;
            case IndexExpression index:
                WalkConditionLines(index.Source, visit);
                WalkConditionLines(index.Index, visit);
                break;
            case FieldAccessExpression field:
                WalkConditionLines(field.Source, visit);
                break;
            case TryExpression tryExpression:
                WalkConditionLines(tryExpression.Value, visit);
                break;
            case BoxExpression box:
                WalkConditionLines(box.Value, visit);
                break;
            case CallExpression call:
                foreach (var argument in call.Arguments)
                {
                    WalkConditionLines(argument, visit);
                }
                break;
            case FlowExpression flow:
                WalkConditionLines(flow.Source, visit);
                foreach (var argument in flow.Targets.SelectMany(static target => target.Arguments))
                {
                    WalkConditionLines(argument, visit);
                }
                break;
            case TypeApplicationExpression typeApplication:
                foreach (var argument in typeApplication.Arguments ?? [])
                {
                    WalkConditionLines(argument, visit);
                }
                break;
        }
    }

    private static int EstimateControlConditionLength(Expression expression)
    {
        var text = new System.Text.StringBuilder();
        AppendControlCondition(text, expression, parentPrec: 0);
        return text.Length;
    }

    private static void AppendControlCondition(System.Text.StringBuilder text, Expression expression, int parentPrec)
    {
        switch (expression)
        {
            case BoolExpression boolean:
                text.Append(boolean.Value ? "true" : "false");
                break;
            case NumberExpression number:
                text.Append(number.Text);
                break;
            case NameExpression name:
                text.Append(name.Name);
                break;
            case NotExpression notExpression:
                text.Append("not ");
                AppendControlCondition(text, notExpression.Value, 5);
                break;
            case NegateExpression negate:
                text.Append('-');
                AppendControlCondition(text, negate.Value, 5);
                break;
            case AndExpression binary:
                AppendBinaryCondition(text, binary.Left, " and ", binary.Right, 2, parentPrec);
                break;
            case OrExpression binary:
                AppendBinaryCondition(text, binary.Left, " or ", binary.Right, 1, parentPrec);
                break;
            case AddExpression binary:
                AppendBinaryCondition(text, binary.Left, " + ", binary.Right, 3, parentPrec);
                break;
            case SubtractExpression binary:
                AppendBinaryCondition(text, binary.Left, " - ", binary.Right, 3, parentPrec);
                break;
            case MultiplyExpression binary:
                AppendBinaryCondition(text, binary.Left, " * ", binary.Right, 4, parentPrec);
                break;
            case DivideExpression binary:
                AppendBinaryCondition(text, binary.Left, " / ", binary.Right, 4, parentPrec);
                break;
            case ModuloExpression binary:
                AppendBinaryCondition(text, binary.Left, " % ", binary.Right, 4, parentPrec);
                break;
            case CompareExpression compare:
                AppendBinaryCondition(
                    text,
                    compare.Left,
                    compare.Operator switch
                    {
                        ComparisonOperator.Equal => " == ",
                        ComparisonOperator.NotEqual => " != ",
                        ComparisonOperator.Less => " < ",
                        ComparisonOperator.LessOrEqual => " <= ",
                        ComparisonOperator.Greater => " > ",
                        ComparisonOperator.GreaterOrEqual => " >= ",
                        _ => " ?? "
                    },
                    compare.Right,
                    2,
                    parentPrec);
                break;
            case FieldAccessExpression field:
                AppendControlCondition(text, field.Source, 6);
                text.Append('.').Append(field.FieldName);
                break;
            case IndexExpression index:
                AppendControlCondition(text, index.Source, 6);
                text.Append('[');
                AppendControlCondition(text, index.Index, 0);
                text.Append(']');
                break;
            case TryExpression tryExpression:
                AppendControlCondition(text, tryExpression.Value, 6);
                text.Append('?');
                break;
            case CallExpression call:
                text.Append(string.Join('.', call.Path)).Append('(');
                AppendConditionList(text, call.Arguments);
                text.Append(')');
                break;
            case FlowExpression flow:
                AppendControlCondition(text, flow.Source, 0);
                foreach (var target in flow.Targets)
                {
                    text.Append(" -> ").Append(string.Join('.', target.Path));
                    if (target.UsesCallSyntax || target.Arguments.Count > 0)
                    {
                        text.Append('(');
                        AppendConditionList(text, target.Arguments);
                        text.Append(')');
                    }
                }
                break;
            case TypeApplicationExpression typeApplication:
                text.Append(string.Join('.', typeApplication.Path))
                    .Append('<')
                    .Append(typeApplication.TypeArgument)
                    .Append(">(");
                AppendConditionList(text, typeApplication.Arguments ?? []);
                text.Append(')');
                break;
            default:
                text.Append("condition");
                break;
        }
    }

    private static void AppendBinaryCondition(
        System.Text.StringBuilder text,
        Expression left,
        string op,
        Expression right,
        int prec,
        int parentPrec)
    {
        if (prec < parentPrec)
        {
            text.Append('(');
        }
        AppendControlCondition(text, left, prec);
        text.Append(op);
        AppendControlCondition(text, right, prec);
        if (prec < parentPrec)
        {
            text.Append(')');
        }
    }

    private static void AppendConditionList(System.Text.StringBuilder text, IReadOnlyList<Expression> arguments)
    {
        for (var index = 0; index < arguments.Count; index++)
        {
            if (index > 0)
            {
                text.Append(", ");
            }
            AppendControlCondition(text, arguments[index], 0);
        }
    }

    private void RegisterMutableBinding(string name, int line, int column)
    {
        if (_currentMutableDeclarations is null || _currentMutableDeclarationsByName is null)
        {
            return;
        }
        var declaration = new MutableBindingDeclaration(name, line, column);
        _currentMutableDeclarations.Add(declaration);
        _currentMutableDeclarationsByName[name.TrimEnd('!')] = declaration;
    }

    private void MarkMutableBindingMutation(string name)
    {
        if (_currentMutableDeclarationsByName?.TryGetValue(name.TrimEnd('!'), out var declaration) == true)
        {
            declaration.IsMutated = true;
        }
    }

    private void WarnUnusedMutableBindings()
    {
        if (_currentMutableDeclarations is null)
        {
            return;
        }
        foreach (var declaration in _currentMutableDeclarations)
        {
            if (declaration.IsMutated)
            {
                continue;
            }
            var immutableName = declaration.Name.EndsWith('!')
                ? declaration.Name[..^1]
                : declaration.Name;
            if (IsReservedName(immutableName))
            {
                AddWarning(
                    "S005",
                    declaration.Line,
                    declaration.Column,
                    $"binding '{declaration.Name}' is never mutated, but '{immutableName}' is reserved; rename it to a non-reserved immutable binding");
                continue;
            }
            AddWarning(
                "S002",
                declaration.Line,
                declaration.Column,
                $"binding '{declaration.Name}' is never mutated; remove '!' to make it immutable");
        }
    }

    private void RegisterFixedLengthArrayCandidate(BindingStatement binding, BoundType valueType)
    {
        if (_currentFixedLengthArrayCandidates is null || !_types.IsDynamicArray(valueType))
        {
            return;
        }
        var initialLength = binding.Value switch
        {
            TypedEmptyArrayExpression { BoundedCapacity: null } => 0,
            ArrayLiteralExpression { IsDynamic: true } array => array.Elements.Count,
            _ => -1
        };
        if (initialLength >= 0)
        {
            _currentFixedLengthArrayCandidates.TryAdd(
                binding.Name,
                new FixedLengthArrayCandidate(binding.Name, binding.Line, binding.Column, initialLength));
        }
    }

    private void RecordContainerOperation(string name, string operation)
    {
        var candidates = _currentFixedLengthArrayCandidates;
        if (candidates is null || !candidates.TryGetValue(name, out var candidate))
        {
            return;
        }
        if (operation == "reserve")
        {
            return;
        }
        if (operation == "push" && _loopDepth == 0 && _conditionalDepth == 0)
        {
            candidate.Length++;
            return;
        }
        candidate.IsLengthUnknown = true;
    }

    private void WarnFixedLengthGrowableArrays()
    {
        if (_currentFixedLengthArrayCandidates is null)
        {
            return;
        }
        foreach (var candidate in _currentFixedLengthArrayCandidates.Values)
        {
            if (candidate.IsLengthUnknown || candidate.RequiresGrowableType || candidate.Length == 0)
            {
                continue;
            }
            AddWarning(
                "S003",
                candidate.Line,
                candidate.Column,
                $"growable array '{candidate.Name}' has a fixed length of {candidate.Length}; use a fixed array value");
        }
    }

    private void MarkFixedLengthCandidateRequiresGrowable(
        Expression expression,
        BoundType? expectedType,
        BoundType actualType)
    {
        var candidates = _currentFixedLengthArrayCandidates;
        var requiredType = expectedType;
        if (requiredType is { } referenceType && _types.IsReference(referenceType))
        {
            requiredType = _types.GetReference(referenceType).ElementType;
        }
        if (expression is not NameExpression name
            || requiredType is null
            || (!_types.IsDynamicArray(requiredType.Value) && !_types.IsBoundedArray(requiredType.Value))
            || (!_types.IsDynamicArray(actualType) && !_types.IsBoundedArray(actualType))
            || candidates is null
            || !candidates.TryGetValue(name.Name, out var candidate))
        {
            return;
        }
        candidate.RequiresGrowableType = true;
    }

    private void MarkFixedLengthCandidateRequiresGrowableOperation(Expression expression)
    {
        if (expression is NameExpression name
            && _currentFixedLengthArrayCandidates?.TryGetValue(name.Name, out var candidate) == true)
        {
            candidate.RequiresGrowableType = true;
        }
    }

    private void ValidateMouseEventCapacityLiteral(Expression expression)
    {
        var negative = expression is NegateExpression;
        var number = expression switch
        {
            NumberExpression direct => direct,
            NegateExpression { Value: NumberExpression negated } => negated,
            _ => null
        };
        if (number is null
            || number.Text.Contains('.', StringComparison.Ordinal)
            || number.Text.Contains('e', StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var text = negative ? "-" + number.Text : number.Text;
        var capacity = BigInteger.Parse(text, CultureInfo.InvariantCulture);
        if (capacity < 2 || capacity > 65536)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"mouse event capacity must be between 2 and 65536 but received {text}");
        }
    }

    private bool IsOwnedHeapType(BoundType type)
    {
        return _types.ContainsOwnedStorage(type);
    }

    private bool IsFileType(BoundType type)
    {
        return IsNamedStructType(type, "sys.file.File");
    }

    private bool IsFileWriterType(BoundType type) =>
        IsNamedStructType(type, "sys.file.FileWriter");

    private bool IsNamedStructType(BoundType type, string name) =>
        _types.IsStruct(type)
        && string.Equals(_types.GetStruct(type).Name, name, StringComparison.Ordinal);

    private bool IsAsyncResultTypeSupported(BoundType type)
    {
        return type == BoundType.Unit || IsAsyncValueTypeSupported(type);
    }

    private bool IsAsyncInputTypeSupported(
        BoundType? type,
        BoundFunctionInputOwnership ownership)
    {
        if (type is null)
        {
            return true;
        }

        if (ownership == BoundFunctionInputOwnership.MutableBorrow
            || !IsAsyncValueTypeSupported(type.Value))
        {
            return false;
        }

        return !_types.ContainsOwnedStorage(type.Value)
            || ownership == BoundFunctionInputOwnership.Move;
    }

    private bool IsAsyncValueTypeSupported(BoundType type)
    {
        return IsValueTypeSupported(type, allowSharedSourceText: false, []);
    }

    private bool IsParallelSharedTypeSupported(BoundType type)
    {
        return IsValueTypeSupported(type, allowSharedSourceText: true, []);
    }

    private bool IsValueTypeSupported(
        BoundType type,
        bool allowSharedSourceText,
        HashSet<BoundType> visiting)
    {
        if (type is BoundType.Unit or BoundType.Text or BoundType.Bool
            or BoundType.DynamicIntArray or BoundType.IntDictionary
            || (allowSharedSourceText && type == BoundType.SourceText)
            || IsNumericType(type))
        {
            return true;
        }

        if (!visiting.Add(type))
        {
            return true;
        }

        try
        {
            if (_types.IsStruct(type))
            {
                return _types.GetStruct(type).Fields.All(
                    field => IsValueTypeSupported(field.Type, allowSharedSourceText, visiting));
            }
            if (_types.IsEnum(type))
            {
                return _types.GetEnum(type).Variants.All(
                    variant => variant.PayloadType is null
                        || IsValueTypeSupported(variant.PayloadType.Value, allowSharedSourceText, visiting));
            }
            if (_types.IsBox(type))
            {
                return IsValueTypeSupported(_types.GetBox(type).ElementType, allowSharedSourceText, visiting);
            }
            if (_types.IsReference(type))
            {
                return allowSharedSourceText
                    && IsValueTypeSupported(
                        _types.GetReference(type).ElementType,
                        allowSharedSourceText,
                        visiting);
            }
            if (_types.IsStaticArray(type))
            {
                return IsValueTypeSupported(_types.GetStaticArray(type).ElementType, allowSharedSourceText, visiting);
            }
            if (_types.IsDynamicArray(type))
            {
                return IsValueTypeSupported(_types.GetDynamicArray(type).ElementType, allowSharedSourceText, visiting);
            }
            if (_types.IsDictionary(type))
            {
                var dictionary = _types.GetDictionary(type);
                return IsValueTypeSupported(dictionary.KeyType, allowSharedSourceText, visiting)
                    && IsValueTypeSupported(dictionary.ValueType, allowSharedSourceText, visiting);
            }

            return false;
        }
        finally
        {
            visiting.Remove(type);
        }
    }

    private bool IsContainerCreationExpression(Expression expression)
    {
        return expression is ArrayLiteralExpression
            or ArrayRepeatExpression
            or TypedEmptyArrayExpression
            or DictionaryLiteralExpression
            or TypedEmptyDictionaryExpression
            or BoxExpression
            or MapExpression
            or StructLiteralExpression
            or FieldAccessExpression { Source: StructLiteralExpression }
            or FieldAccessExpression { Source: CallExpression }
            or FieldAccessExpression { Source: TypeApplicationExpression }
            or ProductExpression
            or BranchExpression
            or TapExpression
            or PartitionExpression
            or StreamJoinExpression
            or CallExpression
            or TryExpression
            or TypeApplicationExpression
            or FlowExpression
            or IfExpression
            or WhenExpression
            || IsPayloadlessEnumVariantCreationExpression(expression)
            || IsZeroArgumentFunctionCreationExpression(expression)
            || IsAssociatedOwnedCreationExpression(expression)
            || IsMoveConsumingContainerTransformExpression(expression);
    }

    private bool IsPayloadlessEnumVariantCreationExpression(Expression expression)
    {
        if (expression is not FieldAccessExpression
            {
                Source: NameExpression typeName,
                FieldName: var variantName
            }
            || !_types.TryResolve(typeName.Name, out var enumType)
            || !_types.IsEnum(enumType))
        {
            return false;
        }

        return _types.GetEnum(enumType).Variants.Any(variant =>
            variant.Name == variantName && variant.PayloadType is null);
    }

    private bool IsZeroArgumentFunctionCreationExpression(Expression expression)
    {
        if (_boundFunctions is null) return false;
        var functionName = expression switch
        {
            NameExpression name => name.Name,
            FieldAccessExpression { Source: NameExpression owner } field
                => owner.Name + "." + field.FieldName,
            _ => null
        };
        return functionName is not null
            && _boundFunctions.TryGetValue(functionName, out var function)
            && function.InputType is null
            && (IsOwnedHeapType(function.ReturnType) || function.IsAsync);
    }

    private bool IsAssociatedOwnedCreationExpression(Expression expression)
    {
        return expression is FieldAccessExpression
        {
            Source: NameExpression typeName
        } field
            && _types.TryResolve(typeName.Name, out var ownerType)
            && _types.IsStruct(ownerType)
            && _boundFunctions is not null
            && _boundFunctions.TryGetValue(typeName.Name + "." + field.FieldName, out var function)
            && function.InputType is null;
    }

    private bool IsOwnedHeapContainerCreationExpression(Expression expression)
    {
        return expression is ArrayLiteralExpression { IsDynamic: true }
            or TypedEmptyArrayExpression
            or DictionaryLiteralExpression
            or TypedEmptyDictionaryExpression
            or BoxExpression;
    }

    private bool IsAnonymousOwnedHeapContainerExpression(Expression expression)
    {
        return expression switch
        {
            NameExpression => false,
            FieldAccessExpression field => IsAnonymousOwnedHeapContainerExpression(field.Source),
            _ => true
        };
    }

    private bool IsMoveConsumingContainerTransformExpression(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction>? functions = null)
    {
        if (expression is not FlowExpression flow || flow.Targets.Count == 0)
        {
            return false;
        }

        var lastTarget = flow.Targets[^1];
        if (lastTarget.Path.Count != 1)
        {
            return false;
        }

        if (functions is not null && TryGetFunction(lastTarget.Path, functions, out _))
        {
            return false;
        }

        return lastTarget.Path[0] is "append" or "updated" or "await" or "cancel";
    }

    private string? GetMoveConsumingContainerSourceName(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction>? functions = null)
    {
        if (expression is EnumMatchExpression match)
        {
            return GetMoveConsumingContainerSourceName(match.Subject, functions);
        }

        if (!IsMoveConsumingContainerTransformExpression(expression, functions)
            || expression is not FlowExpression flow
            || flow.Source is not NameExpression name)
        {
            return null;
        }

        return name.Name;
    }

    private IReadOnlyList<string> GetOwnedAggregateLiteralSourceNames(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings,
        BoundType? inferredAggregateType = null)
    {
        var transferred = new List<string>();
        switch (expression)
        {
            case StructLiteralExpression structure
                when _types.TryResolve(structure.TypeName, out var structureType)
                     && _types.IsStruct(structureType):
                CollectOwnedLiteralSourceNames(structure, structureType, bindings, transferred);
                break;
            case ProductExpression product
                when (inferredAggregateType is { } productType && _types.IsProduct(productType))
                     || _productExpressionTypes.TryGetValue(product, out productType):
                CollectOwnedLiteralSourceNames(product, productType, bindings, transferred);
                break;
            case ArrayLiteralExpression { ElementType: { } elementTypeName } array
                when _types.TryResolve(elementTypeName, out var elementType):
                foreach (var element in array.Elements)
                {
                    CollectOwnedLiteralSourceNames(element, elementType, bindings, transferred);
                }
                break;
            case DictionaryLiteralExpression
                {
                    KeyType: { } keyTypeName,
                    ValueType: { } valueTypeName
                } dictionary
                when _types.TryResolve(keyTypeName, out var keyType)
                     && _types.TryResolve(valueTypeName, out var valueType):
                foreach (var entry in dictionary.Entries)
                {
                    CollectOwnedLiteralSourceNames(entry.Key, keyType, bindings, transferred);
                    CollectOwnedLiteralSourceNames(entry.Value, valueType, bindings, transferred);
                }
                break;
        }

        var duplicate = transferred
            .GroupBy(static name => name, StringComparer.Ordinal)
            .FirstOrDefault(static group => group.Count() > 1);
        if (duplicate is not null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"owned binding '{duplicate.Key}' cannot initialize more than one aggregate position");
        }
        return transferred;
    }

    private string? GetMoveConsumingOwnedFieldOwnerName(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (expression is not FieldAccessExpression { Source: NameExpression owner } field
            || !_currentMoveInputNames.Contains(owner.Name)
            || !bindings.TryGetValue(owner.Name, out var ownerType)
            || !_types.IsStruct(ownerType))
        {
            return null;
        }

        var fieldDefinition = _types.GetStruct(ownerType).Fields
            .FirstOrDefault(candidate => candidate.Name == field.FieldName);
        return fieldDefinition is not null && _types.ContainsOwnedStorage(fieldDefinition.Type)
            ? owner.Name
            : null;
    }

    private string? GetMoveConsumingOwnedFieldPlace(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        var ownerName = GetMoveConsumingOwnedFieldOwnerName(expression, bindings);
        return ownerName is not null && expression is FieldAccessExpression field
            ? $"{CanonicalBorrowOriginName(ownerName)}.{field.FieldName}"
            : null;
    }

    private void EnsureOwnedContainerCanLeaveBlock(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> outerBindings,
        IReadOnlyDictionary<string, BoundType> bodyBindings,
        string? allowedOwnedOuterResultName = null)
    {
        if (expression is NameExpression name)
        {
            EnsureBlockLocalOwner(
                name.Name,
                name.Line,
                name.Column,
                outerBindings,
                bodyBindings,
                allowedOwnedOuterResultName);
            return;
        }

        var movedSourceName = GetMoveConsumingContainerSourceName(expression);
        if (movedSourceName is not null)
        {
            EnsureBlockLocalOwner(
                movedSourceName,
                expression.Line,
                expression.Column,
                outerBindings,
                bodyBindings,
                allowedOwnedOuterResultName);
            return;
        }

        if (expression is ArrayLiteralExpression
            or ArrayRepeatExpression
            or TypedEmptyArrayExpression
            or DictionaryLiteralExpression
            or TypedEmptyDictionaryExpression
            or BoxExpression
            or StructLiteralExpression
            or FieldAccessExpression { Source: TypeApplicationExpression }
            or CallExpression
            or FlowExpression
            or StreamJoinExpression
            or IfExpression
            or WhenExpression
            or EnumMatchExpression)
        {
            return;
        }

        throw Error(
            expression.Line,
            expression.Column,
            "owned container block results must be created in that block or moved from a block-local owner");
    }

    private void EnsureBlockLocalOwner(
        string name,
        int line,
        int column,
        IReadOnlyDictionary<string, BoundType> outerBindings,
        IReadOnlyDictionary<string, BoundType> bodyBindings,
        string? allowedOwnedOuterResultName)
    {
        if (!bodyBindings.TryGetValue(name, out var type) || !IsContainerType(type))
        {
            throw Error(line, column, $"unknown owned container '{name}'");
        }

        if (outerBindings.ContainsKey(name)
            && !string.Equals(name, allowedOwnedOuterResultName, StringComparison.Ordinal))
        {
            throw Error(
                line,
                column,
                "owned container block results must move a block-local owner, not an owner from an outer scope");
        }
    }

    private void EnsureMutableContainerSource(
        Expression source,
        string operation,
        IReadOnlySet<string>? mutableBindings,
        bool allowProjection = false)
    {
        if (allowProjection
            && source is FieldAccessExpression { Source: NameExpression owner })
        {
            MarkMutableBindingMutation(owner.Name);
            if (mutableBindings is null || !mutableBindings.Contains(owner.Name))
            {
                throw Error(
                    source.Line,
                    source.Column,
                    $"{operation} requires a mutable owner binding; use '=> {owner.Name.TrimEnd('!')}!'");
            }
            RecordContainerOperation(owner.Name, operation);
            return;
        }

        if (source is not NameExpression name)
        {
            throw Error(
                source.Line,
                source.Column,
                $"{operation} requires a named mutable container binding");
        }

        MarkMutableBindingMutation(name.Name);
        if (mutableBindings is null || !mutableBindings.Contains(name.Name))
        {
            throw Error(
                source.Line,
                source.Column,
                $"{operation} requires a mutable owner binding; use '=> {name.Name.TrimEnd('!')}!'");
        }
        RecordContainerOperation(name.Name, operation);
    }

    private void EnsureMoveContainerSource(Expression source, string operation)
    {
        if (source is not NameExpression)
        {
            throw Error(
                source.Line,
                source.Column,
                $"{operation} requires a named container owner so ownership can move");
        }
    }

    private void EnsureOwnedParameterFlowSource(Expression source, string functionName)
    {
        if (source is not NameExpression && !IsContainerCreationExpression(source))
        {
            throw Error(
                source.Line,
                source.Column,
                $"function '{functionName}' consumes an owned container, so the flowed input must be a named owner");
        }
    }

    private void EnsureOwnedParameterCallArgument(Expression argument, string functionName)
    {
        if (argument is not NameExpression && !IsContainerCreationExpression(argument))
        {
            throw Error(
                argument.Line,
                argument.Column,
                $"function '{functionName}' consumes an owned container, so the argument must be a named owner");
        }
    }

    private void EnsureMutableBorrowFlowSource(
        Expression source,
        string functionName,
        IReadOnlySet<string>? mutableBindings)
    {
        var root = ReferencePlaceRoot(source);
        if (root is null)
        {
            throw Error(
                source.Line,
                source.Column,
                $"function '{functionName}' mutably borrows a container, so the flowed input must be a mutable owner place");
        }

        EnsureMutableBorrowName(root, source.Line, source.Column, functionName, mutableBindings);
    }

    private void EnsureMutableBorrowCallArgument(
        Expression argument,
        string functionName,
        IReadOnlySet<string>? mutableBindings)
    {
        var root = ReferencePlaceRoot(argument);
        if (root is null)
        {
            throw Error(
                argument.Line,
                argument.Column,
                $"function '{functionName}' mutably borrows a container, so the argument must be a mutable owner place");
        }

        EnsureMutableBorrowName(root, argument.Line, argument.Column, functionName, mutableBindings);
    }

    private void EnsureMutableBorrowName(
        string name,
        int line,
        int column,
        string functionName,
        IReadOnlySet<string>? mutableBindings)
    {
        if (mutableBindings is null || !mutableBindings.Contains(name))
        {
            throw Error(
                line,
                column,
                $"function '{functionName}' mutably borrows a container; use a mutable owner binding such as '{name.TrimEnd('!')}!'");
        }
        RejectBorrowedTextOriginMutation(name, line, column);
        MarkMutableBindingMutation(name);
        if (_currentFixedLengthArrayCandidates?.TryGetValue(name, out var candidate) == true)
        {
            candidate.IsLengthUnknown = true;
        }
    }

    private void EnsureReadonlyBorrowCallArgument(Expression argument, string functionName)
    {
        if (ReferencePlaceRoot(argument) is null && !IsContainerCreationExpression(argument))
        {
            throw Error(
                argument.Line,
                argument.Column,
                $"function '{functionName}' borrows a heap container for the call, so the argument must be a named owner");
        }
    }

    private IReadOnlyList<string> GetOwnedContainerMutationConsumedSourceNames(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (expression is not FlowExpression flow
            || flow.Source is not NameExpression containerName
            || !bindings.TryGetValue(containerName.Name, out var containerType))
        {
            return [];
        }

        var consumed = new List<string>();
        if (_types.IsDynamicArray(containerType) || _types.IsBoundedArray(containerType))
        {
            var elementType = _types.IsBoundedArray(containerType)
                ? _types.GetBoundedArray(containerType).ElementType
                : _types.GetDynamicArray(containerType).ElementType;
            foreach (var target in flow.Targets)
            {
                if (target.Path.Count == 1
                    && target.Path[0] == "push"
                    && target.Arguments.Count == 1)
                {
                    CollectOwnedLiteralSourceNames(target.Arguments[0], elementType, bindings, consumed);
                }
            }
        }
        else if (_types.IsDictionary(containerType))
        {
            var definition = _types.GetDictionary(containerType);
            foreach (var target in flow.Targets)
            {
                if (target.Path.Count == 1
                    && target.Path[0] is "put" or "putIfAbsent"
                    && target.Arguments.Count == 2)
                {
                    CollectOwnedLiteralSourceNames(target.Arguments[0], definition.KeyType, bindings, consumed);
                    CollectOwnedLiteralSourceNames(target.Arguments[1], definition.ValueType, bindings, consumed);
                }
            }
        }
        var duplicatedOwner = consumed
            .GroupBy(static name => name, StringComparer.Ordinal)
            .FirstOrDefault(static group => group.Count() > 1);
        if (duplicatedOwner is not null)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"owned value '{duplicatedOwner.Key}' cannot be transferred into a container more than once");
        }
        return consumed;
    }

    private void CollectOwnedLiteralSourceNames(
        Expression expression,
        BoundType expectedType,
        IReadOnlyDictionary<string, BoundType> bindings,
        List<string> consumed)
    {
        if (!_types.ContainsOwnedStorage(expectedType))
        {
            return;
        }
        if (expression is NameExpression name)
        {
            if (bindings.TryGetValue(name.Name, out var sourceType) && sourceType == expectedType)
            {
                consumed.Add(name.Name);
            }
            return;
        }
        if (expression is FieldAccessExpression
            {
                Source: NameExpression owner,
                FieldName: var fieldName
            }
            && bindings.TryGetValue(owner.Name, out var ownerType)
            && _types.IsStruct(ownerType)
            && _types.GetStruct(ownerType).Fields.FirstOrDefault(field =>
                string.Equals(field.Name, fieldName, StringComparison.Ordinal)) is { } sourceField
            && sourceField.Type == expectedType
            && _types.ContainsOwnedStorage(sourceField.Type))
        {
            consumed.Add(owner.Name);
            return;
        }
        if ((_types.IsDynamicArray(expectedType) || _types.IsBoundedArray(expectedType))
            && expression is ArrayLiteralExpression array)
        {
            var elementType = _types.IsBoundedArray(expectedType)
                ? _types.GetBoundedArray(expectedType).ElementType
                : _types.GetDynamicArray(expectedType).ElementType;
            foreach (var element in array.Elements)
            {
                CollectOwnedLiteralSourceNames(element, elementType, bindings, consumed);
            }
            return;
        }
        if (_types.IsDictionary(expectedType)
            && expression is DictionaryLiteralExpression dictionary)
        {
            var definition = _types.GetDictionary(expectedType);
            foreach (var entry in dictionary.Entries)
            {
                CollectOwnedLiteralSourceNames(entry.Key, definition.KeyType, bindings, consumed);
                CollectOwnedLiteralSourceNames(entry.Value, definition.ValueType, bindings, consumed);
            }
            return;
        }
        if (!_types.IsStruct(expectedType))
        {
            return;
        }

        var initializers = expression switch
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
            DictionaryLiteralExpression contextual => contextual.Entries
                .Where(static entry => entry.Key is NameExpression)
                .ToDictionary(
                    static entry => ((NameExpression)entry.Key).Name,
                    static entry => entry.Value,
                    StringComparer.Ordinal),
            _ => null
        };
        if (initializers is null)
        {
            return;
        }
        foreach (var field in _types.GetStruct(expectedType).Fields)
        {
            if (initializers.TryGetValue(field.Name, out var initializer))
            {
                CollectOwnedLiteralSourceNames(initializer, field.Type, bindings, consumed);
            }
        }
    }

    private IReadOnlyList<string> GetOwnedParameterConsumedSourceNames(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (expression is TryExpression { Value: NameExpression attemptedName }
            && _currentMoveInputNames.Contains(attemptedName.Name))
        {
            return [attemptedName.Name];
        }

        if (expression is TryExpression attempt)
        {
            return GetOwnedParameterConsumedSourceNames(attempt.Value, functions, bindings);
        }

        if (expression is CallExpression enumCall
            && TryGetOwnedEnumConstructorSourceName(enumCall, out var enumSourceName))
        {
            return [enumSourceName];
        }

        if (expression is CallExpression call
            && TryGetFunction(call.Path, functions, out var callFunction)
            && FunctionMovesOwnedHeapInput(callFunction)
            && call.Arguments.Count == 1
            && call.Arguments[0] is NameExpression argumentName)
        {
            return [argumentName.Name];
        }

        if (expression is FlowExpression flow)
        {
            var consumed = new List<string>();
            var sourceType = flow.Source is NameExpression typedSource
                && bindings.TryGetValue(typedSource.Name, out var resolvedSourceType)
                    ? resolvedSourceType
                    : (BoundType?)null;
            foreach (var target in flow.Targets)
            {
                if (_resolvedContainerFlowTargets.Contains(target))
                {
                    continue;
                }
                var path = string.Join('.', target.Path);
                if ((TryGetFunction(target.Path, functions, out var targetFunction)
                        || (sourceType is { } receiverType
                            && TryResolveInstanceMethod(receiverType, path, functions, out targetFunction)))
                    && FunctionMovesOwnedHeapInput(targetFunction)
                    && flow.Source is NameExpression sourceName)
                {
                    consumed.Add(sourceName.Name);
                }
            }

            return consumed;
        }

        if (expression is BranchExpression branch
            && branch.Source is NameExpression branchSource
            && bindings.TryGetValue(branchSource.Name, out var branchSourceType))
        {
            foreach (var target in branch.Arms.SelectMany(static arm => arm.Targets.Take(1)))
            {
                var path = string.Join('.', target.Path);
                if ((TryGetFunction(target.Path, functions, out var targetFunction)
                        || TryResolveInstanceMethod(branchSourceType, path, functions, out targetFunction))
                    && FunctionMovesOwnedHeapInput(targetFunction))
                {
                    return [branchSource.Name];
                }
            }
        }

        if (expression is PartitionExpression { Source: NameExpression partitionSource }
            && bindings.TryGetValue(partitionSource.Name, out var partitionSourceType)
            && (_types.IsStream(partitionSourceType) || _types.IsEventStream(partitionSourceType)))
        {
            return [partitionSource.Name];
        }

        if (expression is StreamJoinExpression { Source: NameExpression joinSource }
            && bindings.TryGetValue(joinSource.Name, out var joinSourceType)
            && _types.IsProduct(joinSourceType)
            && _types.ContainsOwnedStorage(joinSourceType))
        {
            return [joinSource.Name];
        }
        if (expression is StreamJoinExpression { Source: ProductExpression product })
        {
            return product.Elements
                .Select(static element => element.Value)
                .OfType<NameExpression>()
                .Where(name => bindings.TryGetValue(name.Name, out var inputType)
                    && (_types.IsStream(inputType) || _types.IsEventStream(inputType)))
                .Select(static name => name.Name)
                .Distinct(StringComparer.Ordinal)
                .ToArray();
        }

        if (expression is TapExpression { Source: NameExpression tapSource }
            && bindings.TryGetValue(tapSource.Name, out var tapSourceType)
            && _types.ContainsOwnedStorage(tapSourceType))
        {
            return [tapSource.Name];
        }

        if (expression is IfExpression or WhenExpression)
        {
            var consumed = new List<string>();
            foreach (var pair in bindings)
            {
                if (_types.ContainsOwnedStorage(pair.Value)
                    && GetMoveInputDisposition(expression, pair.Key, functions, isResult: false)
                    == MoveInputDisposition.Transferred)
                {
                    consumed.Add(pair.Key);
                }
            }
            return consumed;
        }

        return [];
    }

    private bool TryGetOwnedEnumConstructorSourceName(CallExpression expression, out string sourceName)
    {
        sourceName = "";
        if (expression.Path.Count < 2
            || expression.Arguments.Count != 1
            || expression.Arguments[0] is not NameExpression name)
        {
            return false;
        }
        var typeName = string.Join('.', expression.Path.Take(expression.Path.Count - 1));
        if (!_types.TryResolve(typeName, out var type) || !_types.IsEnum(type))
        {
            return false;
        }
        var variant = _types.GetEnum(type).Variants
            .FirstOrDefault(candidate => candidate.Name == expression.Path[^1]);
        if (variant?.PayloadType is not { } payloadType || !_types.ContainsOwnedStorage(payloadType))
        {
            return false;
        }
        sourceName = name.Name;
        return true;
    }

    private void EnsureMoveInputReturnCoverage(
        Expression expression,
        string inputName,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (GetMoveInputDisposition(expression, inputName, functions, isResult: true)
            == MoveInputDisposition.Mixed)
        {
            throw Error(
                expression.Line,
                expression.Column,
                $"move input '{inputName}' must be transferred on every return branch or on none of them");
        }
    }

    private MoveInputDisposition GetMoveInputDisposition(
        Expression expression,
        string inputName,
        IReadOnlyDictionary<string, BoundFunction> functions,
        bool isResult)
    {
        if (expression is TryExpression attempt)
        {
            return GetMoveInputDisposition(attempt.Value, inputName, functions, isResult);
        }

        if (isResult && expression is NameExpression name && name.Name == inputName)
        {
            return MoveInputDisposition.Transferred;
        }

        if (string.Equals(
            GetMoveConsumingContainerSourceName(expression, functions),
            inputName,
            StringComparison.Ordinal))
        {
            return MoveInputDisposition.Transferred;
        }

        if (expression is CallExpression call
            && TryGetFunction(call.Path, functions, out var callFunction)
            && FunctionMovesOwnedHeapInput(callFunction)
            && call.Arguments.Count == 1
            && call.Arguments[0] is NameExpression argumentName
            && argumentName.Name == inputName)
        {
            return MoveInputDisposition.Transferred;
        }

        if (expression is FlowExpression flow
            && flow.Source is NameExpression sourceName
            && sourceName.Name == inputName
            && flow.Targets.Any(target => IsOwnedParameterFlowTarget(target, functions)))
        {
            return MoveInputDisposition.Transferred;
        }

        if (expression is BranchExpression branch
            && branch.Source is NameExpression branchSource
            && branchSource.Name == inputName
            && branch.Arms.SelectMany(static arm => arm.Targets.Take(1)).Any(target =>
                TryGetFunction(target.Path, functions, out var targetFunction)
                && FunctionMovesOwnedHeapInput(targetFunction)))
        {
            return MoveInputDisposition.Transferred;
        }

        if (expression is IfExpression conditional)
        {
            return CombineAlternativeMoveInputDispositions(
                GetMoveInputDisposition(conditional.Then, inputName, functions),
                conditional.Else is null
                    ? MoveInputDisposition.Retained
                    : GetMoveInputDisposition(conditional.Else, inputName, functions));
        }

        if (expression is WhenExpression whenExpression)
        {
            var disposition = GetMoveInputDisposition(
                whenExpression.Else,
                inputName,
                functions);
            foreach (var arm in whenExpression.Arms)
            {
                disposition = CombineAlternativeMoveInputDispositions(
                    disposition,
                    GetMoveInputDisposition(arm.Body, inputName, functions));
            }

            return disposition;
        }

        return MoveInputDisposition.Retained;
    }

    private MoveInputDisposition GetMoveInputDisposition(
        BlockBody body,
        string inputName,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var disposition = MoveInputDisposition.Retained;
        foreach (var statement in body.Statements)
        {
            var expression = statement switch
            {
                BindingStatement binding => binding.Value,
                ReturnStatement { Value: { } value } => value,
                ExpressionStatement expressionStatement => expressionStatement.Expression,
                GuardLoopControlStatement guard => guard.Condition,
                _ => null
            };
            if (expression is null)
            {
                continue;
            }

            var statementDisposition = GetMoveInputDisposition(
                expression,
                inputName,
                functions,
                isResult: false);
            if (statementDisposition != MoveInputDisposition.Retained)
            {
                disposition = statementDisposition;
                break;
            }
        }

        if (disposition != MoveInputDisposition.Retained || body.Value is null)
        {
            return disposition;
        }

        return GetMoveInputDisposition(body.Value, inputName, functions, isResult: true);
    }

    private MoveInputDisposition CombineAlternativeMoveInputDispositions(
        MoveInputDisposition left,
        MoveInputDisposition right)
    {
        return left == right ? left : MoveInputDisposition.Mixed;
    }

    private void ValidateOwnedParameterConsumptionExpression(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (expression is TryExpression { Value: CallExpression attemptedCall }
            && IsOwnedParameterCall(attemptedCall, functions))
        {
            return;
        }

        if (expression is IfExpression conditional)
        {
            ValidateOwnedParameterConsumptionExpression(conditional.Condition, functions, bindings);
            ValidateAlternativeOwnedParameterConsumption(expression, functions, bindings);
            ValidateOwnedParameterConsumptionBlock(conditional.Then, functions, bindings);
            if (conditional.Else is not null)
            {
                ValidateOwnedParameterConsumptionBlock(conditional.Else, functions, bindings);
            }
            return;
        }

        if (expression is WhenExpression selection)
        {
            if (selection.Subject is not null)
            {
                ValidateOwnedParameterConsumptionExpression(selection.Subject, functions, bindings);
            }
            foreach (var arm in selection.Arms)
            {
                ValidateOwnedParameterConsumptionExpression(arm.Condition, functions, bindings);
                ValidateOwnedParameterConsumptionBlock(arm.Body, functions, bindings);
            }
            ValidateOwnedParameterConsumptionBlock(selection.Else, functions, bindings);
            ValidateAlternativeOwnedParameterConsumption(expression, functions, bindings);
            return;
        }

        if (expression is TryExpression attempt)
        {
            ValidateOwnedParameterConsumptionExpression(attempt.Value, functions, bindings);
            return;
        }

        if (expression is CallExpression call && IsOwnedParameterCall(call, functions))
        {
            return;
        }

        if (expression is FlowExpression flow)
        {
            if (ContainsOwnedParameterCall(flow.Source, functions)
                || flow.Targets.Any(target => target.Arguments.Any(argument => ContainsOwnedParameterCall(argument, functions))))
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    "owned container parameter calls must be direct calls or direct value-flow from a named owner");
            }

            if (flow.Targets.Any(target => IsOwnedParameterFlowTarget(target, functions)))
            {
                return;
            }
        }

        if (ContainsOwnedParameterCall(expression, functions))
        {
            throw Error(
                expression.Line,
                expression.Column,
                "owned container parameter calls must be direct calls or direct value-flow from a named owner");
        }
    }

    private void ValidateAlternativeOwnedParameterConsumption(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        foreach (var pair in bindings)
        {
            if (_types.ContainsOwnedStorage(pair.Value)
                && GetMoveInputDisposition(expression, pair.Key, functions, isResult: false)
                == MoveInputDisposition.Mixed)
            {
                throw Error(
                    expression.Line,
                    expression.Column,
                    $"owned binding '{pair.Key}' must be consumed on every control-flow branch or on none of them");
            }
        }
    }

    private void ValidateOwnedParameterConsumptionBlock(
        BlockBody body,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        foreach (var statement in body.Statements)
        {
            if (statement is BlockFunctionPipelineStatement pipeline)
            {
                foreach (var block in pipeline.Calls)
                {
                    ValidateOwnedParameterConsumptionExpression(block.Source, functions, bindings);
                }
                continue;
            }
            var nested = statement switch
            {
                BindingStatement binding => binding.Value,
                ReturnStatement { Value: { } value } => value,
                IndexAssignmentStatement assignment => assignment.Value,
                FieldAssignmentStatement assignment => assignment.Value,
                ExpressionStatement expressionStatement => expressionStatement.Expression,
                GuardLoopControlStatement guard => guard.Condition,
                BlockFunctionCallStatement block => block.Source,
                _ => null
            };
            if (nested is not null)
            {
                ValidateOwnedParameterConsumptionExpression(nested, functions, bindings);
            }
        }
        if (body.Value is not null)
        {
            ValidateOwnedParameterConsumptionExpression(body.Value, functions, bindings);
        }
    }

    private bool ContainsOwnedParameterCall(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        return expression switch
        {
            CallExpression call => IsOwnedParameterCall(call, functions)
                || call.Arguments.Any(argument => ContainsOwnedParameterCall(argument, functions)),
            FlowExpression flow => ContainsOwnedParameterCall(flow.Source, functions)
                || flow.Targets.Any(target =>
                    IsOwnedParameterFlowTarget(target, functions)
                    || target.Arguments.Any(argument => ContainsOwnedParameterCall(argument, functions))),
            StringExpression text => text.Segments
                .OfType<InterpolationSegment>()
                .Any(segment => ContainsOwnedParameterCall(segment.Expression, functions)),
            AddExpression add => ContainsOwnedParameterCall(add.Left, functions)
                || ContainsOwnedParameterCall(add.Right, functions),
            SubtractExpression subtract => ContainsOwnedParameterCall(subtract.Left, functions)
                || ContainsOwnedParameterCall(subtract.Right, functions),
            MultiplyExpression multiply => ContainsOwnedParameterCall(multiply.Left, functions)
                || ContainsOwnedParameterCall(multiply.Right, functions),
            DivideExpression divide => ContainsOwnedParameterCall(divide.Left, functions)
                || ContainsOwnedParameterCall(divide.Right, functions),
            ModuloExpression modulo => ContainsOwnedParameterCall(modulo.Left, functions)
                || ContainsOwnedParameterCall(modulo.Right, functions),
            NegateExpression negate => ContainsOwnedParameterCall(negate.Value, functions),
            CompareExpression compare => ContainsOwnedParameterCall(compare.Left, functions)
                || ContainsOwnedParameterCall(compare.Right, functions),
            AndExpression logicalAnd => ContainsOwnedParameterCall(logicalAnd.Left, functions)
                || ContainsOwnedParameterCall(logicalAnd.Right, functions),
            OrExpression logicalOr => ContainsOwnedParameterCall(logicalOr.Left, functions)
                || ContainsOwnedParameterCall(logicalOr.Right, functions),
            NotExpression logicalNot => ContainsOwnedParameterCall(logicalNot.Value, functions),
            TryExpression attempt => ContainsOwnedParameterCall(attempt.Value, functions),
            RangeExpression range => ContainsOwnedParameterCall(range.Start, functions)
                || ContainsOwnedParameterCall(range.End, functions),
            FoldExpression fold => ContainsOwnedParameterCall(fold.Source, functions)
                || ContainsOwnedParameterCall(fold.Initial, functions)
                || ContainsOwnedParameterCall(fold.Body, functions),
            IfExpression conditional => ContainsOwnedParameterCall(conditional.Condition, functions)
                || ContainsOwnedParameterCall(conditional.Then, functions)
                || (conditional.Else is not null && ContainsOwnedParameterCall(conditional.Else, functions)),
            WhenExpression whenExpression => (whenExpression.Subject is not null && ContainsOwnedParameterCall(whenExpression.Subject, functions))
                || whenExpression.Arms.Any(arm => ContainsOwnedParameterCall(arm.Condition, functions) || ContainsOwnedParameterCall(arm.Body, functions))
                || ContainsOwnedParameterCall(whenExpression.Else, functions),
            ArrayLiteralExpression array => array.Elements.Any(element => ContainsOwnedParameterCall(element, functions)),
            ArrayRepeatExpression repeat => ContainsOwnedParameterCall(repeat.Value, functions),
            DictionaryLiteralExpression dictionary => dictionary.Entries.Any(entry =>
                ContainsOwnedParameterCall(entry.Key, functions)
                || ContainsOwnedParameterCall(entry.Value, functions)),
            IndexExpression index => ContainsOwnedParameterCall(index.Source, functions)
                || ContainsOwnedParameterCall(index.Index, functions),
            SubjectCompareExpression compare => ContainsOwnedParameterCall(compare.Right, functions),
            SubjectRangeExpression range => ContainsOwnedParameterCall(range.Start, functions)
                || ContainsOwnedParameterCall(range.End, functions),
            _ => false
        };
    }

    private bool TypeContains(BoundType type, BoundType expected)
    {
        return TypeContains(type, expected, []);
    }

    private bool TypeContains(BoundType type, BoundType expected, HashSet<BoundType> visiting)
    {
        if (type == expected)
        {
            return true;
        }
        if (!visiting.Add(type))
        {
            return false;
        }

        bool result;
        if (_types.IsStaticArray(type))
        {
            result = TypeContains(_types.GetStaticArray(type).ElementType, expected, visiting);
        }
        else if (_types.IsDynamicArray(type))
        {
            result = TypeContains(_types.GetDynamicArray(type).ElementType, expected, visiting);
        }
        else if (_types.IsDictionary(type))
        {
            var dictionary = _types.GetDictionary(type);
            result = TypeContains(dictionary.KeyType, expected, visiting)
                || TypeContains(dictionary.ValueType, expected, visiting);
        }
        else if (_types.IsBox(type))
        {
            result = TypeContains(_types.GetBox(type).ElementType, expected, visiting);
        }
        else if (_types.IsReference(type))
        {
            result = TypeContains(_types.GetReference(type).ElementType, expected, visiting);
        }
        else if (_types.IsStruct(type))
        {
            result = _types.GetStruct(type).Fields.Any(field =>
                TypeContains(field.Type, expected, visiting));
        }
        else if (_types.IsEnum(type))
        {
            result = _types.GetEnum(type).Variants.Any(variant =>
                variant.PayloadType is { } payload
                && TypeContains(payload, expected, visiting));
        }
        else
        {
            result = false;
        }
        visiting.Remove(type);
        return result;
    }

    private static bool ContainsSliceFlow(Expression expression)
    {
        return expression switch
        {
            FlowExpression flow => flow.Targets.Any(target =>
                    target.Path.Count == 1 && target.Path[0] == "slice")
                || ContainsSliceFlow(flow.Source)
                || flow.Targets.Any(target => target.Arguments.Any(ContainsSliceFlow)),
            BranchExpression branch => branch.Arms.SelectMany(static arm => arm.Targets).Any(target =>
                    target.Path.Count == 1 && target.Path[0] == "slice")
                || ContainsSliceFlow(branch.Source)
                || branch.Arms.SelectMany(static arm => arm.Targets)
                    .Any(target => target.Arguments.Any(ContainsSliceFlow)),
            TapExpression tap => tap.Targets.Any(target =>
                    target.Path.Count == 1 && target.Path[0] == "slice")
                || ContainsSliceFlow(tap.Source)
                || tap.Targets.Any(target => target.Arguments.Any(ContainsSliceFlow)),
            PartitionExpression partition => ContainsSliceFlow(partition.Source)
                || partition.Arms.Any(arm => arm.Condition is not null && ContainsSliceFlow(arm.Condition)),
            StreamJoinExpression join => ContainsSliceFlow(join.Source),
            CallExpression call => call.Arguments.Any(ContainsSliceFlow),
            StringExpression text => text.Segments
                .OfType<InterpolationSegment>()
                .Any(segment => ContainsSliceFlow(segment.Expression)),
            AddExpression add => ContainsSliceFlow(add.Left) || ContainsSliceFlow(add.Right),
            SubtractExpression subtract => ContainsSliceFlow(subtract.Left) || ContainsSliceFlow(subtract.Right),
            MultiplyExpression multiply => ContainsSliceFlow(multiply.Left) || ContainsSliceFlow(multiply.Right),
            DivideExpression divide => ContainsSliceFlow(divide.Left) || ContainsSliceFlow(divide.Right),
            ModuloExpression modulo => ContainsSliceFlow(modulo.Left) || ContainsSliceFlow(modulo.Right),
            NegateExpression negate => ContainsSliceFlow(negate.Value),
            CompareExpression compare => ContainsSliceFlow(compare.Left) || ContainsSliceFlow(compare.Right),
            AndExpression logicalAnd => ContainsSliceFlow(logicalAnd.Left) || ContainsSliceFlow(logicalAnd.Right),
            OrExpression logicalOr => ContainsSliceFlow(logicalOr.Left) || ContainsSliceFlow(logicalOr.Right),
            NotExpression logicalNot => ContainsSliceFlow(logicalNot.Value),
            TryExpression attempt => ContainsSliceFlow(attempt.Value),
            RangeExpression range => ContainsSliceFlow(range.Start) || ContainsSliceFlow(range.End),
            CompileTimeEachExpression each => ContainsSliceFlow(each.Source)
                || ContainsSliceFlow(each.Selector)
                || (each.DictionaryValueSelector is not null && ContainsSliceFlow(each.DictionaryValueSelector)),
            FoldExpression fold => ContainsSliceFlow(fold.Source)
                || ContainsSliceFlow(fold.Initial)
                || ContainsSliceFlow(fold.Body),
            IfExpression conditional => ContainsSliceFlow(conditional.Condition)
                || ContainsSliceFlow(conditional.Then)
                || (conditional.Else is not null && ContainsSliceFlow(conditional.Else)),
            WhenExpression whenExpression => (whenExpression.Subject is not null && ContainsSliceFlow(whenExpression.Subject))
                || whenExpression.Arms.Any(arm => ContainsSliceFlow(arm.Condition) || ContainsSliceFlow(arm.Body))
                || ContainsSliceFlow(whenExpression.Else),
            EnumMatchExpression match => ContainsSliceFlow(match.Subject)
                || match.Arms.Any(arm => ContainsSliceFlow(arm.Condition) || ContainsSliceFlow(arm.Body))
                || (match.Else is not null && ContainsSliceFlow(match.Else)),
            ArrayLiteralExpression array => array.Elements.Any(ContainsSliceFlow),
            ArrayRepeatExpression repeat => ContainsSliceFlow(repeat.Value),
            DictionaryLiteralExpression dictionary => dictionary.Entries.Any(entry =>
                ContainsSliceFlow(entry.Key) || ContainsSliceFlow(entry.Value)),
            IndexExpression index => ContainsSliceFlow(index.Source) || ContainsSliceFlow(index.Index),
            StructLiteralExpression structure => structure.Fields.Any(field => ContainsSliceFlow(field.Value)),
            ProductExpression product => product.Elements.Any(element => ContainsSliceFlow(element.Value)),
            FieldAccessExpression field => ContainsSliceFlow(field.Source),
            BoxExpression box => ContainsSliceFlow(box.Value),
            MapExpression map => ContainsSliceFlow(map.Path)
                || (map.Offset is not null && ContainsSliceFlow(map.Offset))
                || (map.Length is not null && ContainsSliceFlow(map.Length))
                || (map.FileSize is not null && ContainsSliceFlow(map.FileSize)),
            SubjectCompareExpression compare => ContainsSliceFlow(compare.Right),
            SubjectRangeExpression range => ContainsSliceFlow(range.Start) || ContainsSliceFlow(range.End),
            _ => false
        };
    }

    private static bool ContainsSliceFlow(BlockBody body)
    {
        return ContainsSliceFlow(body.Statements)
            || (body.Value is not null && ContainsSliceFlow(body.Value));
    }

    private static bool IsUnmaterializedDeferredText(Expression expression)
    {
        return expression switch
        {
            StringExpression text => text.Segments.OfType<InterpolationSegment>().Any(),
            FlowExpression flow when flow.Targets.Any(target =>
                target.Path.Count == 1 && target.Path[0] == "materialize") => false,
            FlowExpression flow when flow.Targets.Count == 0 => IsUnmaterializedDeferredText(flow.Source),
            IfExpression conditional => IsUnmaterializedDeferredText(conditional.Then)
                || (conditional.Else is not null && IsUnmaterializedDeferredText(conditional.Else)),
            WhenExpression selection => selection.Arms.Any(arm => IsUnmaterializedDeferredText(arm.Body))
                || IsUnmaterializedDeferredText(selection.Else),
            EnumMatchExpression match => match.Arms.Any(arm => IsUnmaterializedDeferredText(arm.Body))
                || (match.Else is not null && IsUnmaterializedDeferredText(match.Else)),
            _ => false
        };
    }

    private static bool IsUnmaterializedDeferredText(BlockBody body)
    {
        return (body.Value is not null && IsUnmaterializedDeferredText(body.Value))
            || body.Statements.OfType<ReturnStatement>().Any(statement =>
                statement.Value is not null && IsUnmaterializedDeferredText(statement.Value));
    }

    private static bool ContainsSliceFlow(IReadOnlyList<Statement> statements)
    {
        return statements.Any(statement => statement switch
            {
                BindingStatement binding => ContainsSliceFlow(binding.Value),
                ReturnStatement { Value: { } value } => ContainsSliceFlow(value),
                IndexAssignmentStatement assignment => ContainsSliceFlow(assignment.Index)
                    || ContainsSliceFlow(assignment.Value),
                FieldAssignmentStatement assignment => ContainsSliceFlow(assignment.Value),
                ExpressionStatement expression => ContainsSliceFlow(expression.Expression),
                GuardLoopControlStatement guard => ContainsSliceFlow(guard.Condition),
                BlockFunctionCallStatement block => ContainsSliceFlow(block.Source)
                    || block.Body.Any(nested => nested switch
                    {
                        BindingStatement binding => ContainsSliceFlow(binding.Value),
                        ReturnStatement { Value: { } value } => ContainsSliceFlow(value),
                        ExpressionStatement expression => ContainsSliceFlow(expression.Expression),
                        _ => false
                    }),
                BlockFunctionPipelineStatement pipeline => pipeline.Calls.Any(block =>
                    ContainsSliceFlow(block.Source) || ContainsSliceFlow(block.Body)),
                _ => false
            });
    }

    private bool ContainsOwnedParameterCall(
        BlockBody body,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        return body.Statements.Any(statement => statement switch
            {
                BindingStatement binding => ContainsOwnedParameterCall(binding.Value, functions),
                ReturnStatement { Value: { } value } => ContainsOwnedParameterCall(value, functions),
                IndexAssignmentStatement assignment => ContainsOwnedParameterCall(assignment.Value, functions)
                    || ContainsOwnedParameterCall(assignment.Index, functions),
                ExpressionStatement expression => ContainsOwnedParameterCall(expression.Expression, functions),
                GuardLoopControlStatement guard => ContainsOwnedParameterCall(guard.Condition, functions),
                BlockFunctionCallStatement blockFunctionCall => ContainsOwnedParameterCall(blockFunctionCall.Source, functions)
                    || blockFunctionCall.Body.Any(nested => nested is ExpressionStatement expression
                        && ContainsOwnedParameterCall(expression.Expression, functions)),
                BlockFunctionPipelineStatement pipeline => pipeline.Calls.Any(blockFunctionCall =>
                    ContainsOwnedParameterCall(blockFunctionCall.Source, functions)
                    || blockFunctionCall.Body.Any(nested => nested is ExpressionStatement expression
                        && ContainsOwnedParameterCall(expression.Expression, functions))),
                _ => false
            })
            || (body.Value is not null && ContainsOwnedParameterCall(body.Value, functions));
    }

    private bool IsOwnedParameterCall(
        CallExpression call,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        return TryGetFunction(call.Path, functions, out var function)
            && FunctionMovesOwnedHeapInput(function);
    }

    private bool IsOwnedParameterFlowTarget(
        FlowTarget target,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        return !_resolvedContainerFlowTargets.Contains(target)
            && TryGetFunction(target.Path, functions, out var function)
            && FunctionMovesOwnedHeapInput(function);
    }

    private bool FunctionMovesOwnedHeapInput(BoundFunction function)
    {
        return function.InputOwnership == BoundFunctionInputOwnership.Move
            && function.InputType is not null;
    }

    private static IReadOnlySet<string> MoveInputNames(BoundFunction function)
    {
        var names = new HashSet<string>(StringComparer.Ordinal);
        if (function.InputOwnership == BoundFunctionInputOwnership.Move
            && function.InputType is not null)
        {
            names.Add(function.InputName ?? "it");
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            if (parameter.Ownership == BoundFunctionInputOwnership.Move)
            {
                names.Add(parameter.Name);
            }
        }
        return names;
    }

    private static string? ReturnedMoveInputName(BoundFunction function)
    {
        if (function.InputOwnership == BoundFunctionInputOwnership.Move
            && function.InputType == function.ReturnType)
        {
            return function.InputName ?? "it";
        }
        return (function.AdditionalParameters ?? [])
            .Where(parameter => parameter.Ownership == BoundFunctionInputOwnership.Move
                && parameter.Type == function.ReturnType)
            .Select(parameter => parameter.Name)
            .FirstOrDefault();
    }

    private string? MoveInputNameForExpression(Expression? expression)
    {
        var name = expression switch
        {
            NameExpression direct => direct.Name,
            FieldAccessExpression { Source: NameExpression owner } => owner.Name,
            TryExpression { Value: NameExpression attempted } => attempted.Name,
            FlowExpression { Source: NameExpression source } => source.Name,
            _ => null
        };
        return name is not null && _currentMoveInputNames.Contains(name) ? name : null;
    }

    private bool FunctionMutablyBorrowsInput(BoundFunction function)
    {
        return function.InputOwnership == BoundFunctionInputOwnership.MutableBorrow
            && function.InputType is { } inputType
            && (inputType is BoundType.DynamicIntArray or BoundType.IntDictionary or BoundType.Arena
                || _types.IsDynamicArray(inputType)
                || _types.IsStaticArray(inputType)
                || _types.IsBoundedArray(inputType)
                || _types.IsDictionary(inputType)
                || _types.IsStruct(inputType));
    }

    private bool FunctionReadonlyBorrowsHeapInput(BoundFunction function, BoundType actualType)
    {
        return (function.InputType == BoundType.IntDictionaryView
                && actualType == BoundType.IntDictionary)
            || (function.InputType == actualType && _types.IsDictionary(actualType))
            || (function.InputType == actualType
                && (_types.IsDynamicArray(actualType) || _types.IsBoundedArray(actualType)))
            || (function.InputType == BoundType.IntSlice
                && actualType == BoundType.DynamicIntArray);
    }

    private bool TryGetFunction(
        IReadOnlyList<string> path,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out BoundFunction function)
    {
        return TryGetFunction(string.Join('.', path), functions, out function);
    }

    private bool TryGetFunction(
        string path,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out BoundFunction function)
    {
        if (!path.Contains('.', StringComparison.Ordinal)
            && _currentModuleName.Length > 0
            && functions.TryGetValue(_currentModuleName + "." + path, out function!))
        {
            return true;
        }

        return functions.TryGetValue(path, out function!);
    }

    private void EnsureFunctionVisible(BoundFunction function, int line, int column)
    {
        if (function.IsStandardLibrary
            || function.IsLocal
            || function.IsPublic
            || function.ModuleName == _currentModuleName)
        {
            return;
        }

        throw Error(
            line,
            column,
            $"function '{function.Name}' is internal to module '{function.ModuleName}'");
    }

    private void EnsureTypeVisible(TypeId type, int line, int column)
    {
        string? name = null;
        string? moduleName = null;
        var isPublic = true;
        if (_types.IsStruct(type))
        {
            var definition = _types.GetStruct(type);
            if (definition.DeclaringTypeName is not null
                && !definition.IsPublic
                && (_currentTypeScopeName is null
                    || !(_currentTypeScopeName == definition.DeclaringTypeName
                        || _currentTypeScopeName.StartsWith(definition.DeclaringTypeName + ".", StringComparison.Ordinal))))
            {
                throw Error(line, column,
                    $"nested type '{definition.Name}' is private to struct '{definition.DeclaringTypeName}'");
            }
            name = definition.Name;
            moduleName = definition.ModuleName;
            isPublic = definition.IsPublic;
        }
        else if (_types.IsEnum(type))
        {
            var definition = _types.GetEnum(type);
            name = definition.Name;
            moduleName = definition.ModuleName;
            isPublic = definition.IsPublic;
        }
        else if (_types.IsBox(type))
        {
            EnsureTypeVisible(_types.GetBox(type).ElementType, line, column);
            return;
        }
        else if (_types.IsReference(type))
        {
            EnsureTypeVisible(_types.GetReference(type).ElementType, line, column);
            return;
        }
        else if (_types.IsDynTrait(type))
        {
            var traitName = _types.GetDynTrait(type).TraitName;
            var trait = _traits.Values.FirstOrDefault(candidate =>
                candidate.Name == traitName
                || (candidate.ModuleName.Length > 0
                    && candidate.ModuleName + "." + candidate.Name == traitName));
            if (trait is not null)
            {
                EnsureTraitVisible(trait, line, column);
            }
            return;
        }

        if (name is null || isPublic || moduleName == _currentModuleName)
        {
            return;
        }

        throw Error(line, column, $"type '{name}' is internal to module '{moduleName}'");
    }

    private string? ResolveFunctionTypeScope(string functionName)
    {
        return _types.Structs
            .Where(type => functionName.StartsWith(type.Name + ".", StringComparison.Ordinal))
            .OrderByDescending(type => type.Name.Length)
            .Select(type => type.Name)
            .FirstOrDefault();
    }

    private void EnsureTraitVisible(BoundTraitDefinition trait, int line, int column)
    {
        if (trait.IsPublic || trait.ModuleName == _currentModuleName)
        {
            return;
        }

        throw Error(line, column, $"trait '{trait.Name}' is internal to module '{trait.ModuleName}'");
    }

    private bool IsPlainStringLiteral(Expression expression)
    {
        return expression is StringExpression str
            && str.Segments.All(static segment => segment is TextSegment);
    }

    private SollangException Error(int line, int column, string message)
    {
        var module = string.IsNullOrEmpty(_currentModuleName) ? "<main>" : _currentModuleName;
        return new SollangException($"semantic error at {line}:{column}: [module '{module}'] {message}");
    }

    private sealed record FlowResult(BoundType Type, FlowEffect Effect);

    private abstract record FlowEffect
    {
        public static FlowEffect None { get; } = new NoFlowEffect();
    }

    private sealed record NoFlowEffect : FlowEffect;

    private sealed record FlowBindingEffect(string Name, BoundType Type) : FlowEffect;

    private enum MoveInputDisposition
    {
        Retained,
        Transferred,
        Mixed
    }
}
