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

            var numeric = compiler.GetType("Sollang.Compiler.Shared.CodegenCachePolicy", true)!;
            var checksum = Emit(numeric.GetMethod("ChecksumMix")!);
            var fingerprint = Emit(numeric.GetMethod("FingerprintMix")!);
            var changedNumeric = Emit(typeof(SelfHostPolicyTests).GetMethod(nameof(ChangedArithmetic),
                BindingFlags.NonPublic | BindingFlags.Static)!);
            Check("arithmetic-source-body-controls-output", changedNumeric != fingerprint
                && changedNumeric.Contains("hash * 3", StringComparison.Ordinal));
            Check("u64-high-bit-constant-retained", checksum.Contains("11400714819323198485", StringComparison.Ordinal));
            Check("u64-fingerprint-constants-retained", fingerprint.Contains("1099511628211", StringComparison.Ordinal)
                && fingerprint.Contains("97", StringComparison.Ordinal));
            Check("u64-checked-rejected", Rejected(nameof(CheckedArithmetic), "SELFHOST_POLICY_UINT64_IL_UNSUPPORTED"));
            Check("u64-call-rejected", Rejected(nameof(CallArithmetic), "SELFHOST_POLICY_UINT64_IL_UNSUPPORTED"));
            Check("u64-branch-rejected", Rejected(nameof(BranchArithmetic), "SELFHOST_POLICY_UINT64_IL_UNSUPPORTED"));
            Check("u64-other-input-rejected", Rejected(nameof(OtherArithmetic), "SELFHOST_POLICY_UINT64_SIGNATURE_REQUIRED"));
            Check("u64-subtraction-lowered", Emit(typeof(SelfHostPolicyTests).GetMethod(nameof(SubtractArithmetic),
                BindingFlags.NonPublic | BindingFlags.Static)!).Contains("hash - value", StringComparison.Ordinal));

            var textPolicy = compiler.GetType("Sollang.Compiler.Shared.TypeNamePolicy", true)!.GetMethod("BuiltinNames")!;
            Check("compiled-text-catalog-exported", Emit(textPolicy).Contains((string)textPolicy.Invoke(null, null)!, StringComparison.Ordinal));
            Check("text-literal-escaped", Emit(typeof(SelfHostPolicyTests).GetMethod(nameof(EscapedText), BindingFlags.NonPublic | BindingFlags.Static)!)
                .Contains("a\\\"b\\\\c", StringComparison.Ordinal));
            Check("text-call-rejected", Rejected(nameof(CallText), "SELFHOST_POLICY_TEXT_CONSTANT_REQUIRED"));
            Check("text-input-rejected", Rejected(nameof(InputText), "SELFHOST_POLICY_TEXT_SIGNATURE_REQUIRED"));
            Check("text-nonascii-rejected", Rejected(nameof(NonAsciiText), "SELFHOST_POLICY_TEXT_LITERAL_UNSUPPORTED"));
            Check("text-control-rejected", Rejected(nameof(ControlText), "SELFHOST_POLICY_TEXT_LITERAL_UNSUPPORTED"));

            var keyPolicies = compiler.GetType("Sollang.Compiler.Shared.CodegenCacheKeyPolicy", true)!;
            var keyRule = compiler.GetType("Sollang.Compiler.Shared.CodegenKeyRule", true)!;
            var keyPart = compiler.GetType("Sollang.Compiler.Shared.CodegenKeyPart", true)!;
            var renderRule = exporter.GetMethod("RenderKeyRule", BindingFlags.NonPublic | BindingFlags.Static)!;
            string Rule(string name, string domain, params int[] parts)
            {
                var values = Array.CreateInstance(keyPart, parts.Length);
                for (var index = 0; index < parts.Length; index++) values.SetValue(Enum.ToObject(keyPart, parts[index]), index);
                var value = Activator.CreateInstance(keyRule, [domain, values])!;
                return (string)renderRule.Invoke(null, [name, value])!;
            }
            bool RuleRejected(string name, string domain, params int[] parts)
            {
                try { Rule(name, domain, parts); }
                catch (TargetInvocationException error)
                { return error.InnerException!.Message.Contains("SELFHOST_POLICY_KEY_RULE_INVALID", StringComparison.Ordinal); }
                return false;
            }
            var moduleRule = Emit(keyPolicies.GetMethod("ModuleImplementation")!);
            Check("rule-components-match-current-csharp-shape", moduleRule == Rule("ModuleImplementation",
                "module-implementation", 0, 1, 2, 3, 4, 5));
            Check("rule-order-change-propagates", moduleRule != Rule("ModuleImplementation",
                "module-implementation", 5, 4, 3, 2, 1, 0));
            Check("rule-domain-change-propagates", moduleRule != Rule("ModuleImplementation", "changed-domain", 0, 1, 2, 3, 4, 5));
            Check("rule-empty-parts-typed", Rule("Empty", "empty").Contains("[KeyPart; ~]", StringComparison.Ordinal));
            Check("rule-unknown-part-rejected", RuleRejected("Unknown", "unknown", 100));
            Check("rule-unsafe-domain-rejected", RuleRejected("Unsafe", "bad\"domain", 0));
            Check("rule-empty-domain-rejected", RuleRejected("Empty", "", 0));
            Check("rule-oversize-parts-rejected", RuleRejected("Large", "large", new int[33]));
            Check("rule-invalid-name-rejected", RuleRejected("0bad", "valid", 0));
            Check("rule-repeated-part-retained", Regex.Matches(Rule("Repeated", "repeat", 0, 0), "KeyPart.Identity").Count == 2);
            var ruleTypes = (string)exporter.GetMethod("RenderKeyRuleTypes", BindingFlags.NonPublic | BindingFlags.Static)!
                .Invoke(null, null)!;
            Check("rule-enum-and-struct-schema-exported", Enum.GetNames(keyPart).All(name => ruleTypes.Contains(name, StringComparison.Ordinal))
                && ruleTypes.Contains("public parts: [KeyPart; ~]", StringComparison.Ordinal));
            var rules = keyPolicies.GetMethods(BindingFlags.Public | BindingFlags.Static | BindingFlags.DeclaredOnly);
            Check("all-thirteen-key-rules-exported", rules.Length == 13 && rules.All(method => Emit(method).Contains("KeyRule {", StringComparison.Ordinal)));

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
            completed = cases.Count, total = 50, cases, failure }, new JsonSerializerOptions { WriteIndented = true }));
        return failure is null ? 0 : 1;
    }

    private static string FindRoot()
    {
        for (var directory = new DirectoryInfo(Environment.CurrentDirectory); directory is not null; directory = directory.Parent)
            if (File.Exists(Path.Combine(directory.FullName, "src", "Sollang.Compiler", "Sollang.Compiler.csproj"))) return directory.FullName;
        throw new DirectoryNotFoundException("Sollang repository");
    }

    private static string EscapedText() => "a\"b\\c";
    private static string CallText() => string.Concat(Environment.NewLine, "x");
    private static string InputText(string value) => value;
    private static string NonAsciiText() => "한글";
    private static string ControlText() => "\n";
    private static bool ChangedPolicy(bool outerParameter, bool movesOwner, bool ownsStorage) =>
        outerParameter || (movesOwner && ownsStorage);
    private static bool UnsupportedPolicy(int value) => value == 0;
    private static bool _toggle;
    private static bool UnstablePolicy(bool value) { _toggle = !_toggle; return _toggle == value; }
    private static ulong ChangedArithmetic(ulong hash, ulong value) => unchecked(hash * 3 + value);
    private static ulong CheckedArithmetic(ulong hash, ulong value) => checked(hash + value);
    private static ulong CallArithmetic(ulong hash, ulong value) => Math.Max(hash, value);
    private static ulong BranchArithmetic(ulong hash, ulong value) => hash > value ? hash : value;
    private static ulong OtherArithmetic(ulong hash, int value) => unchecked(hash + (ulong)value);
    private static ulong SubtractArithmetic(ulong hash, ulong value) => unchecked(hash - value);
}
