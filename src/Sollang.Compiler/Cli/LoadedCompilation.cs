using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Cli;

internal sealed record LoadedCompilation(
    SollangProgram Program,
    IReadOnlyList<CompilationSource> Sources);

internal sealed record CompilationSource(
    string Path,
    SollangProgram Program,
    ProjectPackage? Package,
    bool IsStandardLibrary,
    byte[] SourceBytes,
    IReadOnlyList<CompilationInput>? AdditionalInputs = null)
{
    public string ModuleName => string.Join('.', Program.NamespacePath);
}

internal sealed record CompilationInput(string Path, byte[] Bytes);
