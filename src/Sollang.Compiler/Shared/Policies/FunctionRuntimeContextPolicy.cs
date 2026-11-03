namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.text",
    "selfhost/llvm/text/functions.slg",
    "src/Sollang.Compiler/Shared/Policies/FunctionRuntimeContextPolicy.cs", Region = "FunctionRuntimeContext")]
internal static class FunctionRuntimeContextPolicy
{
    public static string FunctionDefinitionPrefix() => "define internal ";

    public static string FunctionRuntimeContextParameters() =>
        "ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state";
}
