namespace Sollang.Compiler.Shared;

[SelfHostPolicy("sollang.compiler.llvm.text",
    "selfhost/llvm/text/functions.slg",
    "src/Sollang.Compiler/Shared/Policies/FunctionRuntimeContextPolicy.cs", Region = "FunctionRuntimeContext")]
internal static class FunctionRuntimeContextPolicy
{
    internal const int AsyncInputField = (int)FunctionRuntimeContextSlot.Count;
    internal const int AsyncResultField = AsyncInputField + 1;
    internal const int AsyncChildHandleField = AsyncInputField + 2;
    internal const int AsyncChildContextField = AsyncInputField + 3;
    internal const int AsyncSpillFrameField = AsyncInputField + 4;
    internal const int AsyncAdditionalParameterStart = AsyncInputField + 5;

    public static ulong AsyncContextInputField() => (ulong)AsyncInputField;
    public static ulong AsyncContextResultField() => (ulong)AsyncResultField;
    public static ulong AsyncContextChildHandleField() => (ulong)AsyncChildHandleField;
    public static ulong AsyncContextChildContextField() => (ulong)AsyncChildContextField;
    public static ulong AsyncContextSpillFrameField() => (ulong)AsyncSpillFrameField;
    public static ulong AsyncContextAdditionalParameterStart() => (ulong)AsyncAdditionalParameterStart;

    public static string FunctionDefinitionPrefix() => "define internal ";
}
