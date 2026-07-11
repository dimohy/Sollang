using System.Diagnostics;
using System.Text;

var repoRoot = FindRepositoryRoot(AppContext.BaseDirectory);
var expectedDir = Path.Combine(repoRoot, "examples", "expected");
var artifactsDir = Path.Combine(repoRoot, "artifacts", "example-tests");
Directory.CreateDirectory(artifactsDir);

var expectedFiles = Directory
    .EnumerateFiles(expectedDir, "*.stdout.txt")
    .Order(StringComparer.Ordinal)
    .ToArray();

if (expectedFiles.Length == 0)
{
    Console.Error.WriteLine("No expected stdout files found.");
    return 1;
}

var failures = 0;
foreach (var expectedFile in expectedFiles)
{
    var name = Path.GetFileName(expectedFile)[..^".stdout.txt".Length];
    var sourcePath = Path.Combine(repoRoot, "examples", name + ".sl");
    var stdinPath = Path.Combine(expectedDir, name + ".stdin.txt");
    var outputPath = Path.Combine(artifactsDir, name + ".exe");
    var llvmContainsPath = Path.Combine(expectedDir, name + ".llvm.contains.txt");
    var llvmNotContainsPath = Path.Combine(expectedDir, name + ".llvm.not-contains.txt");
    var sourcesPath = Path.Combine(expectedDir, name + ".sources.txt");
    var verifyLlvm = File.Exists(llvmContainsPath) || File.Exists(llvmNotContainsPath);

    if (!File.Exists(sourcePath))
    {
        Console.Error.WriteLine($"FAIL {name}: source file not found");
        failures++;
        continue;
    }

    var compilerArguments = new List<string>
    {
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        Path.Combine(repoRoot, "scripts", "smalllang.ps1"),
        File.Exists(sourcesPath) ? "-SourcesFile" : "-Source",
        File.Exists(sourcesPath)
            ? Path.Combine("examples", "expected", name + ".sources.txt")
            : Path.Combine("examples", name + ".sl"),
        "-Output",
        Path.Combine("artifacts", "example-tests", name + ".exe"),
        "-Target",
        "windows-x64"
    };
    if (verifyLlvm)
    {
        compilerArguments.Add("-KeepTemps");
    }

    var build = Run(
        "powershell.exe",
        compilerArguments,
        input: null,
        repoRoot);

    if (build.ExitCode != 0)
    {
        Console.Error.WriteLine($"FAIL {name}: compiler exited {build.ExitCode}");
        Console.Error.WriteLine(build.Stdout);
        Console.Error.WriteLine(build.Stderr);
        failures++;
        continue;
    }

    if (verifyLlvm
        && !VerifyLlvmAssertions(
            Path.ChangeExtension(outputPath, ".ll"),
            llvmContainsPath,
            llvmNotContainsPath,
            out var llvmError))
    {
        Console.Error.WriteLine($"FAIL {name}: {llvmError}");
        failures++;
        continue;
    }

    var stdin = File.Exists(stdinPath)
        ? File.ReadAllText(stdinPath, Encoding.UTF8)
        : null;
    var run = Run(outputPath, [], stdin, repoRoot);
    var expected = Normalize(File.ReadAllText(expectedFile, Encoding.UTF8));
    var actual = Normalize(run.Stdout);

    if (run.ExitCode != 0)
    {
        Console.Error.WriteLine($"FAIL {name}: executable exited {run.ExitCode}");
        Console.Error.WriteLine(run.Stderr);
        failures++;
        continue;
    }

    if (!StringComparer.Ordinal.Equals(expected, actual))
    {
        Console.Error.WriteLine($"FAIL {name}: stdout mismatch");
        Console.Error.WriteLine("EXPECTED:");
        Console.Error.WriteLine(expected);
        Console.Error.WriteLine("ACTUAL:");
        Console.Error.WriteLine(actual);
        failures++;
        continue;
    }

    Console.WriteLine($"PASS {name}");
}

var diagnosticDir = Path.Combine(repoRoot, "examples", "diagnostics");
var diagnosticFiles = Directory.Exists(diagnosticDir)
    ? Directory.EnumerateFiles(diagnosticDir, "*.sl").Order(StringComparer.Ordinal).ToArray()
    : [];
foreach (var sourcePath in diagnosticFiles)
{
    var name = Path.GetFileNameWithoutExtension(sourcePath);
    var expectedPath = Path.Combine(diagnosticDir, name + ".stderr.contains.txt");
    if (!File.Exists(expectedPath))
    {
        Console.Error.WriteLine($"FAIL diagnostic/{name}: expected diagnostic file not found");
        failures++;
        continue;
    }

    var build = Run(
        "powershell.exe",
        [
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            Path.Combine(repoRoot, "scripts", "smalllang.ps1"),
            "-Source",
            Path.GetRelativePath(repoRoot, sourcePath),
            "-Output",
            Path.Combine("artifacts", "example-tests", "diagnostic-" + name + ".exe"),
            "-Target",
            "windows-x64"
        ],
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
        failures++;
        continue;
    }

    Console.WriteLine($"PASS diagnostic/{name}");
}

if (failures == 0)
{
    Console.WriteLine($"All {expectedFiles.Length + diagnosticFiles.Length} example tests passed.");
    return 0;
}

Console.Error.WriteLine($"{failures} example test(s) failed.");
return 1;

static string FindRepositoryRoot(string startPath)
{
    for (var current = new DirectoryInfo(startPath); current is not null; current = current.Parent)
    {
        if (File.Exists(Path.Combine(current.FullName, "SmallLang.slnx")))
        {
            return current.FullName;
        }
    }

    throw new InvalidOperationException("Could not find repository root.");
}

static ProcessResult Run(string fileName, IReadOnlyList<string> args, string? input, string workingDirectory)
{
    using var process = new Process();
    process.StartInfo = new ProcessStartInfo
    {
        FileName = fileName,
        WorkingDirectory = workingDirectory,
        RedirectStandardInput = input is not null,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false
    };

    foreach (var arg in args)
    {
        process.StartInfo.ArgumentList.Add(arg);
    }

    process.Start();
    if (input is not null)
    {
        process.StandardInput.Write(input);
        process.StandardInput.Close();
    }

    var stdout = process.StandardOutput.ReadToEnd();
    var stderr = process.StandardError.ReadToEnd();
    process.WaitForExit();
    return new ProcessResult(process.ExitCode, stdout, stderr);
}

static string Normalize(string value)
{
    return value.Replace("\r\n", "\n", StringComparison.Ordinal);
}

static bool VerifyLlvmAssertions(
    string llvmPath,
    string containsPath,
    string notContainsPath,
    out string error)
{
    if (!File.Exists(llvmPath))
    {
        error = $"LLVM file not found: {llvmPath}";
        return false;
    }

    var llvm = File.ReadAllText(llvmPath, Encoding.UTF8);
    foreach (var expected in ReadAssertions(containsPath))
    {
        if (!llvm.Contains(expected, StringComparison.Ordinal))
        {
            error = $"LLVM does not contain '{expected}'";
            return false;
        }
    }

    foreach (var forbidden in ReadAssertions(notContainsPath))
    {
        if (llvm.Contains(forbidden, StringComparison.Ordinal))
        {
            error = $"LLVM unexpectedly contains '{forbidden}'";
            return false;
        }
    }

    error = "";
    return true;
}

static IEnumerable<string> ReadAssertions(string path)
{
    return File.Exists(path)
        ? File.ReadLines(path, Encoding.UTF8).Where(line => !string.IsNullOrWhiteSpace(line))
        : [];
}

internal sealed record ProcessResult(int ExitCode, string Stdout, string Stderr);
