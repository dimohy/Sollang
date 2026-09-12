using System;
using System.Collections.Generic;
using System.Linq;

public enum BoundType
{
    Text,
    SourceText,
    Int,
    StructText,
    StructSourceText,
    OptionSourceText,
    ResultSourceText,
    Arena,
    OwnedBytes
}

public enum BoundFunctionInputOwnership { Default, Move, MutableBorrow }

public abstract record Expression(int Line, int Column);
public sealed record NameExpression(string Name, int SourceLine = 1, int SourceColumn = 1)
    : Expression(SourceLine, SourceColumn);
public sealed record CallExpression(
    IReadOnlyList<string> Path,
    IReadOnlyList<Expression> Arguments,
    int SourceLine = 1,
    int SourceColumn = 1)
    : Expression(SourceLine, SourceColumn);

public sealed class SemanticCompilerProbe
{
    private sealed record BoundFunction(string Name);
    private sealed record ElementDefinition(BoundType ElementType);
    private sealed record DictionaryDefinition(BoundType KeyType, BoundType ValueType);
    private sealed record FieldDefinition(BoundType Type);
    private sealed record StructDefinition(FieldDefinition[] Fields);
    private sealed record BoundEnumVariant(string Name, BoundType? PayloadType);
    private sealed record EnumDefinition(BoundEnumVariant[] Variants);

    private sealed class TypeTable
    {
        private static readonly IReadOnlyDictionary<BoundType, StructDefinition> Structs =
            new Dictionary<BoundType, StructDefinition>
            {
                [BoundType.StructText] = new(new[] { new FieldDefinition(BoundType.Text) }),
                [BoundType.StructSourceText] = new(new[] { new FieldDefinition(BoundType.SourceText) })
            };
        private static readonly IReadOnlyDictionary<BoundType, EnumDefinition> Enums =
            new Dictionary<BoundType, EnumDefinition>
            {
                [BoundType.OptionSourceText] = new(new[]
                {
                    new BoundEnumVariant("Some", BoundType.StructSourceText),
                    new BoundEnumVariant("None", null)
                }),
                [BoundType.ResultSourceText] = new(new[]
                {
                    new BoundEnumVariant("Ok", BoundType.OptionSourceText),
                    new BoundEnumVariant("Err", BoundType.Int)
                })
            };

        public bool IsStaticArray(BoundType type) => false;
        public bool IsDynamicArray(BoundType type) => false;
        public bool IsDictionary(BoundType type) => false;
        public bool IsBox(BoundType type) => false;
        public bool IsReference(BoundType type) => false;
        public bool IsStruct(BoundType type) => Structs.ContainsKey(type);
        public bool IsEnum(BoundType type) => Enums.ContainsKey(type);
        public bool TryResolve(string name, out BoundType type)
        {
            type = name switch
            {
                "Option<SourceText>" => BoundType.OptionSourceText,
                _ => default
            };
            return name == "Option<SourceText>";
        }
        public ElementDefinition GetStaticArray(BoundType type) => throw new InvalidOperationException();
        public ElementDefinition GetDynamicArray(BoundType type) => throw new InvalidOperationException();
        public DictionaryDefinition GetDictionary(BoundType type) => throw new InvalidOperationException();
        public ElementDefinition GetBox(BoundType type) => throw new InvalidOperationException();
        public ElementDefinition GetReference(BoundType type) => throw new InvalidOperationException();
        public StructDefinition GetStruct(BoundType type) => Structs[type];
        public EnumDefinition GetEnum(BoundType type) => Enums[type];
    }

    private readonly TypeTable _types = new();
    private readonly Dictionary<string, IReadOnlySet<string>> _activeBorrowedTextOrigins =
        new(StringComparer.Ordinal)
        {
            ["view"] = new HashSet<string>(new[] { "owner" }, StringComparer.Ordinal)
        };
    private readonly Dictionary<object, BoundFunction> _resolvedGenericCalls =
        new(ReferenceEqualityComparer.Instance);

    private BoundType ParseType(string name, int line, int column) => name switch
    {
        "Result<SourceText,Int>" => BoundType.ResultSourceText,
        _ => throw new InvalidOperationException($"unknown type {name} at {line}:{column}")
    };

    /*PRODUCTION_TYPE_CONTAINS*/

    /*PRODUCTION_HELPER*/

    /*PRODUCTION_PARAMETER_HELPER*/

    private bool IsBorrowedTextByteStorage(BoundType type) => type == BoundType.OwnedBytes;

    /*PRODUCTION_ENUM_HELPERS*/

    /*PRODUCTION_BORROW_SOURCE_HELPER*/

    private bool TryGetConcreteBorrowOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (expression is NameExpression name)
        {
            if (_activeBorrowedTextOrigins.TryGetValue(name.Name, out origins!))
                return true;
            if (bindings.ContainsKey(name.Name))
            {
                origins = new HashSet<string>(new[] { name.Name }, StringComparer.Ordinal);
                return true;
            }
        }
        origins = new HashSet<string>(StringComparer.Ordinal);
        return false;
    }

    private bool TryGetBorrowedTextCallOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (expression is NameExpression name
            && _activeBorrowedTextOrigins.TryGetValue(name.Name, out origins!))
            return true;
        origins = new HashSet<string>(StringComparer.Ordinal);
        return false;
    }

    private bool TryGetFunction(
        IReadOnlyList<string> path,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out BoundFunction function) => functions.TryGetValue(string.Join('.', path), out function!);

    public static string Run()
    {
        var probe = new SemanticCompilerProbe();
        var checks = new (string Name, BoundType Type, bool Expected)[]
        {
            ("text", BoundType.Text, true),
            ("nested-text-struct", BoundType.StructText, true),
            ("source-text", BoundType.SourceText, true),
            ("nested-source-struct", BoundType.StructSourceText, true),
            ("nested-source-option", BoundType.OptionSourceText, true),
            ("nested-source-result", BoundType.ResultSourceText, true),
            ("unrelated-int", BoundType.Int, false),
            ("unrelated-owned-return", BoundType.OwnedBytes, false)
        };
        var passed = 0;
        foreach (var check in checks)
        {
            var actual = probe.TypeCanCarryBorrowedTextOrigin(check.Type);
            if (actual != check.Expected)
                throw new InvalidOperationException($"{check.Name}: expected {check.Expected}, observed {actual}");
            passed++;
        }
        var parameterChecks = new (string Name, BoundType Type, BoundFunctionInputOwnership Ownership, bool Expected)[]
        {
            ("direct-source-default", BoundType.SourceText, BoundFunctionInputOwnership.Default, true),
            ("direct-source-move", BoundType.SourceText, BoundFunctionInputOwnership.Move, false),
            ("nested-source-default", BoundType.StructSourceText, BoundFunctionInputOwnership.Default, true),
            ("nested-source-move", BoundType.StructSourceText, BoundFunctionInputOwnership.Move, true),
            ("text-move", BoundType.Text, BoundFunctionInputOwnership.Move, true),
            ("byte-storage", BoundType.OwnedBytes, BoundFunctionInputOwnership.Default, true),
            ("unrelated-parameter", BoundType.Int, BoundFunctionInputOwnership.Default, false)
        };
        foreach (var check in parameterChecks)
        {
            var actual = probe.CanSupplyBorrowedTextOrigin(check.Type, check.Ownership);
            if (actual != check.Expected)
                throw new InvalidOperationException($"{check.Name}: expected {check.Expected}, observed {actual}");
            passed++;
        }
        var payload = new NameExpression("payload");
        var enumChecks = new (string Name, Expression Value, bool Expected)[]
        {
            ("resolved-option-some", new CallExpression(
                new[] { "Option<SourceText>", "Some" }, new Expression[] { payload }), true),
            ("parsed-result-ok", new CallExpression(
                new[] { "Result<SourceText,Int>", "Ok" }, new Expression[] { payload }), true),
            ("result-error-payload", new CallExpression(
                new[] { "Result<SourceText,Int>", "Err" }, new Expression[] { payload }), false),
            ("payloadless-variant", new CallExpression(
                new[] { "Option<SourceText>", "None" }, Array.Empty<Expression>()), false),
            ("unknown-variant", new CallExpression(
                new[] { "Option<SourceText>", "Missing" }, new Expression[] { payload }), false),
            ("ordinary-expression", payload, false)
        };
        foreach (var check in enumChecks)
        {
            var actual = probe.TryGetBorrowedTextEnumPayload(check.Value, out var observedPayload);
            if (actual != check.Expected)
                throw new InvalidOperationException($"{check.Name}: expected {check.Expected}, observed {actual}");
            if (actual && !ReferenceEquals(payload, observedPayload))
                throw new InvalidOperationException($"{check.Name}: enum payload identity was not preserved");
            passed++;
        }
        var functions = new Dictionary<string, BoundFunction>(StringComparer.Ordinal);
        var ownerBindings = new Dictionary<string, BoundType>(StringComparer.Ordinal)
        {
            ["bytes"] = BoundType.OwnedBytes
        };
        if (!probe.TryGetBorrowedSourceCallSiteOrigins(
                new NameExpression("bytes"), functions, ownerBindings, out var localOrigins)
            || !localOrigins.SetEquals(new[] { "bytes" }))
            throw new InvalidOperationException("local-owner-source: concrete origin was not created");
        passed++;
        if (!probe.TryGetBorrowedSourceCallSiteOrigins(
                new NameExpression("view"), functions, ownerBindings, out var propagatedOrigins)
            || !propagatedOrigins.SetEquals(new[] { "owner" }))
            throw new InvalidOperationException("borrowed-view-source: active origin was not propagated");
        passed++;
        if (probe.TryGetBorrowedSourceCallSiteOrigins(
                new NameExpression("missing"), functions, ownerBindings, out _))
            throw new InvalidOperationException("unknown-source: unexpectedly inferred an origin");
        passed++;
        var resolvedSite = new object();
        var resolvedFunction = new BoundFunction("resolved-instance");
        probe._resolvedGenericCalls[resolvedSite] = resolvedFunction;
        if (!probe.TryGetBorrowedCallSiteFunction(
                resolvedSite, new[] { "reader" }, functions, out var observedResolved)
            || !ReferenceEquals(resolvedFunction, observedResolved))
            throw new InvalidOperationException("resolved-call-site: semantic authority was not reused");
        passed++;
        var fallbackFunction = new BoundFunction("fallback-global");
        functions["global"] = fallbackFunction;
        if (!probe.TryGetBorrowedCallSiteFunction(
                new object(), new[] { "global" }, functions, out var observedFallback)
            || !ReferenceEquals(fallbackFunction, observedFallback))
            throw new InvalidOperationException("textual-call-fallback: unresolved call did not use the textual fallback");
        passed++;
        return $"PASS {passed}/{checks.Length + parameterChecks.Length + enumChecks.Length + 5}";
    }
}
