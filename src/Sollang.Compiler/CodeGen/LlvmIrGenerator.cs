using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal static class LlvmIrGenerator
{
    public static string GenerateProgram(
        BoundProgram program,
        CompilationTarget target,
        bool sharedLibrary = false)
    {
        return new LlvmEmitter(program, LlvmRuntimePlatform.Create(target), sharedLibrary).Emit();
    }

    public static void WriteProgram(
        BoundProgram program,
        CompilationTarget target,
        TextWriter writer,
        bool sharedLibrary = false)
    {
        var output = new TextWriterOutputSink(writer);
        new LlvmEmitter(program, LlvmRuntimePlatform.Create(target), sharedLibrary).Emit(output);
    }

    public static LlvmCodegenOutput GenerateUnits(
        BoundProgram program,
        CompilationTarget target,
        LlvmCodegenReuse reuse,
        bool sharedLibrary = false)
    {
        return new LlvmEmitter(program, LlvmRuntimePlatform.Create(target), sharedLibrary).EmitUnits(reuse);
    }
}
