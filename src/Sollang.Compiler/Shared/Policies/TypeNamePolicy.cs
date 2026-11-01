namespace Sollang.Compiler.Shared;

#if !BUILDING_GENERATOR
[SelfHostPolicy("sollang.compiler.semantic.type_name_policy",
    "selfhost/semantic/generated/type_name_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/TypeNamePolicy.cs")]
#endif
internal static class TypeNamePolicy
{
    public const string InferredFunctionTypeName = "<inferred>";
    public static string InferredFunctionName() => InferredFunctionTypeName;

    // Parser source generation and native metadata use the same compiled names.
    public static string BuiltinNames() =>
        "Unit|Text|Bool|Self|Int|Long|Int8|Int16|Int32|Int64|UInt8|UInt16|UInt32|UInt64|Size|UIntSize|CodePoint|Arena|Arguments|SourceText|MappedBytes|MutableMappedBytes|Float|Double|Float32|Float64";

    // Unlisted enum names keep their spelling. Both compilers consume this
    // compiled table when formatting resolved synthetic type names.
    public static string BuiltinDisplayOverrides() =>
        "Int64=Long|Float32=Float|Float64=Double|IntSlice=[Int]|StaticIntArray=[Int; N]|StaticTextArray=[Text; N]|DynamicIntArray=[Int; ~]|IntDictionaryView={Int: Int}|IntDictionary={Int: Int}|GenericParameter=generic parameter|SecondaryGenericParameter=secondary generic parameter|TertiaryGenericParameter=tertiary generic parameter";

    public static string OptionVariantNames() => "None|Some";
    public static string ResultVariantNames() => "Ok|Err";
    public static string RuntimeResultAliasNames() => "sys.directory.RawResult|sys.directory.ReadResult";

    public static string PredeclaredFixedArrays() =>
        "FixedUInt8Array12:UInt8:12|FixedUInt8Array16:UInt8:16|FixedUInt8Array32:UInt8:32";
    public static string PredeclaredDynamicArrays() =>
        "DynamicUInt8Array:UInt8|DynamicDirectoryEntryArray:sys.directory.Entry";
    public static bool SourceDynamicArrayIsImplicit(bool builtinInt) => builtinInt;
    public static bool SourceDictionaryIsImplicit(bool builtinIntKey, bool builtinIntValue) =>
        builtinIntKey && builtinIntValue;

    public static string RangeDefinition() => "Range|start:Int|endInclusive:Int";

    public static string AffineStorageFieldName() => "handle";
    public static string AffineStorageFieldType() => "UInt64";

    public static string PrimitiveBoxNames() => "Text|Int|Int32|Bool";
    public static string BoxExcludedStructNames() =>
        "sys.file.File|sys.file.FileWriter|sys.file.SourceText|sys.process.Command|sys.file.AtomicReplaceRequest";
    public static string BoxExcludedNominalNames() =>
        "sys.path.Path|sys.path.Style|sys.directory.Raw|sys.directory.kind.Kind|sys.directory.Entry|sys.directory.RawResult|sys.directory.ReadResult|sys.input.mouse.Event|sys.input.mouse.Kind|sys.input.mouse.OverflowPolicy";
    public static bool CanRegisterBoxName(bool primitive, bool structure, bool enumeration,
        bool excludedStructure, bool excludedNominal) =>
        (primitive || structure && !excludedStructure || enumeration) && !excludedNominal;

    // Structural identity spellings are shared by the encoder, parser and SLG.
    public static string StableOptionPrefix() => "Option<";
    public static string StableResultPrefix() => "Result<";
    public static string StableTaskPrefix() => "Task<";
    public static string StableStreamPrefix() => "Stream<";
    public static string StableEventStreamPrefix() => "EventStream<";
    public static string StableFixedArrayPrefix() => "FixedArray<";
    public static string StableStaticArrayPrefix() => "StaticArray<";
    public static string StableBinaryHeapPrefix() => "BinaryHeap<";
    public static string StableDequePrefix() => "Deque<";
    public static string StableSetPrefix() => "Set<";
    public static string StableArrayPrefix() => "Array<";
    public static string StableBoundedArrayPrefix() => "BoundedArray<";
    public static string StableBitSetPrefix() => "BitSet<";
    public static string StableDictionaryPrefix() => "Dictionary<";
    public static string StableBoundedDictionaryPrefix() => "BoundedDictionary<";
    public static string StableBoxPrefix() => "Box<";
    public static string StableReferencePrefix() => "Ref<";
    public static string StableSlicePrefix() => "Slice<";
    public static string StableDynTraitPrefix() => "Dyn<";
    public static string StableProductPrefix() => "Product<";
    public static string StableStructPrefix() => "struct:";
    public static string StableEnumPrefix() => "enum:";
    public static string StableBuiltinPrefix() => "builtin:";
}
