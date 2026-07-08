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

    if (!File.Exists(sourcePath))
    {
        Console.Error.WriteLine($"FAIL {name}: source file not found");
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
            Path.Combine("examples", name + ".sl"),
            "-Output",
            Path.Combine("artifacts", "example-tests", name + ".exe"),
            "-Target",
            "windows-x64"
        ],
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

if (failures == 0)
{
    Console.WriteLine($"All {expectedFiles.Length} example tests passed.");
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

internal sealed record ProcessResult(int ExitCode, string Stdout, string Stderr);
