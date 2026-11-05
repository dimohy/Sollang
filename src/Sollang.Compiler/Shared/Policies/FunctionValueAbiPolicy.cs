namespace Sollang.Compiler.Shared;

#if !BUILDING_GENERATOR
[SelfHostPolicy("sollang.compiler.llvm.function_value_abi_policy",
    "selfhost/llvm/generated/function_value_abi_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/FunctionValueAbiPolicy.cs")]
#endif
internal static class FunctionValueAbiPolicy
{
    public static string UnitValueLlvmType() => "i8";
    public static string UnitValueLiteral() => "0";
}
