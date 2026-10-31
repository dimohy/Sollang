namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.codegen_cache_policy",
    "selfhost/llvm/generated/codegen_cache_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/CodegenCachePolicy.cs")]
internal static class CodegenCachePolicy
{
    public static bool MatchesContext(bool compilerMatches, bool targetMatches, bool configurationMatches) =>
        compilerMatches && targetMatches && configurationMatches;
}
