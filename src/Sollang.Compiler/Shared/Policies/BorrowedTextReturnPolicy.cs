namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.semantic.borrowed_text_return_policy",
    "selfhost/semantic/generated/borrowed_text_return_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/BorrowedTextReturnPolicy.cs")]
internal static class BorrowedTextReturnPolicy
{
    public static bool RequiresOriginCheck(bool outerParameter, bool movesOwner, bool ownsStorage) =>
        !outerParameter || (movesOwner && ownsStorage);
}
