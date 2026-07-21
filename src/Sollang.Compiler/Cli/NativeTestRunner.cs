using System.Diagnostics;
using System.Globalization;
using System.Text;
using Sollang.Compiler.CodeGen;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Lexing;
using Sollang.Compiler.Parsing;
using Sollang.Compiler.Syntax;
using Sollang.Compiler.Tooling;

namespace Sollang.Compiler.Cli;

internal static class NativeTestRunner
{
    private const string TestPrefix = "test_";

    public static int Run(string[] args)
    {
        var (buildArgs, filter) = ParseArguments(args);
        var options = CliOptions.Parse(buildArgs);
        if (options.Target == CompilationTarget.Wasm32Browser)
        {
            throw new SollangException("sollang test requires a native windows-x64 or linux-x64 target");
        }

        var sourcePaths = DiscoverTestSources(options);
        options = options with
        {
            SourcePaths = sourcePaths,
            OutputPath = TestOutputPath(options)
        };
        var loaded = CompilerApp.LoadProgram(options.SourcePaths, options.Project);
        var selected = SelectTests(loaded, options.Project, filter);
        var harness = BuildHarness(loaded.Program, selected);

        CompilerApp.CompileStandalone(options, harness);
        return Execute(options);
    }

    private static (string[] BuildArgs, string? Filter) ParseArguments(IReadOnlyList<string> args)
    {
        var buildArgs = new List<string> { "build" };
        string? filter = null;
        for (var index = 1; index < args.Count; index++)
        {
            if (args[index] != "--filter")
            {
                buildArgs.Add(args[index]);
                continue;
            }
            if (filter is not null)
            {
                throw new SollangException("--filter may be specified only once");
            }
            if (++index >= args.Count)
            {
                throw new SollangException("missing value for --filter");
            }
            filter = args[index];
        }
        return (buildArgs.ToArray(), filter);
    }

    private static IReadOnlyList<string> DiscoverTestSources(CliOptions options)
    {
        if (options.Project is null)
        {
            return options.SourcePaths;
        }

        var testsRoot = Path.Combine(options.Project.RootPackage.Manifest.Directory, "tests");
        if (!Directory.Exists(testsRoot))
        {
            return options.SourcePaths;
        }

        var known = options.SourcePaths
            .Select(Path.GetFullPath)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var discovered = Directory.EnumerateFiles(testsRoot, "*.slg", SearchOption.AllDirectories)
            .Select(Path.GetFullPath)
            .Where(known.Add)
            .Order(StringComparer.OrdinalIgnoreCase);
        return options.SourcePaths.Concat(discovered).ToArray();
    }

    private static IReadOnlyList<TestFunction> SelectTests(
        LoadedCompilation loaded,
        ProjectBuild? project,
        string? filter)
    {
        var candidates = loaded.Sources
            .Where(source => IsTestSource(source, project))
            .SelectMany(static source => source.Program.Functions)
            .Where(static function => SimpleName(function).StartsWith(TestPrefix, StringComparison.Ordinal))
            .ToArray();

        foreach (var function in candidates)
        {
            if (function.InputName is not null
                || function.BlockInputName is not null
                || function.AdditionalParameters is { Count: > 0 }
                || function.ReturnType != "Bool"
                || function.GenericParameterName is not null
                || function.SecondaryGenericParameterName is not null
                || function.TertiaryGenericParameterName is not null
                || function.IsValueGeneric
                || function.TraitName is not null
                || function.IsIntrinsic)
            {
                throw new SollangException(
                    $"test function '{QualifiedName(function)}' must be a non-generic, zero-input, non-intrinsic function returning Bool");
            }
        }

        var selected = candidates
            .Select(static function => new TestFunction(function, QualifiedName(function)))
            .Where(test => filter is null || test.Name.Contains(filter, StringComparison.Ordinal))
            .OrderBy(static test => test.Name, StringComparer.Ordinal)
            .ToArray();
        if (selected.Length == 0)
        {
            var available = string.Join(", ", loaded.Sources
                .Where(source => IsTestSource(source, project))
                .SelectMany(static source => source.Program.Functions)
                .Select(QualifiedName)
                .Order(StringComparer.Ordinal));
            throw new SollangException(filter is null
                ? $"no tests found; declare a zero-input Bool function whose name starts with '{TestPrefix}'"
                    + (available.Length == 0 ? "" : $"; available functions: {available}")
                : $"no tests matched filter '{filter}'");
        }
        if (selected.Select(static test => test.Name).Distinct(StringComparer.Ordinal).Count() != selected.Length)
        {
            throw new SollangException("test names must be unique after module qualification");
        }
        return selected;
    }

    private static SollangProgram BuildHarness(SollangProgram program, IReadOnlyList<TestFunction> tests)
    {
        var source = new StringBuilder();
        source.AppendLine("import sys.io as io");
        source.AppendLine("import sys.process as process");
        var moduleAliases = tests
            .Select(static test => test.Function.ModuleName)
            .Where(static module => module.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .Select(static (module, index) => (Module: module, Alias: $"test_module_{index}"))
            .ToDictionary(static item => item.Module, static item => item.Alias, StringComparer.Ordinal);
        foreach (var module in moduleAliases)
        {
            source.Append("import ").Append(module.Key).Append(" as ").AppendLine(module.Value);
        }
        source.AppendLine("main {");
        source.AppendLine("    0 => failures!");
        source.Append("    \"running ")
            .Append(tests.Count.ToString(CultureInfo.InvariantCulture))
            .AppendLine(" tests\" -> io.println");
        foreach (var test in tests)
        {
            var invocation = test.Function.ModuleName.Length == 0
                ? SimpleName(test.Function)
                : moduleAliases[test.Function.ModuleName] + "." + SimpleName(test.Function);
            source.Append("    ").Append(invocation).AppendLine(" -> if {");
            source.Append("        \"test ").Append(test.Name).AppendLine(" ... ok\" -> io.println");
            source.AppendLine("    } else {");
            source.Append("        \"test ").Append(test.Name).AppendLine(" ... FAILED\" -> io.println");
            source.AppendLine("        failures! + 1 => failures!");
            source.AppendLine("    }");
        }
        source.Append("    \"test result: $(")
            .Append(tests.Count.ToString(CultureInfo.InvariantCulture))
            .AppendLine(" - failures!) passed; $(failures!) failed\" -> io.println")
            .AppendLine("    failures! == 0 -> if {")
            .AppendLine("        0 -> process.exit")
            .AppendLine("    } else {")
            .AppendLine("        1 -> process.exit")
            .AppendLine("    }")
            .AppendLine("}");

        var harness = new Parser(new Lexer(source.ToString()).Lex()).Parse();
        var selected = tests.Select(static test => test.Function).ToHashSet(ReferenceEqualityComparer.Instance);
        return new SollangProgram(
            [],
            [],
            program.Structs,
            program.Enums,
            program.Traits,
            program.Functions.Select(function => selected.Contains(function)
                    ? function with { IsPublic = true }
                    : function)
                .ToArray(),
            harness.Statements);
    }

    private static string TestOutputPath(CliOptions options)
    {
        var root = options.Project?.Workspace?.Directory
            ?? options.Project?.RootPackage.Manifest.Directory
            ?? Path.GetDirectoryName(options.SourcePaths[0])
            ?? Directory.GetCurrentDirectory();
        var target = options.Target == CompilationTarget.WindowsX64 ? "windows-x64" : "linux-x64";
        var name = options.Project?.Product.Name
            ?? Path.GetFileNameWithoutExtension(options.SourcePaths[0]);
        var extension = options.Target == CompilationTarget.WindowsX64 ? ".tests.exe" : ".tests";
        return Path.Combine(root, ".sollang", "test", target, name + extension);
    }

    private static int Execute(CliOptions options)
    {
        var start = options.Target == CompilationTarget.LinuxX64 && OperatingSystem.IsWindows()
            ? CreateWslStart(options.OutputPath)
            : new ProcessStartInfo(options.OutputPath);
        start.UseShellExecute = false;
        start.RedirectStandardOutput = true;
        start.RedirectStandardError = true;

        using var process = Process.Start(start)
            ?? throw new SollangException($"failed to start native test executable: {options.OutputPath}");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit((int)TimeSpan.FromMinutes(5).TotalMilliseconds))
        {
            process.Kill(entireProcessTree: true);
            throw new SollangException("native test executable exceeded the five-minute timeout");
        }
        Task.WaitAll(stdout, stderr);
        Console.Out.Write(stdout.Result);
        Console.Error.Write(stderr.Result);
        return process.ExitCode;
    }

    private static ProcessStartInfo CreateWslStart(string outputPath)
    {
        var start = new ProcessStartInfo("wsl.exe");
        start.ArgumentList.Add("--exec");
        start.ArgumentList.Add(WslLinuxLinker.ToWslPath(outputPath));
        return start;
    }

    private static string QualifiedName(FunctionDeclaration function) =>
        function.ModuleName.Length == 0
            || function.Name.StartsWith(function.ModuleName + ".", StringComparison.Ordinal)
                ? function.Name
                : function.ModuleName + "." + function.Name;

    private static bool IsTestSource(CompilationSource source, ProjectBuild? project)
    {
        if (source.IsStandardLibrary)
        {
            return false;
        }
        if (project is null)
        {
            return true;
        }
        return source.Package is not null
            && StringComparer.OrdinalIgnoreCase.Equals(
                source.Package.Manifest.Path,
                project.RootPackage.Manifest.Path);
    }

    private static string SimpleName(FunctionDeclaration function)
    {
        var separator = function.Name.LastIndexOf('.');
        return separator < 0 ? function.Name : function.Name[(separator + 1)..];
    }

    private sealed record TestFunction(FunctionDeclaration Function, string Name);
}
