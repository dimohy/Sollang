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
}
