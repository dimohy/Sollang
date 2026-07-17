using SmallLang.Compiler.Diagnostics;

namespace SmallLang.Compiler.Tooling;

internal sealed record LlvmToolchain(
    string Home,
    string Clang,
    string LldLink,
    string LlvmLib,
    string LlvmSplit,
    string Opt,
    string Llc,
    string WasmLd)
{
    public static LlvmToolchain From(string? llvmHome)
    {
        var home = llvmHome
            ?? Environment.GetEnvironmentVariable("SLANG_LLVM_HOME")
            ?? throw new SmallLangException("LLVM toolchain not found. Run scripts\\smalllang.ps1 so LLVM is downloaded locally.");

        var bin = Path.Combine(home, "bin");
        var clang = Path.Combine(bin, "clang.exe");
        var lldLink = Path.Combine(bin, "lld-link.exe");
        var llvmLib = Path.Combine(bin, "llvm-lib.exe");
        var llvmSplit = Path.Combine(bin, "llvm-split.exe");
        var opt = Path.Combine(bin, "opt.exe");
        var llc = Path.Combine(bin, "llc.exe");
        var wasmLd = Path.Combine(bin, "wasm-ld.exe");

        RequireFile(clang, "clang.exe");
        RequireFile(lldLink, "lld-link.exe");
        RequireFile(llvmLib, "llvm-lib.exe");
        RequireFile(llvmSplit, "llvm-split.exe");
        RequireFile(opt, "opt.exe");
        RequireFile(llc, "llc.exe");
        RequireFile(wasmLd, "wasm-ld.exe");

        return new LlvmToolchain(home, clang, lldLink, llvmLib, llvmSplit, opt, llc, wasmLd);
    }

    private static void RequireFile(string path, string name)
    {
        if (!File.Exists(path))
        {
            throw new SmallLangException($"required LLVM tool '{name}' was not found at {path}");
        }
    }
}
