namespace Sollang.Compiler.CodeGen;

// The production method and relevant runtime value records are extracted by
// the existing generic-context verifier. Slice element queries use its actual
// loaded compiler type table, not a duplicate type mapping.
internal sealed partial class LlvmEmitter
{
    private readonly ProbeProgram _program;
    private sealed record ProbeProgram(ProbeTypes Types);
    private sealed record ProbeReference(BoundType ElementType);
    private sealed record ProbeTypes(
        Func<BoundType, BoundType> Query,
        Func<BoundType, bool> Slice,
        Func<BoundType, bool> Reference,
        Func<BoundType, BoundType> ReferenceElement,
        Func<BoundType, string> Identity)
    {
        public BoundType GetSliceElement(BoundType type) => Query(type);
        public bool IsSlice(BoundType type) => Slice(type);
        public bool IsReference(BoundType type) => Reference(type);
        public ProbeReference GetReference(BoundType type) => new(ReferenceElement(type));
    }
    private static class SemanticStableIdentity
    {
        public static string Type(ProbeTypes types, BoundType type) => types.Identity(type);
    }
    private readonly List<string> _instructions = [];
    private int _temporary;
    private string NextTemp(string name) => $"%{name}{_temporary++}";
    private void EmitAssign(string name, string instruction) => _instructions.Add(name + " = " + instruction);
    private sealed class SollangException(string message) : Exception(message);
    private sealed record NonArrayValue() : RuntimeValue(BoundType.Text);
    private RuntimeValue CreateRuntimeIntSlice(RuntimeValue value) =>
        throw new InvalidOperationException("IntSlice branch is outside this Text-only extraction probe");

    private LlvmEmitter(ProbeTypes types) => _program = new(types);

    internal static int CheckReadonlyTextSlice(
        Func<string, BoundType> parse, Func<BoundType, BoundType> query,
        Func<BoundType, bool> isSlice, Func<BoundType, bool> isReference,
        Func<BoundType, BoundType> referenceElement, Func<BoundType, string> identity)
    {
        var emitter = new LlvmEmitter(new(query, isSlice, isReference, referenceElement, identity));
        var sliceType = parse("[Text]");
        var fixedType = parse("[Text; 2]");
        var dynamicType = parse("[Text; ~]");
        var passed = 0;
        void View(string id, RuntimeValue owner, string pointer, string length)
        {
            var descriptor = TryGetRuntimeArrayView(owner);
            if (descriptor is not { } parts || parts.Element != BoundType.Text
                || !ReferenceEquals(parts.Pointer, pointer) || !ReferenceEquals(parts.Length, length))
                throw new InvalidOperationException("array descriptor changed the owner: " + id);
            var view = emitter.CreateRuntimeSlice(sliceType, owner) as RuntimeInlineSlice;
            if (view is null || view.ElementType != BoundType.Text || view.Type != sliceType
                || !ReferenceEquals(view.PointerName, pointer) || !ReferenceEquals(view.LengthName, length))
                throw new InvalidOperationException("readonly Text view changed the owner descriptor: " + id);
            emitter.EnsureFunctionArgumentRuntimeType(owner, sliceType, "probe");
            emitter._instructions.Clear();
            emitter._temporary = 0;
            var argument = emitter.BuildReadonlySliceArgument(sliceType, owner, "probe");
            var expectedInstructions = new[]
            {
                $"%slice_arg0 = insertvalue %sollang.int_slice poison, ptr {pointer}, 0",
                $"%slice_arg1 = insertvalue %sollang.int_slice %slice_arg0, i64 {length}, 1"
            };
            if (argument != "%sollang.int_slice %slice_arg1"
                || !emitter._instructions.SequenceEqual(expectedInstructions))
                throw new InvalidOperationException("slice serializer did not reuse the owner descriptor: " + id);
            passed++;
            Console.WriteLine("PASS readonly-text-slice-" + id);
        }
        const string pointer = "%existing_text_elements";
        const string length = "%existing_text_length";
        View("fixed-heap", new RuntimeStaticTextArray(pointer, length, 2, RuntimeContainerStorage.Heap, fixedType), pointer, length);
        View("fixed-stack", new RuntimeStaticTextArray(pointer, length, 2, RuntimeContainerStorage.Stack, fixedType), pointer, length);
        View("empty-fixed", new RuntimeStaticTextArray(pointer, "0", 1, RuntimeContainerStorage.Heap, parse("[Text; 0]")), pointer, "0");
        View("inline-fixed", new RuntimeStaticInlineArray(fixedType, BoundType.Text, pointer, length, 2, 2), pointer, length);
        View("growable", new RuntimeDynamicInlineArray(dynamicType, BoundType.Text, pointer, length, "%capacity"), pointer, length);
        View("existing-view", new RuntimeInlineSlice(sliceType, BoundType.Text, pointer, length), pointer, length);
        void Reject(string id, RuntimeValue owner, string diagnostic)
        {
            void MustReject(Action action, string message)
            {
                try { action(); }
                catch (SollangException failure) when (failure.Message.Contains(message, StringComparison.Ordinal))
                { return; }
                throw new InvalidOperationException("readonly Text consumer accepted invalid owner: " + id);
            }
            MustReject(() => emitter.CreateRuntimeSlice(sliceType, owner), diagnostic);
            MustReject(() => emitter.EnsureFunctionArgumentRuntimeType(owner, sliceType, "probe"), "function 'probe' expects ");
            MustReject(() => emitter.BuildReadonlySliceArgument(sliceType, owner, "probe"), "function 'probe' expects ");
            passed++;
            Console.WriteLine("PASS readonly-text-slice-" + id);
        }
        Reject("wrong-element", new RuntimeStaticInlineArray(parse("[Int; 2]"), BoundType.Int, pointer, length, 2, 2), "readonly array view element type mismatch");
        Reject("non-array", new NonArrayValue(), "readonly array view requires an array value");
        foreach (var (id, owner) in new (string, RuntimeValue)[]
        {
            ("int-view-descriptor", new RuntimeIntSlice(pointer, length)),
            ("fixed-int-descriptor", new RuntimeStaticIntArray(pointer, length, 2)),
            ("growable-int-descriptor", new RuntimeDynamicIntArray(pointer, length, "%capacity"))
        })
        {
            if (TryGetRuntimeArrayView(owner) is not { } descriptor
                || descriptor.Element != BoundType.Int
                || !ReferenceEquals(descriptor.Pointer, pointer) || !ReferenceEquals(descriptor.Length, length))
                throw new InvalidOperationException("existing Int descriptor changed: " + id);
            passed++;
            Console.WriteLine("PASS readonly-text-slice-" + id);
        }
        if (TryGetRuntimeArrayView(new NonArrayValue()) is not null)
            throw new InvalidOperationException("array descriptor accepted a non-array");
        Console.WriteLine($"readonly-text-slice={passed}/11");
        return 0;
    }
}
