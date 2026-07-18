using System.Diagnostics;
using System.Text;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Tooling;

internal sealed class WasmBrowserLinker(LlvmToolchain toolchain)
{
    public void LinkLlvmIr(string llPath, string outputPath, string workDir, string? optimizationLevel)
    {
        var objectPath = Path.Combine(workDir, Path.GetFileNameWithoutExtension(outputPath) + ".wasm.o");

        Run(toolchain.Clang,
        [
            "-target",
            "wasm32-unknown-unknown-wasm",
            optimizationLevel ?? "-Oz",
            "-fno-addrsig",
            "-c",
            llPath,
            "-o",
            objectPath
        ]);

        Run(toolchain.WasmLd,
        [
            "--no-entry",
            "--export=sollang_start",
            "--export-memory",
            "--allow-undefined",
            "--gc-sections",
            "--strip-all",
            objectPath,
            "-o",
            outputPath
        ]);
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
