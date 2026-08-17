using System.Diagnostics;
using System.Text;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Tooling;

internal sealed class WslLinuxLinker(LlvmToolchain toolchain)
{
    public void LinkLlvmIr(
        string llPath,
        string outputPath,
        string workDir,
        string? optimizationLevel,
        bool sharedLibrary = false)
    {
        var objectPath = Path.Combine(workDir, Path.GetFileNameWithoutExtension(outputPath) + ".o");
        Run(toolchain.Clang,
        [
            "-target",
            "x86_64-unknown-linux-gnu",
            optimizationLevel ?? "-Oz",
            "-fno-addrsig",
            ..(sharedLibrary ? ["-fPIC"] : Array.Empty<string>()),
            "-c",
            llPath,
            "-o",
            objectPath
        ]);

        if (OperatingSystem.IsWindows())
        {
            var linkArguments = new List<string>
            {
                "--exec",
                "cc",
                ToWslPath(objectPath),
                "-ldl",
                "-Wl,--gc-sections",
                "-s",
                "-o",
                ToWslPath(outputPath)
            };
            if (sharedLibrary)
            {
                linkArguments.Insert(3, "-shared");
            }
            Run("wsl.exe", linkArguments);

            if (!sharedLibrary)
            {
                Run("wsl.exe",
                [
                    "--exec",
                    "chmod",
                    "+x",
                    ToWslPath(outputPath)
                ]);
            }
        }
        else
        {
            var linkArguments = new List<string>
            {
                objectPath,
                "-ldl",
                "-Wl,--gc-sections",
                "-s",
                "-o",
                outputPath
            };
            if (sharedLibrary)
            {
                linkArguments.Insert(0, "-shared");
            }
            Run("cc", linkArguments);
        }
    }

    internal static string ToWslPath(string path)
    {
        var fullPath = Path.GetFullPath(path);
        if (fullPath.Length >= 3 && fullPath[1] == ':' && fullPath[2] == Path.DirectorySeparatorChar)
        {
            var drive = char.ToLowerInvariant(fullPath[0]);
            return "/mnt/" + drive + fullPath[2..].Replace('\\', '/');
        }

        throw new SollangException($"cannot convert path to WSL path: {path}");
    }

    private static void Run(string fileName, IReadOnlyList<string> arguments)
    {
        var psi = new ProcessStartInfo(fileName)
        {
            UseShellExecute = false,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };

        foreach (var argument in arguments)
        {
            psi.ArgumentList.Add(argument);
        }

        using var process = Process.Start(psi)
            ?? throw new SollangException($"failed to start {fileName}");

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (process.ExitCode != 0)
        {
            var message = new StringBuilder();
            message.AppendLine($"{Path.GetFileName(fileName)} failed with exit code {process.ExitCode}");
            if (!string.IsNullOrWhiteSpace(stdout))
            {
                message.AppendLine(stdout.TrimEnd());
            }

            if (!string.IsNullOrWhiteSpace(stderr))
            {
                message.AppendLine(stderr.TrimEnd());
            }

            throw new SollangException(message.ToString().TrimEnd());
        }
    }
}
