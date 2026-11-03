using System.Diagnostics;
using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class SelfHostPolicyTests
{
    internal static int Run(string compilerPath, string resultPath)
    {
        const int expectedTestCount = 65;
        if (File.Exists(resultPath)) throw new IOException("Result already exists.");
        var directory = Path.GetDirectoryName(Path.GetFullPath(resultPath))!;
        Directory.CreateDirectory(directory);
        var context = new AssemblyLoadContext("shared-policy-test", isCollectible: true);
        var compiler = context.LoadFromAssemblyPath(Path.GetFullPath(compilerPath));
        var exporter = compiler.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", throwOnError: true)!;
        var render = exporter.GetMethod("RenderDecision", BindingFlags.NonPublic | BindingFlags.Static)!;
        var cases = new List<string>();
        string? failure = null;
        string? runtimeProbeContract = null;
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
            var enumRender = exporter.GetMethod("RenderEnumModel", BindingFlags.NonPublic | BindingFlags.Static)!;
            string EnumModel(Type type) => (string)enumRender.Invoke(null, [type])!;
            bool EnumRejected(Type type)
            {
                try { EnumModel(type); }
                catch (TargetInvocationException error)
                { return error.InnerException!.Message == "SELFHOST_POLICY_ENUM_IDENTITY_REQUIRED"; }
                return false;
            }
            var typeId = compiler.GetType("Sollang.Compiler.Semantics.TypeId", throwOnError: true)!;
            var enumModel = EnumModel(typeId);
            Check("enum-actual-type-id-model", Enum.GetNames(typeId).All(name =>
                enumModel.Contains("name == \"" + name + "\" -> if { " + Convert.ToInt32(Enum.Parse(typeId, name)) + " -> return }", StringComparison.Ordinal))
                && Enum.GetValues(typeId).Cast<object>().All(value =>
                    enumModel.Contains("== " + Convert.ToInt32(value) + " => \"" + Enum.GetName(typeId, value) + "\"", StringComparison.Ordinal))
                && enumModel.Contains("else => \"\"", StringComparison.Ordinal)
                && enumModel.Contains("    -1\n}", StringComparison.Ordinal));
            Check("enum-changed-declarations-projected", EnumModel(typeof(OriginalIdentity)) != EnumModel(typeof(ChangedIdentity))
                && EnumModel(typeof(ChangedIdentity)).Contains("name == \"Changed\" -> if { 9 -> return }", StringComparison.Ordinal)
                && EnumModel(typeof(ChangedIdentity)).Contains("name == \"Added\" -> if { 12 -> return }", StringComparison.Ordinal));
            var aliasModel = EnumModel(typeof(AliasedIdentity));
            Check("enum-aliases-preserve-compiled-canonical-name", aliasModel.Contains("== 1 => \""
                + Enum.GetName(typeof(AliasedIdentity), 1) + "\"", StringComparison.Ordinal)
                && aliasModel.Contains("name == \"One\" -> if { 1 -> return }", StringComparison.Ordinal)
                && aliasModel.Contains("name == \"Alias\" -> if { 1 -> return }", StringComparison.Ordinal)
                && Regex.Matches(aliasModel, "== 1 =>").Count == 1);
            Check("enum-non-enum-rejected", EnumRejected(typeof(string)));
            Check("enum-non-int32-rejected", EnumRejected(typeof(ByteIdentity)));
            Check("enum-negative-identity-rejected", EnumRejected(typeof(NegativeIdentity)));
            Check("enum-flags-rejected", EnumRejected(typeof(FlagIdentity)));
            Check("enum-empty-rejected", EnumRejected(typeof(EmptyIdentity)));
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
            var integerInput = compiler.GetType("Sollang.Compiler.Shared.NativeRuntimePolicy", true)!;
            Check("runtime-multiline-text-exported", Emit(integerInput.GetMethod("LegacyReadFunction")!)
                .Contains("\\n", StringComparison.Ordinal));
            Check("runtime-read-function-source-retained", Emit(integerInput.GetMethod("LegacyWindowsReadFunction")!)
                .Contains("@GetLastError()", StringComparison.Ordinal));

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
            var declaredParts = Enum.GetValues(keyPart).Cast<object>()
                .Select(value => Convert.ToInt32(value, System.Globalization.CultureInfo.InvariantCulture)).ToHashSet();
            var unknownPart = Enumerable.Range(0, declaredParts.Count + 1)
                .First(value => !declaredParts.Contains(value));
            Check("rule-unknown-part-rejected", RuleRejected("Unknown", "unknown", unknownPart));
            Check("rule-unsafe-domain-rejected", RuleRejected("Unsafe", "bad\"domain", 0));
            Check("rule-empty-domain-rejected", RuleRejected("Empty", "", 0));
            Check("rule-oversize-parts-rejected", RuleRejected("Large", "large", new int[33]));
            Check("rule-invalid-name-rejected", RuleRejected("0bad", "valid", 0));
            Check("rule-repeated-part-retained", Regex.Matches(Rule("Repeated", "repeat", 0, 0), "KeyPart.Identity").Count == 2);
            var ruleTypes = (string)exporter.GetMethod("RenderKeyRuleTypes", BindingFlags.NonPublic | BindingFlags.Static)!
                .Invoke(null, null)!;
            Check("rule-enum-and-struct-schema-exported", Enum.GetNames(keyPart).All(name => ruleTypes.Contains(name, StringComparison.Ordinal))
                && ruleTypes.Contains("public parts: [KeyPart; ~]", StringComparison.Ordinal));
            var rules = keyPolicies.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.DeclaredOnly);
            var emittedRules = rules.Select(Emit).ToArray();
            var exportedRuleNames = Regex.Matches(string.Concat(emittedRules), @"(?m)^public (\w+): -> KeyRule")
                .Select(match => match.Groups[1].Value).ToArray();
            var expectedRuleNames = rules.Select(method => char.ToLowerInvariant(method.Name[0]) + method.Name[1..])
                .ToHashSet(StringComparer.Ordinal);
            Check("all-current-key-rules-exported", rules.Length > 0
                && emittedRules.All(text => text.Contains("KeyRule {", StringComparison.Ordinal))
                && exportedRuleNames.Length == rules.Length && expectedRuleNames.SetEquals(exportedRuleNames));

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
                if (attribute.NamedArguments.Any(argument => argument.MemberName == "Region"))
                {
                    var output = (string)attribute.ConstructorArguments[1].Value!;
                    var authoredTarget = Path.Combine(mirror, output);
                    Directory.CreateDirectory(Path.GetDirectoryName(authoredTarget)!);
                    File.Copy(Path.Combine(root, output), authoredTarget);
                    File.AppendAllText(authoredTarget, "\n# retained authored suffix\n");
                }
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
            var regionPath = Path.Combine(mirror, "selfhost/llvm/runtime.slg");
            var regionText = File.ReadAllText(regionPath);
            Check("region-authored-content-preserved", regionText.Contains("# retained authored suffix", StringComparison.Ordinal));
            File.WriteAllText(regionPath, regionText.Replace("# END generated NativeRuntime", "# changed generated content\n# END generated NativeRuntime", StringComparison.Ordinal));
            Check("region-edited-projection-rejected", Sync(true).Exit != 0);
            Check("region-repair-preserves-authored-content", Sync(false).Exit == 0 && Sync(true).Exit == 0
                && File.ReadAllText(regionPath) == regionText);
            File.AppendAllText(regionPath, "# BEGIN generated NativeRuntime\n");
            var brokenRegion = Sync(false);
            Check("region-duplicate-marker-rejected", brokenRegion.Exit != 0
                && brokenRegion.Output.Contains("SELFHOST_POLICY_REGION_MARKERS_INVALID", StringComparison.Ordinal));
            File.WriteAllText(regionPath, regionText.Replace("namespace sollang.compiler.llvm.runtime", "namespace wrong.module", StringComparison.Ordinal));
            var wrongModule = Sync(false);
            Check("region-wrong-module-rejected", wrongModule.Exit != 0
                && wrongModule.Output.Contains("SELFHOST_POLICY_REGION_NAMESPACE_MISMATCH", StringComparison.Ordinal));
            File.WriteAllText(regionPath, regionText);
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
            runtimeProbeContract = WriteRuntimeProbe(compiler, root, directory);
        }
        catch (Exception error) { failure = error.ToString(); }
        finally { context.Unload(); }
        if (failure is null && cases.Count != expectedTestCount)
            failure = $"Policy test count differs: {cases.Count}/{expectedTestCount}.";
        AtomicResultFile.Write(resultPath, JsonSerializer.Serialize(new { status = failure is null ? "passed" : "failed",
            completed = cases.Count, total = expectedTestCount, cases, failure, runtimeProbeContract }, new JsonSerializerOptions { WriteIndented = true }));
        return failure is null ? 0 : 1;
    }

    private static string WriteRuntimeProbe(Assembly compiler, string root, string directory)
    {
        var source = new System.Text.StringBuilder();
        var expected = new System.Text.StringBuilder();
        var dependencies = new List<string>();
        var types = compiler.GetTypes().Where(type => type.GetCustomAttributesData().Any(attribute =>
                attribute.AttributeType.FullName == "Sollang.Compiler.Shared.SelfHostPolicyAttribute"))
            .OrderBy(type => type.FullName, StringComparer.Ordinal).ToArray();
        var names = types.Select(type => type.Name).ToArray();
        var typeNamePolicy = compiler.GetType("Sollang.Compiler.Shared.TypeNamePolicy", true)!;
        string Alias(int index) => types[index] == typeNamePolicy ? "typeNames" : "policy" + index;
        for (var index = 0; index < types.Length; index++)
        {
            var attribute = types[index].GetCustomAttributesData().Single(item =>
                item.AttributeType.FullName == "Sollang.Compiler.Shared.SelfHostPolicyAttribute");
            source.Append("import ").Append(attribute.ConstructorArguments[0].Value)
                .Append(" as ").Append(Alias(index)).Append('\n');
            dependencies.Add(Path.Combine(root, (string)attribute.ConstructorArguments[1].Value!));
        }
        dependencies.Add(Path.Combine(root, "selfhost/semantic/type_name_policy.slg"));
        source.Append("\nmain {\n");
        for (var index = 0; index < types.Length; index++)
        {
            if (types[index].IsEnum)
            {
                var enumType = types[index];
                var values = Enum.GetValues(enumType).Cast<object>().Select(value => Convert.ToInt32(value))
                    .Concat([-1, 50, 511, 515, 1023, 1025, int.MaxValue]).Distinct().ToArray();
                foreach (var value in values)
                {
                    var literal = value.ToString(System.Globalization.CultureInfo.InvariantCulture);
                    var name = Enum.GetName(enumType, value);
                    var label = names[index] + ".EnumName." + literal;
                    source.Append("    \"").Append(label).Append("\" -> println\n    ").Append(Alias(index))
                        .Append(".enumName(").Append(literal).Append(") -> println\n");
                    expected.Append(label).Append('\n').Append(name ?? "").Append('\n');
                    label = names[index] + ".TypeName." + literal;
                    source.Append("    \"").Append(label).Append("\" -> println\n    ").Append(Alias(index))
                        .Append(".nameOf(").Append(literal).Append(") -> when {\n")
                        .Append("        Named(name) { name -> println }\n        Numeric(number) { number -> println }\n    }\n");
                    expected.Append(label).Append('\n').Append(name ?? literal).Append('\n');
                }
                foreach (var name in Enum.GetNames(enumType).Concat(["", "__unknown_type_id__", "unit"]))
                {
                    var label = names[index] + ".EnumValue." + name;
                    source.Append("    \"").Append(label).Append("\" -> println\n    ").Append(Alias(index))
                        .Append(".enumValue(\"").Append(name).Append("\") -> println\n");
                    var value = Enum.IsDefined(enumType, name) ? Convert.ToInt32(Enum.Parse(enumType, name)) : -1;
                    expected.Append(label).Append('\n').Append(value).Append('\n');
                }
                continue;
            }
            var multilineText = types[index].GetCustomAttributesData()
                .Where(attribute => attribute.AttributeType.FullName == "Sollang.Compiler.Shared.SelfHostPolicyAttribute")
                .SelectMany(attribute => attribute.NamedArguments)
                .Any(argument => argument.MemberName == "MultilineText" && argument.TypedValue.Value is true);
            foreach (var method in types[index].GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.DeclaredOnly)
                .OrderBy(method => method.Name, StringComparer.Ordinal))
            {
                var parameters = method.GetParameters();
                var call = Alias(index) + "." + char.ToLowerInvariant(method.Name[0]) + method.Name[1..];
                if (method.ReturnType.FullName == "Sollang.Compiler.Shared.CodegenKeyRule" && parameters.Length == 0)
                {
                    var rule = method.Invoke(null, null)!;
                    var domain = (string)method.ReturnType.GetProperty("Domain")!.GetValue(rule)!;
                    var parts = ((System.Collections.IEnumerable)method.ReturnType.GetProperty("Parts")!.GetValue(rule)!)
                        .Cast<object>().Select(part => Convert.ToInt32(part, System.Globalization.CultureInfo.InvariantCulture)).ToArray();
                    var label = names[index] + "." + method.Name;
                    var binding = "rule" + index + method.Name;
                    // Read both the declaration order and its exported partIndex at runtime.
                    source.Append("    \"").Append(label).Append("\" -> println\n    ").Append(call)
                        .Append("() => ").Append(binding).Append('\n')
                        .Append("    ").Append(binding).Append(".domain -> println\n    (").Append(binding).Append(".parts -> len) -> println\n")
                        .Append("    ").Append(binding).Append(".parts -> each part { ").Append(Alias(index)).Append(".partIndex(part) -> println }\n");
                    expected.Append(label).Append('\n').Append(domain).Append('\n').Append(parts.Length).Append('\n');
                    foreach (var part in parts) expected.Append(part).Append('\n');
                    continue;
                }
                if (parameters.Length > 6 || parameters.Any(parameter => parameter.ParameterType != typeof(bool) && parameter.ParameterType != typeof(ulong))
                    || (method.ReturnType != typeof(bool) && method.ReturnType != typeof(string) && method.ReturnType != typeof(ulong)))
                    throw new InvalidDataException("Unsupported runtime policy probe signature: " + method.Name);
                object[][] vectors = parameters.Select(parameter => parameter.ParameterType == typeof(bool)
                    ? new object[] { false, true } : new object[] { 0UL, 1UL, 1UL << 63, ulong.MaxValue }).ToArray();
                var rowCount = vectors.Aggregate(1, (count, vector) => checked(count * vector.Length));
                for (var row = 0; row < rowCount; row++)
                {
                    var remaining = row;
                    var arguments = vectors.Select(vector =>
                    {
                        var argument = vector[remaining % vector.Length];
                        remaining /= vector.Length;
                        return argument;
                    }).ToArray();
                    var value = method.Invoke(null, arguments);
                    var text = value switch
                    {
                        bool boolean => boolean ? "true" : "false",
                        string literal => multilineText
                            ? literal.Replace("\r\n", "\n", StringComparison.Ordinal)
                            : literal,
                        ulong number => number.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        _ => throw new InvalidDataException("Unsupported runtime policy result: " + method.Name)
                    };
                    var label = names[index] + "." + method.Name + ":" + row;
                    source.Append("    \"").Append(label).Append("\" -> println\n    ").Append(call).Append('(')
                        .AppendJoin(", ", arguments.Select(argument => argument is bool boolean ? boolean ? "true" : "false"
                            : ((ulong)argument).ToString(System.Globalization.CultureInfo.InvariantCulture)))
                        .Append(") -> println\n");
                    expected.Append(label).Append('\n').Append(text).Append('\n');
                }
            }
        }
        // Compare the authored SLG predicate with the real generated C# parser,
        // including near misses; the shared name string alone is not execution proof.
        var parserPredicate = compiler.GetTypes()
            .Select(type => type.GetMethod("IsBuiltinTypeName", BindingFlags.NonPublic | BindingFlags.Static))
            .Single(method => method is not null)!;
        var builtinNames = ((string)typeNamePolicy.GetMethod("BuiltinNames")!.Invoke(null, null)!).Split('|');
        var spellings = builtinNames.Concat(builtinNames.Select(name => name + "Extra"))
            .Concat(builtinNames.Select(name => name.ToLowerInvariant()))
            .Concat(["", "Range", "module.Int", " Self", "Self "])
            .Distinct(StringComparer.Ordinal);
        foreach (var spelling in spellings)
        {
            var accepted = (bool)parserPredicate.Invoke(null, [spelling])!;
            var label = "Parser.IsBuiltinTypeName:" + spelling;
            source.Append("    \"").Append(label).Append("\" -> println\n    typeNames.isBuiltin(\"")
                .Append(spelling).Append("\") -> println\n");
            expected.Append(label).Append('\n').Append(accepted ? "true" : "false").Append('\n');
        }
        var boxPredicate = compiler.GetType("Sollang.Compiler.Semantics.SemanticTypeRegistrationNames", true)!
            .GetMethod("BoxName", BindingFlags.Public | BindingFlags.Static)!;
        var primitiveBoxes = ((string)typeNamePolicy.GetMethod("PrimitiveBoxNames")!.Invoke(null, null)!).Split('|');
        var declarations = new[] { "BoxExcludedStructNames", "BoxExcludedNominalNames" }
            .SelectMany(name => ((string)typeNamePolicy.GetMethod(name)!.Invoke(null, null)!).Split('|'))
            .Concat(["Local", "", "sys.file.FileExtra", "SYS.FILE.FILE"]);
        foreach (var declaration in declarations)
        foreach (var name in new[] { "Int", "Local" })
        foreach (var structure in new[] { false, true })
        foreach (var enumeration in new[] { false, true })
            AppendBoxCase(name, structure, enumeration, declaration);
        foreach (var name in primitiveBoxes)
            AppendBoxCase(name, false, false, "");
        void AppendBoxCase(string name, bool structure, bool enumeration, string declaration)
        {
            var accepted = (bool)boxPredicate.Invoke(null, [name, structure, enumeration, declaration])!;
            var flags = (structure ? "true" : "false") + ", " + (enumeration ? "true" : "false");
            var label = "SemanticTypeRegistrationNames.BoxName:" + name + ":" + flags + ":" + declaration;
            source.Append("    \"").Append(label).Append("\" -> println\n    typeNames.boxName(\"")
                .Append(name).Append("\", ").Append(flags).Append(", \"").Append(declaration).Append("\") -> println\n");
            expected.Append(label).Append('\n').Append(accepted ? "true" : "false").Append('\n');
        }
        var typeId = compiler.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
        var display = compiler.GetType("Sollang.Compiler.Semantics.SemanticTypeDisplayNames", true)!
            .GetMethod("Builtin", BindingFlags.Public | BindingFlags.Static)!;
        foreach (var value in Enum.GetValues(typeId))
        {
            var name = value.ToString()!;
            AppendValue("SemanticTypeDisplayNames.Builtin:" + name,
                "typeNames.builtinDisplayName(\"" + name + "\")", (string)display.Invoke(null, [value])!);
        }
        var range = compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
            .GetMethod("Range", BindingFlags.Public | BindingFlags.Static)!.Invoke(null, null)!;
        AppendValue("BuiltinTypeDefinitions.Range.Name", "typeNames.rangeStructName()",
            (string)range.GetType().GetProperty("Name")!.GetValue(range)!);
        var rangeFields = ((System.Collections.IEnumerable)range.GetType().GetProperty("Fields")!.GetValue(range)!)
            .Cast<object>().ToArray();
        foreach (var field in rangeFields)
        {
            var ordinal = (int)field.GetType().GetProperty("Index")!.GetValue(field)!;
            var name = (string)field.GetType().GetProperty("Name")!.GetValue(field)!;
            var type = field.GetType().GetProperty("Type")!.GetValue(field)!.ToString()!;
            AppendValue("BuiltinTypeDefinitions.Range.FieldName:" + ordinal,
                "typeNames.rangeFieldName(" + ordinal + ")", name);
            AppendValue("BuiltinTypeDefinitions.Range.FieldType:" + ordinal,
                "typeNames.rangeFieldType(" + ordinal + ")", type);
            AppendValue("BuiltinTypeDefinitions.Range.FieldOrdinal:" + name,
                "typeNames.rangeFieldOrdinal(\"" + name + "\")", ordinal.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        AppendValue("BuiltinTypeDefinitions.Range.End", "typeNames.rangeFieldName(" + rangeFields.Length + ")", "");
        foreach (var missing in new[] { "", "missing", "Start", "end" })
            AppendValue("BuiltinTypeDefinitions.Range.Missing:" + missing,
                "typeNames.rangeFieldOrdinal(\"" + missing + "\")", "-1");
        void AppendValue(string label, string call, string value)
        {
            source.Append("    \"").Append(label).Append("\" -> println\n    ")
                .Append(call).Append(" -> println\n");
            expected.Append(label).Append('\n').Append(value).Append('\n');
        }
        source.Append("}\n");
        var sourcePath = Path.Combine(directory, "runtime-policy-probe.slg");
        File.WriteAllText(sourcePath, source.ToString());
        var contractPath = Path.Combine(directory, "runtime-policy-contract.json");
        File.WriteAllText(contractPath, JsonSerializer.Serialize(new
        {
            schemaVersion = 1,
            formatCheckSources = new[] { Path.Combine(root, "selfhost/semantic/reference_type_ids.slg") },
            policyModules = names,
            scope = "Generated policies against compiled CSharp method results; exhaustive boolean inputs, UInt64 boundary products and every declared cache-key rule",
            cases = new[] { new { id = "shared-policy-runtime", source = sourcePath,
                additionalSources = dependencies, exit = 0, stderr = "", stdout = expected.ToString().TrimEnd('\r', '\n') } }
        }, new JsonSerializerOptions { WriteIndented = true }));
        return contractPath;
    }

    private static string FindRoot()
    {
        for (var directory = new DirectoryInfo(Environment.CurrentDirectory); directory is not null; directory = directory.Parent)
            if (File.Exists(Path.Combine(directory.FullName, "src", "Sollang.Compiler", "Sollang.Compiler.csproj"))) return directory.FullName;
        throw new DirectoryNotFoundException("Sollang repository");
    }

    private enum OriginalIdentity { Zero, Changed = 7 }
    private enum ChangedIdentity { Zero, Changed = 9, Added = 12 }
    private enum AliasedIdentity { Zero, One, Alias = One }
    private enum ByteIdentity : byte { Zero }
    private enum NegativeIdentity { Negative = -1 }
    [Flags] private enum FlagIdentity { Zero, One }
    private enum EmptyIdentity { }

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
