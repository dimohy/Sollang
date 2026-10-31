namespace Sollang.Compiler.Shared;

internal enum CodegenKeyPart
{
    Identity,
    SourceImplementation,
    AmbientStandardLibrary,
    TypeUniverse,
    Emissions,
    DependencyInterfaces,
    ModuleInterfaces,
    ModuleImplementations,
    WholeInterface,
    WholeImplementation,
    DeclarationContainer,
    Visibility,
    StructFields,
    EnumVariants,
    TraitAssociatedTypes,
    TraitMethods,
    FunctionInput,
    FunctionReturn,
    FunctionBlock,
    FunctionStream,
    FunctionAsync,
    FunctionGenerics,
    FunctionEffects,
    FunctionParameters,
    FunctionAssociatedTypes,
    MemberName,
    MemberType,
    MemberOwnership,
    MethodParameterCount,
    MethodParameters,
    InterfaceStructs,
    InterfaceEnums,
    InterfaceTraits,
    InterfaceFunctions,
    BlockInput,
    BlockResult,
    GenericPrimary,
    GenericSecondary,
    GenericTertiary,
    GenericTraitBound,
    GenericAssociatedName,
    GenericAssociatedType,
    TypeStructs,
    TypeEnums,
    TypeBoxes,
    TypeReferences,
    TypeDynTraits,
    TypeStaticArrays,
    TypeDynamicArrays,
    TypeDictionaries,
    TypeId,
    TypeName,
    TypeModule,
    TypePayloadWords,
    TypeElement,
    TypeSize,
    TypeAlignment,
    TypeLength,
    TypeKey,
    TypeValue,
    TypeKeySize,
    TypeKeyAlignment,
    TypeValueOffset,
    TypeValueSize,
    TypeValueAlignment,
    TypeEntryStride,
    TypeFieldIndex,
    TypeVariantTag
}

internal readonly record struct CodegenKeyRule(string Domain, IReadOnlyList<CodegenKeyPart> Parts);

[SelfHostPolicy("sollang.compiler.llvm.codegen_cache_key_policy",
    "selfhost/llvm/generated/codegen_cache_key_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/CodegenCacheKeyPolicy.cs")]
internal static class CodegenCacheKeyPolicy
{
    // Layout records retain their existing colon framing inside one hash field.
    // Both compilers consume this category and record order from generated plans.
    public static CodegenKeyRule TypeUniverseFields() => new("type-universe-1",
        [CodegenKeyPart.TypeStructs, CodegenKeyPart.TypeEnums, CodegenKeyPart.TypeBoxes,
            CodegenKeyPart.TypeReferences, CodegenKeyPart.TypeDynTraits, CodegenKeyPart.TypeStaticArrays,
            CodegenKeyPart.TypeDynamicArrays, CodegenKeyPart.TypeDictionaries]);

    public static CodegenKeyRule StructLayoutFields() => new("struct",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeName, CodegenKeyPart.TypeModule]);
    public static CodegenKeyRule StructFieldLayoutFields() => new("field",
        [CodegenKeyPart.TypeFieldIndex, CodegenKeyPart.MemberName, CodegenKeyPart.MemberType]);
    public static CodegenKeyRule EnumLayoutFields() => new("enum",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeName, CodegenKeyPart.TypeModule, CodegenKeyPart.TypePayloadWords]);
    public static CodegenKeyRule EnumVariantLayoutFields() => new("variant",
        [CodegenKeyPart.TypeVariantTag, CodegenKeyPart.MemberName, CodegenKeyPart.MemberType]);
    public static CodegenKeyRule BoxLayoutFields() => new("box",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeElement, CodegenKeyPart.TypeSize, CodegenKeyPart.TypeAlignment]);
    public static CodegenKeyRule ReferenceLayoutFields() => new("reference",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeElement]);
    public static CodegenKeyRule DynTraitLayoutFields() => new("dyn",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeName]);
    public static CodegenKeyRule StaticArrayLayoutFields() => new("static-array",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeElement, CodegenKeyPart.TypeSize,
            CodegenKeyPart.TypeAlignment, CodegenKeyPart.TypeLength]);
    public static CodegenKeyRule DynamicArrayLayoutFields() => new("dynamic-array",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeElement, CodegenKeyPart.TypeSize, CodegenKeyPart.TypeAlignment]);
    public static CodegenKeyRule DictionaryLayoutFields() => new("dictionary",
        [CodegenKeyPart.TypeId, CodegenKeyPart.TypeKey, CodegenKeyPart.TypeValue,
            CodegenKeyPart.TypeKeySize, CodegenKeyPart.TypeKeyAlignment, CodegenKeyPart.TypeValueOffset,
            CodegenKeyPart.TypeValueSize, CodegenKeyPart.TypeValueAlignment, CodegenKeyPart.TypeEntryStride]);

    // Declaration categories are ordered within each source, never across files.
    // This plan contributes no domain field to the module's interface stream.
    public static CodegenKeyRule InterfaceDeclarations() => new("interface-declarations",
        [CodegenKeyPart.InterfaceStructs, CodegenKeyPart.InterfaceEnums,
            CodegenKeyPart.InterfaceTraits, CodegenKeyPart.InterfaceFunctions]);

    // Nested record layouts contribute only their parts, without a domain field.
    public static CodegenKeyRule NamedTypeFields() => new("named-type-fields",
        [CodegenKeyPart.MemberName, CodegenKeyPart.MemberType]);

    public static CodegenKeyRule OwnedTypeFields() => new("owned-type-fields",
        [CodegenKeyPart.MemberType, CodegenKeyPart.MemberOwnership]);

    public static CodegenKeyRule NamedOwnedTypeFields() => new("named-owned-type-fields",
        [CodegenKeyPart.MemberName, CodegenKeyPart.MemberType, CodegenKeyPart.MemberOwnership]);

    public static CodegenKeyRule TraitMethodFields() => new("trait-method-fields",
        [CodegenKeyPart.MemberName, CodegenKeyPart.MemberOwnership, CodegenKeyPart.MemberType,
            CodegenKeyPart.MethodParameterCount, CodegenKeyPart.MethodParameters]);

    public static CodegenKeyRule FunctionBlockFields() => new("function-block-fields",
        [CodegenKeyPart.BlockInput, CodegenKeyPart.BlockResult]);

    public static CodegenKeyRule FunctionGenericFields() => new("function-generic-fields",
        [CodegenKeyPart.GenericPrimary, CodegenKeyPart.GenericSecondary,
            CodegenKeyPart.GenericTertiary, CodegenKeyPart.GenericTraitBound,
            CodegenKeyPart.GenericAssociatedName, CodegenKeyPart.GenericAssociatedType]);

    public static CodegenKeyRule StructInterface() => new("struct",
        [CodegenKeyPart.Identity, CodegenKeyPart.DeclarationContainer,
            CodegenKeyPart.Visibility, CodegenKeyPart.StructFields]);

    public static CodegenKeyRule EnumInterface() => new("enum",
        [CodegenKeyPart.Identity, CodegenKeyPart.Visibility, CodegenKeyPart.EnumVariants]);

    public static CodegenKeyRule TraitInterface() => new("trait",
        [CodegenKeyPart.Identity, CodegenKeyPart.TraitAssociatedTypes, CodegenKeyPart.TraitMethods]);

    public static CodegenKeyRule FunctionInterface() => new("function",
        [CodegenKeyPart.Identity, CodegenKeyPart.FunctionInput, CodegenKeyPart.FunctionReturn,
            CodegenKeyPart.FunctionBlock, CodegenKeyPart.FunctionStream, CodegenKeyPart.FunctionAsync,
            CodegenKeyPart.FunctionGenerics, CodegenKeyPart.FunctionEffects,
            CodegenKeyPart.FunctionParameters, CodegenKeyPart.FunctionAssociatedTypes]);

    public static CodegenKeyRule ModuleImplementation() => new("module-implementation",
        [CodegenKeyPart.Identity, CodegenKeyPart.SourceImplementation,
            CodegenKeyPart.AmbientStandardLibrary, CodegenKeyPart.TypeUniverse,
            CodegenKeyPart.Emissions, CodegenKeyPart.DependencyInterfaces]);

    public static CodegenKeyRule SyntheticInterface() => new("synthetic-interface", [CodegenKeyPart.Identity]);

    public static CodegenKeyRule SyntheticImplementation() => new("synthetic-implementation",
        [CodegenKeyPart.Identity, CodegenKeyPart.AmbientStandardLibrary,
            CodegenKeyPart.TypeUniverse, CodegenKeyPart.Emissions]);

    public static CodegenKeyRule WholeInterface() => new("whole-interface", [CodegenKeyPart.ModuleInterfaces]);
    public static CodegenKeyRule WholeImplementation() => new("whole-implementation", [CodegenKeyPart.ModuleImplementations]);
    public static CodegenKeyRule PrefixInterface() => new("prefix-interface", [CodegenKeyPart.WholeInterface]);
    public static CodegenKeyRule PrefixImplementation() => new("prefix-implementation", [CodegenKeyPart.WholeImplementation]);
    public static CodegenKeyRule SuffixInterface() => new("suffix-interface", [CodegenKeyPart.WholeInterface]);
    public static CodegenKeyRule SuffixImplementation() => new("suffix-implementation", [CodegenKeyPart.WholeImplementation]);
}
