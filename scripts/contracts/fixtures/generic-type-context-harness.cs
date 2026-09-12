using System.Collections;
using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text.Json;

namespace Sollang.Compiler.Semantics;

// Only the selected current production methods are compiled beside this
// adapter. Concrete type parsing/table operations run in the existing compiler
// DLL; there is no duplicate type parser and no rebuilt compiler here.
internal sealed partial class SemanticCompiler
{
    private const BindingFlags Instance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
    private readonly object _referenceCompiler;
    private readonly Type _referenceType;
    private readonly Type _referenceTypeId;
    private readonly TypeTableAdapter _types;
    private IReadOnlyDictionary<string, BoundType> _activeGenericTypeArguments =
        new Dictionary<string, BoundType>(StringComparer.Ordinal);

    private SemanticCompiler(Assembly assembly, string fixture)
    {
        var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", throwOnError: true)!;
        var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", throwOnError: true)!, "WindowsX64");
        var loaded = Invoke(app.GetMethod("LoadProgram", BindingFlags.Static | BindingFlags.NonPublic)!,
            null, [new[] { fixture }, null, target])!;
        var program = loaded.GetType().GetProperty("Program")!.GetValue(loaded)!;
        _referenceType = assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler", throwOnError: true)!;
        _referenceTypeId = assembly.GetType("Sollang.Compiler.Semantics.TypeId", throwOnError: true)!;
        _referenceCompiler = Activator.CreateInstance(_referenceType, Instance, null, [program, 64], null)!;
        _types = new TypeTableAdapter(this, _referenceType.GetField("_types", Instance)!.GetValue(_referenceCompiler)!);
    }

    private static object? Invoke(MethodInfo method, object? target, object?[] arguments)
    {
        try { return method.Invoke(target, arguments); }
        catch (TargetInvocationException failure) when (failure.InnerException is { } inner)
        {
            ExceptionDispatchInfo.Capture(inner).Throw();
            throw;
        }
    }

    private object ReferenceType(BoundType type) => Enum.ToObject(_referenceTypeId, (int)type);
    private object? ReferenceCall(string name, params object?[] arguments) =>
        Invoke(_referenceType.GetMethod(name, Instance)!, _referenceCompiler, arguments);
    private BoundType ParsePlain(string syntax) => (BoundType)Convert.ToInt32(ReferenceCall("ParseType", syntax, 1, 1));
    private string FormatType(BoundType type) => (string)ReferenceCall("FormatType", ReferenceType(type))!;
    private static Exception Error(int line, int column, string message) => new InvalidOperationException(message);
    private bool IsNestedContainerElementType(BoundType type) => (bool)ReferenceCall("IsNestedContainerElementType", ReferenceType(type))!;
    private bool IsUnsupportedGrowableArrayElementType(BoundType type) => (bool)ReferenceCall("IsUnsupportedGrowableArrayElementType", ReferenceType(type))!;
    private bool IsSupportedDictionaryKeyType(BoundType type) => (bool)ReferenceCall("IsSupportedDictionaryKeyType", ReferenceType(type))!;
    private void EnsureTypeVisible(BoundType type, int line, int column) => ReferenceCall("EnsureTypeVisible", ReferenceType(type), line, column);

    private BoundType ParseAssociatedType(string syntax, IReadOnlyDictionary<string, BoundType> bindings, int line, int column)
        => (BoundType)Convert.ToInt32(ReferenceCall("ParseAssociatedType", syntax, ReferenceBindings(bindings), line, column));

    private IDictionary ReferenceBindings(IReadOnlyDictionary<string, BoundType> bindings)
    {
        var mapType = typeof(Dictionary<,>).MakeGenericType(typeof(string), _referenceTypeId);
        var map = (IDictionary)Activator.CreateInstance(mapType)!;
        foreach (var (name, type) in bindings) map.Add(name, ReferenceType(type));
        return map;
    }

    private bool TryGetContextualArrayElementType(BoundType type, out BoundType element)
    {
        object?[] arguments = [ReferenceType(type), null];
        var matched = (bool)ReferenceCall("TryGetContextualArrayElementType", arguments)!;
        element = (BoundType)Convert.ToInt32(arguments[1]);
        return matched;
    }

    private sealed class TypeTableAdapter(SemanticCompiler owner, object table)
    {
        private object? Call(string name, params object?[] args) => Invoke(table.GetType().GetMethod(name)!, table, args);
        private BoundType TypeCall(string name, params object?[] args) => (BoundType)Convert.ToInt32(Call(name, args));
        public bool TryResolve(string name, out BoundType type)
        {
            object?[] args = [name, null];
            var found = (bool)Call("TryResolve", args)!;
            type = (BoundType)Convert.ToInt32(args[1]);
            return found;
        }
        public void AddAlias(string name, BoundType type) => Call("AddAlias", name, owner.ReferenceType(type));
        public BoundType GetOrAddReference(BoundType type) => TypeCall("GetOrAddReference", owner.ReferenceType(type));
        public BoundType GetOrAddStream(BoundType type) => TypeCall("GetOrAddStream", owner.ReferenceType(type));
        public BoundType GetOrAddEventStream(BoundType type) => TypeCall("GetOrAddEventStream", owner.ReferenceType(type));
        public BoundType GetOrAddDynamicArray(BoundType type) => TypeCall("GetOrAddDynamicArray", owner.ReferenceType(type));
        public BoundType GetOrAddSlice(BoundType type) => TypeCall("GetOrAddSlice", owner.ReferenceType(type));
        public BoundType GetSliceElement(BoundType type) => TypeCall("GetSliceElement", owner.ReferenceType(type));
        public bool IsSlice(BoundType type) => (bool)Call("IsSlice", owner.ReferenceType(type))!;
        public string StableIdentity(BoundType type) => (string)Invoke(
            owner._referenceType.Assembly.GetType("Sollang.Compiler.Semantics.SemanticStableIdentity", true)!
                .GetMethod("Type", BindingFlags.Static | BindingFlags.Public)!,
            null, [table, owner.ReferenceType(type)])!;
        public BoundType GetOrAddOption(BoundType type, string name) => TypeCall("GetOrAddOption", owner.ReferenceType(type), name);
        public BoundType GetOrAddResult(BoundType ok, BoundType error, string name) => TypeCall("GetOrAddResult", owner.ReferenceType(ok), owner.ReferenceType(error), name);
        public BoundType GetOrAddFixedStaticArray(BoundType type, int length) => TypeCall("GetOrAddFixedStaticArray", owner.ReferenceType(type), length);
        public BoundType GetOrAddBoundedArray(BoundType type, int capacity) => TypeCall("GetOrAddBoundedArray", owner.ReferenceType(type), capacity);
        public BoundType GetOrAddDictionary(BoundType key, BoundType value) => TypeCall("GetOrAddDictionary", owner.ReferenceType(key), owner.ReferenceType(value));
        public BoundType GetOrAddBoundedDictionary(BoundType key, BoundType value, int capacity) => TypeCall("GetOrAddBoundedDictionary", owner.ReferenceType(key), owner.ReferenceType(value), capacity);
        public BoundType GetOrAddProduct(IReadOnlyList<(string? Label, BoundType Type)> fields, string name, int line, int column)
        {
            var tupleType = typeof(ValueTuple<,>).MakeGenericType(typeof(string), owner._referenceTypeId);
            var list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(tupleType))!;
            foreach (var field in fields) list.Add(Activator.CreateInstance(tupleType, [field.Label, owner.ReferenceType(field.Type)]));
            return TypeCall("GetOrAddProduct", list, name, line, column);
        }
        public bool IsReference(BoundType type) => (bool)Invoke(
            table.GetType().GetMethod("IsReference")!, table, [owner.ReferenceType(type)])!;
        public ReferenceElement GetReference(BoundType type)
        {
            var reference = Invoke(table.GetType().GetMethod("GetReference")!, table, [owner.ReferenceType(type)])!;
            return new ReferenceElement((BoundType)Convert.ToInt32(reference.GetType().GetProperty("ElementType")!.GetValue(reference)));
        }
    }
    private sealed record ReferenceElement(BoundType ElementType);

    private static int Main(string[] args)
    {
        var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
        var resolver = new SemanticCompiler(assembly, Path.GetFullPath(args[1]));
        if (args.Length > 2 && args[2] == "--type-delimiters")
            return resolver.CheckTypeDelimiters(args[3]);
        if (args.Length > 2 && args[2] == "--readonly-text-slice")
            return CodeGen.LlvmEmitter.CheckReadonlyTextSlice(
                resolver.ParsePlain, resolver._types.GetSliceElement, resolver._types.IsSlice,
                resolver._types.IsReference, type => resolver._types.GetReference(type).ElementType,
                resolver._types.StableIdentity);
        if (args.Length > 2 && args[2] == "--inspect-type")
        {
            foreach (var syntax in args.Skip(3))
            {
                try { Console.WriteLine($"TYPE {syntax} = {resolver.FormatType(resolver.ParsePlain(syntax))}"); }
                catch (Exception failure) { Console.WriteLine($"REJECT {syntax}: {failure.Message}"); }
            }
            return 0;
        }
        var passed = 0;
        void Check(string id, Action body)
        {
            body();
            passed++;
            Console.WriteLine($"PASS {id}");
        }
        static void Require(bool condition) { if (!condition) throw new InvalidOperationException("assertion failed"); }
        static void Reject(Action body, string fragment)
        {
            try { body(); }
            catch (Exception failure) when (failure.Message.Contains(fragment, StringComparison.Ordinal)) { return; }
            throw new InvalidOperationException($"expected diagnostic: {fragment}");
        }
        void Unwrap(string syntax, string actual, string elementSyntax, string element)
        {
            Require(resolver.TryGetBorrowedGenericElement(syntax, resolver.ParsePlain(actual), 1, 1, out var name, out var type));
            Require(name == elementSyntax && type == resolver.ParsePlain(element));
        }
        BoundType Resolve(string syntax, string name, string actual) => resolver.ParseSpecializedFunctionType(
            syntax, new Dictionary<string, BoundType> { [name] = resolver.ParsePlain(actual) }, 1, 1);

        Check("unbound-readonly-rejects-T", () => Reject(() => resolver.ParsePlain("[T]"), "unknown type 'T'"));
        Check("unbound-reference-rejects-T", () => Reject(() => resolver.ParsePlain("ref T"), "unknown type 'T'"));
        Check("infer-readonly-growable", () => Unwrap("[T]", "[Int; ~]", "T", "Int"));
        Check("infer-readonly-fixed", () => Unwrap("[T]", "[Text; 2]", "T", "Text"));
        Check("infer-readonly-view", () => Unwrap("[T]", "[Int]", "T", "Int"));
        Check("infer-reference-owner", () => Unwrap("ref T", "Int", "T", "Int"));
        Check("infer-reference-value", () => Unwrap("ref T", "ref Int", "T", "Int"));
        Check("reject-scalar-as-view", () => Reject(() => Unwrap("[T]", "Int", "T", "Int"), "expected a readonly array view"));
        Check("preserve-growable-route", () => Require(!resolver.TryGetBorrowedGenericElement("[T; ~]", resolver.ParsePlain("[Int; ~]"), 1, 1, out _, out _)));
        Check("specialize-readonly", () => Require(Resolve("[T]", "T", "Int") == resolver.ParsePlain("[Int]")));
        Check("specialize-reference", () => Require(Resolve("ref T", "T", "Int") == resolver.ParsePlain("ref Int")));
        Check("specialize-nested-option", () => Require(Resolve("Option<ref T>", "T", "Int") == resolver.ParsePlain("Option<ref Int>")));
        Check("specialize-legacy-three-parameter-path", () => Require(resolver.ParseSpecializedFunctionType(
            "Result<ref T, U>", "T", resolver.ParsePlain("Int"), "U", resolver.ParsePlain("Text"), null, null, 1, 1)
            == resolver.ParsePlain("Result<ref Int, Text>")));
        Check("specialization-no-alias-leak", () => Require(Resolve("ref T", "T", "Text") == resolver.ParsePlain("ref Text")));
        Check("preserve-outer-generic-scope", () => {
            resolver._activeGenericTypeArguments = new Dictionary<string, BoundType> { ["C"] = resolver.ParsePlain("Text") };
            Require(Resolve("Result<T, C>", "T", "Int") == resolver.ParsePlain("Result<Int, Text>"));
            Require(resolver._activeGenericTypeArguments.Count == 1);
        });
        Check("reject-uninferred-secondary", () => Reject(() => resolver.ParseSpecializedFunctionType(
            "ref U", "T", resolver.ParsePlain("Int"), "U", null, null, null, 1, 1), "cannot infer type parameter 'U'"));
        Check("reject-reference-to-reference", () => Reject(() => Resolve("ref T", "T", "ref Int"), "ref requires a non-reference value type"));
        Check("reject-unit-view", () => Reject(() => Resolve("[T]", "T", "Unit"), "readonly array views require"));
        Check("reference-parser-scope-restored", () => Reject(() => resolver.ParsePlain("T"), "unknown type 'T'"));
        Check("named-owner-remains-addressable", () => {
            var name = Activator.CreateInstance(assembly.GetType("Sollang.Compiler.Syntax.NameExpression", throwOnError: true)!, ["number", 1, 1])!;
            resolver.ReferenceCall("EnsureReferenceArgumentPlace", name,
                resolver.ReferenceBindings(new Dictionary<string, BoundType> { ["number"] = resolver.ParsePlain("Int") }), null, "Ordering.copy");
        });
        Check("temporary-reference-remains-rejected", () => {
            var number = Activator.CreateInstance(assembly.GetType("Sollang.Compiler.Syntax.NumberExpression", throwOnError: true)!, ["2", 1, 1])!;
            Reject(() => resolver.ReferenceCall("EnsureReferenceArgumentPlace", number,
                resolver.ReferenceBindings(new Dictionary<string, BoundType>()), null, "Ordering.copy"), "requires an addressable owner or reference");
        });
        Console.WriteLine($"generic-type-contexts={passed}/21");
        return 0;
    }

    private int CheckTypeDelimiters(string matrixPath)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(matrixPath));
        var matrix = document.RootElement;
        // Observe the currently supplied DLL before extracted-method aliases
        // can affect it. Historical baseline evidence is preserved separately;
        // a newer reference compiler may already accept every positive case.
        foreach (var item in matrix.GetProperty("accepted").EnumerateArray())
        {
            var syntax = item.GetString()!;
            try { Console.WriteLine($"REFERENCE ACCEPT {syntax}: {FormatType(ParsePlain(syntax))}"); }
            catch (Exception failure) { Console.WriteLine($"REFERENCE REJECT {syntax}: {failure.Message}"); }
        }
        foreach (var item in matrix.GetProperty("accepted").EnumerateArray())
        {
            var syntax = item.GetString()!;
            var parsed = ParseCandidateType(syntax, 1, 1);
            Console.WriteLine($"PASS delimiter-accept {syntax}: {FormatType(parsed)}");
        }
        foreach (var item in matrix.GetProperty("rejected").EnumerateArray())
        {
            var syntax = item.GetProperty("type").GetString()!;
            var diagnostic = item.GetProperty("diagnostic").GetString()!;
            try { ParseCandidateType(syntax, 1, 1); }
            catch (Exception failure) when (failure.Message.Contains(diagnostic, StringComparison.Ordinal))
            {
                Console.WriteLine($"PASS delimiter-reject {syntax}: {failure.Message}");
                continue;
            }
            throw new InvalidOperationException($"expected {diagnostic}: {syntax}");
        }
        foreach (var item in matrix.GetProperty("separators").EnumerateArray())
        {
            var text = item.GetProperty("text").GetString()!;
            var delimiter = item.GetProperty("delimiter").GetString()![0];
            var prefix = item.GetProperty("prefix").GetString();
            if (FindTopLevelTypeSeparator(text, delimiter) != (prefix?.Length ?? -1))
                throw new InvalidOperationException($"wrong top-level delimiter: {text}");
            Console.WriteLine($"PASS delimiter-position {text}");
        }
        var nested = ParseCandidateType("[(Int, [Int; 2]); ~]", 1, 1);
        if (!TryGetBorrowedGenericElement("[(T, [Int; 2])]", nested, 1, 1, out var element, out _)
            || element != "(T, [Int; 2])") throw new InvalidOperationException("generic readonly nested delimiter");
        Console.WriteLine("PASS delimiter-generic-readonly-nested");
        if (ProbeTryResolveDefinitionFixedStaticArray("[(Int, [Int; <= 2]); 3]", 1, 1) != (true, "(Int, [Int; <= 2])", 3)
            || ProbeTryResolveDefinitionFixedStaticArray("[(Int, [Int; 2])]", 1, 1).Matched
            || ProbeTryResolveDefinitionFixedStaticArray("[(Int, [Int; 2]); <= 3]", 1, 1).Matched)
            throw new InvalidOperationException("definition fixed-array prefix diverged");
        Console.WriteLine("PASS delimiter-definition-fixed");
        if (ProbeTryResolveDefinitionBoundedArray("[(Int, [Int; 2]); <= 3]", 1, 1) != (true, "(Int, [Int; 2])", 3)
            || ProbeTryResolveDefinitionBoundedArray("[(Int, [Int; <= 2]); 3]", 1, 1).Matched
            || ProbeTryResolveDefinitionBoundedArray("[(Int, [Int; <= 2])]", 1, 1).Matched)
            throw new InvalidOperationException("definition bounded-array prefix diverged");
        Console.WriteLine("PASS delimiter-definition-bounded");
        return 0;
    }
}
