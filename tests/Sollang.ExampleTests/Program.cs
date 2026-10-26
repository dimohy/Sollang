using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

if (args.Length > 0 && args[0] == "--selfhost-product-tests")
{
    if (args.Length != 2) throw new ArgumentException("Expected a new result path.");
    return SelfHostCompilerProductTests.Run(args[1]);
}

if (args.Length > 0 && args[0] == "--llvm-assertion-tests")
{
    if (args.Length != 3) throw new ArgumentException("Expected LLVM input and new result path.");
    return LlvmAssertionTests.Run(args[1], args[2]);
}

// Compiler and native fixture streams use UTF-8 regardless of the host console code page.
Console.OutputEncoding = new UTF8Encoding(false);

if (args.Length > 0 && args[0] == "--raw-llvm-fixture-tests")
{
    if (args.Length != 2)
    {
        Console.Error.WriteLine("--raw-llvm-fixture-tests requires a new result JSON path.");
        return 2;
    }
    return RawLlvmFixtureTests.Run(args[1]);
}

if (args.Length > 0 && args[0] == "--llvm-execution-target-tests")
{
    if (args.Length != 2)
    {
        Console.Error.WriteLine("--llvm-execution-target-tests requires a new result JSON path.");
        return 2;
    }
    return LinkedLlvmExecutionTargetTests.Run(args[1]);
}

if (args.Length > 0 && args[0] == "--result-publication-tests")
{
    if (args.Length != 2)
    {
        Console.Error.WriteLine("--result-publication-tests requires a new result JSON path.");
        return 2;
    }
    return ResultPublicationTests.Run(args[1]);
}

if (args.Length == 3 && args[0] == "--container-element-alignment")
    return ContainerElementAlignmentTests.Run(args[1], args[2]);

if (args.Length > 0 && args[0] == "--semantic-type-cache-codec")
{
    if (args.Length != 3)
    {
        Console.Error.WriteLine("--semantic-type-cache-codec requires a compiler DLL and a result JSON path.");
        return 2;
    }
    return SemanticTypeCacheCodecTests.Run(args[1], args[2]);
}

var filters = new List<string>();
var exactFilters = new List<string>();
var affectedFiles = new List<string>();
var suite = TestSuite.Full;
var skipBootstrap = false;
var updateExpected = false;
var compareCompilers = false;
var validateInputsOnly = false;
var testTarget = TestTarget.WindowsX64;
var wslDistribution = "Ubuntu";
string? explicitCompilerPath = null;
string? selfHostCompilerBuildDirectory = null;
string? selfHostProductionRoot = null;
string? resultOutputDirectory = null;
string? baselineCandidatePlan = null;
string[]? comparisonResults = null;
// LLVM-backed cases spend a meaningful part of their lifetime in child
// processes, so leaving half of a 24-core workstation idle lengthens the
// repository feedback loop. Keep the cap bounded for memory predictability,
// while allowing current development machines to overlap up to 16 cases.
var jobs = Math.Min(Environment.ProcessorCount, 16);
for (var argumentIndex = 0; argumentIndex < args.Length; argumentIndex++)
{
    switch (args[argumentIndex])
    {
        case "--filter":
            if (++argumentIndex >= args.Length)
            {
                Console.Error.WriteLine("--filter requires a case-insensitive name fragment.");
                return 2;
            }
            filters.Add(args[argumentIndex]);
            break;
        case "--exact":
            if (++argumentIndex >= args.Length)
            {
                Console.Error.WriteLine("--exact requires a case-insensitive full test name.");
                return 2;
            }
            exactFilters.Add(args[argumentIndex]);
            break;
        case "--affected":
            if (++argumentIndex >= args.Length)
            {
                Console.Error.WriteLine("--affected requires a repository-relative source path.");
                return 2;
            }
            affectedFiles.Add(args[argumentIndex]);
            break;
        case "--suite":
            if (++argumentIndex >= args.Length
                || !Enum.TryParse<TestSuite>(args[argumentIndex], ignoreCase: true, out suite))
            {
                Console.Error.WriteLine("--suite requires fast, reference, semantic, selfhost, llvm, or full.");
                return 2;
            }
            break;
        case "--skip-bootstrap":
            skipBootstrap = true;
            break;
        case "--update-expected":
            updateExpected = true;
            break;
        case "--compare-compilers":
            compareCompilers = true;
            break;
        case "--stage-linked-llvm-baselines":
            if (++argumentIndex >= args.Length || string.IsNullOrWhiteSpace(args[argumentIndex]))
            {
                Console.Error.WriteLine("--stage-linked-llvm-baselines requires a frozen candidate plan.");
                return 2;
            }
            baselineCandidatePlan = args[argumentIndex];
            break;
        case "--validate-inputs-only":
            validateInputsOnly = true;
            break;
        case "--compiler":
            if (++argumentIndex >= args.Length || string.IsNullOrWhiteSpace(args[argumentIndex]))
            {
                Console.Error.WriteLine("--compiler requires a compiler assembly path.");
                return 2;
            }
            explicitCompilerPath = args[argumentIndex];
            break;
        case "--output-directory":
            if (++argumentIndex >= args.Length || string.IsNullOrWhiteSpace(args[argumentIndex]))
            {
                Console.Error.WriteLine("--output-directory requires a new result directory.");
                return 2;
            }
            resultOutputDirectory = args[argumentIndex];
            break;
        case "--selfhost-driver-build":
            if (++argumentIndex >= args.Length || string.IsNullOrWhiteSpace(args[argumentIndex]))
            {
                Console.Error.WriteLine("--selfhost-driver-build requires an existing canonical compiler build directory.");
                return 2;
            }
            selfHostCompilerBuildDirectory = args[argumentIndex];
            break;
        case "--selfhost-production-root":
            if (++argumentIndex >= args.Length || string.IsNullOrWhiteSpace(args[argumentIndex]))
            {
                Console.Error.WriteLine("--selfhost-production-root requires the reused compiler's production source root.");
                return 2;
            }
            selfHostProductionRoot = args[argumentIndex];
            break;
        case "--compare-results":
            if (argumentIndex + 2 >= args.Length)
            {
                Console.Error.WriteLine("--compare-results requires managed and native result JSON paths.");
                return 2;
            }
            comparisonResults = [args[++argumentIndex], args[++argumentIndex]];
            break;
        case "--target":
            if (++argumentIndex >= args.Length
                || !TryParseTestTarget(args[argumentIndex], out testTarget))
            {
                Console.Error.WriteLine("--target requires windows-x64 or linux-x64.");
                return 2;
            }
            break;
        case "--wsl-distribution":
            if (++argumentIndex >= args.Length || string.IsNullOrWhiteSpace(args[argumentIndex]))
            {
                Console.Error.WriteLine("--wsl-distribution requires a WSL distribution name.");
                return 2;
            }
            wslDistribution = args[argumentIndex];
            break;
        case "--jobs":
            if (++argumentIndex >= args.Length
                || !int.TryParse(args[argumentIndex], out jobs)
                || jobs < 1)
            {
                Console.Error.WriteLine("--jobs requires a positive integer.");
                return 2;
            }
            break;
        default:
            Console.Error.WriteLine($"Unknown test option: {args[argumentIndex]}");
            Console.Error.WriteLine("Usage: dotnet run --project tests/Sollang.ExampleTests -- [--filter <fragment>]... [--exact <name>]... [--affected <path>]... [--suite fast|reference|semantic|selfhost|llvm|full] [--target windows-x64|linux-x64] [--wsl-distribution <name>] [--compiler <path>] [--output-directory <new-directory>] [--compare-results <managed.json> <native.json>] [--skip-bootstrap] [--update-expected] [--compare-compilers] [--jobs <count>]");
            return 2;
    }
}

if (comparisonResults is not null)
{
    if (args.Length != 3)
    {
        Console.Error.WriteLine("--compare-results is a standalone command.");
        return 2;
    }
    return ExampleTestResults.Compare(comparisonResults[0], comparisonResults[1], Normalize);
}
if (resultOutputDirectory is not null && explicitCompilerPath is null && !skipBootstrap)
{
    Console.Error.WriteLine("Durable results require an existing explicit compiler or --skip-bootstrap; inputs must be pinned before compiler build cost.");
    return 2;
}
if (resultOutputDirectory is not null && updateExpected)
{
    Console.Error.WriteLine("--output-directory freezes input oracles and cannot be combined with --update-expected.");
    return 2;
}
if (baselineCandidatePlan is not null && (!compareCompilers || resultOutputDirectory is null
    || explicitCompilerPath is null || selfHostCompilerBuildDirectory is null
    || testTarget != TestTarget.WindowsX64))
{
    Console.Error.WriteLine("BASELINE_CANDIDATE_REQUIRES_PINNED_MANAGED_REFERENCE_AND_SELFHOST_WINDOWS_RUN");
    return 2;
}
if (selfHostProductionRoot is not null && selfHostCompilerBuildDirectory is null)
{
    Console.Error.WriteLine("--selfhost-production-root requires --selfhost-driver-build.");
    return 2;
}
if (selfHostCompilerBuildDirectory is not null && resultOutputDirectory is null)
{
    Console.Error.WriteLine("--selfhost-driver-build requires --output-directory to protect the reused product and record its inputs.");
    return 2;
}
if (validateInputsOnly && resultOutputDirectory is null)
{
    Console.Error.WriteLine("--validate-inputs-only requires --output-directory for its non-execution record.");
    return 2;
}

if (testTarget == TestTarget.LinuxX64 && updateExpected)
{
    Console.Error.WriteLine("--update-expected is not supported with --target linux-x64; Linux verifies target-neutral behavior without replacing Windows LLVM snapshots.");
    return 2;
}

var repoRoot = FindRepositoryRoot(AppContext.BaseDirectory);
var compilerProject = Path.Combine(repoRoot, "src", "Sollang.Compiler", "Sollang.Compiler.csproj");
var compilerDll = Path.Combine(
    repoRoot,
    "src",
    "Sollang.Compiler",
    "bin",
    "Release",
    "net11.0",
    "Sollang.Compiler.dll");
if (explicitCompilerPath is not null)
{
    try
    {
        compilerDll = Path.GetFullPath(explicitCompilerPath, repoRoot);
    }
    catch (Exception exception) when (exception is ArgumentException or NotSupportedException or PathTooLongException)
    {
        Console.Error.WriteLine($"--compiler path is invalid: {exception.Message}");
        return 2;
    }

    if (!File.Exists(compilerDll))
    {
        Console.Error.WriteLine($"Compiler path does not exist: {compilerDll}");
        return 2;
    }
}
if (compareCompilers && !string.Equals(Path.GetExtension(compilerDll), ".dll", StringComparison.OrdinalIgnoreCase))
{
    Console.Error.WriteLine("--compare-compilers requires a managed .dll reference compiler; use a native compiler without --compare-compilers.");
    return 2;
}
SelfHostCompilerProduct? reusedSelfHostCompiler = null;
if (selfHostCompilerBuildDirectory is not null)
{
    try
    {
        reusedSelfHostCompiler = SelfHostCompilerProduct.Validate(repoRoot,
            selfHostCompilerBuildDirectory, selfHostProductionRoot);
    }
    catch (Exception error) when (error is IOException or UnauthorizedAccessException or InvalidOperationException
        or System.Text.Json.JsonException or KeyNotFoundException or ArgumentException)
    {
        Console.Error.WriteLine($"Selfhost product preflight failed: {error.Message}");
        return 2;
    }
}
var expectedDir = Path.Combine(repoRoot, "examples", "regression", "expected");
var regressionDir = Path.GetDirectoryName(expectedDir)!;
var misplacedExpectations = Directory
    .EnumerateFiles(regressionDir, "*.stdout.txt")
    .Order(StringComparer.Ordinal)
    .ToArray();
if (misplacedExpectations.Length > 0)
{
    Console.Error.WriteLine("Regression stdout expectations must be placed in examples/regression/expected:");
    foreach (var path in misplacedExpectations)
    {
        Console.Error.WriteLine($"  {Path.GetFileName(path)}");
    }
    return 1;
}
if (resultOutputDirectory is not null)
{
    resultOutputDirectory = Path.GetFullPath(resultOutputDirectory, repoRoot);
    if (Directory.Exists(resultOutputDirectory) || File.Exists(resultOutputDirectory))
    {
        Console.Error.WriteLine("Result directory already exists; preserve its prior evidence.");
        return 2;
    }
    Directory.CreateDirectory(resultOutputDirectory);
}
var baseArtifactsDir = resultOutputDirectory is null
    ? Path.Combine(repoRoot, "artifacts", "example-tests")
    : Path.Combine(resultOutputDirectory, "compiler-artifacts");
var artifactsDir = testTarget == TestTarget.WindowsX64
    ? baseArtifactsDir
    : Path.Combine(baseArtifactsDir, "linux-x64");
Directory.CreateDirectory(artifactsDir);
var llvmDir = Path.Combine(repoRoot, ".tools", "llvm-22.1.8");
var clangPath = Path.Combine(llvmDir, "bin", "clang.exe");
var llvmAsPath = Path.Combine(llvmDir, "bin", "llvm-as.exe");
if (!File.Exists(clangPath))
{
    Console.Error.WriteLine($"LLVM toolchain not found: {clangPath}");
    Console.Error.WriteLine("Run scripts/sollang.ps1 once to install the pinned toolchain.");
    return 1;
}
if (testTarget == TestTarget.LinuxX64)
{
    var wslCheck = Run("wsl.exe", ["-d", wslDistribution, "--", "true"], input: null, repoRoot);
    if (wslCheck.ExitCode != 0)
    {
        Console.Error.WriteLine($"WSL distribution is unavailable: {wslDistribution}");
        Console.Error.WriteLine(wslCheck.Stderr);
        return 1;
    }
}

if (!skipBootstrap && explicitCompilerPath is null)
{
    Console.WriteLine("[bootstrap 1/2] Building the Release compiler...");
    Console.Out.Flush();
    var compilerBuild = Run(
        "dotnet",
        ["build", compilerProject, "-c", "Release", "--nologo", "--no-restore"],
        input: null,
        repoRoot);
    if (compilerBuild.ExitCode != 0)
    {
        Console.Error.WriteLine("FAIL compiler bootstrap build");
        Console.Error.WriteLine(compilerBuild.Stdout);
        Console.Error.WriteLine(compilerBuild.Stderr);
        return 1;
    }
    Console.WriteLine("[bootstrap 1/2] PASS Release compiler build");
    Console.Out.Flush();

    Console.WriteLine("[bootstrap 2/2] Generating and verifying the grammar table...");
    Console.Out.Flush();
    var generatedGrammarPath = Path.Combine(artifactsDir, "sollang_grammar.generated.slg");
    var grammarBuild = RunCompiler(
        [compilerDll, "grammar", "build",
            Path.Combine(repoRoot, "syntax", "sollang.lexer"),
            Path.Combine(repoRoot, "syntax", "sollang.grammar"),
            "-o", generatedGrammarPath],
        input: null,
        repoRoot);
    if (grammarBuild.ExitCode != 0)
    {
        Console.Error.WriteLine("FAIL grammar table generation");
        Console.Error.WriteLine(grammarBuild.Stdout);
        Console.Error.WriteLine(grammarBuild.Stderr);
        return 1;
    }
    var checkedInGrammarPath = Path.Combine(repoRoot, "syntax", "generated", "sollang_grammar.slg");
    if (!File.Exists(checkedInGrammarPath)
        || !File.ReadAllBytes(checkedInGrammarPath).SequenceEqual(File.ReadAllBytes(generatedGrammarPath)))
    {
        Console.Error.WriteLine("FAIL generated grammar table is stale; run `sollang grammar build`");
        return 1;
    }
    Console.WriteLine("[bootstrap 2/2] PASS grammar/table-determinism");
    Console.Out.Flush();

    if (testTarget == TestTarget.WindowsX64)
    {
        Console.WriteLine("[cli] Verifying `sollang run <source.slg>`...");
        Console.Out.Flush();
        var cliRunOutput = Path.Combine(artifactsDir, "cli-run-smoke.exe");
        var cliRun = RunCompiler(
            [
                compilerDll,
                "run",
                Path.Combine(repoRoot, "examples", "regression", "03-flow-call-parens.slg"),
                "-o", cliRunOutput,
                "--llvm", llvmDir
            ],
            input: null,
            repoRoot);
        if (cliRun.ExitCode != 0
            || !StringComparer.Ordinal.Equals(
                Normalize(cliRun.Stdout),
                "Hello, dimohy. square = 49\n"))
        {
            Console.Error.WriteLine("FAIL cli/run-source");
            Console.Error.WriteLine(cliRun.Stdout);
            Console.Error.WriteLine(cliRun.Stderr);
            return 1;
        }
        Console.WriteLine("[cli] PASS run-source");
        Console.Out.Flush();
    }
}
else if (!File.Exists(compilerDll))
{
    Console.Error.WriteLine($"Compiler output not found: {compilerDll}");
    Console.Error.WriteLine("Remove --skip-bootstrap so the test runner can build it.");
    return 1;
}

var allExpectedFiles = Directory
    .EnumerateFiles(expectedDir, "*.stdout.txt")
    // Browser target goldens are consumed by the dedicated browser gate. They
    // do not name a native regression source and must not enter this catalog.
    .Where(file => !Path.GetFileName(file).EndsWith(".browser.stdout.txt", StringComparison.Ordinal))
    .Order(StringComparer.Ordinal)
    .ToArray();
var userExampleDir = Path.Combine(repoRoot, "examples", "user");
var userExampleFiles = Directory.Exists(userExampleDir)
    ? Directory.EnumerateFiles(userExampleDir, "*.slg").Order(StringComparer.Ordinal).ToArray()
    : [];
foreach (var userExample in userExampleFiles)
{
    var regressionExample = Path.Combine(
        repoRoot,
        "examples",
        "regression",
        Path.GetFileName(userExample));
    if (!File.Exists(regressionExample)
        || !File.ReadAllBytes(userExample).SequenceEqual(File.ReadAllBytes(regressionExample)))
    {
        Console.Error.WriteLine(
            $"User example must match its fully tested regression counterpart: {Path.GetFileName(userExample)}");
        return 1;
    }
}
var diagnosticDir = Path.Combine(repoRoot, "examples", "regression", "diagnostics");
var affectedPaths = affectedFiles
    .Select(path => Path.GetFullPath(path, repoRoot))
    .ToHashSet(StringComparer.OrdinalIgnoreCase);
var affectedGraph = new AffectedDependencyGraph(repoRoot, affectedPaths);
var allDiagnosticFiles = Directory.Exists(diagnosticDir)
    ? Directory.EnumerateFiles(diagnosticDir, "*.slg")
        .Concat(Directory.EnumerateFiles(diagnosticDir, "*.project"))
        .Concat(Directory.EnumerateFiles(diagnosticDir, "*.workspace"))
        .Order(StringComparer.Ordinal)
        .ToArray()
    : [];
Console.WriteLine(
    $"[catalog] user={userExampleFiles.Length}, regression={allExpectedFiles.Length}, "
    + $"diagnostics={allDiagnosticFiles.Length}, total-fixtures={allExpectedFiles.Length + allDiagnosticFiles.Length}");
var expectedFiles = allExpectedFiles
    .Where(file => MatchesFilters(Path.GetFileName(file)[..^".stdout.txt".Length], filters, exactFilters))
    .Where(file => MatchesSuite(file, suite))
    .Where(file => testTarget == TestTarget.LinuxX64
        || !Path.GetFileName(file).EndsWith(".linux-x64.stdout.txt", StringComparison.Ordinal))
    .Where(file => testTarget == TestTarget.WindowsX64
        || !Path.GetFileName(file).EndsWith(".windows-x64.stdout.txt", StringComparison.Ordinal))
    .Where(file => testTarget == TestTarget.WindowsX64
        || !File.Exists(Path.Combine(
            expectedDir,
            Path.GetFileName(file)[..^".stdout.txt".Length] + ".windows-only.txt")))
    .Where(file => MatchesAffectedExpected(file, repoRoot, expectedDir, affectedPaths, affectedGraph))
    .OrderByDescending(IsExpensiveSelfHostLlvmTest)
    .ThenBy(file => file, StringComparer.Ordinal)
    .ToArray();
var diagnosticFiles = allDiagnosticFiles
    .Where(file => suite != TestSuite.Llvm && suite != TestSuite.SelfHost && suite != TestSuite.Semantic)
    .Where(file => MatchesFilters("diagnostic/" + Path.GetFileNameWithoutExtension(file), filters, exactFilters))
    .Where(file => MatchesAffectedDiagnostic(file, diagnosticDir, repoRoot, affectedPaths, affectedGraph))
    .ToArray();

if (allExpectedFiles.Length == 0)
{
    Console.Error.WriteLine("No expected stdout files found.");
    return 1;
}
if (expectedFiles.Length + diagnosticFiles.Length == 0)
{
    Console.Error.WriteLine($"No example or diagnostic test matched suite={suite}, filters=[{string.Join(", ", filters)}], exact=[{string.Join(", ", exactFilters)}], affected=[{string.Join(", ", affectedFiles)}].");
    return 2;
}

ExampleTestResults? results = null;
LinkedLlvmBaselineCandidates? baselineCandidates = null;
if (baselineCandidatePlan is not null)
{
    try
    {
        if (diagnosticFiles.Length != 0)
            throw new InvalidOperationException("BASELINE_CANDIDATE_DIAGNOSTICS_NOT_ALLOWED");
        baselineCandidates = new LinkedLlvmBaselineCandidates(baselineCandidatePlan, repoRoot,
            resultOutputDirectory!, expectedDir, expectedFiles, IsReusableSelfHostCompilerTest,
            source => SelfHostTargetMode(source, testTarget));
    }
    catch (Exception error) when (error is IOException or InvalidOperationException or JsonException)
    {
        Console.Error.WriteLine(error.Message);
        return 2;
    }
}
if (reusedSelfHostCompiler is not null && !expectedFiles.Any(IsReusableSelfHostCompilerTest))
{
    Console.Error.WriteLine("--selfhost-driver-build was supplied but the selected catalog has no reusable selfhost compiler cases.");
    return 2;
}
if (validateInputsOnly && expectedFiles.Any(IsReusableSelfHostCompilerTest) && reusedSelfHostCompiler is null)
{
    Console.Error.WriteLine("Selfhost input preflight requires --selfhost-driver-build; it cannot bootstrap a new product.");
    return 2;
}
if (resultOutputDirectory is not null)
{
    try
    {
        var inputs = CollectResultInputs(repoRoot, expectedDir, diagnosticDir, expectedFiles, diagnosticFiles, testTarget);
        results = new ExampleTestResults(resultOutputDirectory, compilerDll, TestTargetName(testTarget),
            expectedFiles.Select(file => Path.GetFileName(file)[..^".stdout.txt".Length])
                .Concat(diagnosticFiles.Select(file => "diagnostic/" + Path.GetFileNameWithoutExtension(file))).ToArray(),
            inputs, CreateCompilerInvocation([compilerDll]).IdentityPaths.Concat(new[]
            {
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "Program.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "ExampleTestResults.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "CompilerDiagnosticAssertions.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "AtomicResultFile.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "ResultPublicationTests.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "SelfHostCompilerProduct.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "LinkedLlvmBaselineCandidates.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "LinkedLlvmExecutionTarget.cs"),
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "LinkedLlvmExecutionTargetTests.cs"),
                typeof(ExampleTestResults).Assembly.Location, clangPath, llvmAsPath
            }).Concat(baselineCandidates?.InputPaths ?? [])
                .Concat(Directory.EnumerateFiles(AppContext.BaseDirectory, "*.runtimeconfig.json"))
                .Concat(Directory.EnumerateFiles(AppContext.BaseDirectory, "*.deps.json"))
                .Concat(Environment.ProcessPath is { } host ? new[] { host } : [])
                .Concat(reusedSelfHostCompiler?.InputHashes.Keys.AsEnumerable() ?? []),
            expectedFiles.Where(IsReusableSelfHostCompilerTest)
                .Select(file => Path.GetFileName(file)[..^".stdout.txt".Length]),
            baselineCandidates is null ? "regression" : LinkedLlvmBaselineCandidates.Scope);
        reusedSelfHostCompiler?.AssertStable();
    }
    catch (Exception error) when (error is IOException or UnauthorizedAccessException or InvalidOperationException)
    {
        File.WriteAllText(Path.Combine(resultOutputDirectory, "result.json"),
            System.Text.Json.JsonSerializer.Serialize(new
            {
                status = "failed", completed = 0, total = expectedFiles.Length + diagnosticFiles.Length,
                inputHashes = new Dictionary<string, string>(), cases = Array.Empty<object>(), processes = Array.Empty<object>(),
                failure = "INPUT_PREFLIGHT: " + error.Message, inputsStable = false, processesStopped = true
            }), new UTF8Encoding(false));
        Console.Error.WriteLine($"Result input preflight failed: {error.Message}");
        return 2;
    }
}

if (validateInputsOnly)
{
    var valid = results!.CompleteInputPreflight();
    Console.WriteLine($"Input preflight {(valid ? "PASS" : "FAIL")}; executed 0/{expectedFiles.Length + diagnosticFiles.Length} cases.");
    return valid ? 0 : 2;
}

var selfHostDriverPath = reusedSelfHostCompiler?.CompilerPath
    ?? Path.Combine(baseArtifactsDir, "selfhost-sollangc-driver.exe");
var selfHostDriverSourcesPath = Path.Combine(
    repoRoot,
    "tests",
    "Sollang.ExampleTests",
    "Fixtures",
    "selfhost-sollangc-driver.sources.txt");
if (reusedSelfHostCompiler is not null)
{
    reusedSelfHostCompiler.AssertStable();
    Console.WriteLine("[selfhost bootstrap] REUSE canonical compiler with current build/source proof");
    Console.Out.Flush();
}
if (reusedSelfHostCompiler is null && expectedFiles.Any(IsReusableSelfHostCompilerTest))
{
    using var bootstrapMutex = new Mutex(
        initiallyOwned: false,
        TestMutexName(repoRoot, "selfhost-bootstrap"));
    var bootstrapLockTaken = false;
    try
    {
        try
        {
            bootstrapLockTaken = bootstrapMutex.WaitOne();
        }
        catch (AbandonedMutexException)
        {
            bootstrapLockTaken = true;
        }
    var selfHostDriverSources = File.ReadLines(selfHostDriverSourcesPath)
        .Where(static line => !string.IsNullOrWhiteSpace(line))
        .Select(line => Path.GetFullPath(line.Trim(), repoRoot))
        .ToArray();
    var selfHostDriverInputs = selfHostDriverSources
        .Concat(Directory.EnumerateFiles(
            Path.Combine(repoRoot, "stdlib"),
            "*.slg",
            SearchOption.AllDirectories))
        .Append(selfHostDriverSourcesPath)
        .Append(Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "Program.cs"))
        .Concat(CreateCompilerInvocation([compilerDll]).IdentityPaths)
        .ToArray();
    var selfHostDriverFingerprintPath = selfHostDriverPath + ".inputs.sha256";
    var selfHostDriverFingerprint = ComputeInputFingerprint(selfHostDriverInputs);
    if (!IsOutputCurrent(
            selfHostDriverPath,
            selfHostDriverFingerprintPath,
            selfHostDriverFingerprint))
    {
        File.Delete(selfHostDriverFingerprintPath);
        while (true)
        {
            var buildFingerprint = ComputeInputFingerprint(selfHostDriverInputs);
            if (buildFingerprint is null)
            {
                Console.Error.WriteLine("FAIL reusable native sollangc bootstrap input is missing");
                return 1;
            }

            Console.WriteLine("[selfhost bootstrap] Building the reusable native sollangc...");
            Console.Out.Flush();
            var driverArguments = new List<string> { compilerDll, "build" };
            driverArguments.AddRange(selfHostDriverSources);
            driverArguments.AddRange([
                "-o", selfHostDriverPath,
                "--target", "windows-x64",
                "--llvm", llvmDir,
                "-O1"
            ]);
            var driverBuild = RunCompiler(driverArguments, input: null, repoRoot, relayOutput: true);
            if (driverBuild.ExitCode != 0)
            {
                Console.Error.WriteLine("FAIL reusable native sollangc bootstrap");
                Console.Error.WriteLine(driverBuild.Stdout);
                Console.Error.WriteLine(driverBuild.Stderr);
                return 1;
            }
            var driverDiagnostics = driverBuild.Stdout + driverBuild.Stderr;
            if (Regex.IsMatch(
                    driverDiagnostics,
                    @"(?:^|\r?\n)(?:warning S|note N)\d{3}\b",
                    RegexOptions.CultureInvariant))
            {
                Console.Error.WriteLine("FAIL reusable native sollangc bootstrap emitted a warning or note");
                Console.Error.WriteLine(driverDiagnostics);
                return 1;
            }

            var verifiedFingerprint = ComputeInputFingerprint(selfHostDriverInputs);
            if (StringComparer.Ordinal.Equals(buildFingerprint, verifiedFingerprint))
            {
                WriteFingerprintAtomically(selfHostDriverFingerprintPath, buildFingerprint);
                var publishedFingerprint = ComputeInputFingerprint(selfHostDriverInputs);
                if (StringComparer.Ordinal.Equals(buildFingerprint, publishedFingerprint))
                {
                    break;
                }

                File.Delete(selfHostDriverFingerprintPath);
            }

            Console.WriteLine("[selfhost bootstrap] Inputs changed during build; rebuilding from the current snapshot...");
            Console.Out.Flush();
        }
        Console.WriteLine("[selfhost bootstrap] PASS reusable native sollangc");
    }
    else
    {
        Console.WriteLine("[selfhost bootstrap] REUSE current native sollangc");
    }
    Console.Out.Flush();
    }
    finally
    {
        if (bootstrapLockTaken)
        {
            bootstrapMutex.ReleaseMutex();
        }
    }
}

if (expectedFiles.Any(file => string.Equals(
        Path.GetFileName(file),
        "442-git-dependency.stdout.txt",
        StringComparison.Ordinal)))
{
    PrepareGitDependencyFixture(baseArtifactsDir);
}
if (expectedFiles.Any(file => Path.GetFileName(file) is
        "443-registry-dependency.stdout.txt" or "444-registry-lock-pin.stdout.txt"))
{
    PrepareRegistryDependencyFixture(baseArtifactsDir, compilerDll, repoRoot);
}
if (testTarget == TestTarget.WindowsX64
    && expectedFiles.Any(file => string.Equals(
        Path.GetFileName(file),
        "604-com-interface.stdout.txt",
        StringComparison.Ordinal)))
{
    var fixtureBuild = Run(
        "powershell.exe",
        [
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", Path.Combine(repoRoot, "scripts", "build-com-interop-fixture.ps1")
        ],
        input: null,
        repoRoot);
    if (fixtureBuild.ExitCode != 0)
    {
        Console.Error.WriteLine("FAIL COM fixture build");
        Console.Error.WriteLine(fixtureBuild.Stdout);
        Console.Error.WriteLine(fixtureBuild.Stderr);
        return 1;
    }
}

var failures = 0;
var started = 0;
var completed = 0;
var totalTests = expectedFiles.Length + diagnosticFiles.Length;
var progressLock = new object();
Console.WriteLine($"[0/{totalTests}] Running {suite.ToString().ToLowerInvariant()} suite for {TestTargetName(testTarget)} with {jobs} worker(s).");
Console.Out.Flush();

void ReportStarted(string name)
{
    lock (progressLock)
    {
        ExampleTestResults.StartCase(name);
        var current = Interlocked.Increment(ref started);
        Console.WriteLine($"[start {current}/{totalTests}] {name}");
        Console.Out.Flush();
    }
}

void ReportCompleted(string name, bool passed, TimeSpan elapsed)
{
    lock (progressLock)
    {
        ExampleTestResults.CompleteCase(name, passed, elapsed);
        var current = Interlocked.Increment(ref completed);
        Console.WriteLine($"[{current}/{totalTests}] {(passed ? "PASS" : "FAIL")} {name} ({elapsed.TotalSeconds:F2}s)");
        Console.Out.Flush();
    }
}

Parallel.ForEach(
    Partitioner.Create(expectedFiles, loadBalance: true),
    new ParallelOptions { MaxDegreeOfParallelism = jobs },
    expectedFile =>
{
    if (ExampleTestResults.Current?.Cancelled == true) return;
    var stopwatch = Stopwatch.StartNew();
    var name = Path.GetFileName(expectedFile)[..^".stdout.txt".Length];
    var passed = false;
    var managedReferenceVerified = false;
    ReportStarted(name);
    using var testMutex = new Mutex(
        initiallyOwned: false,
        TestMutexName(repoRoot, $"expected:{TestTargetName(testTarget)}:{name}"));
    var testLockTaken = false;
    try
    {
    try
    {
        testLockTaken = testMutex.WaitOne();
    }
    catch (AbandonedMutexException)
    {
        testLockTaken = true;
    }
    var defaultSourcePath = Path.Combine(repoRoot, "examples", "regression", name + ".slg");
    var targetSourcePath = Path.Combine(repoRoot, "examples", "regression", name + "." + TestTargetName(testTarget) + ".slg");
    var sourcePath = File.Exists(targetSourcePath) ? targetSourcePath : defaultSourcePath;
    var projectPath = Path.Combine(expectedDir, name + ".project.txt");
    var stdinPath = Path.Combine(expectedDir, name + ".stdin.txt");
    var argumentsPath = Path.Combine(expectedDir, name + ".args.txt");
    var environmentPath = Path.Combine(expectedDir, name + ".env.txt");
    var outputPath = Path.Combine(
        artifactsDir,
        CompilationArtifactStem(name, TestTargetName(testTarget)) + TestExecutableSuffix(testTarget));
    var (llvmContainsPath, llvmNotContainsPath, llvmRegexCountsPath) = LlvmAssertions.SelectPaths(
        expectedDir, name, TestTargetName(testTarget), LlvmAssertions.IsManagedProducer(compilerDll));
    var wasmLlvmContainsPath = Path.Combine(expectedDir, name + ".wasm32.llvm.contains.txt");
    var sourcesPath = Path.Combine(expectedDir, name + ".sources.txt");
    var selfHostRootPath = Path.Combine(expectedDir, name + ".root.txt");
    var stdoutLlvmValidationPath = Path.Combine(expectedDir, name + ".stdout.llvm.validate.txt");
    var stdoutLlvmExecutionPath = Path.Combine(expectedDir, name + ".stdout.llvm.execute.txt");
    var windowsLlvmExecutionPath = Path.Combine(expectedDir, name + ".stdout.llvm.windows-x64.execute.txt");
    var linuxLlvmExecutionPath = Path.Combine(expectedDir, name + ".stdout.llvm.linux-x64.execute.txt");
    var hasStdoutLlvmExecution = File.Exists(stdoutLlvmExecutionPath)
        || File.Exists(windowsLlvmExecutionPath) || File.Exists(linuxLlvmExecutionPath);
    // An execution expectation necessarily requires assembly and linking even
    // when the separate assembly-only marker was not supplied.
    var needsStdoutLlvmValidation = File.Exists(stdoutLlvmValidationPath) || hasStdoutLlvmExecution;
    var stdoutLlvmLinkArgumentsPath = Path.Combine(expectedDir, name + ".stdout.llvm.link-args.txt");
    var targetStdoutPath = Path.Combine(
        expectedDir,
        name + ".stdout." + TestTargetName(testTarget) + ".txt");
    var expectedStdoutPath = File.Exists(targetStdoutPath) ? targetStdoutPath : expectedFile;
    var compileOnlyPath = Path.Combine(expectedDir, name + ".compile-only.txt");
    var compilerStderrContainsPath = Path.Combine(expectedDir, name + ".compiler.stderr.contains.txt");
    var compilerStderrExactPath = Path.Combine(expectedDir, name + ".compiler.stderr.exact.txt");
    var hasExactCompilerStderr = File.Exists(compilerStderrExactPath);
    if (hasExactCompilerStderr && File.Exists(compilerStderrContainsPath))
    {
        Console.Error.WriteLine($"FAIL {name}: ambiguous exact and contains compiler diagnostic contracts");
        Interlocked.Increment(ref failures);
        return;
    }
    if (hasExactCompilerStderr)
    {
        var declaredDiagnostic = File.ReadAllText(compilerStderrExactPath, Encoding.UTF8);
        if (!CompilerDiagnosticAssertions.Verify("", declaredDiagnostic, declaredDiagnostic, out var contractError))
        {
            Console.Error.WriteLine($"FAIL {name}: {contractError}");
            Interlocked.Increment(ref failures);
            return;
        }
    }
    var verifyLlvm = File.Exists(llvmContainsPath)
        || File.Exists(llvmNotContainsPath)
        || File.Exists(llvmRegexCountsPath);

    ExampleTestResults.Oracle(File.Exists(compileOnlyPath) ? "compile-only"
        : needsStdoutLlvmValidation ? "llvm" : "runtime", expectedStdoutPath, verifyLlvm || needsStdoutLlvmValidation);

    if (!File.Exists(sourcePath) && !File.Exists(projectPath))
    {
        Console.Error.WriteLine($"FAIL {name}: source or project manifest reference not found");
        Interlocked.Increment(ref failures);
        return;
    }

    ProcessResult run = new(-1, string.Empty, "test did not run");
    string[]? selfHostSourcePaths = null;
    var reusableSelfHostTest = IsReusableSelfHostCompilerTest(expectedFile);
    var selfHostMode = "";
    if (reusableSelfHostTest)
    {
        var outerSource = File.ReadAllText(sourcePath, Encoding.UTF8);
        selfHostMode = SelfHostTargetMode(outerSource, testTarget);
        var driverArguments = new List<string> { selfHostMode };
        if (File.Exists(selfHostRootPath))
        {
            var sourceRoot = File.ReadLines(selfHostRootPath)
                .First(static line => !string.IsNullOrWhiteSpace(line))
                .Trim();
            // A root can supply canonical providers to explicit raw fixture sources.
            // Root-only fixtures keep their existing discovery/entry-point contract.
            var hasExplicitSources = outerSource.Contains("\"\"\"", StringComparison.Ordinal);
            driverArguments[0] += hasExplicitSources ? "-stdlib" : "-root";
            driverArguments.Add(Path.GetFullPath(sourceRoot, repoRoot));
            if (hasExplicitSources)
            {
                var explicitSources = MaterializeSelfHostSources(
                    name, ExtractRawMultilineStrings(outerSource), artifactsDir);
                driverArguments.AddRange(explicitSources);
                selfHostSourcePaths = Directory.EnumerateFiles(
                        Path.GetFullPath(sourceRoot, repoRoot), "*.slg", SearchOption.AllDirectories)
                    .Order(StringComparer.Ordinal)
                    .Concat(explicitSources)
                    .ToArray();
            }
        }
        else
        {
            selfHostSourcePaths = MaterializeSelfHostSources(
                name,
                ExtractRawMultilineStrings(outerSource),
                artifactsDir);
            // A linked embedded program has the same canonical prelude as the
            // C# reference build. Raw emission-only probes retain their partial
            // source contract; they must not silently acquire declarations.
            if (hasStdoutLlvmExecution
                && selfHostMode is "windows" or "linux" or "wasm")
            {
                driverArguments[0] += "-stdlib";
                driverArguments.Add(Path.Combine(repoRoot, "stdlib"));
            }
            driverArguments.AddRange(selfHostSourcePaths);
        }
        run = Run(selfHostDriverPath, driverArguments, input: null, repoRoot,
            role: needsStdoutLlvmValidation ? "emit" : "run");
    }
    else
    {
    var compilerArguments = new List<string>
    {
        compilerDll,
        "build"
    };
    if (File.Exists(projectPath))
    {
        var projectArguments = File.ReadLines(projectPath)
            .Where(static line => !string.IsNullOrWhiteSpace(line))
            .Select(static line => line.Trim())
            .ToArray();
        var projectReference = projectArguments[0];
        compilerArguments.AddRange([
            string.Equals(Path.GetExtension(projectReference), ".workspace", StringComparison.OrdinalIgnoreCase)
                ? "--workspace"
                : "--project",
            ResolveGeneratedFixturePath(projectReference, repoRoot, baseArtifactsDir)
        ]);
        compilerArguments.AddRange(projectArguments[1..]);
    }
    else if (File.Exists(sourcesPath))
    {
        var sourceArguments = File.ReadLines(sourcesPath)
            .Where(static line => !string.IsNullOrWhiteSpace(line))
            .Select(line => Path.GetFullPath(line.Trim(), repoRoot))
            .ToArray();
        if (!string.Equals(sourcePath, defaultSourcePath, StringComparison.OrdinalIgnoreCase)
            && sourceArguments.Length != 0
            && string.Equals(
                sourceArguments[0],
                Path.GetFullPath(defaultSourcePath),
                StringComparison.OrdinalIgnoreCase))
        {
            sourceArguments[0] = sourcePath;
        }
        compilerArguments.AddRange(sourceArguments);
    }
    else
    {
        compilerArguments.Add(sourcePath);
    }
    compilerArguments.AddRange([
        "-o", outputPath,
        "--target", TestTargetName(testTarget),
        "--llvm", llvmDir,
        "-O1"
    ]);
    if (verifyLlvm)
    {
        compilerArguments.Add("--keep-temps");
    }

    var unexpectedWarningsPath = Path.Combine(artifactsDir, name + ".unexpected-warnings.log");
    File.Delete(unexpectedWarningsPath);
    var build = RunCompiler(
        compilerArguments,
        input: null,
        repoRoot);

    if (build.ExitCode != 0)
    {
        Console.Error.WriteLine($"FAIL {name}: compiler exited {build.ExitCode}");
        Console.Error.WriteLine(build.Stdout);
        Console.Error.WriteLine(build.Stderr);
        Interlocked.Increment(ref failures);
        return;
    }

    var compilerOutput = build.Stdout + build.Stderr;
    if (hasExactCompilerStderr != File.Exists(compilerStderrExactPath))
        throw new InvalidDataException("Compiler diagnostic contract presence changed during verification.");
    var exactCompilerStderr = hasExactCompilerStderr ? File.ReadAllText(compilerStderrExactPath, Encoding.UTF8) : null;
    if ((hasExactCompilerStderr || !File.Exists(compilerStderrContainsPath))
        && !CompilerDiagnosticAssertions.Verify(build.Stdout, build.Stderr, exactCompilerStderr, out var compilerDiagnosticError))
    {
        File.WriteAllText(
            unexpectedWarningsPath,
            compilerOutput,
            new UTF8Encoding(false));
        Console.Error.WriteLine($"FAIL {name}: {compilerDiagnosticError}");
        Console.Error.WriteLine(compilerOutput);
        Interlocked.Increment(ref failures);
        return;
    }

    if (verifyLlvm
        && !LlvmAssertions.Verify(
            outputPath + ".ll",
            llvmContainsPath,
            llvmNotContainsPath,
            llvmRegexCountsPath,
            out var llvmError))
    {
        Console.Error.WriteLine($"FAIL {name}: {llvmError}");
        Interlocked.Increment(ref failures);
        return;
    }

    if (File.Exists(wasmLlvmContainsPath))
    {
        var wasmOutputPath = Path.Combine(artifactsDir, CompilationArtifactStem(name, "wasm32-browser") + ".wasm");
        var wasmArguments = new List<string>
        {
            compilerDll, "build", sourcePath,
            "-o", wasmOutputPath,
            "--target", "wasm32-browser",
            "--llvm", llvmDir,
            "-O1",
            "--keep-temps"
        };
        var wasmUnexpectedWarningsPath = Path.Combine(artifactsDir, name + ".wasm32.unexpected-warnings.log");
        File.Delete(wasmUnexpectedWarningsPath);
        var wasmBuild = RunCompiler(wasmArguments, input: null, repoRoot);
        var wasmLlvmError = string.Empty;
        if (wasmBuild.ExitCode != 0
            || !LlvmAssertions.Verify(
                wasmOutputPath + ".ll",
                wasmLlvmContainsPath,
                Path.Combine(expectedDir, name + ".wasm32.llvm.not-contains.txt"),
                Path.Combine(expectedDir, name + ".wasm32.llvm.regex-counts.txt"),
                out wasmLlvmError))
        {
            Console.Error.WriteLine($"FAIL {name}: wasm32 LLVM verification failed");
            Console.Error.WriteLine(wasmBuild.Stdout);
            Console.Error.WriteLine(wasmBuild.Stderr);
            Console.Error.WriteLine(wasmLlvmError);
            Interlocked.Increment(ref failures);
            return;
        }
        var wasmCompilerOutput = wasmBuild.Stdout + wasmBuild.Stderr;
        if ((hasExactCompilerStderr || !File.Exists(compilerStderrContainsPath))
            && !CompilerDiagnosticAssertions.Verify(wasmBuild.Stdout, wasmBuild.Stderr, exactCompilerStderr, out _))
        {
            File.WriteAllText(
                wasmUnexpectedWarningsPath,
                wasmCompilerOutput,
                new UTF8Encoding(false));
            Console.Error.WriteLine($"FAIL {name}: unexpected Sollang compiler warning for wasm32-browser");
            Console.Error.WriteLine(wasmCompilerOutput);
            Interlocked.Increment(ref failures);
            return;
        }
    }

    if (File.Exists(compileOnlyPath))
    {
        passed = true;
        return;
    }

    if (File.Exists(compilerStderrContainsPath))
    {
        var expectedCompilerDiagnostic = Normalize(
            File.ReadAllText(compilerStderrContainsPath, Encoding.UTF8)).Trim();
        var actualCompilerDiagnostic = Normalize(build.Stdout + build.Stderr);
        if (!actualCompilerDiagnostic.Contains(expectedCompilerDiagnostic, StringComparison.Ordinal))
        {
            Console.Error.WriteLine($"FAIL {name}: expected compiler diagnostic containing:");
            Console.Error.WriteLine(expectedCompilerDiagnostic);
            Console.Error.WriteLine("ACTUAL:");
            Console.Error.WriteLine(actualCompilerDiagnostic);
            Interlocked.Increment(ref failures);
            return;
        }
    }

    var stdin = File.Exists(stdinPath)
        ? File.ReadAllText(stdinPath, Encoding.UTF8)
        : null;
    var runArguments = File.Exists(argumentsPath)
        ? File.ReadAllLines(argumentsPath, Encoding.UTF8).ToList()
        : [];
    var runEnvironment = File.Exists(environmentPath)
        ? File.ReadAllLines(environmentPath, Encoding.UTF8)
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .Select(line => line.Split('=', 2))
            .ToDictionary(parts => parts[0], parts => parts.Length == 2 ? parts[1] : "", StringComparer.Ordinal)
        : null;
    if (!reusableSelfHostTest)
    {
        run = RunTargetExecutable(
            testTarget,
            outputPath,
            runArguments,
            stdin,
            repoRoot,
            runEnvironment,
            wslDistribution, role: needsStdoutLlvmValidation ? "emit" : "run");
    }
    }
    var actual = Normalize(run.Stdout);
    var compareRawStdout = testTarget == TestTarget.WindowsX64
        || !reusableSelfHostTest
        || selfHostMode.StartsWith("wasm", StringComparison.Ordinal);
    var expected = compareRawStdout
        ? Normalize(File.ReadAllText(expectedStdoutPath, Encoding.UTF8))
        : actual;

    if (run.ExitCode != 0)
    {
        Console.Error.WriteLine($"FAIL {name}: executable exited {run.ExitCode}");
        Console.Error.WriteLine(run.Stdout);
        Console.Error.WriteLine(run.Stderr);
        Interlocked.Increment(ref failures);
        return;
    }

    if (needsStdoutLlvmValidation
        || (testTarget == TestTarget.LinuxX64
            && reusableSelfHostTest
            && !selfHostMode.StartsWith("wasm", StringComparison.Ordinal)))
    {
        var stdoutArtifactStem = CompilationArtifactStem(name, TestTargetName(testTarget));
        var stdoutLlvmPath = Path.Combine(artifactsDir, stdoutArtifactStem + ".stdout.ll");
        var stdoutBitcodePath = Path.Combine(artifactsDir, stdoutArtifactStem + ".stdout.bc");
        File.WriteAllText(stdoutLlvmPath, actual, new UTF8Encoding(false));
        var llvmAs = Run(llvmAsPath, [stdoutLlvmPath, "-o", stdoutBitcodePath], input: null, repoRoot);
        if (llvmAs.ExitCode != 0)
        {
            Console.Error.WriteLine($"FAIL {name}: stdout is not valid LLVM IR");
            Console.Error.WriteLine(llvmAs.Stdout);
            Console.Error.WriteLine(llvmAs.Stderr);
            Interlocked.Increment(ref failures);
            return;
        }

        if (hasStdoutLlvmExecution)
        {
            var linkedTarget = LinkedLlvmExecutionTarget.Resolve(actual, reusableSelfHostTest ? selfHostMode : null);
            var targetExecutionPath = linkedTarget == TestTarget.WindowsX64 ? windowsLlvmExecutionPath : linuxLlvmExecutionPath;
            var executionPath = File.Exists(targetExecutionPath) ? targetExecutionPath : stdoutLlvmExecutionPath;
            if (!File.Exists(executionPath))
                throw new InvalidOperationException("LLVM_EXECUTION_EXPECTATION_MISSING");
            var linkedPath = Path.Combine(artifactsDir, CompilationArtifactStem(name, TestTargetName(linkedTarget)) + ".stdout" + TestExecutableSuffix(linkedTarget));
            var linkArguments = File.Exists(stdoutLlvmLinkArgumentsPath)
                ? File.ReadLines(stdoutLlvmLinkArgumentsPath)
                    .Where(static line => !string.IsNullOrWhiteSpace(line))
                    .Select(static line => line.Trim())
                    .ToArray()
                : [];
            if (linkedTarget == TestTarget.WindowsX64 && reusableSelfHostTest)
            {
                // Canonical stdlib emission carries the Windows runtime imports
                // also supplied by the normal compiler's Windows linker.
                linkArguments = ["-lws2_32", "-lshell32", "-lbcrypt", .. linkArguments];
            }
            var link = linkedTarget == TestTarget.LinuxX64
                ? LinkLinuxLlvm(clangPath, stdoutLlvmPath, linkedPath, repoRoot, wslDistribution)
                : Run(
                    clangPath,
                    ["-Wno-override-module", stdoutLlvmPath, "-o", linkedPath, .. linkArguments],
                    input: null,
                    repoRoot);
            if (link.ExitCode != 0)
            {
                Console.Error.WriteLine($"FAIL {name}: stdout LLVM could not be linked");
                Console.Error.WriteLine(link.Stdout);
                Console.Error.WriteLine(link.Stderr);
                Interlocked.Increment(ref failures);
                return;
            }

            var linkedRun = RunTargetExecutable(
                linkedTarget,
                linkedPath,
                [],
                input: null,
                repoRoot,
                environment: null,
                wslDistribution);
            var executionExpectation = Normalize(File.ReadAllText(executionPath, Encoding.UTF8));
            var expectedLinkedStdout = string.IsNullOrWhiteSpace(executionExpectation)
                || StringComparer.Ordinal.Equals(executionExpectation.Trim(), "exit=0")
                ? string.Empty
                : executionExpectation;
            var actualLinkedStdout = Normalize(linkedRun.Stdout);
            if (linkedRun.ExitCode != 0
                || !StringComparer.Ordinal.Equals(expectedLinkedStdout, actualLinkedStdout))
            {
                Console.Error.WriteLine($"FAIL {name}: linked stdout LLVM executable failed");
                Console.Error.WriteLine("EXPECTED:");
                Console.Error.WriteLine(expectedLinkedStdout);
                Console.Error.WriteLine("ACTUAL:");
                Console.Error.WriteLine(linkedRun.Stdout);
                Console.Error.WriteLine(linkedRun.Stderr);
                Interlocked.Increment(ref failures);
                return;
            }

            if (compareCompilers && selfHostSourcePaths is not null)
            {
                var referencePath = Path.Combine(artifactsDir, CompilationArtifactStem(name, TestTargetName(linkedTarget)) + ".reference" + TestExecutableSuffix(linkedTarget));
                var referenceArguments = new List<string> { compilerDll, "build" };
                referenceArguments.AddRange(selfHostSourcePaths);
                referenceArguments.AddRange([
                    "-o", referencePath,
                    "--target", TestTargetName(linkedTarget),
                    "--llvm", llvmDir,
                    "-O0",
                    "--keep-temps"
                ]);
                var referenceBuild = RunCompiler(referenceArguments, input: null, repoRoot, role: "reference-compile");
                if (referenceBuild.ExitCode != 0)
                {
                    Console.Error.WriteLine($"FAIL {name}: C# reference compiler failed during differential verification");
                    Console.Error.WriteLine(referenceBuild.Stdout);
                    Console.Error.WriteLine(referenceBuild.Stderr);
                    Interlocked.Increment(ref failures);
                    return;
                }

                var referenceRun = RunTargetExecutable(
                    linkedTarget,
                    referencePath,
                    [],
                    input: null,
                    repoRoot,
                    environment: null,
                    wslDistribution, role: "reference-run");
                var referenceStdout = Normalize(referenceRun.Stdout);
                if (referenceRun.ExitCode != linkedRun.ExitCode
                    || !StringComparer.Ordinal.Equals(referenceStdout, actualLinkedStdout))
                {
                    Console.Error.WriteLine($"FAIL {name}: C# and Sollang generated LLVM differ at runtime");
                    Console.Error.WriteLine("C# LLVM OUTPUT:");
                    Console.Error.WriteLine(referenceRun.Stdout);
                    Console.Error.WriteLine("Sollang LLVM OUTPUT:");
                    Console.Error.WriteLine(linkedRun.Stdout);
                    Interlocked.Increment(ref failures);
                    return;
                }
                managedReferenceVerified = true;
            }
        }
    }

    if (baselineCandidates is not null)
    {
        if (!managedReferenceVerified)
            throw new InvalidOperationException("BASELINE_CANDIDATE_REFERENCE_NOT_VERIFIED");
        baselineCandidates.Write(name, expectedStdoutPath, actual);
        passed = true;
        return;
    }

    // LLVM structure, linked behavior, and the managed reference must be
    // observed before an exact snapshot mismatch returns or an explicit
    // refresh changes its oracle. A stale snapshot never bypasses these checks.
    if (!StringComparer.Ordinal.Equals(expected, actual) && updateExpected)
    {
        File.WriteAllText(expectedStdoutPath, actual, new UTF8Encoding(false));
        expected = actual;
        Console.WriteLine($"UPDATE {name}: expected stdout refreshed");
        Console.Out.Flush();
    }

    if (!StringComparer.Ordinal.Equals(expected, actual))
    {
        Console.Error.WriteLine($"FAIL {name}: stdout mismatch");
        ReportStdoutMismatch(artifactsDir, name, expected, actual);
        Interlocked.Increment(ref failures);
        return;
    }

    passed = true;
    }
    finally
    {
        if (testLockTaken)
        {
            testMutex.ReleaseMutex();
        }
        ReportCompleted(name, passed, stopwatch.Elapsed);
    }
});

Parallel.ForEach(diagnosticFiles, new ParallelOptions { MaxDegreeOfParallelism = jobs }, sourcePath =>
{
    if (ExampleTestResults.Current?.Cancelled == true) return;
    var stopwatch = Stopwatch.StartNew();
    var name = Path.GetFileNameWithoutExtension(sourcePath);
    var displayName = $"diagnostic/{name}";
    var passed = false;
    ReportStarted(displayName);
    using var testMutex = new Mutex(
        initiallyOwned: false,
        TestMutexName(repoRoot, $"diagnostic:{TestTargetName(testTarget)}:{name}"));
    var testLockTaken = false;
    try
    {
    try
    {
        testLockTaken = testMutex.WaitOne();
    }
    catch (AbandonedMutexException)
    {
        testLockTaken = true;
    }
    var targetExpectedPath = Path.Combine(
        diagnosticDir,
        name + "." + TestTargetName(testTarget) + ".stderr.contains.txt");
    var expectedPath = File.Exists(targetExpectedPath)
        ? targetExpectedPath
        : Path.Combine(diagnosticDir, name + ".stderr.contains.txt");
    var sourcesPath = Path.Combine(diagnosticDir, name + ".sources.txt");
    var diagnosticTarget = name.Contains("-wasm32-", StringComparison.Ordinal)
        ? "wasm32-browser"
        : name.Contains("-linux-x64-", StringComparison.Ordinal)
            ? "linux-x64"
            : TestTargetName(testTarget);
    ExampleTestResults.Oracle("compiler-diagnostic", expectedPath, requiredLlvmAssertions: false);
    if (!File.Exists(expectedPath))
    {
        Console.Error.WriteLine($"FAIL diagnostic/{name}: expected diagnostic file not found");
        Interlocked.Increment(ref failures);
        return;
    }

    var diagnosticArguments = new List<string> { compilerDll, "build" };
    if (File.Exists(sourcesPath))
    {
        diagnosticArguments.AddRange(File.ReadLines(sourcesPath)
            .Where(static line => !string.IsNullOrWhiteSpace(line))
            .Select(line => Path.GetFullPath(line.Trim(), repoRoot)));
    }
    else
    {
        if (string.Equals(Path.GetExtension(sourcePath), ".project", StringComparison.OrdinalIgnoreCase))
        {
            diagnosticArguments.AddRange(["--project", sourcePath]);
        }
        else if (string.Equals(Path.GetExtension(sourcePath), ".workspace", StringComparison.OrdinalIgnoreCase))
        {
            diagnosticArguments.AddRange(["--workspace", sourcePath]);
            if (name.Contains("lock-stale", StringComparison.Ordinal))
            {
                diagnosticArguments.Add("--locked");
            }
        }
        else
        {
            diagnosticArguments.Add(sourcePath);
        }
    }
    diagnosticArguments.AddRange([
        "-o", Path.Combine(artifactsDir, CompilationArtifactStem(displayName, diagnosticTarget) + TestExecutableSuffix(testTarget)),
        "--target", diagnosticTarget,
        "--llvm", llvmDir
    ]);
    var build = RunCompiler(
        diagnosticArguments,
        input: null,
        repoRoot);
    var expectedDiagnostic = Normalize(File.ReadAllText(expectedPath, Encoding.UTF8)).Trim();
    var actualDiagnostic = Normalize(build.Stdout + build.Stderr);
    if (build.ExitCode == 0 || !actualDiagnostic.Contains(expectedDiagnostic, StringComparison.Ordinal))
    {
        Console.Error.WriteLine($"FAIL diagnostic/{name}: expected compiler failure containing:");
        Console.Error.WriteLine(expectedDiagnostic);
        Console.Error.WriteLine("ACTUAL:");
        Console.Error.WriteLine(actualDiagnostic);
        Interlocked.Increment(ref failures);
        return;
    }

    passed = true;
    }
    finally
    {
        if (testLockTaken)
        {
            testMutex.ReleaseMutex();
        }
        ReportCompleted(displayName, passed, stopwatch.Elapsed);
    }
});

var recordPassed = results?.Finish(failures == 0) ?? failures == 0;
if (failures == 0 && recordPassed)
{
    Console.WriteLine(baselineCandidates is null
        ? $"All {expectedFiles.Length + diagnosticFiles.Length} example tests passed."
        : $"Staged {expectedFiles.Length} LLVM baseline candidates after runtime/reference checks; regression acceptance remains pending.");
    return 0;
}

Console.Error.WriteLine($"{failures} example test(s) failed.");
if (!recordPassed && failures == 0) Console.Error.WriteLine("Result record rejected: cancelled, incomplete, process failure or input drift.");
return 1;

// Generated project fixtures retain their declared logical paths, with physical
// files isolated alongside the selected run's other compiler artifacts.
static string ResolveGeneratedFixturePath(string declaredPath, string repoRoot, string artifactsRoot)
{
    var path = Path.GetFullPath(declaredPath, repoRoot);
    var legacy = Path.Combine(repoRoot, "artifacts", "example-tests") + Path.DirectorySeparatorChar;
    return path.StartsWith(legacy, StringComparison.OrdinalIgnoreCase)
        ? Path.Combine(artifactsRoot, Path.GetRelativePath(legacy, path)) : path;
}

static IEnumerable<string> CollectResultInputs(string repoRoot, string expectedDir, string diagnosticDir,
    string[] expectedFiles, string[] diagnosticFiles, TestTarget target)
{
    var inputs = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    void Add(string path)
    {
        path = Path.GetFullPath(path, repoRoot);
        if (Directory.Exists(path))
        {
            foreach (var file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories)
                .Where(file => Path.GetExtension(file) is ".slg" or ".project" or ".workspace" or ".lock" or ".h" or ".hpp"))
                inputs.Add(file);
        }
        else if (File.Exists(path)) inputs.Add(path);
        else throw new FileNotFoundException("Selected fixture dependency is missing", path);
    }
    void Sidecars(string folder, string name)
    {
        foreach (var path in Directory.EnumerateFiles(folder, name + ".*"))
        {
            Add(path);
            if (path.EndsWith(".sources.txt", StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".root.txt", StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".runtime-inputs.txt", StringComparison.OrdinalIgnoreCase))
                foreach (var reference in File.ReadLines(path).Where(line => !string.IsNullOrWhiteSpace(line))) Add(reference.Trim());
        }
    }
    foreach (var expected in expectedFiles)
    {
        var name = Path.GetFileName(expected)[..^".stdout.txt".Length];
        Sidecars(expectedDir, name);
        var ordinary = Path.Combine(repoRoot, "examples", "regression", name + ".slg");
        var targetSource = Path.Combine(repoRoot, "examples", "regression", name + "." + TestTargetName(target) + ".slg");
        var project = Path.Combine(expectedDir, name + ".project.txt");
        if (File.Exists(targetSource)) Add(targetSource);
        else if (File.Exists(ordinary)) Add(ordinary);
        else if (!File.Exists(project)) throw new FileNotFoundException("Selected source or project declaration is missing", ordinary);
        if (File.Exists(project))
        {
            var reference = File.ReadLines(project).First(line => !string.IsNullOrWhiteSpace(line)).Trim();
            // These existing setup producers create their inputs after catalog preflight.
            // Pin their declaration and producer source; do not manufacture a source hash.
            var generatedReference = name switch
            {
                "442-git-dependency" => "artifacts/example-tests/442-git-dependency/app",
                "443-registry-dependency" => "artifacts/example-tests/443-registry-dependency/app-latest",
                "444-registry-lock-pin" => "artifacts/example-tests/443-registry-dependency/app-pinned",
                _ => null
            };
            if (generatedReference is null) Add(reference);
            else if (!string.Equals(Path.GetFullPath(reference, repoRoot), Path.GetFullPath(generatedReference, repoRoot), StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Generated fixture declaration differs from its existing setup producer");
        }
    }
    foreach (var diagnostic in diagnosticFiles)
    {
        Add(diagnostic);
        Sidecars(diagnosticDir, Path.GetFileNameWithoutExtension(diagnostic));
    }
    // Static project fixtures declare relative roots, dependencies and members.
    // Protect the existing fixture trees rather than parsing negative manifests
    // with a second, potentially divergent project/workspace resolver.
    if (diagnosticFiles.Any(file => Path.GetExtension(file) is ".project" or ".workspace"))
        Add(Path.Combine(diagnosticDir, "projects"));
    if (expectedFiles.Any(file => File.Exists(Path.Combine(expectedDir,
            Path.GetFileName(file)[..^".stdout.txt".Length] + ".project.txt"))))
        Add(Path.Combine(repoRoot, "examples", "regression", "projects"));
    Add(Path.Combine(repoRoot, "stdlib"));
    if (expectedFiles.Any(IsReusableSelfHostCompilerTest))
    {
        Add(Path.Combine(repoRoot, "selfhost"));
        Add(Path.Combine(repoRoot, "syntax"));
        Add(Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "Fixtures", "selfhost-sollangc-driver.sources.txt"));
    }
    return inputs.Order(StringComparer.Ordinal).ToArray();
}

static string TestMutexName(string repoRoot, string scope)
{
    var identity = Encoding.UTF8.GetBytes(Path.GetFullPath(repoRoot) + "\n" + scope);
    return "Sollang.ExampleTests." + Convert.ToHexString(SHA256.HashData(identity));
}

static string FindRepositoryRoot(string startPath)
{
    for (var current = new DirectoryInfo(startPath); current is not null; current = current.Parent)
    {
        if (File.Exists(Path.Combine(current.FullName, "Sollang.slnx")))
        {
            return current.FullName;
        }
    }

    throw new InvalidOperationException("Could not find repository root.");
}

static bool MatchesFilters(
    string name,
    IReadOnlyList<string> filters,
    IReadOnlyList<string> exactFilters) => (filters.Count == 0 && exactFilters.Count == 0)
    || filters.Any(filter => name.Contains(filter, StringComparison.OrdinalIgnoreCase))
    || exactFilters.Any(filter => name.Equals(filter, StringComparison.OrdinalIgnoreCase));

static bool MatchesSuite(string path, TestSuite suite) => suite switch
{
    TestSuite.Fast => !IsExpensiveSelfHostLlvmTest(path),
    TestSuite.Reference => !IsSelfHostTest(path),
    TestSuite.Semantic => IsSelfHostTest(path) && !IsExpensiveSelfHostLlvmTest(path),
    TestSuite.SelfHost => IsSelfHostTest(path),
    TestSuite.Llvm => IsExpensiveSelfHostLlvmTest(path),
    _ => true
};

static bool MatchesAffectedExpected(
    string expectedFile,
    string repoRoot,
    string expectedDir,
    IReadOnlySet<string> affectedPaths,
    AffectedDependencyGraph affectedGraph)
{
    if (affectedPaths.Count == 0)
    {
        return true;
    }

    var name = Path.GetFileName(expectedFile)[..^".stdout.txt".Length];
    if (affectedGraph.HasGlobalCompilerImpact)
    {
        return true;
    }

    var sourceFile = Path.Combine(repoRoot, "examples", "regression", name + ".slg");
    if (affectedPaths.Contains(Path.GetFullPath(expectedFile))
        || affectedPaths.Contains(sourceFile)
        || affectedPaths.Contains(Path.Combine(expectedDir, name + ".project.txt")))
    {
        return true;
    }

    var sourcesPath = Path.Combine(expectedDir, name + ".sources.txt");
    var rootPath = Path.Combine(expectedDir, name + ".root.txt");
    if (File.Exists(rootPath))
    {
        if (affectedPaths.Contains(Path.GetFullPath(rootPath)))
        {
            return true;
        }

        var rootReference = File.ReadLines(rootPath)
            .First(static line => !string.IsNullOrWhiteSpace(line))
            .Trim();
        var sourceRoot = Path.GetFullPath(rootReference, repoRoot)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        if (affectedPaths.Any(path => path.StartsWith(sourceRoot, StringComparison.OrdinalIgnoreCase)))
        {
            return true;
        }
    }

    var explicitSources = ReadSourceManifest(sourcesPath, repoRoot);
    return MatchesAffectedSources(sourcesPath, repoRoot, affectedPaths)
        || affectedGraph.DependsOnAffected(
            File.Exists(sourceFile) ? explicitSources.Append(sourceFile) : explicitSources);
}

static bool MatchesAffectedDiagnostic(
    string sourceFile,
    string diagnosticDir,
    string repoRoot,
    IReadOnlySet<string> affectedPaths,
    AffectedDependencyGraph affectedGraph)
{
    if (affectedPaths.Count == 0)
    {
        return true;
    }

    var name = Path.GetFileNameWithoutExtension(sourceFile);
    if (affectedGraph.HasGlobalCompilerImpact)
    {
        return true;
    }

    if (affectedPaths.Contains(Path.GetFullPath(sourceFile))
        || affectedPaths.Contains(Path.Combine(diagnosticDir, name + ".stderr.contains.txt"))
        || affectedPaths.Contains(Path.Combine(diagnosticDir, name + ".windows-x64.stderr.contains.txt"))
        || affectedPaths.Contains(Path.Combine(diagnosticDir, name + ".linux-x64.stderr.contains.txt")))
    {
        return true;
    }

    var sourcesPath = Path.Combine(diagnosticDir, name + ".sources.txt");
    var explicitSources = ReadSourceManifest(sourcesPath, repoRoot);
    return MatchesAffectedSources(sourcesPath, repoRoot, affectedPaths)
        || affectedGraph.DependsOnAffected(explicitSources.Append(sourceFile));
}

static IEnumerable<string> ReadSourceManifest(string sourcesPath, string repoRoot) =>
    File.Exists(sourcesPath)
        ? File.ReadLines(sourcesPath)
            .Where(static line => !string.IsNullOrWhiteSpace(line))
            .Select(line => Path.GetFullPath(line.Trim(), repoRoot))
        : [];

static bool MatchesAffectedSources(
    string sourcesPath,
    string repoRoot,
    IReadOnlySet<string> affectedPaths)
{
    if (!File.Exists(sourcesPath))
    {
        return false;
    }

    if (affectedPaths.Contains(Path.GetFullPath(sourcesPath)))
    {
        return true;
    }

    return File.ReadLines(sourcesPath)
        .Where(line => !string.IsNullOrWhiteSpace(line))
        .Select(line => Path.GetFullPath(line.Trim(), repoRoot))
        .Any(affectedPaths.Contains);
}

static bool IsExpensiveSelfHostLlvmTest(string path) => Path
    .GetFileName(path)
    .Contains("selfhost-llvm-", StringComparison.Ordinal);

static bool IsReusableSelfHostCompilerTest(string path)
{
    var name = Path.GetFileName(path);
    if (name.StartsWith("195-selfhost-llvm-target-descriptor", StringComparison.Ordinal)
        || name.StartsWith("291-selfhost-llvm-canonical-type-selection", StringComparison.Ordinal))
        return false;
    if (name.Contains("selfhost-llvm-", StringComparison.Ordinal)) return true;
    const string suffix = ".stdout.txt";
    if (!name.EndsWith(suffix, StringComparison.Ordinal)) return false;
    var stem = name[..^suffix.Length];
    var expectedDirectory = Path.GetDirectoryName(Path.GetFullPath(path))!;
    if (!File.Exists(Path.Combine(expectedDirectory, stem + ".root.txt"))) return false;
    var sourceDirectory = Directory.GetParent(expectedDirectory)?.FullName;
    if (sourceDirectory is null) return false;
    var sourcePath = Path.Combine(sourceDirectory, stem + ".slg");
    return File.Exists(sourcePath)
        && RawLlvmFixture.SupportsCanonicalProviderEmission(File.ReadAllText(sourcePath));
}

static string SelfHostTargetMode(string source, TestTarget testTarget) =>
    source.Contains("llvm.emitWasm", StringComparison.Ordinal)
        ? "wasm"
        : testTarget == TestTarget.LinuxX64
            || source.Contains("llvm.emitLinux", StringComparison.Ordinal)
                ? "linux"
                : "windows";

static IEnumerable<string> ExtractRawMultilineStrings(string source)
{
    var matches = Regex.Matches(
        source,
        "\"\"\"\\r?\\n(?<body>.*?)\\r?\\n[ \\t]*\"\"\"",
        RegexOptions.Singleline);
    if (matches.Count == 0)
    {
        throw new InvalidOperationException("Reusable self-host compiler test requires at least one raw multiline source string.");
    }

    foreach (Match match in matches)
    {
        var lines = Normalize(match.Groups["body"].Value).Split('\n');
        var indentation = lines
            .Where(static line => line.Length != 0)
            .Select(static line => line.TakeWhile(static character => character is ' ' or '\t').Count())
            .DefaultIfEmpty(0)
            .Min();
        yield return string.Join('\n', lines.Select(line =>
            line.Length >= indentation ? line[indentation..] : string.Empty));
    }
}

static string[] MaterializeSelfHostSources(
    string testName,
    IEnumerable<string> sources,
    string artifactsDir)
{
    var sourceDirectory = Path.Combine(artifactsDir, "selfhost-inputs", CompilationArtifactStem(testName, "source-input"));
    Directory.CreateDirectory(sourceDirectory);
    return sources.Select((source, index) =>
    {
        var sourcePath = Path.Combine(sourceDirectory, $"source-{index}.slg");
        File.WriteAllText(sourcePath, source, new UTF8Encoding(false));
        return sourcePath;
    }).ToArray();
}

static bool IsOutputCurrent(
    string outputPath,
    string fingerprintPath,
    string? inputFingerprint)
{
    if (!File.Exists(outputPath)
        || inputFingerprint is null
        || !File.Exists(fingerprintPath))
    {
        return false;
    }

    return StringComparer.Ordinal.Equals(
        File.ReadAllText(fingerprintPath).Trim(),
        inputFingerprint);
}

static string? ComputeInputFingerprint(IEnumerable<string> inputPaths)
{
    using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
    var buffer = new byte[64 * 1024];
    foreach (var inputPath in inputPaths
        .Select(Path.GetFullPath)
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .Order(StringComparer.OrdinalIgnoreCase))
    {
        if (!File.Exists(inputPath))
        {
            return null;
        }

        var normalizedPath = inputPath.Replace('\\', '/');
        var pathBytes = Encoding.UTF8.GetBytes(normalizedPath);
        hash.AppendData(BitConverter.GetBytes(pathBytes.Length));
        hash.AppendData(pathBytes);

        using var input = File.OpenRead(inputPath);
        hash.AppendData(BitConverter.GetBytes(input.Length));
        int read;
        while ((read = input.Read(buffer, 0, buffer.Length)) != 0)
        {
            hash.AppendData(buffer, 0, read);
        }
    }

    return Convert.ToHexString(hash.GetHashAndReset());
}

static void WriteFingerprintAtomically(string fingerprintPath, string fingerprint)
{
    var temporaryPath = fingerprintPath + "." + Environment.ProcessId + ".tmp";
    File.WriteAllText(temporaryPath, fingerprint + Environment.NewLine, new UTF8Encoding(false));
    File.Move(temporaryPath, fingerprintPath, overwrite: true);
}

static bool IsSelfHostTest(string path) => Path
    .GetFileName(path)
    .Contains("selfhost-", StringComparison.Ordinal);

static bool TryParseTestTarget(string value, out TestTarget target)
{
    switch (value.ToLowerInvariant())
    {
        case "windows-x64":
            target = TestTarget.WindowsX64;
            return true;
        case "linux-x64":
            target = TestTarget.LinuxX64;
            return true;
        default:
            target = default;
            return false;
    }
}

static string TestTargetName(TestTarget target) => target switch
{
    TestTarget.WindowsX64 => "windows-x64",
    TestTarget.LinuxX64 => "linux-x64",
    _ => throw new ArgumentOutOfRangeException(nameof(target), target, null)
};

// Full case identity remains in result records; private file names have a bounded stem.
static string CompilationArtifactStem(string caseId, string target) =>
    Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(caseId + "\0" + target)))
        .TrimEnd('=').Replace('+', '-').Replace('/', '_');

static string TestExecutableSuffix(TestTarget target) => target switch
{
    TestTarget.WindowsX64 => ".exe",
    TestTarget.LinuxX64 => ".linux",
    _ => throw new ArgumentOutOfRangeException(nameof(target), target, null)
};

static ProcessResult RunTargetExecutable(
    TestTarget target,
    string executablePath,
    IReadOnlyList<string> args,
    string? input,
    string workingDirectory,
    IReadOnlyDictionary<string, string>? environment,
    string wslDistribution,
    string role = "run") => target switch
{
    TestTarget.WindowsX64 => Run(executablePath, args, input, workingDirectory, environment, role: role),
    TestTarget.LinuxX64 => RunInWsl(
        executablePath,
        args,
        input,
        workingDirectory,
        environment,
        wslDistribution, role),
    _ => throw new ArgumentOutOfRangeException(nameof(target), target, null)
};

static ProcessResult RunInWsl(
    string executablePath,
    IReadOnlyList<string> args,
    string? input,
    string workingDirectory,
    IReadOnlyDictionary<string, string>? environment,
    string wslDistribution,
    string role = "run")
{
    var wslArguments = new List<string>
    {
        "-d", wslDistribution,
        "--cd", ConvertToWslPath(workingDirectory),
        "--"
    };
    if (environment is not null && environment.Count != 0)
    {
        wslArguments.Add("env");
        wslArguments.AddRange(environment.Select(static pair => $"{pair.Key}={pair.Value}"));
    }
    wslArguments.Add(ConvertToWslPath(executablePath));
    wslArguments.AddRange(args);
    return Run("wsl.exe", wslArguments, input, workingDirectory, role: role);
}

static ProcessResult LinkLinuxLlvm(
    string clangPath,
    string llvmPath,
    string executablePath,
    string workingDirectory,
    string wslDistribution)
{
    var objectPath = Path.ChangeExtension(executablePath, ".o");
    var compile = Run(
        clangPath,
        ["--target=x86_64-unknown-linux-gnu", "-Wno-override-module", "-c", llvmPath, "-O0", "-o", objectPath],
        input: null,
        workingDirectory);
    if (compile.ExitCode != 0)
    {
        return compile;
    }

    return Run(
        "wsl.exe",
        [
            "-d", wslDistribution,
            "--cd", ConvertToWslPath(workingDirectory),
            "--", "gcc", ConvertToWslPath(objectPath), "-pthread", "-o", ConvertToWslPath(executablePath)
        ],
        input: null,
        workingDirectory);
}

static string ConvertToWslPath(string path)
{
    var absolute = Path.GetFullPath(path);
    if (absolute.Length < 3 || absolute[1] != ':' || absolute[2] != Path.DirectorySeparatorChar)
    {
        throw new InvalidOperationException($"WSL test paths must be drive-qualified Windows paths: {absolute}");
    }

    var drive = char.ToLowerInvariant(absolute[0]);
    return $"/mnt/{drive}/{absolute[3..].Replace('\\', '/')}";
}

static void PrepareGitDependencyFixture(string artifactsDir)
{
    var root = Path.Combine(artifactsDir, "442-git-dependency");
    if (Directory.Exists(root))
    {
        foreach (var path in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(path, FileAttributes.Normal);
        }
        Directory.Delete(root, recursive: true);
    }
    var remote = Path.Combine(root, "remote");
    var app = Path.Combine(root, "app");
    Directory.CreateDirectory(Path.Combine(remote, "src"));
    Directory.CreateDirectory(Path.Combine(remote, "base", "src"));
    Directory.CreateDirectory(Path.Combine(app, "src"));
    File.WriteAllText(
        Path.Combine(remote, "sollang.project"),
        "project {\n    name: \"remote\"\n    version: \"1.2.3\"\n    root: \"src/remote.slg\"\n    dependencies: { base: { path: \"base\", version: \"^1.0.0\" } }\n}\n",
        new UTF8Encoding(false));
    File.WriteAllText(
        Path.Combine(remote, "src", "remote.slg"),
        "namespace remote\n\nimport base\n\npublic addTwo value: Int -> Int {\n    value -> base.addOne => incremented\n    incremented + 1\n}\n",
        new UTF8Encoding(false));
    File.WriteAllText(
        Path.Combine(remote, "base", "sollang.project"),
        "project {\n    name: \"base\"\n    version: \"1.0.0\"\n    root: \"src/base.slg\"\n}\n",
        new UTF8Encoding(false));
    File.WriteAllText(
        Path.Combine(remote, "base", "src", "base.slg"),
        "namespace base\n\npublic addOne value: Int -> Int { value + 1 }\n",
        new UTF8Encoding(false));
    foreach (var command in new[]
    {
        new[] { "init", "--quiet" },
        new[] { "config", "user.name", "Sollang Tests" },
        new[] { "config", "user.email", "tests@sollang.invalid" },
        new[] { "add", "." },
        new[] { "commit", "--quiet", "-m", "fixture" }
    })
    {
        var result = Run("git", command, input: null, remote);
        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException($"failed to prepare Git dependency fixture: {result.Stderr}");
        }
    }
    var revisionResult = Run("git", ["rev-parse", "HEAD"], input: null, remote);
    if (revisionResult.ExitCode != 0)
    {
        throw new InvalidOperationException($"failed to read Git dependency fixture revision: {revisionResult.Stderr}");
    }
    var revision = revisionResult.Stdout.Trim();
    var portableRemote = remote.Replace('\\', '/');
    File.WriteAllText(
        Path.Combine(app, "sollang.project"),
        $"project {{\n    name: \"git_app\"\n    version: \"0.1.0\"\n    root: \"src/main.slg\"\n    dependencies: {{\n        remote: {{ git: \"{portableRemote}\", rev: \"{revision}\", version: \"^1.2.0\" }}\n    }}\n}}\n",
        new UTF8Encoding(false));
    File.WriteAllText(
        Path.Combine(app, "src", "main.slg"),
        "import remote\n\nmain { 40 -> remote.addTwo => value\n    \"$value\" -> println }\n",
        new UTF8Encoding(false));
}

static void PrepareRegistryDependencyFixture(
    string artifactsDir,
    string compilerDll,
    string repoRoot)
{
    var root = Path.Combine(artifactsDir, "443-registry-dependency");
    if (Directory.Exists(root))
    {
        foreach (var path in Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(path, FileAttributes.Normal);
        }
        Directory.Delete(root, recursive: true);
    }
    var registry = Path.Combine(root, "registry");
    var packageDirectory = Path.Combine(registry, "v1", "remote");
    Directory.CreateDirectory(packageDirectory);
    var versions = new[]
    {
        (Version: "1.1.0", Value: 41, Yanked: false),
        (Version: "1.2.3", Value: 42, Yanked: false),
        (Version: "1.3.0", Value: 99, Yanked: true),
        (Version: "1.4.0-beta.1", Value: 100, Yanked: false)
    };
    var checksums = new Dictionary<string, string>(StringComparer.Ordinal);
    foreach (var version in versions)
    {
        var source = Path.Combine(root, "package-" + version.Version);
        Directory.CreateDirectory(Path.Combine(source, "src"));
        File.WriteAllText(
            Path.Combine(source, "sollang.project"),
            $"project {{\n    name: \"remote\"\n    version: \"{version.Version}\"\n    root: \"src/remote.slg\"\n}}\n",
            new UTF8Encoding(false));
        File.WriteAllText(
            Path.Combine(source, "src", "remote.slg"),
            $"namespace remote\n\npublic answer: -> Int => {version.Value}\n",
            new UTF8Encoding(false));
        var archive = Path.Combine(packageDirectory, version.Version + ".zip");
        ZipFile.CreateFromDirectory(source, archive, CompressionLevel.NoCompression, includeBaseDirectory: false);
        checksums[version.Version] = "sha256:"
            + Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(archive))).ToLowerInvariant();
    }
    var index = new StringBuilder("registry {\n    package: \"remote\"\n    versions: [\n");
    foreach (var version in versions)
    {
        index.Append("        { version: \"")
            .Append(version.Version)
            .Append("\", checksum: \"")
            .Append(checksums[version.Version])
            .Append("\", yanked: ")
            .Append(version.Yanked ? "true" : "false")
            .AppendLine(" }");
    }
    index.Append("    ]\n}\n");
    File.WriteAllText(Path.Combine(packageDirectory, "index.slg"), index.ToString(), new UTF8Encoding(false));

    var registryLocation = new Uri(registry).AbsoluteUri.TrimEnd('/');
    var appLatest = Path.Combine(root, "app-latest");
    var appPinned = Path.Combine(root, "app-pinned");
    var appUpdate = Path.Combine(root, "app-update");
    var appBadChecksum = Path.Combine(root, "app-bad-checksum");
    WriteRegistryApp(appLatest, registryLocation);
    WriteRegistryApp(appPinned, registryLocation);
    WriteRegistryApp(appUpdate, registryLocation);
    WriteRegistryApp(appBadChecksum, registryLocation);

    var resolve = RunCompiler(
        [compilerDll, "resolve", "--project", appLatest],
        input: null,
        repoRoot);
    if (resolve.ExitCode != 0)
    {
        throw new InvalidOperationException($"failed to resolve registry fixture: {resolve.Stderr}");
    }
    var latestLock = File.ReadAllText(Path.Combine(appLatest, "sollang.lock"));
    if (!latestLock.Contains("remote@1.2.3", StringComparison.Ordinal)
        || latestLock.Contains("remote@1.3.0", StringComparison.Ordinal))
    {
        throw new InvalidOperationException("registry fixture did not select the highest non-yanked compatible version");
    }

    WriteRegistryLock(appPinned, registryLocation, "1.1.0", checksums["1.1.0"]);
    WriteRegistryLock(appUpdate, registryLocation, "1.1.0", checksums["1.1.0"]);
    var update = RunCompiler(
        [compilerDll, "resolve", "--project", appUpdate],
        input: null,
        repoRoot);
    if (update.ExitCode != 0
        || !File.ReadAllText(Path.Combine(appUpdate, "sollang.lock"))
            .Contains("remote@1.2.3", StringComparison.Ordinal))
    {
        throw new InvalidOperationException("explicit registry resolve did not update the pinned version");
    }

    WriteRegistryLock(
        appBadChecksum,
        registryLocation,
        "1.1.0",
        "sha256:" + new string('0', 64));
    var badChecksum = RunCompiler(
        [compilerDll, "build", "--project", appBadChecksum, "--locked"],
        input: null,
        repoRoot);
    if (badChecksum.ExitCode == 0
        || !badChecksum.Stderr.Contains("registry archive checksum mismatch", StringComparison.Ordinal))
    {
        throw new InvalidOperationException("registry fixture did not reject a lock checksum mismatch");
    }

    static void WriteRegistryApp(string app, string registryLocation)
    {
        Directory.CreateDirectory(Path.Combine(app, "src"));
        File.WriteAllText(
            Path.Combine(app, "sollang.project"),
            $"project {{\n    name: \"registry_app\"\n    version: \"0.1.0\"\n    root: \"src/main.slg\"\n    dependencies: {{\n        remote: {{ registry: \"{registryLocation}\", version: \"^1.0.0\" }}\n    }}\n}}\n",
            new UTF8Encoding(false));
        File.WriteAllText(
            Path.Combine(app, "src", "main.slg"),
            "import remote\n\nmain { remote.answer() => value\n    \"$value\" -> println }\n",
            new UTF8Encoding(false));
    }

    static void WriteRegistryLock(
        string app,
        string registryLocation,
        string version,
        string checksum)
    {
        File.WriteAllText(
            Path.Combine(app, "sollang.lock"),
            $"lock {{\n    format: 2\n    packages: [\n        {{\n            id: \"registry_app@0.1.0\"\n            source: \"path:.\"\n            dependencies: [\n                \"remote@{version}\"\n            ]\n        }}\n        {{\n            id: \"remote@{version}\"\n            source: \"registry:{registryLocation}#{version}\"\n            checksum: \"{checksum}\"\n            dependencies: []\n        }}\n    ]\n}}\n",
            new UTF8Encoding(false));
    }
}

// One command/identity authority for managed DLL and native compiler products.
static CompilerInvocation CreateCompilerInvocation(IReadOnlyList<string> compilerArguments)
{
    if (compilerArguments.Count == 0)
    {
        throw new ArgumentException("Compiler argument vector must start with its product path.", nameof(compilerArguments));
    }
    var compilerPath = Path.GetFullPath(compilerArguments[0]);
    var managed = string.Equals(Path.GetExtension(compilerPath), ".dll", StringComparison.OrdinalIgnoreCase);
    var arguments = managed
        ? compilerArguments.ToArray()
        : compilerArguments.Skip(1).ToArray();
    var identityPaths = new List<string> { compilerPath };
    if (LlvmAssertions.IsManagedProducer(compilerPath))
    {
        if (!managed) identityPaths.Add(Path.ChangeExtension(compilerPath, ".dll"));
        foreach (var extension in new[] { ".deps.json", ".runtimeconfig.json" })
        {
            var sidecar = Path.ChangeExtension(compilerPath, extension);
            if (File.Exists(sidecar))
            {
                identityPaths.Add(sidecar);
            }
        }
    }
    return new CompilerInvocation(managed ? "dotnet" : compilerPath, arguments, identityPaths);
}

static ProcessResult RunCompiler(
    IReadOnlyList<string> compilerArguments,
    string? input,
    string workingDirectory,
    bool relayOutput = false,
    string role = "compile")
{
    var actualArguments = compilerArguments.ToList();
    if (!string.Equals(Path.GetExtension(actualArguments[0]), ".dll", StringComparison.OrdinalIgnoreCase)
        && actualArguments.Count > 1 && actualArguments[1] is "build" or "test"
        && !actualArguments.Contains("--stdlib", StringComparer.Ordinal))
    {
        actualArguments.AddRange(["--stdlib", Path.Combine(FindRepositoryRoot(workingDirectory), "stdlib")]);
    }
    var invocation = CreateCompilerInvocation(actualArguments);
    return Run(invocation.FileName, invocation.Arguments, input, workingDirectory, relayOutput: relayOutput, role: role);
}

static ProcessResult Run(
    string fileName,
    IReadOnlyList<string> args,
    string? input,
    string workingDirectory,
    IReadOnlyDictionary<string, string>? environment = null,
    bool relayOutput = false,
    string role = "process")
{
    const int ProcessTimeoutMilliseconds = 5 * 60 * 1000;
    using var process = new Process();
    process.StartInfo = new ProcessStartInfo
    {
        FileName = fileName,
        WorkingDirectory = workingDirectory,
        RedirectStandardInput = input is not null,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        StandardOutputEncoding = Encoding.UTF8,
        StandardErrorEncoding = Encoding.UTF8,
        UseShellExecute = false
    };

    foreach (var arg in args)
    {
        process.StartInfo.ArgumentList.Add(arg);
    }
    if (environment is not null)
    {
        foreach (var (name, value) in environment)
        {
            process.StartInfo.Environment[name] = value;
        }
    }

    ExampleTestResults.ProcessRecord? processRecord = null;
    ProcessResult? observed = null;
    var startedProcess = false;
    Task<string>? stdoutTask = null;
    Task<string>? stderrTask = null;
    string? observationError = null;
    var commandInputs = ExampleTestResults.CommandInputs(fileName, args, workingDirectory);
    try
    {
    process.Start();
    startedProcess = true;
    processRecord = ExampleTestResults.Started(process, fileName, args, workingDirectory, input, environment, role, commandInputs);
    if (input is not null)
    {
        process.StandardInput.Write(input);
        process.StandardInput.Close();
    }

    stdoutTask = relayOutput
        ? ReadAndRelayAsync(process.StandardOutput, Console.Out)
        : process.StandardOutput.ReadToEndAsync();
    stderrTask = relayOutput
        ? ReadAndRelayAsync(process.StandardError, Console.Error)
        : process.StandardError.ReadToEndAsync();
    if (!process.WaitForExit(ProcessTimeoutMilliseconds))
    {
        process.Kill(entireProcessTree: true);
        process.WaitForExit();
        Task.WaitAll(stdoutTask, stderrTask);
        observed = new ProcessResult(
            -1,
            stdoutTask.Result,
            $"process timed out after {ProcessTimeoutMilliseconds / 1000} seconds: {fileName}{Environment.NewLine}{stderrTask.Result}");
        return observed;
    }

    Task.WaitAll(stdoutTask, stderrTask);
    observed = new ProcessResult(process.ExitCode, stdoutTask.Result, stderrTask.Result);
    return observed;
    }
    catch (Exception error)
    {
        observationError = error.ToString();
        throw;
    }
    finally
    {
        if (startedProcess)
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit();
            }
            if (processRecord is not null && observed is null)
            {
                observed = new ProcessResult(process.ExitCode,
                    stdoutTask?.GetAwaiter().GetResult() ?? process.StandardOutput.ReadToEnd(),
                    stderrTask?.GetAwaiter().GetResult() ?? process.StandardError.ReadToEnd());
            }
            ExampleTestResults.Ended(processRecord, process, observed, observationError,
                stdoutTask?.GetAwaiter().GetResult(), stderrTask?.GetAwaiter().GetResult());
        }
    }
}

static async Task<string> ReadAndRelayAsync(StreamReader reader, TextWriter writer)
{
    var output = new StringBuilder();
    if (ExampleTestResults.Current is not null)
    {
        var buffer = new char[4096];
        int read;
        while ((read = await reader.ReadAsync(buffer)) > 0)
        {
            output.Append(buffer, 0, read);
            await writer.WriteAsync(buffer.AsMemory(0, read));
            await writer.FlushAsync();
        }
        return output.ToString();
    }
    while (await reader.ReadLineAsync() is { } line)
    {
        output.AppendLine(line);
        await writer.WriteLineAsync(line);
        await writer.FlushAsync();
    }
    return output.ToString();
}

static void ReportStdoutMismatch(string artifactsDirectory, string name, string expected, string actual)
{
    var expectedPath = Path.Combine(artifactsDirectory, name + ".stdout.expected.txt");
    var actualPath = Path.Combine(artifactsDirectory, name + ".stdout.actual.txt");
    File.WriteAllText(expectedPath, expected, new UTF8Encoding(false));
    File.WriteAllText(actualPath, actual, new UTF8Encoding(false));

    var offset = 0;
    var line = 1;
    var column = 1;
    while (offset < expected.Length && offset < actual.Length && expected[offset] == actual[offset])
    {
        if (expected[offset] == '\n') { line++; column = 1; }
        else column++;
        offset++;
    }
    string Preview(string value)
    {
        var start = Math.Max(0, offset - 80);
        return value.Substring(start, Math.Min(240, value.Length - start))
            .Replace("\r", "\\r", StringComparison.Ordinal)
            .Replace("\n", "\\n", StringComparison.Ordinal);
    }
    Console.Error.WriteLine($"First difference at line {line}, column {column} (character {offset}).");
    Console.Error.WriteLine($"EXPECTED ({expected.Length} characters): {expectedPath}");
    Console.Error.WriteLine(Preview(expected));
    Console.Error.WriteLine($"ACTUAL ({actual.Length} characters): {actualPath}");
    Console.Error.WriteLine(Preview(actual));
}

static string Normalize(string value)
{
    return value.Replace("\r\n", "\n", StringComparison.Ordinal);
}

internal sealed class AffectedDependencyGraph
{
    private static readonly Regex NamespacePattern = new(
        @"^\s*namespace\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)\s*$",
        RegexOptions.Compiled);
    private static readonly Regex ImportPattern = new(
        @"^\s*import\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)\b",
        RegexOptions.Compiled);

    private readonly IReadOnlySet<string> _affectedPaths;
    private readonly Dictionary<string, string[]> _moduleSources =
        new(StringComparer.Ordinal);
    private readonly Dictionary<string, string[]> _sourceImports =
        new(StringComparer.OrdinalIgnoreCase);

    public AffectedDependencyGraph(string repoRoot, IReadOnlySet<string> affectedPaths)
    {
        _affectedPaths = affectedPaths;
        HasGlobalCompilerImpact = affectedPaths.Any(path =>
            IsUnder(path, Path.Combine(repoRoot, "src", "Sollang.Compiler"))
            || IsUnder(path, Path.Combine(repoRoot, "src", "Sollang.Compiler.Generators"))
            || IsUnder(path, Path.Combine(repoRoot, "syntax"))
            || path.Equals(
                Path.Combine(repoRoot, "tests", "Sollang.ExampleTests", "Program.cs"),
                StringComparison.OrdinalIgnoreCase));

        if (affectedPaths.Count == 0)
        {
            return;
        }

        var stdlibRoot = Path.Combine(repoRoot, "stdlib");
        var modules = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        foreach (var source in Directory.EnumerateFiles(stdlibRoot, "*.slg", SearchOption.AllDirectories))
        {
            var module = ReadNamespace(source);
            if (module is null)
            {
                continue;
            }

            if (!modules.TryGetValue(module, out var sources))
            {
                sources = [];
                modules.Add(module, sources);
            }
            sources.Add(Path.GetFullPath(source));
        }

        foreach (var (module, sources) in modules)
        {
            _moduleSources.Add(module, sources.Order(StringComparer.Ordinal).ToArray());
        }
    }

    public bool HasGlobalCompilerImpact { get; }

    public bool DependsOnAffected(IEnumerable<string> roots)
    {
        if (_affectedPaths.Count == 0)
        {
            return true;
        }

        var pending = new Queue<string>(roots.Select(Path.GetFullPath));
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (pending.TryDequeue(out var source))
        {
            if (!visited.Add(source))
            {
                continue;
            }
            if (_affectedPaths.Contains(source))
            {
                return true;
            }
            if (!File.Exists(source))
            {
                continue;
            }

            foreach (var importedModule in ReadImports(source))
            {
                if (!_moduleSources.TryGetValue(importedModule, out var importedSources))
                {
                    continue;
                }
                foreach (var importedSource in importedSources)
                {
                    pending.Enqueue(importedSource);
                }
            }
        }
        return false;
    }

    private string[] ReadImports(string source)
    {
        if (_sourceImports.TryGetValue(source, out var imports))
        {
            return imports;
        }

        imports = File.ReadLines(source)
            .Select(line => ImportPattern.Match(line))
            .Where(static match => match.Success)
            .Select(static match => match.Groups["name"].Value)
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        _sourceImports.Add(source, imports);
        return imports;
    }

    private static string? ReadNamespace(string source)
    {
        foreach (var line in File.ReadLines(source))
        {
            var match = NamespacePattern.Match(line);
            if (match.Success)
            {
                return match.Groups["name"].Value;
            }
        }
        return null;
    }

    private static bool IsUnder(string path, string directory)
    {
        var prefix = Path.GetFullPath(directory).TrimEnd(
            Path.DirectorySeparatorChar,
            Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return Path.GetFullPath(path).StartsWith(prefix, StringComparison.OrdinalIgnoreCase);
    }
}

internal sealed record ProcessResult(int ExitCode, string Stdout, string Stderr);

internal enum TestSuite
{
    Fast,
    Reference,
    Semantic,
    SelfHost,
    Full,
    Llvm
}

internal enum TestTarget
{
    WindowsX64,
    LinuxX64
}

internal sealed record CompilerInvocation(
    string FileName, IReadOnlyList<string> Arguments, IReadOnlyList<string> IdentityPaths);
