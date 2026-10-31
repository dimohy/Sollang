using System.Diagnostics;
using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class SelfHostPolicyTests
{
    internal static int Run(string compilerPath, string resultPath)
    {
        if (File.Exists(resultPath)) throw new IOException("Result already exists.");
        var directory = Path.GetDirectoryName(Path.GetFullPath(resultPath))!;
        Directory.CreateDirectory(directory);
        var context = new AssemblyLoadContext("shared-policy-test", isCollectible: true);
        var compiler = context.LoadFromAssemblyPath(Path.GetFullPath(compilerPath));
        var exporter = compiler.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", throwOnError: true)!;
        var render = exporter.GetMethod("RenderDecision", BindingFlags.NonPublic | BindingFlags.Static)!;
        var cases = new List<string>();
        string? failure = null;
        void Check(string name, bool condition)
        {
            if (!condition) throw new InvalidDataException(name);
            cases.Add(name);
        }
        string Emit(MethodInfo method) => (string)render.Invoke(null, [method])!;
        ulong Mask(string text) => ulong.Parse(Regex.Match(text, @"UInt64\((\d+)\) => decision!").Groups[1].Value,
            System.Globalization.CultureInfo.InvariantCulture);
        bool Rejected(string name, string diagnostic)
        {
            try { Emit(typeof(SelfHostPolicyTests).GetMethod(name, BindingFlags.NonPublic | BindingFlags.Static)!); }
            catch (TargetInvocationException error) { return error.InnerException!.Message.Contains(diagnostic, StringComparison.Ordinal); }
            return false;
        }
        try
        {
            var actual = compiler.GetType("Sollang.Compiler.Shared.BorrowedTextReturnPolicy", true)!
                .GetMethod("RequiresOriginCheck", BindingFlags.Public | BindingFlags.Static)!;
            var original = Emit(actual);
            var changed = typeof(SelfHostPolicyTests).GetMethod(nameof(ChangedPolicy), BindingFlags.NonPublic | BindingFlags.Static)!;
            var changedMask = Mask(Emit(changed));
            Check("changed-csharp-body-changes-generated-decision", Mask(original) != changedMask);
            for (var row = 0; row < 8; row++)
            {
                var outer = (row & 1) != 0; var moves = (row & 2) != 0;
                var owns = (row & 4) != 0;
                var expected = !outer || (moves && owns);
                Check("original-row-" + row, (bool)actual.Invoke(null, [outer, moves, owns])! == expected
                    && ((Mask(original) >> row) & 1) == (expected ? 1UL : 0UL));
                Check("changed-row-" + row, ((changedMask >> row) & 1) == (ChangedPolicy(outer, moves, owns) ? 1UL : 0UL));
            }
            Check("non-boolean-rejected", Rejected(nameof(UnsupportedPolicy), "SELFHOST_POLICY_BOOLEAN_SIGNATURE_REQUIRED"));
            Check("nondeterminism-rejected", Rejected(nameof(UnstablePolicy), "SELFHOST_POLICY_NONDETERMINISTIC"));

            var root = FindRoot();
            var mirror = Path.Combine(directory, "policy-input");
            Directory.CreateDirectory(mirror);
            var attributes = compiler.GetTypes().SelectMany(type => type.GetCustomAttributesData())
                .Where(attribute => attribute.AttributeType.FullName == "Sollang.Compiler.Shared.SelfHostPolicyAttribute").ToArray();
            foreach (var attribute in attributes)
            {
                var source = (string)attribute.ConstructorArguments[2].Value!;
                var target = Path.Combine(mirror, source);
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                File.Copy(Path.Combine(root, source), target);
            }
            (int Exit, string Output) Sync(bool check)
            {
                var start = new ProcessStartInfo("dotnet") { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false };
                foreach (var argument in new[] { Path.GetFullPath(compilerPath), "selfhost-sync", "--root", mirror }) start.ArgumentList.Add(argument);
                if (check) start.ArgumentList.Add("--check");
                using var process = Process.Start(start)!;
                var stdout = process.StandardOutput.ReadToEndAsync(); var stderr = process.StandardError.ReadToEndAsync();
                if (!process.WaitForExit(30000)) { process.Kill(entireProcessTree: true); throw new TimeoutException(); }
                return (process.ExitCode, stdout.GetAwaiter().GetResult() + stderr.GetAwaiter().GetResult());
            }
            Check("generate", Sync(false).Exit == 0);
            Check("check", Sync(true).Exit == 0);
            var first = attributes[0];
            var sourcePath = Path.Combine(mirror, (string)first.ConstructorArguments[2].Value!);
            var generatedPath = Path.Combine(mirror, (string)first.ConstructorArguments[1].Value!);
            var sourceBytes = File.ReadAllBytes(sourcePath);
            File.AppendAllText(sourcePath, "\n// stale binary probe\n");
            var stale = Sync(true);
            Check("stale-csharp-binary-rejected", stale.Exit != 0 && stale.Output.Contains("SELFHOST_POLICY_SOURCE_DRIFT", StringComparison.Ordinal));
            File.WriteAllBytes(sourcePath, sourceBytes);
            File.AppendAllText(generatedPath, "\n# stale generated output\n");
            var drift = Sync(true);
            Check("edited-generated-source-rejected", drift.Exit != 0 && drift.Output.Contains("SELFHOST_POLICY_OUTPUT_DRIFT", StringComparison.Ordinal));
            Check("regenerate", Sync(false).Exit == 0 && Sync(true).Exit == 0);
        }
        catch (Exception error) { failure = error.ToString(); }
        finally { context.Unload(); }
        AtomicResultFile.Write(resultPath, JsonSerializer.Serialize(new { status = failure is null ? "passed" : "failed",
            completed = cases.Count, total = 24, cases, failure }, new JsonSerializerOptions { WriteIndented = true }));
        return failure is null ? 0 : 1;
    }

    private static string FindRoot()
    {
        for (var directory = new DirectoryInfo(Environment.CurrentDirectory); directory is not null; directory = directory.Parent)
            if (File.Exists(Path.Combine(directory.FullName, "src", "Sollang.Compiler", "Sollang.Compiler.csproj"))) return directory.FullName;
        throw new DirectoryNotFoundException("Sollang repository");
    }

    private static bool ChangedPolicy(bool outerParameter, bool movesOwner, bool ownsStorage) =>
        outerParameter || (movesOwner && ownsStorage);
    private static bool UnsupportedPolicy(int value) => value == 0;
    private static bool _toggle;
    private static bool UnstablePolicy(bool value) { _toggle = !_toggle; return _toggle == value; }
}
