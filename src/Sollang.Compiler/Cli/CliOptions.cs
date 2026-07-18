using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Cli;

internal sealed record CliOptions(
    IReadOnlyList<string> SourcePaths,
    ProjectBuild? Project,
    string OutputPath,
    string? LlvmHome,
    CompilationTarget Target,
    bool KeepTemps,
    string? OptimizationLevel)
{
    public static CliOptions Parse(string[] args)
    {
        if (args is not ["build", ..])
        {
            throw new SollangException(Usage);
        }

        var sources = new List<string>();
        string? output = null;
        string? llvmHome = null;
        string? projectPath = null;
        string? productName = null;
        var target = CompilationTarget.WindowsX64;
        var keepTemps = false;
        string? optimizationLevel = null;

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
                case "--project":
                    projectPath = RequireValue(args, ref i, arg);
                    break;
                case "--product":
                    productName = RequireValue(args, ref i, arg);
                    break;
                case "--target":
                    target = ParseTarget(RequireValue(args, ref i, arg));
                    break;
                case "--keep-temps":
                    keepTemps = true;
                    break;
                case "-O0":
                case "-O1":
                case "-O2":
                case "-O3":
                    optimizationLevel = arg;
                    break;
                default:
                    if (arg.StartsWith("-", StringComparison.Ordinal))
                    {
                        throw new SollangException($"unknown option '{arg}'");
                    }

                    sources.Add(arg);
                    break;
            }
        }

        if (sources.Count > 0 && projectPath is not null)
        {
            throw new SollangException("--project cannot be combined with explicit source files");
        }
        if (sources.Count > 0 && productName is not null)
        {
            throw new SollangException("--product requires a project build");
        }

        ProjectBuild? project = null;
        if (sources.Count == 0)
        {
            projectPath ??= ProjectManifest.FindFrom(Directory.GetCurrentDirectory());
            if (projectPath is null)
            {
                throw new SollangException(
                    $"no source file or {ProjectManifest.FileName} was found; {Usage}");
            }
            project = ProjectBuild.Load(projectPath, productName);
            sources.Add(project.Product.RootSource);
        }

        output ??= project is null
            ? DefaultSourceOutput(sources[0], target)
            : DefaultProjectOutput(project, target);

        return new CliOptions(
            sources.Select(Path.GetFullPath).ToArray(),
            project,
            Path.GetFullPath(output),
            llvmHome is null ? null : Path.GetFullPath(llvmHome),
            target,
            keepTemps,
            optimizationLevel);
    }

    private static string DefaultSourceOutput(string source, CompilationTarget target) =>
        target switch
        {
            CompilationTarget.WindowsX64 => Path.ChangeExtension(source, ".exe"),
            CompilationTarget.LinuxX64 => Path.Combine(
                Path.GetDirectoryName(source) ?? Directory.GetCurrentDirectory(),
                Path.GetFileNameWithoutExtension(source)),
            CompilationTarget.Wasm32Browser => Path.ChangeExtension(source, ".wasm"),
            _ => throw new SollangException($"unsupported target '{target}'")
        };

    private static string DefaultProjectOutput(ProjectBuild project, CompilationTarget target) =>
        Path.Combine(
            project.RootPackage.Manifest.Directory,
            "build",
            target switch
            {
                CompilationTarget.WindowsX64 => project.Product.Name + ".exe",
                CompilationTarget.LinuxX64 => project.Product.Name,
                CompilationTarget.Wasm32Browser => project.Product.Name + ".wasm",
                _ => throw new SollangException($"unsupported target '{target}'")
            });

    private const string Usage =
        "usage: sollang build [<source.slg> ... | --project <sollang.project|directory>] [--product <name>] "
        + "[-o <output>] [--target windows-x64|linux-x64|wasm32-browser] "
        + "[--llvm <dir>] [-O0|-O1|-O2|-O3] [--keep-temps]";

    private static CompilationTarget ParseTarget(string value)
    {
        return value switch
        {
            "windows-x64" => CompilationTarget.WindowsX64,
            "linux-x64" => CompilationTarget.LinuxX64,
            "wasm32-browser" => CompilationTarget.Wasm32Browser,
            _ => throw new SollangException($"unknown target '{value}'")
        };
    }

    private static string RequireValue(string[] args, ref int index, string option)
    {
        if (index + 1 >= args.Length)
        {
            throw new SollangException($"missing value for {option}");
        }

        index++;
        return args[index];
    }
}
