using System.Diagnostics;
using System.Globalization;
using System.Text;
using Sollang.Compiler.CodeGen;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Lexing;
using Sollang.Compiler.Parsing;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;
using Sollang.Compiler.Tooling;

namespace Sollang.Compiler.Cli;

internal static class CompilerApp
{
    public static int Run(string[] args)
    {
        try
        {
            if (args is ["--version"] or ["-v"])
            {
                Console.WriteLine($"Sollang {CompilerVersion.Current}");
                return 0;
            }
            if (args.Length >= 2 && args[0] == "grammar" && args[1] == "build")
            {
                GrammarCompiler.Build(args[2..]);
                return 0;
            }
            if (args is ["resolve", ..])
            {
                return PackageLock.Resolve(args);
            }
            if (args is ["format", ..])
            {
                return SourceFormatter.Run(args[1..]);
            }
            if (args is ["language-server", ..])
            {
                return LanguageServer.Run(args[1..]);
            }
            if (args is ["test", ..])
            {
                return NativeTestRunner.Run(args);
            }
            if (args is ["run", ..])
            {
                return RunProgram(args);
            }
            var options = CliOptions.Parse(args);
            Build(options);
            return 0;
        }
        catch (SollangException ex)
        {
            Console.Error.WriteLine($"sollang: {ex.Message}");
            return 1;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"sollang: unexpected failure: {ex.Message}");
            return 1;
        }
    }

    private static int RunProgram(string[] args)
    {
        var separatorIndex = Array.IndexOf(args, "--");
        var buildArgs = (separatorIndex < 0 ? args : args[..separatorIndex]).ToList();
        var programArgs = separatorIndex < 0 ? [] : args[(separatorIndex + 1)..];
        buildArgs[0] = "build";

        var hostTarget = OperatingSystem.IsWindows()
            ? CompilationTarget.WindowsX64
            : OperatingSystem.IsLinux()
                ? CompilationTarget.LinuxX64
                : throw new SollangException("run is supported only on Windows and Linux hosts");
        if (!buildArgs.Contains("--target", StringComparer.Ordinal))
        {
            buildArgs.Add("--target");
            buildArgs.Add(TargetName(hostTarget));
        }

        var options = CliOptions.Parse([.. buildArgs]);
        if (options.Target != hostTarget)
        {
            throw new SollangException(
                $"run target must match the current host ({TargetName(hostTarget)}); "
                + $"received {TargetName(options.Target)}");
        }

        BuildSilently(options);
        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = options.OutputPath,
            UseShellExecute = false
        }.WithArguments(programArgs))
            ?? throw new SollangException($"failed to start '{options.OutputPath}'");
        process.WaitForExit();
        return process.ExitCode;
    }

    private static void BuildSilently(CliOptions options)
    {
        var originalOutput = Console.Out;
        try
        {
            Console.SetOut(TextWriter.Null);
            Build(options);
        }
        finally
        {
            Console.SetOut(originalOutput);
        }
    }

    private static ProcessStartInfo WithArguments(
        this ProcessStartInfo startInfo,
        IReadOnlyList<string> arguments)
    {
        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }
        return startInfo;
    }

    private static string TargetName(CompilationTarget target) => target switch
    {
        CompilationTarget.WindowsX64 => "windows-x64",
        CompilationTarget.LinuxX64 => "linux-x64",
        CompilationTarget.Wasm32Browser => "wasm32-browser",
        _ => throw new SollangException($"unsupported target '{target}'")
    };

    private static void Build(CliOptions options)
    {
        var toolchain = LlvmToolchain.From(options.LlvmHome);
        Directory.CreateDirectory(Path.GetDirectoryName(options.OutputPath)
            ?? Directory.GetCurrentDirectory());
        var frontendCache = IncrementalFrontendCache.Open(options);
        if (frontendCache.Output is not null)
        {
            var productCache = IncrementalProductCache.Open(
                frontendCache.Location,
                options.OutputPath,
                frontendCache.SourceGenerationKey!);
            if (!productCache.IsExact)
            {
                WriteAndLink(options, toolchain, frontendCache.Output);
                IncrementalProductCache.Publish(frontendCache.Location, options.OutputPath);
            }
            else if (options.KeepTemps)
            {
                WriteKeptLlvm(options.OutputPath, frontendCache.Output);
            }
            Console.WriteLine(
                $"[frontend-cache] {frontendCache.Status}; skipped parsing and semantic analysis for "
                + $"{frontendCache.SourceCount.ToString(CultureInfo.InvariantCulture)} sources; "
                + frontendCache.Location.SourceSnapshotPath);
            Console.WriteLine(
                $"[codegen-cache] exact; reused "
                + $"{frontendCache.Output.ReusedCount.ToString(CultureInfo.InvariantCulture)}/"
                + $"{frontendCache.Output.Units.Count.ToString(CultureInfo.InvariantCulture)} units; "
                + frontendCache.Location.CodegenPath);
            Console.WriteLine(
                $"[semantic-cache] exact via frontend; skipped semantic loading; "
                + frontendCache.Location.SemanticPath);
            Console.WriteLine(
                $"[product-cache] {productCache.Status}; "
                + (productCache.IsExact ? "skipped linking; " : "linked and published; ")
                + frontendCache.Location.ProductPath);
            PrintOutput(options.OutputPath);
            return;
        }

        var loaded = LoadProgram(options.SourcePaths, options.Project);
        var pointerBitWidth = options.Target == CompilationTarget.Wasm32Browser ? 32 : 64;
        var semanticProbe = IncrementalSemanticCache.Probe(frontendCache.Location, loaded);
        var boundProgram = new SemanticCompiler(loaded.Program, pointerBitWidth)
            .Compile(semanticProbe.ReusePlan);
        var semanticCache = IncrementalSemanticCache.Create(
            frontendCache.Location,
            loaded,
            boundProgram,
            semanticProbe);
        var codegenCache = IncrementalCodegenCache.Open(loaded, boundProgram, options);
        var codegenOutput = LlvmIrGenerator.GenerateUnits(boundProgram, options.Target, codegenCache.Reuse);
        WriteAndLink(options, toolchain, codegenOutput);
        codegenCache.Publish(codegenOutput);
        semanticCache.Publish();
        IncrementalFrontendCache.Publish(loaded, options, codegenCache.Location);
        IncrementalProductCache.Publish(codegenCache.Location, options.OutputPath);
        Console.WriteLine(
            $"[frontend-cache] {frontendCache.Status}; rebuilt and published "
            + $"{loaded.Sources.Count.ToString(CultureInfo.InvariantCulture)} sources; "
            + codegenCache.Location.SourceSnapshotPath);
        Console.WriteLine(
            $"[codegen-cache] {codegenCache.LoadStatus}; reused "
            + $"{codegenOutput.ReusedCount.ToString(CultureInfo.InvariantCulture)}/"
            + $"{codegenOutput.Units.Count.ToString(CultureInfo.InvariantCulture)} units; "
            + codegenCache.Path);
        Console.WriteLine(
            $"[semantic-cache] {semanticCache.Status}; reused "
            + $"{semanticCache.ReusedFunctions.ToString(CultureInfo.InvariantCulture)}/"
            + $"{semanticCache.TotalReusableFunctions.ToString(CultureInfo.InvariantCulture)} functions; main "
            + (semanticCache.ReusedMainSemantics ? "reused; mapped " : "rebuilt; mapped ")
            + $"{semanticCache.MappedFunctions.ToString(CultureInfo.InvariantCulture)}/"
            + $"{semanticCache.TotalFunctions.ToString(CultureInfo.InvariantCulture)} functions, "
            + $"{semanticCache.MappedCalls.ToString(CultureInfo.InvariantCulture)}/"
            + $"{semanticCache.TotalCalls.ToString(CultureInfo.InvariantCulture)} call sites; "
            + semanticCache.Path);
        Console.WriteLine(
            $"[product-cache] rebuilt; linked and published; {codegenCache.Location.ProductPath}");
        PrintOutput(options.OutputPath);
    }

    private static void WriteAndLink(
        CliOptions options,
        LlvmToolchain toolchain,
        LlvmCodegenOutput codegenOutput)
    {
        var workDir = Path.Combine(
            Path.GetDirectoryName(Path.GetFullPath(options.OutputPath))
                ?? Directory.GetCurrentDirectory(),
            Path.GetFileNameWithoutExtension(options.OutputPath) + ".slg-tmp");

        if (Directory.Exists(workDir))
        {
            Directory.Delete(workDir, recursive: true);
        }

        Directory.CreateDirectory(workDir);

        try
        {
            var llPath = Path.Combine(workDir, Path.GetFileNameWithoutExtension(options.OutputPath) + ".ll");
            using (var writer = new StreamWriter(
                llPath,
                append: false,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false)))
            {
                codegenOutput.CopyTo(new TextWriterOutputSink(writer));
            }
            LinkLlvmIr(options, toolchain, llPath, workDir);

            if (options.KeepTemps)
            {
                var keptLlPath = Path.ChangeExtension(options.OutputPath, ".ll");
                File.Copy(llPath, keptLlPath, overwrite: true);
            }
        }
        finally
        {
            if (!options.KeepTemps && Directory.Exists(workDir))
            {
                Directory.Delete(workDir, recursive: true);
            }
        }
    }

    private static void WriteKeptLlvm(string outputPath, LlvmCodegenOutput codegenOutput)
    {
        using var writer = new StreamWriter(
            Path.ChangeExtension(outputPath, ".ll"),
            append: false,
            new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        codegenOutput.CopyTo(new TextWriterOutputSink(writer));
    }

    internal static void CompileStandalone(CliOptions options, SollangProgram program)
    {
        var toolchain = LlvmToolchain.From(options.LlvmHome);
        Directory.CreateDirectory(Path.GetDirectoryName(options.OutputPath)
            ?? Directory.GetCurrentDirectory());
        var pointerBitWidth = options.Target == CompilationTarget.Wasm32Browser ? 32 : 64;
        var boundProgram = new SemanticCompiler(program, pointerBitWidth).Compile();
        WriteAndLinkStandalone(options, toolchain, boundProgram);
        PrintOutput(options.OutputPath);
    }

    private static void WriteAndLinkStandalone(
        CliOptions options,
        LlvmToolchain toolchain,
        BoundProgram program)
    {
        var workDir = Path.Combine(
            Path.GetDirectoryName(Path.GetFullPath(options.OutputPath))
                ?? Directory.GetCurrentDirectory(),
            Path.GetFileNameWithoutExtension(options.OutputPath) + ".slg-tmp");

        if (Directory.Exists(workDir))
        {
            Directory.Delete(workDir, recursive: true);
        }

        Directory.CreateDirectory(workDir);
        try
        {
            var llPath = Path.Combine(workDir, Path.GetFileNameWithoutExtension(options.OutputPath) + ".ll");
            using (var writer = new StreamWriter(
                llPath,
                append: false,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false)))
            {
                LlvmIrGenerator.WriteProgram(program, options.Target, writer);
            }
            LinkLlvmIr(options, toolchain, llPath, workDir);

            if (options.KeepTemps)
            {
                File.Copy(llPath, Path.ChangeExtension(options.OutputPath, ".ll"), overwrite: true);
            }
        }
        finally
        {
            if (!options.KeepTemps && Directory.Exists(workDir))
            {
                Directory.Delete(workDir, recursive: true);
            }
        }
    }

    private static void PrintOutput(string outputPath)
    {
        var exeInfo = new FileInfo(outputPath);
        Console.WriteLine($"Wrote {exeInfo.FullName} ({exeInfo.Length.ToString("N0", CultureInfo.InvariantCulture)} bytes)");
    }

    private static void LinkLlvmIr(CliOptions options, LlvmToolchain toolchain, string llPath, string workDir)
    {
        switch (options.Target)
        {
            case CompilationTarget.WindowsX64:
                new WindowsLinker(toolchain).LinkLlvmIr(llPath, options.OutputPath, workDir, options.OptimizationLevel);
                break;
            case CompilationTarget.LinuxX64:
                new WslLinuxLinker(toolchain).LinkLlvmIr(llPath, options.OutputPath, workDir, options.OptimizationLevel);
                break;
            case CompilationTarget.Wasm32Browser:
                new WasmBrowserLinker(toolchain).LinkLlvmIr(llPath, options.OutputPath, workDir, options.OptimizationLevel);
                break;
            default:
                throw new SollangException($"unsupported target '{options.Target}'");
        }
    }

    internal static LoadedCompilation LoadProgram(
        IReadOnlyList<string> sourcePaths,
        ProjectBuild? project)
    {
        var standardLibrary = LoadStandardLibrary(sourcePaths[0]);
        var sourcePrograms = LoadUserPrograms(sourcePaths, project);
        var modules = standardLibrary
            .Concat(sourcePrograms)
            .Where(static source => source.ModuleName.Length > 0)
            .ToDictionary(static source => source.ModuleName, StringComparer.Ordinal);
        standardLibrary = ReparseOpenImports(standardLibrary, modules);
        sourcePrograms = ReparseOpenImports(sourcePrograms, modules);
        var executableFiles = sourcePrograms.Where(static source => source.Program.Statements.Count > 0).ToArray();
        if (executableFiles.Length > 1)
        {
            throw new SollangException("multiple source files contain executable top-level statements; exactly one root file may define the program entry point");
        }

        var program = new SollangProgram(
            [],
            [],
            standardLibrary.SelectMany(static source => source.Program.Structs)
                .Concat(sourcePrograms.SelectMany(static source => source.Program.Structs))
                .ToArray(),
            standardLibrary.SelectMany(static source => source.Program.Enums)
                .Concat(sourcePrograms.SelectMany(static source => source.Program.Enums))
                .ToArray(),
            standardLibrary.SelectMany(static source => source.Program.Traits)
                .Concat(sourcePrograms.SelectMany(static source => source.Program.Traits))
                .ToArray(),
            standardLibrary.SelectMany(static source => source.Program.Functions)
                .Concat(sourcePrograms.SelectMany(static source => source.Program.Functions))
                .ToArray(),
            sourcePrograms.SelectMany(static source => source.Program.Statements).ToArray());
        return new LoadedCompilation(program, standardLibrary.Concat(sourcePrograms).ToArray());
    }

    private static IReadOnlyList<CompilationSource> ReparseOpenImports(
        IReadOnlyList<CompilationSource> sources,
        IReadOnlyDictionary<string, CompilationSource> modules)
    {
        return sources.Select(source =>
        {
            var openImports = BuildOpenImports(source, modules);
            if (openImports.Count == 0)
            {
                return source;
            }

            var parsed = ParseSourceFile(source.Path, source.IsStandardLibrary, openImports);
            return source with { Program = parsed.Program, SourceBytes = parsed.SourceBytes };
        }).ToArray();
    }

    private static IReadOnlyDictionary<string, IReadOnlyList<OpenImportCandidate>> BuildOpenImports(
        CompilationSource source,
        IReadOnlyDictionary<string, CompilationSource> modules)
    {
        var localNames = DirectDeclarationNames(source.Program).ToHashSet(StringComparer.Ordinal);
        var explicitAliases = source.Program.Imports
            .Select(static import => import.Alias)
            .ToHashSet(StringComparer.Ordinal);
        var candidates = new Dictionary<string, List<OpenImportCandidate>>(StringComparer.Ordinal);

        foreach (var import in source.Program.Imports)
        {
            var moduleName = string.Join('.', import.Path);
            if (!modules.TryGetValue(moduleName, out var importedModule))
            {
                continue;
            }

            foreach (var (name, path) in PublicModuleSymbols(importedModule))
            {
                if (localNames.Contains(name) || explicitAliases.Contains(name))
                {
                    continue;
                }

                if (!candidates.TryGetValue(name, out var namedCandidates))
                {
                    namedCandidates = [];
                    candidates.Add(name, namedCandidates);
                }

                if (!namedCandidates.Any(candidate => candidate.Path.SequenceEqual(path)))
                {
                    namedCandidates.Add(new OpenImportCandidate(path, import.Alias));
                }
            }
        }

        return candidates.ToDictionary(
            static pair => pair.Key,
            static pair => (IReadOnlyList<OpenImportCandidate>)pair.Value,
            StringComparer.Ordinal);
    }

    private static IEnumerable<string> DirectDeclarationNames(SollangProgram program)
    {
        var moduleName = string.Join('.', program.NamespacePath);
        foreach (var function in program.Functions)
        {
            if (TryGetDirectSymbolName(moduleName, function.Name, out var functionName))
            {
                yield return functionName;
            }

            foreach (var localName in LocalFunctionNames(function.LocalFunctions))
            {
                yield return localName;
            }
        }

        foreach (var name in program.Structs.Select(static declaration => declaration.Name)
                     .Concat(program.Enums.Select(static declaration => declaration.Name))
                     .Concat(program.Traits.Select(static declaration => declaration.Name)))
        {
            if (TryGetDirectSymbolName(moduleName, name, out var symbolName))
            {
                yield return symbolName;
            }
        }
    }

    private static IEnumerable<string> LocalFunctionNames(IReadOnlyList<FunctionDeclaration> functions)
    {
        foreach (var function in functions)
        {
            if (!function.Name.Contains('.', StringComparison.Ordinal))
            {
                yield return function.Name;
            }

            foreach (var nestedName in LocalFunctionNames(function.LocalFunctions))
            {
                yield return nestedName;
            }
        }
    }

    private static IEnumerable<(string Name, IReadOnlyList<string> Path)> PublicModuleSymbols(
        CompilationSource source)
    {
        foreach (var function in source.Program.Functions)
        {
            if ((function.IsPublic || source.IsStandardLibrary)
                && TryGetDirectSymbolName(source.ModuleName, function.Name, out var name))
            {
                yield return (name, function.Name.Split('.'));
            }
        }

        foreach (var (name, isPublic) in source.Program.Structs
                     .Select(static declaration => (declaration.Name, declaration.IsPublic))
                     .Concat(source.Program.Enums.Select(static declaration => (declaration.Name, declaration.IsPublic)))
                     .Concat(source.Program.Traits.Select(static declaration => (declaration.Name, declaration.IsPublic))))
        {
            if (isPublic && TryGetDirectSymbolName(source.ModuleName, name, out var symbolName))
            {
                yield return (symbolName, name.Split('.'));
            }
        }
    }

    private static bool TryGetDirectSymbolName(string moduleName, string declarationName, out string symbolName)
    {
        var prefix = moduleName.Length == 0 ? string.Empty : moduleName + ".";
        if (!declarationName.StartsWith(prefix, StringComparison.Ordinal))
        {
            symbolName = string.Empty;
            return false;
        }

        var remainder = declarationName[prefix.Length..];
        if (remainder.Length == 0 || remainder.Contains('.', StringComparison.Ordinal))
        {
            symbolName = string.Empty;
            return false;
        }

        symbolName = remainder;
        return true;
    }

    private static IReadOnlyList<CompilationSource> LoadUserPrograms(
        IReadOnlyList<string> sourcePaths,
        ProjectBuild? project)
    {
        var loadedByPath = new Dictionary<string, CompilationSource>(StringComparer.OrdinalIgnoreCase);
        var modules = new Dictionary<string, CompilationSource>(StringComparer.Ordinal);
        foreach (var sourcePath in sourcePaths)
        {
            AddSource(
                Path.GetFullPath(sourcePath),
                expectedModule: null,
                project?.RootPackage,
                isDependencyRoot: false,
                loadedByPath,
                modules);
        }

        var roots = loadedByPath.Values.Where(static source => source.Program.Statements.Count > 0).ToArray();
        if (roots.Length > 1)
        {
            throw new SollangException("multiple source files contain executable top-level statements; exactly one root file may define the program entry point");
        }

        var root = roots.Length == 1
            ? roots[0]
            : loadedByPath[Path.GetFullPath(sourcePaths[0])];
        var moduleRoot = Path.GetDirectoryName(root.Path)
            ?? Directory.GetCurrentDirectory();
        var packagesByName = project?.Packages.ToDictionary(
            static package => package.Manifest.Name,
            StringComparer.Ordinal)
            ?? new Dictionary<string, ProjectPackage>(StringComparer.Ordinal);
        var states = new Dictionary<string, ModuleVisitState>(StringComparer.OrdinalIgnoreCase);
        VisitImports(root, moduleRoot, packagesByName, loadedByPath, modules, states, []);
        foreach (var sourcePath in sourcePaths)
        {
            var explicitSource = loadedByPath[Path.GetFullPath(sourcePath)];
            if (!ReferenceEquals(explicitSource, root))
            {
                VisitImports(explicitSource, moduleRoot, packagesByName, loadedByPath, modules, states, []);
            }
        }
        return loadedByPath.Values.OrderBy(static source => source.Path, StringComparer.OrdinalIgnoreCase).ToArray();
    }

    private static CompilationSource AddSource(
        string path,
        string? expectedModule,
        ProjectPackage? package,
        bool isDependencyRoot,
        IDictionary<string, CompilationSource> loadedByPath,
        IDictionary<string, CompilationSource> modules)
    {
        if (loadedByPath.TryGetValue(path, out var existing))
        {
            if (!SamePackage(existing.Package, package))
            {
                throw new SollangException(
                    $"source file '{path}' belongs to both project '{PackageName(existing.Package)}' "
                    + $"and project '{PackageName(package)}'");
            }
            return existing;
        }
        if (!File.Exists(path))
        {
            throw new SollangException($"imported module file not found: {path}");
        }

        var parsed = ParseSourceFile(path, isStandardLibrary: false);
        var program = parsed.Program;
        var moduleName = string.Join('.', program.NamespacePath);
        if (expectedModule is not null && moduleName != expectedModule)
        {
            throw new SollangException(
                $"module file '{path}' declares namespace '{moduleName}' but import expects '{expectedModule}'");
        }
        if (isDependencyRoot && program.Statements.Count > 0)
        {
            throw new SollangException(
                $"dependency product '{package!.Product.Name}' contains executable top-level statements: {path}");
        }
        if (moduleName.Length > 0
            && modules.TryGetValue(moduleName, out var duplicate)
            && !StringComparer.OrdinalIgnoreCase.Equals(duplicate.Path, path))
        {
            throw new SollangException(
                $"module '{moduleName}' is declared by both '{duplicate.Path}' and '{path}'");
        }

        var loaded = new CompilationSource(path, program, package, IsStandardLibrary: false, parsed.SourceBytes);
        loadedByPath.Add(path, loaded);
        if (moduleName.Length > 0)
        {
            modules[moduleName] = loaded;
        }
        return loaded;
    }

    private static void VisitImports(
        CompilationSource source,
        string moduleRoot,
        IReadOnlyDictionary<string, ProjectPackage> packagesByName,
        IDictionary<string, CompilationSource> loadedByPath,
        IDictionary<string, CompilationSource> modules,
        IDictionary<string, ModuleVisitState> states,
        IReadOnlyList<string> chain)
    {
        if (states.TryGetValue(source.Path, out var state))
        {
            if (state == ModuleVisitState.Visiting)
            {
                throw new SollangException(
                    "module import cycle: " + string.Join(" -> ", chain.Append(ModuleName(source.Program))));
            }
            return;
        }

        states[source.Path] = ModuleVisitState.Visiting;
        var nextChain = chain.Append(ModuleName(source.Program)).ToArray();
        foreach (var import in source.Program.Imports)
        {
            if (import.Path.Count > 0 && import.Path[0] is "sys" or "std")
            {
                continue;
            }

            var moduleName = string.Join('.', import.Path);
            var importedPackage = source.Package;
            var importRoot = source.Package?.SourceRoot ?? moduleRoot;
            var isDependencyRoot = false;
            if (source.Package is not null
                && source.Package.Dependencies.TryGetValue(import.Path[0], out var dependency))
            {
                importedPackage = dependency;
                importRoot = dependency.SourceRoot;
                isDependencyRoot = import.Path.Count == 1;
            }
            else if (source.Package is not null
                     && packagesByName.ContainsKey(import.Path[0])
                     && !string.Equals(
                         import.Path[0],
                         source.Package.Manifest.Name,
                         StringComparison.Ordinal))
            {
                throw new SollangException(
                    $"project '{source.Package.Manifest.Name}' imports undeclared dependency '{import.Path[0]}'");
            }

            CompilationSource? imported = null;
            if (modules.TryGetValue(moduleName, out var existing)
                && SamePackage(existing.Package, importedPackage))
            {
                imported = existing;
            }
            if (imported is null)
            {
                var modulePath = isDependencyRoot
                    ? importedPackage!.Product.RootSource
                    : Path.Combine(importRoot, Path.Combine(import.Path.ToArray()) + ".slg");
                imported = AddSource(
                    Path.GetFullPath(modulePath),
                    moduleName,
                    importedPackage,
                    isDependencyRoot,
                    loadedByPath,
                    modules);
            }
            VisitImports(
                imported,
                moduleRoot,
                packagesByName,
                loadedByPath,
                modules,
                states,
                nextChain);
        }
        states[source.Path] = ModuleVisitState.Visited;
    }

    private static string ModuleName(SollangProgram program)
    {
        return program.NamespacePath.Count == 0 ? "<root>" : string.Join('.', program.NamespacePath);
    }

    private static bool SamePackage(ProjectPackage? left, ProjectPackage? right)
    {
        if (left is null || right is null)
        {
            return left is null && right is null;
        }
        return StringComparer.OrdinalIgnoreCase.Equals(left.Manifest.Path, right.Manifest.Path);
    }

    private static string PackageName(ProjectPackage? package) => package?.Manifest.Name ?? "<explicit-sources>";

    private static IReadOnlyList<CompilationSource> LoadStandardLibrary(string sourcePath)
    {
        var standardLibraryRoot = Path.Combine(FindRepositoryRoot(sourcePath), "stdlib");
        var paths = DiscoverStandardLibraryPaths(sourcePath);
        if (paths.Count == 0)
        {
            throw new SollangException(
                $"standard library contains no Sollang source modules: {standardLibraryRoot}");
        }

        var sources = new List<CompilationSource>(paths.Count);
        var modules = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var path in paths)
        {
            var relativePath = Path.GetRelativePath(standardLibraryRoot, path);
            var expectedModule = string.Join(
                '.',
                Path.ChangeExtension(relativePath, extension: null)!
                    .Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            var parsed = ParseSourceFile(path, isStandardLibrary: true);
            var program = parsed.Program;
            var actualModule = ModuleName(program);
            if (!string.Equals(actualModule, expectedModule, StringComparison.Ordinal))
            {
                throw new SollangException(
                    $"standard library file '{path}' declares namespace '{actualModule}' "
                    + $"but its path requires '{expectedModule}'");
            }
            if (program.Statements.Count > 0)
            {
                throw new SollangException(
                    $"standard library module '{actualModule}' contains executable top-level statements: {path}");
            }
            if (modules.TryGetValue(actualModule, out var duplicatePath))
            {
                throw new SollangException(
                    $"standard library module '{actualModule}' is declared by both "
                    + $"'{duplicatePath}' and '{path}'");
            }

            modules.Add(actualModule, path);
            sources.Add(new CompilationSource(
                path,
                program,
                Package: null,
                IsStandardLibrary: true,
                parsed.SourceBytes));
        }

        return sources;
    }

    internal static IReadOnlyList<string> DiscoverStandardLibraryPaths(string sourcePath)
    {
        var standardLibraryRoot = Path.Combine(FindRepositoryRoot(sourcePath), "stdlib");
        return Directory
            .EnumerateFiles(standardLibraryRoot, "*.slg", SearchOption.AllDirectories)
            .OrderBy(
                path => Path.GetRelativePath(standardLibraryRoot, path),
                StringComparer.Ordinal)
            .Select(Path.GetFullPath)
            .ToArray();
    }

    private static string FindRepositoryRoot(string sourcePath)
    {
        foreach (var start in GetRootSearchStarts(sourcePath))
        {
            for (var current = new DirectoryInfo(start); current is not null; current = current.Parent)
            {
                if (File.Exists(Path.Combine(current.FullName, "Sollang.slnx"))
                    && Directory.Exists(Path.Combine(current.FullName, "stdlib")))
                {
                    return current.FullName;
                }
            }
        }

        throw new SollangException("could not locate the Sollang standard library root");
    }

    private static IEnumerable<string> GetRootSearchStarts(string sourcePath)
    {
        var sourceFullPath = Path.GetFullPath(sourcePath);
        yield return Path.GetDirectoryName(sourceFullPath) ?? Directory.GetCurrentDirectory();
        yield return Directory.GetCurrentDirectory();
        yield return AppContext.BaseDirectory;
    }

    private static ParsedSource ParseSourceFile(
        string path,
        bool isStandardLibrary,
        IReadOnlyDictionary<string, IReadOnlyList<OpenImportCandidate>>? openImports = null)
    {
        var sourceBytes = File.ReadAllBytes(path);
        using var stream = new MemoryStream(sourceBytes, writable: false);
        using var reader = new StreamReader(
            stream,
            new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true),
            detectEncodingFromByteOrderMarks: true);
        var sourceText = reader.ReadToEnd();
        var tokens = new Lexer(sourceText).Lex();
        return new ParsedSource(new Parser(tokens, isStandardLibrary, openImports).Parse(), sourceBytes);
    }

    private sealed record ParsedSource(SollangProgram Program, byte[] SourceBytes);

    private enum ModuleVisitState
    {
        Visiting,
        Visited
    }
}
