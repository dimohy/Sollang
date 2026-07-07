using SLang.Compiler.Diagnostics;

namespace SLang.Compiler.Cli;

internal sealed record CliOptions(
    string SourcePath,
    string OutputPath,
    string? LlvmHome,
    bool KeepTemps)
{
    public static CliOptions Parse(string[] args)
    {
        if (args is not ["build", ..])
        {
            throw new SlangException("usage: slang build <source.slang> -o <output.exe> [--llvm <dir>] [--keep-temps]");
        }

        string? source = null;
        string? output = null;
        string? llvmHome = null;
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
                case "--keep-temps":
                    keepTemps = true;
                    break;
                default:
                    if (arg.StartsWith("-", StringComparison.Ordinal))
                    {
                        throw new SlangException($"unknown option '{arg}'");
                    }

                    if (source is not null)
                    {
                        throw new SlangException($"multiple source files are not supported yet: '{source}' and '{arg}'");
                    }

                    source = arg;
                    break;
            }
        }

        if (source is null)
        {
            throw new SlangException("missing source file");
        }

        output ??= Path.ChangeExtension(source, ".exe");

        return new CliOptions(
            Path.GetFullPath(source),
            Path.GetFullPath(output),
            llvmHome is null ? null : Path.GetFullPath(llvmHome),
            keepTemps);
    }

    private static string RequireValue(string[] args, ref int index, string option)
    {
        if (index + 1 >= args.Length)
        {
            throw new SlangException($"missing value for {option}");
        }

        index++;
        return args[index];
    }
}
