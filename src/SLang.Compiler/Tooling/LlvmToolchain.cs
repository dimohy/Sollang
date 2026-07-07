using SLang.Compiler.Diagnostics;

namespace SLang.Compiler.Tooling;

internal sealed record LlvmToolchain(string Home, string Clang, string LldLink, string LlvmLib)
{
    public static LlvmToolchain From(string? llvmHome)
    {
        var home = llvmHome
            ?? Environment.GetEnvironmentVariable("SLANG_LLVM_HOME")
            ?? throw new SlangException("LLVM toolchain not found. Run scripts\\slang.ps1 so LLVM is downloaded locally.");

        var bin = Path.Combine(home, "bin");
        var clang = Path.Combine(bin, "clang.exe");
        var lldLink = Path.Combine(bin, "lld-link.exe");
        var llvmLib = Path.Combine(bin, "llvm-lib.exe");

        RequireFile(clang, "clang.exe");
        RequireFile(lldLink, "lld-link.exe");
        RequireFile(llvmLib, "llvm-lib.exe");

        return new LlvmToolchain(home, clang, lldLink, llvmLib);
    }

    private static void RequireFile(string path, string name)
    {
        if (!File.Exists(path))
        {
            throw new SlangException($"required LLVM tool '{name}' was not found at {path}");
        }
    }
}
