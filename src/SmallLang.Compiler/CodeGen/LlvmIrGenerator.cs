using SmallLang.Compiler.Semantics;

namespace SmallLang.Compiler.CodeGen;

internal static class LlvmIrGenerator
{
    public static string GenerateConsoleProgram(BoundProgram program, CompilationTarget target)
    {
        return new ConsoleLlvmEmitter(program, LlvmRuntimePlatform.Create(target)).Emit();
    }
}
