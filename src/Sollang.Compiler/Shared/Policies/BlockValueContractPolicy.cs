namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.semantic.block_value_contract_policy",
    "selfhost/semantic/generated/block_value_contract_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/BlockValueContractPolicy.cs")]
internal static class BlockValueContractPolicy
{
    // A yield may borrow the declared reference's element. Callback results
    // require the exact declared type and disable the element alternative.
    public static bool AcceptsValue(bool exactType, bool referenceInput, bool elementType) =>
        exactType || (referenceInput && elementType);
}
