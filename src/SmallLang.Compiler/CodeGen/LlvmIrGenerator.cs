using SmallLang.Compiler.Semantics;

namespace SmallLang.Compiler.CodeGen;

internal static class LlvmIrGenerator
{
    public static string GenerateWindowsConsoleProgram(BoundProgram program)
    {
        return new WindowsRuntimeLlvmEmitter(program).Emit();
    }
}
