using System.Diagnostics;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Tooling;

namespace Sollang.Compiler.Cli;

internal static class CppBindingTool
{
    public static int Run(string[] args)
    {
        var options = CppBindingOptions.Parse(args);
        var toolchain = LlvmToolchain.From(options.LlvmHome);
        var result = CppBindingGenerator.Generate(options, toolchain);

        Directory.CreateDirectory(options.OutputDirectory);
        File.WriteAllText(result.SollangPath, result.SollangSource);
        File.WriteAllText(result.ShimPath, result.ShimSource);
        File.WriteAllBytes(result.ManifestPath, result.Manifest);

        if (options.Build)
        {
            BuildShim(options, toolchain, result);
        }

        Console.WriteLine($"C++ binding: {result.FunctionCount} functions");
        Console.WriteLine(result.SollangPath);
        Console.WriteLine(result.ShimPath);
        Console.WriteLine(result.ManifestPath);
        if (options.Build)
        {
            Console.WriteLine(result.LibraryPath);
        }
        return 0;
    }

    private static void BuildShim(
        CppBindingOptions options,
        LlvmToolchain toolchain,
        CppBindingResult result)
    {
        var hostTarget = OperatingSystem.IsWindows()
            ? CompilationTarget.WindowsX64
            : OperatingSystem.IsLinux()
                ? CompilationTarget.LinuxX64
                : throw new SollangException("C++ shim builds require a Windows or Linux host");
        if (hostTarget != options.Target)
        {
            throw new SollangException(
                $"--build target must match the current host; requested {options.TargetName}");
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = toolchain.Clang,
            UseShellExecute = false
        };
        foreach (var argument in new[]
        {
            "-x", "c++", "-std=c++20", "-shared", "-O2",
            result.ShimPath, "-o", result.LibraryPath
        })
        {
            startInfo.ArgumentList.Add(argument);
        }
        foreach (var argument in options.BuildArguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo)
            ?? throw new SollangException("failed to start Clang for the generated C++ shim");
        process.WaitForExit();
        if (process.ExitCode != 0)
        {
            throw new SollangException(
                $"Clang failed to build the generated C++ shim (exit {process.ExitCode})");
        }
    }
}

internal sealed record CppBindingOptions(
    string HeaderPath,
    string ModuleName,
    string LibraryName,
    string OutputDirectory,
    string? LlvmHome,
    CompilationTarget Target,
    string? CompilationDatabase,
    string? CompilationEntry,
    IReadOnlyList<string> ClangArguments,
    IReadOnlyList<string> BuildArguments,
    bool Build)
{
    public string TargetName => Target switch
    {
        CompilationTarget.WindowsX64 => "windows-x64",
        CompilationTarget.LinuxX64 => "linux-x64",
        _ => "unsupported"
    };

    public static CppBindingOptions Parse(string[] args)
    {
        string? header = null;
        string? module = null;
        string? library = null;
        string? output = null;
        string? llvm = null;
        string? compilationDatabase = null;
        string? compilationEntry = null;
        var target = OperatingSystem.IsLinux()
            ? CompilationTarget.LinuxX64
            : CompilationTarget.WindowsX64;
        var clangArguments = new List<string>();
        var buildArguments = new List<string>();
        var build = false;
        var afterSeparator = false;

        for (var index = 0; index < args.Length; index++)
        {
            var argument = args[index];
            if (afterSeparator)
            {
                clangArguments.Add(argument);
                continue;
            }
            switch (argument)
            {
                case "--":
                    afterSeparator = true;
                    break;
                case "--module":
                    module = RequireValue(args, ref index, argument);
                    break;
                case "--library":
                    library = RequireValue(args, ref index, argument);
                    break;
                case "-o":
                case "--output":
                    output = RequireValue(args, ref index, argument);
                    break;
                case "--llvm":
                    llvm = RequireValue(args, ref index, argument);
                    break;
                case "--target":
                    target = RequireValue(args, ref index, argument) switch
                    {
                        "windows-x64" => CompilationTarget.WindowsX64,
                        "linux-x64" => CompilationTarget.LinuxX64,
                        var value => throw new SollangException(
                            $"unsupported C++ binding target '{value}'")
                    };
                    break;
                case "--compile-commands":
                    compilationDatabase = RequireValue(args, ref index, argument);
                    break;
                case "--compile-entry":
                    compilationEntry = RequireValue(args, ref index, argument);
                    break;
                case "--clang-arg":
                    clangArguments.Add(RequireValue(args, ref index, argument));
                    break;
                case "--build-arg":
                    buildArguments.Add(RequireValue(args, ref index, argument));
                    break;
                case "--build":
                    build = true;
                    break;
                default:
                    if (argument.StartsWith("-", StringComparison.Ordinal))
                    {
                        throw new SollangException($"unknown bind-cpp option '{argument}'");
                    }
                    if (header is not null)
                    {
                        throw new SollangException("bind-cpp accepts exactly one header");
                    }
                    header = argument;
                    break;
            }
        }

        if (header is null)
        {
            throw new SollangException(Usage);
        }
        header = Path.GetFullPath(header);
        if (!File.Exists(header))
        {
            throw new SollangException($"C++ header was not found: {header}");
        }
        module ??= SanitizeIdentifier(Path.GetFileNameWithoutExtension(header));
        if (!IsIdentifier(module))
        {
            throw new SollangException($"invalid Sollang module name '{module}'");
        }
        library ??= module + "_shim";
        output = Path.GetFullPath(output ?? Path.Combine(
            Directory.GetCurrentDirectory(),
            "generated",
            module));

        return new CppBindingOptions(
            header,
            module,
            library,
            output,
            llvm is null ? null : Path.GetFullPath(llvm),
            target,
            compilationDatabase is null ? null : Path.GetFullPath(compilationDatabase),
            compilationEntry is null ? null : Path.GetFullPath(compilationEntry),
            clangArguments,
            buildArguments,
            build);
    }

    private static string RequireValue(string[] args, ref int index, string option)
    {
        if (++index >= args.Length)
        {
            throw new SollangException($"{option} requires a value");
        }
        return args[index];
    }

    private static bool IsIdentifier(string value) =>
        value.Length > 0
        && (char.IsLetter(value[0]) || value[0] == '_')
        && value.All(character => char.IsLetterOrDigit(character) || character == '_');

    private static string SanitizeIdentifier(string value)
    {
        var result = new string(value.Select(character =>
            char.IsLetterOrDigit(character) || character == '_' ? character : '_').ToArray());
        return result.Length > 0 && char.IsDigit(result[0]) ? "_" + result : result;
    }

    private const string Usage =
        "usage: sollang bind-cpp <header.hpp> [--module <name>] [--library <logical-path>] "
        + "[-o|--output <directory>] [--target windows-x64|linux-x64] [--llvm <directory>] "
        + "[--compile-commands <file-or-directory> [--compile-entry <source.cpp>]] "
        + "[--clang-arg <argument>] [--build [--build-arg <argument>]] [-- <clang arguments>]";
}
