using SLang.Compiler.Semantics;

namespace SLang.Compiler.CodeGen;

internal static class LlvmIrGenerator
{
    public static string GenerateWindowsConsoleProgram(BoundProgram program)
    {
        return new WindowsRuntimeLlvmEmitter(program).Emit();
    }
}
