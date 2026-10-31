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
    FunctionAssociatedTypes
}

internal readonly record struct CodegenKeyRule(string Domain, IReadOnlyList<CodegenKeyPart> Parts);

[SelfHostPolicy("sollang.compiler.llvm.codegen_cache_key_policy",
    "selfhost/llvm/generated/codegen_cache_key_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/CodegenCacheKeyPolicy.cs")]
internal static class CodegenCacheKeyPolicy
{
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
