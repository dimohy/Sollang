namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.emitter.diagnostics",
    "selfhost/llvm/emitter/diagnostics.slg",
    "src/Sollang.Compiler/Shared/Policies/DynTraitPolicy.cs", Region = "DynTraitCompatibility")]
internal static class DynTraitPolicy
{
    public static bool DynTraitMethodCompatible(bool readonlySelf, bool additionalInputs, bool intResult) =>
        readonlySelf && !additionalInputs && intResult;

    public static ulong DynTraitTableKey(ulong traitTypeId, ulong concreteTypeId) =>
        unchecked(traitTypeId * 4294967296UL + concreteTypeId);
}
