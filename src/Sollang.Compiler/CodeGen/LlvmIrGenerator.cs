using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal static class LlvmIrGenerator
{
    public static string GenerateProgram(BoundProgram program, CompilationTarget target)
    {
        return new LlvmEmitter(program, LlvmRuntimePlatform.Create(target)).Emit();
    }

    public static void WriteProgram(BoundProgram program, CompilationTarget target, TextWriter writer)
    {
        var output = new TextWriterOutputSink(writer);
        new LlvmEmitter(program, LlvmRuntimePlatform.Create(target)).Emit(output);
    }
}
