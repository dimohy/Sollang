using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    // Facts belong to a single successful binder traversal. They contain selected
    // types/sites, not a second syntax-name resolver or another language model.
    private sealed class LoopBorrowCapture(
        string moduleName,
        string? functionName,
        IReadOnlyList<Statement> statements,
        IReadOnlyDictionary<string, BoundType> bindings,
        IReadOnlyDictionary<string, MutableBindingDeclaration> declarations,
        object? ownerContext,
        BorrowOriginState entry,
        Expression? condition = null)
    {
        public string ModuleName { get; } = moduleName;
        public string? FunctionName { get; } = functionName;
        public IReadOnlyList<Statement> Statements { get; } = statements;
        public Dictionary<string, BoundType> Bindings { get; } = new(bindings, StringComparer.Ordinal);
        public Dictionary<string, MutableBindingDeclaration> Declarations { get; } =
            new(declarations, StringComparer.Ordinal);
        public BorrowOriginState Entry { get; } = entry;
        public Expression? Condition { get; } = condition;
        public object? OwnerContext { get; } = ownerContext;
        public List<LoopBorrowFact> Facts { get; } = [];
    }

    private abstract record LoopBorrowFact;

    private sealed record LoopBorrowBindingFact(
        BindingStatement Definition,
        BoundType Type,
        Expression Value,
        IReadOnlyDictionary<string, BoundType> Types,
        IReadOnlyDictionary<string, BoundFunction> Functions,
        bool KillsPreviousOrigin,
        bool RebindsHeaderScalar) : LoopBorrowFact;

    private sealed record LoopBorrowStoreFact(
        object ReceiverDefinition,
        string ReceiverPlace,
        Expression Value,
        IReadOnlyDictionary<string, BoundType> Types,
        IReadOnlyDictionary<string, BoundFunction> Functions) : LoopBorrowFact;

    private sealed record LoopBorrowMutationFact(
        string OriginPlace,
        int Line,
        int Column) : LoopBorrowFact;

    private sealed record LoopBorrowPatternFact(
        Expression Subject, BoundEnumVariant Variant, string Name) : LoopBorrowFact;

    private sealed record LoopBorrowKillFact(string Carrier) : LoopBorrowFact;
    private sealed record LoopBorrowExitFact(BorrowControlExit Exit) : LoopBorrowFact;
    private sealed record LoopBorrowSeedFact(
        object Definition, string Name, BoundType Type, Expression Source,
        IReadOnlyDictionary<string, BoundType> Types,
        IReadOnlyDictionary<string, BoundFunction> Functions) : LoopBorrowFact;

    private sealed record LoopBorrowExpirationFact(
        IReadOnlyList<Statement> Statements,
        int StatementIndex,
        Expression? Result,
        IReadOnlySet<string>? Continuation,
        IReadOnlyDictionary<string, BoundType> Types) : LoopBorrowFact;

    private sealed record LoopBorrowControlFact(
        Expression Site,
        List<LoopBorrowArm> Arms,
        IReadOnlyDictionary<string, BoundType> OuterTypes) : LoopBorrowFact;

    private sealed record LoopBorrowArm(
        BlockBody Body,
        List<LoopBorrowFact> Facts,
        IReadOnlyDictionary<string, BoundType> OuterTypes,
        string? ShadowedName,
        List<LoopBorrowFact> Conditions);

    private sealed record LoopBorrowNestedFact(LoopBorrowCapture Capture) : LoopBorrowFact;

    private LoopBorrowCapture? _loopBorrowCapture;
    private List<LoopBorrowFact>? _loopBorrowFacts;
    private LoopBorrowControlCapture? _loopBorrowControl;

    private sealed class LoopBorrowRestore(Action restore) : IDisposable
    {
        public void Dispose() => restore();
    }

    private sealed class LoopBorrowControlCapture(
        LoopBorrowControlFact fact,
        List<LoopBorrowFact> parent)
    {
        public LoopBorrowControlFact Fact { get; } = fact;
        public List<LoopBorrowFact> Parent { get; } = parent;
        public bool Added { get; set; }
        public Dictionary<BlockBody, LoopBorrowPatternFact> Patterns { get; } = [];
        public Dictionary<BlockBody, List<LoopBorrowFact>> Conditions { get; } = [];
        public bool Owns(BlockBody body) => Fact.Site switch
        {
            IfExpression conditional => ReferenceEquals(body, conditional.Then)
                || ReferenceEquals(body, conditional.Else),
            WhenExpression match => match.Arms.Any(arm => ReferenceEquals(body, arm.Body))
                || ReferenceEquals(body, match.Else),
            EnumMatchExpression match => match.Arms.Any(arm => ReferenceEquals(body, arm.Body))
                || ReferenceEquals(body, match.Else),
            _ => false
        };
    }

    private IDisposable BeginLoopBorrowControl(Expression site, IReadOnlyDictionary<string, BoundType> outerTypes)
    {
        var previous = _loopBorrowControl;
        if (IsCurrentLoopBorrowCapture)
            _loopBorrowControl = new(new(site, [],
                new Dictionary<string, BoundType>(outerTypes, StringComparer.Ordinal)), _loopBorrowFacts!);
        return new LoopBorrowRestore(() => _loopBorrowControl = previous);
    }

    private IDisposable BeginLoopBorrowArm(BlockBody body, IReadOnlyDictionary<string, BoundType> outerTypes)
    {
        var previous = _loopBorrowFacts;
        if (IsCurrentLoopBorrowCapture && _loopBorrowControl is { } control && control.Owns(body))
        {
            // Subject/condition evaluation stays before the first arm commit.
            if (!control.Added)
            {
                control.Parent.Add(control.Fact);
                control.Added = true;
            }
            control.Patterns.TryGetValue(body, out var pattern);
            var arm = new LoopBorrowArm(body, [], control.Fact.OuterTypes, pattern?.Name,
                control.Conditions.TryGetValue(body, out var conditions) ? conditions : []);
            if (pattern is not null)
                arm.Facts.Add(pattern);
            control.Fact.Arms.Add(arm);
            _loopBorrowFacts = arm.Facts;
        }
        return new LoopBorrowRestore(() => _loopBorrowFacts = previous);
    }

    private IDisposable BeginLoopBorrowWhenCondition(BlockBody body)
    {
        var previous = _loopBorrowFacts;
        if (IsCurrentLoopBorrowCapture && _loopBorrowControl is { } control
            && control.Fact.Site is WhenExpression && control.Owns(body))
        {
            if (!control.Added)
            {
                control.Parent.Add(control.Fact);
                control.Added = true;
            }
            var conditions = new List<LoopBorrowFact>();
            control.Conditions.Add(body, conditions);
            _loopBorrowFacts = conditions;
        }
        return new LoopBorrowRestore(() => _loopBorrowFacts = previous);
    }

    private void CaptureLoopBorrowPattern(
        BlockBody body, Expression subject, BoundEnumVariant variant, string name)
    {
        if (IsCurrentLoopBorrowCapture && _loopBorrowControl is { } control && control.Owns(body))
            control.Patterns[body] = new(subject, variant, name);
    }

    private bool IsCurrentLoopBorrowCapture => _loopBorrowCapture is { } capture
        && capture.ModuleName == _currentModuleName
        && capture.FunctionName == _currentFunctionName
        && ReferenceEquals(capture.OwnerContext, _currentMutableDeclarations);

    private void CaptureLoopBorrowMutation(string origin, int line, int column)
    {
        if (IsCurrentLoopBorrowCapture)
            _loopBorrowFacts!.Add(new LoopBorrowMutationFact(origin, line, column));
    }

    private void CaptureLoopBorrowKill(string carrier)
    {
        if (IsCurrentLoopBorrowCapture)
            _loopBorrowFacts!.Add(new LoopBorrowKillFact(carrier));
    }

    private void CaptureLoopBorrowExit(BorrowControlExit exit)
    {
        if (IsCurrentLoopBorrowCapture)
            _loopBorrowFacts!.Add(new LoopBorrowExitFact(exit));
    }

    private void CaptureLoopBorrowStore(
        string receiver,
        Expression value,
        IReadOnlyDictionary<string, BoundType> types,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (!IsCurrentLoopBorrowCapture)
            return;
        var capture = _loopBorrowCapture!;
        var root = SplitBorrowPlace(receiver)[0];
        if (!capture.Bindings.ContainsKey(root)
            || (_loopBorrowControl is { } control && control.Fact.Arms.Any(arm =>
                ReferenceEquals(arm.Facts, _loopBorrowFacts) && arm.ShadowedName == root)))
            return; // A new loop-local receiver cannot feed the outer loop header.
        object definition = capture.Declarations.TryGetValue(root, out var declaration)
            ? declaration : capture.Bindings;
        _loopBorrowFacts!.Add(new LoopBorrowStoreFact(
            definition, receiver, value,
            new Dictionary<string, BoundType>(types, StringComparer.Ordinal),
            new Dictionary<string, BoundFunction>(functions, StringComparer.Ordinal)));
    }

    private void CaptureLoopBorrowBinding(
        BindingStatement binding,
        BoundType type,
        bool killsPrevious,
        IReadOnlyDictionary<string, BoundType> types,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (IsCurrentLoopBorrowCapture)
        {
            var name = binding.Name.TrimEnd('!');
            var capture = _loopBorrowCapture!;
            var rebindsHeaderScalar = killsPrevious && type == BoundType.Text
                && capture.Bindings.TryGetValue(binding.Name, out var headerType) && headerType == BoundType.Text
                && capture.Declarations.TryGetValue(name, out var headerDeclaration)
                && _currentMutableDeclarationsByName is { } currentDeclarations
                && currentDeclarations.TryGetValue(name, out var currentDeclaration)
                && ReferenceEquals(headerDeclaration, currentDeclaration);
            _loopBorrowFacts!.Add(new LoopBorrowBindingFact(
                binding, type, binding.Value,
                new Dictionary<string, BoundType>(types, StringComparer.Ordinal),
                new Dictionary<string, BoundFunction>(functions, StringComparer.Ordinal),
                killsPrevious, rebindsHeaderScalar));
        }
    }

    private void CaptureLoopBorrowSeed(
        object definition, string name, BoundType type, Expression source,
        IReadOnlyDictionary<string, BoundType> types,
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        if (IsCurrentLoopBorrowCapture)
            _loopBorrowFacts!.Add(new LoopBorrowSeedFact(definition, name, type, source,
                new Dictionary<string, BoundType>(types, StringComparer.Ordinal),
                new Dictionary<string, BoundFunction>(functions, StringComparer.Ordinal)));
    }

    private void CaptureLoopBorrowExpiration(
        IReadOnlyList<Statement> statements,
        int statementIndex,
        Expression? result,
        IReadOnlySet<string>? continuation,
        IReadOnlyDictionary<string, BoundType> types)
    {
        if (IsCurrentLoopBorrowCapture)
            _loopBorrowFacts!.Add(new LoopBorrowExpirationFact(
                statements, statementIndex, result,
                continuation is null ? null : new HashSet<string>(continuation, StringComparer.Ordinal),
                new Dictionary<string, BoundType>(types, StringComparer.Ordinal)));
    }

    private BorrowOriginState ValidateLoopBorrowCapture(LoopBorrowCapture capture)
    {
        if (!HasLoopBorrowHeaderTransfer(capture.Facts))
            return CaptureBorrowedTextOriginState();
        var exits = EvaluateLoopBorrowCapture(capture, capture.Entry, validate: true);
        return exits[BorrowControlExit.Fallthrough];
    }

    private static bool HasLoopBorrowHeaderTransfer(IEnumerable<LoopBorrowFact> facts) => facts.Any(fact => fact switch
    {
        LoopBorrowStoreFact => true,
        LoopBorrowBindingFact { RebindsHeaderScalar: true } => true,
        LoopBorrowControlFact control => control.Arms.Any(arm => HasLoopBorrowHeaderTransfer(arm.Conditions) || HasLoopBorrowHeaderTransfer(arm.Facts)),
        LoopBorrowNestedFact nested => HasLoopBorrowHeaderTransfer(nested.Capture.Facts),
        _ => false
    });

    private static IEnumerable<string> LoopBorrowStoredCarriers(IEnumerable<LoopBorrowFact> facts)
    {
        foreach (var fact in facts)
        {
            if (fact is LoopBorrowStoreFact store)
                yield return store.ReceiverPlace;
            else if (fact is LoopBorrowControlFact control)
                foreach (var carrier in control.Arms.SelectMany(arm =>
                    LoopBorrowStoredCarriers(arm.Conditions).Concat(LoopBorrowStoredCarriers(arm.Facts))))
                    yield return carrier;
            else if (fact is LoopBorrowNestedFact nested)
                foreach (var carrier in LoopBorrowStoredCarriers(nested.Capture.Facts))
                    yield return carrier;
        }
    }

    private Dictionary<BorrowControlExit, BorrowOriginState> EvaluateLoopBorrowCapture(
        LoopBorrowCapture capture,
        BorrowOriginState entry,
        bool validate)
    {
        var header = FilterLoopBorrowScope(entry, capture.Bindings);
        var appendedCarriers = LoopBorrowStoredCarriers(capture.Facts)
            .Where(carrier => capture.Bindings.ContainsKey(SplitBorrowPlace(carrier)[0]))
            .ToHashSet(StringComparer.Ordinal);
        Dictionary<BorrowControlExit, BorrowOriginState> body;
        while (true)
        {
            body = ReplayLoopBorrowFacts(capture.Facts, header, capture, validate: false);
            // Only successfully selected append receivers preserve their
            // previous header payload. Do not union all scalar/alias header
            // state: their actual kill/registration facts remain authoritative.
            var retainedStores = header.Origins
                .Where(pair => appendedCarriers.Contains(pair.Key))
                .ToDictionary(static pair => pair.Key, static pair => pair.Value, StringComparer.Ordinal);
            var inputs = new List<BorrowOriginState>
            {
                entry,
                new(retainedStores, header.ReadonlyReferenceBindings
                    .Where(retainedStores.ContainsKey).ToHashSet(StringComparer.Ordinal))
            };
            foreach (var exit in new[] { BorrowControlExit.Fallthrough, BorrowControlExit.Continue })
                if (body.TryGetValue(exit, out var backEdge))
                    inputs.Add(FilterLoopBorrowScope(backEdge, capture.Bindings));
            var next = FilterLoopBorrowScope(MergeBorrowedTextOriginStates(inputs), capture.Bindings);
            if (SameLoopBorrowState(header, next))
                break;
            header = next;
        }
        if (validate)
            body = ReplayLoopBorrowFacts(capture.Facts, header, capture, validate: true);

        // Zero iterations and a closest-loop break both reach the statement
        // after this loop. Its stable header also reaches a false condition,
        // including storage retained by an earlier continue iteration.
        var after = new List<BorrowOriginState> { header };
        foreach (var exit in new[] { BorrowControlExit.Fallthrough, BorrowControlExit.Break })
            if (body.TryGetValue(exit, out var state))
                after.Add(FilterLoopBorrowScope(state, capture.Bindings));
        var result = new Dictionary<BorrowControlExit, BorrowOriginState>
        {
            [BorrowControlExit.Fallthrough] = MergeBorrowedTextOriginStates(after)
        };
        if (body.TryGetValue(BorrowControlExit.Return, out var returned))
            result[BorrowControlExit.Return] = FilterLoopBorrowScope(returned, capture.Bindings);
        return result;
    }

    private Dictionary<BorrowControlExit, BorrowOriginState> ReplayLoopBorrowFacts(
        IReadOnlyList<LoopBorrowFact> facts,
        BorrowOriginState input,
        LoopBorrowCapture capture,
        bool validate,
        BorrowControlExit continuation = BorrowControlExit.Fallthrough)
    {
        var suffixExits = new BorrowControlExit[facts.Count + 1];
        suffixExits[facts.Count] = continuation;
        for (var index = facts.Count - 1; index >= 0; index--)
            suffixExits[index] = ComposeLoopBorrowExits(LoopBorrowFactExits(facts[index]), suffixExits[index + 1]);
        var states = new Dictionary<BorrowControlExit, BorrowOriginState>
        {
            [BorrowControlExit.Fallthrough] = input
        };
        for (var factIndex = 0; factIndex < facts.Count; factIndex++)
        {
            var fact = facts[factIndex];
            if (!states.Remove(BorrowControlExit.Fallthrough, out var incoming))
                break;
            var origins = new Dictionary<string, IReadOnlySet<string>>(incoming.Origins, StringComparer.Ordinal);
            var readonlyBindings = new HashSet<string>(incoming.ReadonlyReferenceBindings, StringComparer.Ordinal);
            BorrowOriginState Current() => new(origins, readonlyBindings);
            switch (fact)
            {
                case LoopBorrowPatternFact pattern:
                    WithLoopBorrowQueryState(Current(), () =>
                    {
                        foreach (var place in origins.Keys.Where(place => SplitBorrowPlace(place)[0] == pattern.Name).ToArray())
                        {
                            origins.Remove(place);
                            readonlyBindings.Remove(place);
                        }
                        if (pattern.Variant.PayloadType is { } payloadType && TypeContainsReadonlyReference(payloadType))
                        {
                            foreach (var carrier in InstallReadonlyReferenceEnumPatternOrigins(
                                pattern.Subject, pattern.Variant, pattern.Name))
                            {
                                origins[carrier] = _activeBorrowedTextOrigins[carrier];
                                readonlyBindings.Add(carrier);
                            }
                        }
                    });
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                case LoopBorrowSeedFact seed:
                {
                    WithLoopBorrowQueryState(Current(), () =>
                    {
                        IReadOnlySet<string> payload = EmptyBorrowOrigins();
                        var found = seed.Definition is BlockFunctionCallStatement
                            ? TryGetEachItemBorrowedTextOrigins(seed.Source, seed.Functions, seed.Types, out payload)
                            : TryGetBorrowedSourceCallSiteOrigins(seed.Source, seed.Functions, seed.Types, out payload);
                        if (found)
                            origins[seed.Name] = payload;
                        else if (seed.Definition is not BlockFunctionCallStatement
                            && TryGetReadonlyReferenceCallOrigins(seed.Source, seed.Functions, seed.Types, out var referenceOrigins))
                        {
                            origins[seed.Name] = referenceOrigins;
                            readonlyBindings.Add(seed.Name);
                        }
                        else if (TypeCanCarryBorrowedTextOrigin(seed.Type))
                            origins[seed.Name] = EmptyBorrowOrigins();
                    });
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                }
                case LoopBorrowBindingFact binding:
                {
                    // The pre-RHS kill, when legal, is a preceding fact. The
                    // normal registration kill follows RHS evaluation exactly.
                    WithLoopBorrowQueryState(Current(), () =>
                    {
                        IReadOnlySet<string> payload = EmptyBorrowOrigins();
                        var carries = TypeCanCarryBorrowedTextOrigin(binding.Type);
                        var found = carries && TryGetBorrowedSourceCallSiteOrigins(
                            binding.Value, binding.Functions, binding.Types, out payload);
                        if (binding.KillsPreviousOrigin)
                        {
                            origins.Remove(binding.Definition.Name);
                            readonlyBindings.Remove(binding.Definition.Name);
                        }
                        if (found)
                            origins[binding.Definition.Name] = payload;
                        else
                        {
                            if (carries)
                                origins[binding.Definition.Name] = EmptyBorrowOrigins();
                            foreach (var carrier in GetReadonlyReferenceCarrierOrigins(
                                binding.Value, binding.Type, binding.Functions, binding.Types))
                            {
                                var place = binding.Definition.Name + carrier.Key;
                                origins[place] = carrier.Value;
                                readonlyBindings.Add(place);
                            }
                        }
                    });
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                }
                case LoopBorrowStoreFact store:
                {
                    var root = SplitBorrowPlace(store.ReceiverPlace)[0];
                    if (capture.Declarations.TryGetValue(root, out var definition)
                        && !ReferenceEquals(definition, store.ReceiverDefinition))
                        throw new SollangException("loop borrowed carrier definition changed after binding");
                    WithLoopBorrowQueryState(Current(), () =>
                    {
                        if (TryGetBorrowedTextCallOrigins(store.Value, store.Functions, store.Types, out var payload))
                            UnionBorrowOriginCarrier(origins, store.ReceiverPlace, payload);
                    });
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                }
                case LoopBorrowKillFact kill:
                    origins.Remove(kill.Carrier);
                    readonlyBindings.Remove(kill.Carrier);
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                case LoopBorrowExpirationFact expiration:
                {
                    WithLoopBorrowQueryState(Current(), () =>
                    {
                        foreach (var carrier in origins.Keys.ToArray())
                        {
                            var live = expiration.Continuation?.Contains(carrier) == true;
                            for (var index = expiration.StatementIndex; !live && index < expiration.Statements.Count; index++)
                                live = ReferencesTrackedBorrow(expiration.Statements[index], carrier, expiration.Types);
                            if (!live && expiration.Result is not null)
                                live = ReferencesTrackedBorrow(expiration.Result, carrier, expiration.Types);
                            // Header carriers that remain on a backedge are also
                            // consumed by the next iteration, including sibling arms.
                            if (!live && capture.Bindings.ContainsKey(SplitBorrowPlace(carrier)[0])
                                && (suffixExits[factIndex + 1]
                                    & (BorrowControlExit.Fallthrough | BorrowControlExit.Continue)) != 0)
                                live = capture.Statements.Any(statement => ReferencesBorrowCarrier(statement, carrier))
                                    || (capture.Condition is not null && ReferencesBorrowCarrier(capture.Condition, carrier));
                            if (!live)
                            {
                                origins.Remove(carrier);
                                readonlyBindings.Remove(carrier);
                            }
                        }
                    });
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                }
                case LoopBorrowMutationFact mutation:
                    if (validate)
                        CheckBorrowedTextOriginMutation(origins, readonlyBindings,
                            mutation.OriginPlace, mutation.Line, mutation.Column);
                    MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, Current());
                    break;
                case LoopBorrowExitFact exit:
                    foreach (var kind in new[] { BorrowControlExit.Fallthrough, BorrowControlExit.Break,
                                 BorrowControlExit.Continue, BorrowControlExit.Return })
                        if ((exit.Exit & kind) != 0)
                            MergeLoopBorrowExit(states, kind, Current());
                    break;
                case LoopBorrowControlFact control:
                {
                    var conditionState = incoming;
                    foreach (var arm in control.Arms)
                    {
                        // A later when condition runs only on the preceding
                        // false path, after those earlier condition effects.
                        var tests = ReplayLoopBorrowFacts(arm.Conditions, conditionState,
                            capture, validate, suffixExits[factIndex + 1]);
                        foreach (var exit in tests.Where(exit => exit.Key != BorrowControlExit.Fallthrough))
                            MergeLoopBorrowExit(states, exit.Key, exit.Value);
                        if (!tests.TryGetValue(BorrowControlExit.Fallthrough, out var tested))
                            break;
                        foreach (var exit in ReplayLoopBorrowFacts(arm.Facts, tested,
                            capture, validate, suffixExits[factIndex + 1]))
                            MergeLoopBorrowExit(states, exit.Key, FilterLoopBorrowArmScope(exit.Value, arm, tested));
                        if (control.Site is WhenExpression)
                            conditionState = tested;
                    }
                    if (control.Site is IfExpression { Else: null })
                        MergeLoopBorrowExit(states, BorrowControlExit.Fallthrough, incoming);
                    break;
                }
                case LoopBorrowNestedFact nested:
                    foreach (var exit in EvaluateLoopBorrowCapture(nested.Capture, incoming, validate))
                        MergeLoopBorrowExit(states, exit.Key, exit.Value);
                    break;
                default:
                    throw new SollangException("unsupported bound loop borrowed-origin fact");
            }
        }
        return states;
    }

    private void WithLoopBorrowQueryState(BorrowOriginState state, Action query)
    {
        var previousState = CaptureBorrowedTextOriginState();
        var previousCapture = _loopBorrowCapture;
        try
        {
            // Reuse the actual registration/query authority with frozen selected
            // call/type context. Queries cannot record another binder traversal.
            _loopBorrowCapture = null;
            RestoreBorrowedTextOriginState(state);
            query();
        }
        finally
        {
            RestoreBorrowedTextOriginState(previousState);
            _loopBorrowCapture = previousCapture;
        }
    }

    // Compose captured control exits; this does not bind or resolve syntax again.
    private static BorrowControlExit ComposeLoopBorrowExits(
        BorrowControlExit exits, BorrowControlExit continuation) =>
        (exits & ~BorrowControlExit.Fallthrough)
        | ((exits & BorrowControlExit.Fallthrough) != 0 ? continuation : BorrowControlExit.None);

    private static BorrowControlExit LoopBorrowFactExits(LoopBorrowFact fact) => fact switch
    {
        LoopBorrowExitFact exit => exit.Exit,
        LoopBorrowControlFact control => LoopBorrowControlExits(control),
        // The nested loop consumes its own break/continue. Its zero-iteration
        // edge continues this loop, while a function return exits both.
        LoopBorrowNestedFact nested => BorrowControlExit.Fallthrough
            | (LoopBorrowFactsExits(nested.Capture.Facts) & BorrowControlExit.Return),
        _ => BorrowControlExit.Fallthrough
    };

    private static BorrowControlExit LoopBorrowControlExits(LoopBorrowControlFact control)
    {
        var exits = control.Site is IfExpression { Else: null }
            ? BorrowControlExit.Fallthrough : BorrowControlExit.None;
        for (var index = control.Arms.Count - 1; index >= 0; index--)
        {
            var arm = control.Arms[index];
            var body = LoopBorrowFactsExits(arm.Facts);
            exits = control.Site is WhenExpression
                ? ComposeLoopBorrowExits(LoopBorrowFactsExits(arm.Conditions), body | exits)
                : exits | body;
        }
        return exits;
    }

    private static BorrowControlExit LoopBorrowFactsExits(IReadOnlyList<LoopBorrowFact> facts)
    {
        var exits = BorrowControlExit.Fallthrough;
        foreach (var fact in facts)
            exits = ComposeLoopBorrowExits(exits, LoopBorrowFactExits(fact));
        return exits;
    }

    private static void MergeLoopBorrowExit(
        IDictionary<BorrowControlExit, BorrowOriginState> states,
        BorrowControlExit exit,
        BorrowOriginState state) => states[exit] = states.TryGetValue(exit, out var previous)
            ? MergeBorrowedTextOriginStates([previous, state]) : state;

    private static BorrowOriginState FilterLoopBorrowArmScope(
        BorrowOriginState state, LoopBorrowArm arm, BorrowOriginState incoming)
    {
        var filtered = FilterLoopBorrowScope(state, arm.OuterTypes);
        if (arm.ShadowedName is not { } shadow)
            return filtered;
        var origins = new Dictionary<string, IReadOnlySet<string>>(filtered.Origins, StringComparer.Ordinal);
        var references = new HashSet<string>(filtered.ReadonlyReferenceBindings, StringComparer.Ordinal);
        foreach (var place in origins.Keys.Where(place => SplitBorrowPlace(place)[0] == shadow).ToArray())
        {
            origins.Remove(place);
            references.Remove(place);
        }
        foreach (var pair in incoming.Origins.Where(pair => SplitBorrowPlace(pair.Key)[0] == shadow))
            origins[pair.Key] = pair.Value;
        references.UnionWith(incoming.ReadonlyReferenceBindings.Where(place => SplitBorrowPlace(place)[0] == shadow));
        return new(origins, references);
    }

    private static BorrowOriginState FilterLoopBorrowScope(
        BorrowOriginState state,
        IReadOnlyDictionary<string, BoundType> types)
    {
        var origins = state.Origins.Where(pair => types.ContainsKey(SplitBorrowPlace(pair.Key)[0]))
            .ToDictionary(static pair => pair.Key, static pair => pair.Value, StringComparer.Ordinal);
        return new(origins,
            state.ReadonlyReferenceBindings.Where(origins.ContainsKey).ToHashSet(StringComparer.Ordinal));
    }

    private static bool SameLoopBorrowState(BorrowOriginState left, BorrowOriginState right) =>
        left.Origins.Count == right.Origins.Count
        && left.Origins.All(pair => right.Origins.TryGetValue(pair.Key, out var value)
            && pair.Value.SetEquals(value))
        && left.ReadonlyReferenceBindings.SetEquals(right.ReadonlyReferenceBindings);
}
