using System.Text;
using SmallLang.Compiler.Diagnostics;

namespace SmallLang.Compiler.CodeGen;

internal abstract class LlvmRuntimePlatform
{
    public abstract string TargetTriple { get; }

    public abstract string EntryPointName { get; }

    public virtual void EmitGlobals(StringBuilder globals)
    {
    }

    public abstract void EmitExternalDeclarations(StringBuilder functions);

    public abstract void EmitIoPrimitives(StringBuilder functions);

    public abstract void EmitFilePrimitives(StringBuilder functions);

    public abstract void EmitEntryHandles(StringBuilder functions);

    public static LlvmRuntimePlatform Create(CompilationTarget target)
    {
        return target switch
        {
            CompilationTarget.WindowsX64 => new WindowsLlvmRuntimePlatform(),
            CompilationTarget.LinuxX64 => new LinuxLlvmRuntimePlatform(),
            _ => throw new SmallLangException($"unsupported target '{target}'")
        };
    }
}
