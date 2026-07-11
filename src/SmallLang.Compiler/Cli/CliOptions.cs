using SmallLang.Compiler.Diagnostics;

namespace SmallLang.Compiler.Cli;

internal sealed record CliOptions(
    IReadOnlyList<string> SourcePaths,
    string OutputPath,
    string? LlvmHome,
    CompilationTarget Target,
    bool KeepTemps)
{
    public static CliOptions Parse(string[] args)
    {
        if (args is not ["build", ..])
        {
            throw new SmallLangException("usage: smalllang build <source.sl> [more-source.sl ...] -o <output> [--target windows-x64|linux-x64|wasm32-browser] [--llvm <dir>] [--keep-temps]");
        }

        var sources = new List<string>();
        string? output = null;
        string? llvmHome = null;
        var target = CompilationTarget.WindowsX64;
        var keepTemps = false;

        for (var i = 1; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "-o":
                case "--output":
                    output = RequireValue(args, ref i, arg);
                    break;
                case "--llvm":
                    llvmHome = RequireValue(args, ref i, arg);
                    break;
                case "--target":
                    target = ParseTarget(RequireValue(args, ref i, arg));
                    break;
                case "--keep-temps":
                    keepTemps = true;
                    break;
                default:
                    if (arg.StartsWith("-", StringComparison.Ordinal))
                    {
                        throw new SmallLangException($"unknown option '{arg}'");
                    }

                    sources.Add(arg);
                    break;
            }
        }

        if (sources.Count == 0)
        {
            throw new SmallLangException("missing source file");
        }

        output ??= target switch
        {
            CompilationTarget.WindowsX64 => Path.ChangeExtension(sources[0], ".exe"),
            CompilationTarget.LinuxX64 => Path.Combine(
                Path.GetDirectoryName(sources[0]) ?? Directory.GetCurrentDirectory(),
                Path.GetFileNameWithoutExtension(sources[0])),
            CompilationTarget.Wasm32Browser => Path.ChangeExtension(sources[0], ".wasm"),
            _ => throw new SmallLangException($"unsupported target '{target}'")
        };

        return new CliOptions(
            sources.Select(Path.GetFullPath).ToArray(),
            Path.GetFullPath(output),
            llvmHome is null ? null : Path.GetFullPath(llvmHome),
            target,
            keepTemps);
    }

    private static CompilationTarget ParseTarget(string value)
    {
        return value switch
        {
            "windows-x64" => CompilationTarget.WindowsX64,
            "linux-x64" => CompilationTarget.LinuxX64,
            "wasm32-browser" => CompilationTarget.Wasm32Browser,
            _ => throw new SmallLangException($"unknown target '{value}'")
        };
    }

    private static string RequireValue(string[] args, ref int index, string option)
    {
        if (index + 1 >= args.Length)
        {
            throw new SmallLangException($"missing value for {option}");
        }

        index++;
        return args[index];
    }
}
