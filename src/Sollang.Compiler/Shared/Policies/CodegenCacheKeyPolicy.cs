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
    GenericAssociatedType
}

internal readonly record struct CodegenKeyRule(string Domain, IReadOnlyList<CodegenKeyPart> Parts);

[SelfHostPolicy("sollang.compiler.llvm.codegen_cache_key_policy",
    "selfhost/llvm/generated/codegen_cache_key_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/CodegenCacheKeyPolicy.cs")]
internal static class CodegenCacheKeyPolicy
{
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
