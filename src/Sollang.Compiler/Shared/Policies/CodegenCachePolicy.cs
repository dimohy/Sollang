namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.codegen_cache_policy",
    "selfhost/llvm/generated/codegen_cache_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/CodegenCachePolicy.cs")]
internal static class CodegenCachePolicy
{
    public static ulong EnvelopeChecksumSeed() => 7809847782465536322UL;
    public static ulong FragmentChecksumSeed() => 16320118547808316911UL;

    public static ulong ChecksumMix(ulong hash, ulong value) => unchecked(
        (hash + 11400714819323198485UL) * (hash + 13787848793156543929UL)
        + (value + 10723151780598845931UL) * (value + 7146057691288625177UL)
        + 1099511628211UL);

    public static ulong FingerprintMix(ulong hash, ulong value) =>
        unchecked(hash * 1099511628211UL + value + 97UL);

    public static bool MatchesContext(bool compilerMatches, bool targetMatches, bool configurationMatches) =>
        compilerMatches && targetMatches && configurationMatches;
}
