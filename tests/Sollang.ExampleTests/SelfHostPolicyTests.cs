using System.Diagnostics;
using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class SelfHostPolicyTests
{
    internal static int Run(string compilerPath, string resultPath)
    {
        const int expectedTestCount = 84;
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
            var intrinsicFactory = compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
                .GetMethod("IntrinsicNominal", BindingFlags.Public | BindingFlags.Static)!;
            var namePolicy = compiler.GetType("Sollang.Compiler.Shared.TypeNamePolicy", true)!;
            var intrinsicRows = new[] { (Enumeration: false, Method: "IntrinsicStructDefinitions"),
                (Enumeration: true, Method: "IntrinsicEnumDefinitions") }.SelectMany(item =>
                    ((string)namePolicy.GetMethod(item.Method)!.Invoke(null, null)!).Split('|')
                        .Select(row => row.Split(':', 2)).Select(parts =>
                            (item.Enumeration, Member: parts[0], Name: parts[1]))).ToArray();
            Check("intrinsic-catalog-defined-and-unique", intrinsicRows.Length > 0
                && intrinsicRows.Select(row => row.Name).Distinct(StringComparer.Ordinal).Count() == intrinsicRows.Length
                && intrinsicRows.All(row => Enum.IsDefined(typeId, row.Member)));
            Check("intrinsic-factory-consumes-compiled-catalog", intrinsicRows.All(row =>
                intrinsicFactory.Invoke(null, [row.Name, row.Enumeration]) is { } value
                && Convert.ToInt32(value) == Convert.ToInt32(Enum.Parse(typeId, row.Member))));
            Check("intrinsic-kind-and-near-miss-rejection", intrinsicRows.All(row =>
                intrinsicFactory.Invoke(null, [row.Name, !row.Enumeration]) is null
                && new[] { row.Name + "Extra", row.Name.ToLowerInvariant(), row.Name.Split('.').Last() }
                    .All(name => intrinsicFactory.Invoke(null, [name, row.Enumeration]) is null))
                && intrinsicFactory.Invoke(null, ["", false]) is null
                && intrinsicFactory.Invoke(null, ["missing", true]) is null);
            var predefinedFactory = compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
                .GetMethod("PredefinedTypeNames", BindingFlags.Public | BindingFlags.Static)!;
            var predefined = (System.Collections.IDictionary)predefinedFactory.Invoke(null, null)!;
            var predefinedRows = ((string)namePolicy.GetMethod("PredefinedTypeBindings")!.Invoke(null, null)!)
                .Split('|').Select(row => row.Split(':', 2)).ToArray();
            Check("predefined-compiled-bindings-and-order", predefined.Count == predefinedRows.Length
                && predefined.Keys.Cast<string>().SequenceEqual(predefinedRows.Select(row => row[1]))
                && predefinedRows.All(row => Convert.ToInt32(predefined[row[1]]) == Convert.ToInt32(Enum.Parse(typeId, row[0]))));
            predefined["Int"] = Enum.Parse(typeId, "Bool");
            predefined["__probe__"] = Enum.Parse(typeId, "Int");
            var independent = (System.Collections.IDictionary)predefinedFactory.Invoke(null, null)!;
            Check("predefined-compilation-copies-isolated", !independent.Contains("__probe__")
                && Convert.ToInt32(independent["Int"]) == Convert.ToInt32(Enum.Parse(typeId, "Int")));
            Check("predefined-alias-and-case-contract", !independent.Contains("int") && !independent.Contains("IntExtra")
                && Convert.ToInt32(independent["Int32"]) == Convert.ToInt32(independent["Int"])
                && Convert.ToInt32(independent["Long"]) == Convert.ToInt32(independent["Int64"])
                && Convert.ToInt32(independent["Float"]) == Convert.ToInt32(independent["Float32"])
                && Convert.ToInt32(independent["Double"]) == Convert.ToInt32(independent["Float64"]));
            var table = CreateTypeTable(compiler);
            var tableType = table.GetType();
            var taskFactory = tableType.GetMethod("GetOrAddTask")!;
            var intType = Enum.Parse(typeId, "Int");
            var taskType = taskFactory.Invoke(table, [intType])!;
            Check("task-predeclared-identity", taskType.Equals(Enum.Parse(typeId, "TaskInt")));
            Check("task-repeat-does-not-allocate", taskFactory.Invoke(table, [intType])!.Equals(taskType)
                && Convert.ToInt32(tableType.GetMethod("GetOrAddTask")!.Invoke(table, [Enum.Parse(typeId, "Int64")]))
                    == Convert.ToInt32(tableType.GetMethod("GetOrAddTask")!.Invoke(CreateTypeTable(compiler), [Enum.Parse(typeId, "Int64")])));
            var inverse = new object?[] { taskType, null };
            Check("task-predeclared-inverse", (bool)tableType.GetMethod("TryGetTaskValue")!.Invoke(table, inverse)!
                && intType.Equals(inverse[1]));
            var storageNames = (System.Collections.IDictionary)CreateBuiltinNames(compiler);
            var storageFactory = compiler.GetType("Sollang.Compiler.Semantics.StorageTypeDefinitions", true)!;
            var fixedFactory = storageFactory.GetMethod("FixedArrays")!;
            var dynamicFactory = storageFactory.GetMethod("DynamicArrays")!;
            var fixedShapes = (System.Collections.IDictionary)fixedFactory.Invoke(null, [storageNames])!;
            var dynamicShapes = (System.Collections.IDictionary)dynamicFactory.Invoke(null, [storageNames])!;
            var fixedRows = ((string)namePolicy.GetMethod("PredeclaredFixedArrays")!.Invoke(null, null)!)
                .Split('|').Select(row => row.Split(':')).ToArray();
            var dynamicRows = ((string)namePolicy.GetMethod("PredeclaredDynamicArrays")!.Invoke(null, null)!)
                .Split('|').Select(row => row.Split(':', 2)).ToArray();
            Check("storage-fixed-compiled-shapes-and-order", fixedShapes.Count == fixedRows.Length
                && fixedShapes.Keys.Cast<object>().SequenceEqual(fixedRows.Select(row => Enum.Parse(typeId, row[0])))
                && fixedRows.All(row => {
                    var shape = fixedShapes[Enum.Parse(typeId, row[0])]!;
                    return storageNames[row[1]]!.Equals(shape.GetType().GetField("Item1")!.GetValue(shape))
                        && int.Parse(row[2], System.Globalization.CultureInfo.InvariantCulture)
                            == (int)shape.GetType().GetField("Item2")!.GetValue(shape)!;
                }));
            Check("storage-dynamic-compiled-shapes-and-order", dynamicShapes.Count == dynamicRows.Length
                && dynamicShapes.Keys.Cast<object>().SequenceEqual(dynamicRows.Select(row => Enum.Parse(typeId, row[0])))
                && dynamicRows.All(row => storageNames[row[1]]!.Equals(dynamicShapes[Enum.Parse(typeId, row[0])])));
            fixedShapes.Clear();
            dynamicShapes.Clear();
            Check("storage-factory-copies-isolated",
                ((System.Collections.IDictionary)fixedFactory.Invoke(null, [storageNames])!).Count == fixedRows.Length
                && ((System.Collections.IDictionary)dynamicFactory.Invoke(null, [storageNames])!).Count == dynamicRows.Length);
            storageNames.Remove(dynamicRows[^1][1]);
            var missingStorageRejected = false;
            try { dynamicFactory.Invoke(null, [storageNames]); }
            catch (TargetInvocationException error) when (error.InnerException is KeyNotFoundException)
            { missingStorageRejected = true; }
            Check("storage-missing-element-rejected", missingStorageRejected);
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
            bool ExactTextSource(string emitted, string expected)
            {
                var formatted = (string)compiler.GetType("Sollang.Compiler.Cli.SourceFormatter", true)!
                    .GetMethod("Format")!.Invoke(null, [emitted])!;
                var lexerType = compiler.GetType("Sollang.Compiler.Lexing.Lexer", true)!;
                var lexer = Activator.CreateInstance(lexerType, [formatted]);
                var tokens = (System.Collections.IEnumerable)lexerType.GetMethod("Lex")!.Invoke(lexer, null)!;
                var token = tokens.Cast<object>().Single(value => value.GetType().GetProperty("Kind")!
                    .GetValue(value)!.ToString() == "String");
                var tokenType = token.GetType();
                var parser = compiler.GetType("Sollang.Compiler.Parsing.StringLiteralParser", true)!;
                var raw = (bool)tokenType.GetProperty("IsRawString")!.GetValue(token)!;
                var actual = raw
                    ? (string)parser.GetMethod("NormalizeRawString", BindingFlags.NonPublic | BindingFlags.Static)!
                        .Invoke(null, [token])!
                    : (string)parser.GetMethod("DecodeEscapes", BindingFlags.NonPublic | BindingFlags.Static)!
                        .Invoke(null, [tokenType.GetProperty("Text")!.GetValue(token)])!;
                if (raw)
                {
                    if (actual.Length < 2 || actual[0] != 'x' || actual[^1] != 'x'
                        || !formatted.Contains("-> slice(1, " + expected.Length + ")", StringComparison.Ordinal)) return false;
                    actual = actual[1..^1];
                }
                return actual == expected && (raw || !expected.Contains('"') && !expected.Contains('$'));
            }
            bool ExactTextLiteral(MethodInfo method)
            {
                var expected = (string)method.Invoke(null, null)!;
                var multiline = method.DeclaringType!.GetCustomAttributesData()
                    .Any(attribute => attribute.AttributeType.FullName == "Sollang.Compiler.Shared.SelfHostPolicyAttribute"
                        && attribute.NamedArguments.Any(argument => argument.MemberName == "MultilineText"
                            && argument.TypedValue.Value is true));
                if (multiline) expected = expected.Replace("\r\n", "\n", StringComparison.Ordinal);
                return ExactTextSource(Emit(method), expected);
            }
            bool ExactMultilineText(string value) => ExactTextSource(RenderTextValue(compiler, "Value", value),
                value.Replace("\r\n", "\n", StringComparison.Ordinal));
            MethodInfo TextMethod(string name) => typeof(SelfHostPolicyTests)
                .GetMethod(name, BindingFlags.NonPublic | BindingFlags.Static)!;
            Check("text-quoted-literal-parses-exactly", ExactTextLiteral(TextMethod(nameof(EscapedText))));
            Check("text-interpolation-markers-stay-literal", ExactTextLiteral(TextMethod(nameof(InterpolationText))));
            Check("text-boundary-quotes-stay-literal", ExactTextLiteral(TextMethod(nameof(BoundaryQuoteText))));
            Check("text-repeated-quotes-stay-literal", ExactTextLiteral(TextMethod(nameof(RepeatedQuoteText))));
            Check("text-leading-newline-whitespace-preserved", ExactMultilineText("\n  \n$")
                && ExactMultilineText("\r\n  \r\n$"));
            Check("text-multiline-quote-runs-preserved", ExactMultilineText("first\n  left\"\"\"right\n  tail"));
            Check("text-call-rejected", Rejected(nameof(CallText), "SELFHOST_POLICY_TEXT_CONSTANT_REQUIRED"));
            Check("text-input-rejected", Rejected(nameof(InputText), "SELFHOST_POLICY_TEXT_SIGNATURE_REQUIRED"));
            Check("text-nonascii-rejected", Rejected(nameof(NonAsciiText), "SELFHOST_POLICY_TEXT_LITERAL_UNSUPPORTED"));
            Check("text-control-rejected", Rejected(nameof(ControlText), "SELFHOST_POLICY_TEXT_LITERAL_UNSUPPORTED"));
            var integerInput = compiler.GetType("Sollang.Compiler.Shared.NativeRuntimePolicy", true)!;
            Check("runtime-quoted-multiline-parses-exactly", ExactTextLiteral(integerInput.GetMethod("MouseLinuxWorkerFunctions")!));
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

    private static object CreateBuiltinNames(Assembly compiler)
    {
        var names = (System.Collections.IDictionary)compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
            .GetMethod("PredefinedTypeNames")!.Invoke(null, null)!;
        var policy = compiler.GetType("Sollang.Compiler.Shared.TypeNamePolicy", true)!;
        var typeId = compiler.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
        foreach (var method in new[] { "IntrinsicStructDefinitions", "IntrinsicEnumDefinitions" })
            foreach (var row in ((string)policy.GetMethod(method)!.Invoke(null, null)!).Split('|').Select(row => row.Split(':', 2)))
                if (!names.Contains(row[1])) names.Add(row[1], Enum.Parse(typeId, row[0]));
        return names;
    }

    private static object CreateTypeTable(Assembly compiler)
    {
        var constructor = compiler.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!.GetConstructors().Single();
        var parameters = constructor.GetParameters();
        if (parameters.Length != 9 || parameters[5].Name != "pointerSize")
            throw new InvalidOperationException("TypeDefinitionTable constructor contract changed.");
        var arguments = new object?[parameters.Length];
        for (var index = 0; index < 5; index++)
            arguments[index] = Activator.CreateInstance(typeof(Dictionary<,>)
                .MakeGenericType(parameters[index].ParameterType.GetGenericArguments()));
        arguments[5] = 8;
        return constructor.Invoke(arguments);
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
        string Alias(int index) => types[index] == typeNamePolicy ? "typeNames"
            : names[index] == "TypeId" ? "referenceIds" : "policy" + index;
        for (var index = 0; index < types.Length; index++)
        {
            var attribute = types[index].GetCustomAttributesData().Single(item =>
                item.AttributeType.FullName == "Sollang.Compiler.Shared.SelfHostPolicyAttribute");
            source.Append("import ").Append(attribute.ConstructorArguments[0].Value)
                .Append(" as ").Append(Alias(index)).Append('\n');
            dependencies.Add(Path.Combine(root, (string)attribute.ConstructorArguments[1].Value!));
        }
        dependencies.Add(Path.Combine(root, "selfhost/semantic/type_name_policy.slg"));
        dependencies.Add(Path.Combine(root, "selfhost/semantic/reference_synthetic_type_ids.slg"));
        source.Append("import sollang.compiler.semantic.reference_synthetic_type_ids as synthetic\n");
        source.Append("""

taskRegistrationValue index: Int -> Int {
    [
    synthetic.Recipe { kind: synthetic.Kind.Named, first: -1, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Named, first: -1, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Task, first: 0, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Task, first: 1, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Dynamic, first: 3, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Task, first: 0, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Stream, first: 0, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.EventStream, first: 0, second: -1, length: 0 },
    synthetic.Recipe { kind: synthetic.Kind.Task, first: 2, second: -1, length: 0 }; ~] => recipes
    [referenceIds.enumValue("Int"), referenceIds.enumValue("Int64"), -1, -1, -1, -1, -1, -1, -1; ~] => seeds
    seeds -> synthetic.predeclaredTasks => aliases
    [2, 3, 4, 5, 6, 7, 8; ~] => roots
    recipes -> synthetic.register(seeds, aliases, roots, referenceIds.enumValue("FirstUserDefined") + 1) -> when {
        Err(_) { -1 }
        Ok(registered) {
            index < 7 -> if { registered.ids[index + 2] } else { registered.nextTypeId }
        }
    }
}

""");
        source.Append("""

arrayAliasValue index: Int, part: Int -> Int {
    synthetic.predeclaredArrays() -> when {
        Err(_) { -2 }
        Ok(shapes) {
            index < 0 or index >= (shapes -> len) -> if { -1 -> return }
            shapes[index] => shape
            part -> when {
                == 0 => shape.identity
                == 1 => shape.first
                == 2 => shape.length
                == 3 => shape.kind -> when {
                    Dynamic => 0
                    Fixed => 1
                    else => -1
                }
                else => -1
            }
        }
    }
}

storageBindingCount schema: Text, fixedLength: Bool -> Int {
    schema -> typeNames.storageBindings(fixedLength) -> when {
        Err(_) { -1 }
        Ok(bindings) { Int(bindings -> len) }
    }
}

storageBindingSpan schema: Text, fixedLength: Bool, index: Int, part: Int -> Int {
    schema -> typeNames.storageBindings(fixedLength) -> when {
        Err(_) { -2 }
        Ok(bindings) {
            index < 0 or index >= (bindings -> len) -> if { -1 -> return }
            bindings[index] => binding
            part -> when {
                == 0 => Int(binding.identityStart)
                == 1 => Int(binding.identityLength)
                == 2 => Int(binding.elementStart)
                == 3 => Int(binding.elementLength)
                == 4 => binding.length
                else => -1
            }
        }
    }
}

""");
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
                    if (enumType.FullName == "Sollang.Compiler.Semantics.TypeId")
                    {
                        label = names[index] + ".TypeName." + literal;
                        source.Append("    \"").Append(label).Append("\" -> println\n    ").Append(Alias(index))
                            .Append(".nameOf(").Append(literal).Append(") -> when {\n")
                            .Append("        Named(name) { name -> println }\n        Numeric(number) { number -> println }\n    }\n");
                        expected.Append(label).Append('\n').Append(name ?? literal).Append('\n');
                    }
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
        var intrinsicFactory = compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
            .GetMethod("IntrinsicNominal", BindingFlags.Public | BindingFlags.Static)!;
        var intrinsicNames = new[] { "IntrinsicStructDefinitions", "IntrinsicEnumDefinitions" }
            .SelectMany(method => ((string)typeNamePolicy.GetMethod(method)!.Invoke(null, null)!).Split('|'))
            .Select(row => row.Split(':', 2)[1])
            .SelectMany(name => new[] { name, name + "Extra", name.ToLowerInvariant(), name.Split('.').Last() })
            .Concat(["", "missing"]).Distinct(StringComparer.Ordinal).ToArray();
        foreach (var enumeration in new[] { false, true })
        foreach (var name in intrinsicNames)
        {
            var value = intrinsicFactory.Invoke(null, [name, enumeration]);
            var flag = enumeration ? "true" : "false";
            AppendValue("BuiltinTypeDefinitions.IntrinsicNominal:" + flag + ":" + name,
                "referenceIds.enumValue(typeNames.intrinsicEnumName(\"" + name + "\", " + flag + "))",
                (value is null ? -1 : Convert.ToInt32(value)).ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        var predefinedFactory = compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
            .GetMethod("PredefinedTypeNames", BindingFlags.Public | BindingFlags.Static)!;
        var predefined = (System.Collections.IDictionary)predefinedFactory.Invoke(null, null)!;
        foreach (var name in predefined.Keys.Cast<string>().SelectMany(name =>
                new[] { name, name + "Extra", name.ToLowerInvariant() }).Concat(["", "missing"]).Distinct(StringComparer.Ordinal))
        {
            var value = predefined.Contains(name) ? Convert.ToInt32(predefined[name]) : -1;
            AppendValue("BuiltinTypeDefinitions.Predefined:" + name,
                "referenceIds.enumValue(typeNames.builtinEnumName(\"" + name + "\"))",
                value.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        var taskTable = CreateTypeTable(compiler);
        var taskMethod = taskTable.GetType().GetMethod("GetOrAddTask")!;
        var taskIdType = compiler.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
        object Task(string name) => taskMethod.Invoke(taskTable, [Enum.Parse(taskIdType, name)])!;
        var intTask = Task("Int");
        var longTask = Task("Int64");
        var taskSequence = new[] {
            intTask, longTask,
            taskTable.GetType().GetMethod("GetOrAddDynamicArray")!.Invoke(taskTable, [longTask])!,
            Task("Int"),
            taskTable.GetType().GetMethod("GetOrAddStream")!.Invoke(taskTable, [Enum.Parse(taskIdType, "Int")])!,
            taskTable.GetType().GetMethod("GetOrAddEventStream")!.Invoke(taskTable, [Enum.Parse(taskIdType, "Int")])!,
            taskMethod.Invoke(taskTable, [intTask])!, Task("Bool")
        };
        for (var index = 0; index < taskSequence.Length; index++)
            AppendValue("TypeDefinitionTable.TaskRegistration:" + index, "taskRegistrationValue(" + index + ")",
                Convert.ToInt32(taskSequence[index]).ToString(System.Globalization.CultureInfo.InvariantCulture));
        var taskBindings = (System.Collections.IDictionary)compiler.GetType("Sollang.Compiler.Semantics.BuiltinTypeDefinitions", true)!
            .GetMethod("PredeclaredTasks")!.Invoke(null, null)!;
        foreach (var name in Enum.GetNames(taskIdType).Concat(["", "int", "IntExtra", "missing"]))
        {
            var value = Enum.IsDefined(taskIdType, name) ? Enum.Parse(taskIdType, name) : null;
            AppendValue("BuiltinTypeDefinitions.PredeclaredTask:" + name,
                "referenceIds.enumValue(typeNames.taskEnumName(\"" + name + "\"))",
                (value is not null && taskBindings.Contains(value) ? Convert.ToInt32(taskBindings[value]) : -1)
                    .ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        var storageNames = CreateBuiltinNames(compiler);
        var storageFactory = compiler.GetType("Sollang.Compiler.Semantics.StorageTypeDefinitions", true)!;
        var arrayIndex = 0;
        foreach (var fixedLength in new[] { false, true })
        {
            var shapes = (System.Collections.IDictionary)storageFactory.GetMethod(fixedLength ? "FixedArrays" : "DynamicArrays")!
                .Invoke(null, [storageNames])!;
            foreach (System.Collections.DictionaryEntry entry in shapes)
            {
                var element = fixedLength ? entry.Value!.GetType().GetField("Item1")!.GetValue(entry.Value)! : entry.Value!;
                var length = fixedLength ? (int)entry.Value!.GetType().GetField("Item2")!.GetValue(entry.Value)! : 0;
                var values = new[] { Convert.ToInt32(entry.Key), Convert.ToInt32(element), length, fixedLength ? 1 : 0 };
                for (var part = 0; part < values.Length; part++)
                    AppendValue("StorageTypeDefinitions.Alias:" + arrayIndex + ":" + part,
                        "arrayAliasValue(" + arrayIndex + ", " + part + ")",
                        values[part].ToString(System.Globalization.CultureInfo.InvariantCulture));
                arrayIndex++;
            }
            var schema = (string)typeNamePolicy.GetMethod(fixedLength ? "PredeclaredFixedArrays" : "PredeclaredDynamicArrays")!
                .Invoke(null, null)!;
            var start = 0;
            var ordinal = 0;
            foreach (var row in schema.Split('|'))
            {
                var fields = row.Split(':');
                var values = new[] { start, fields[0].Length, start + fields[0].Length + 1, fields[1].Length,
                    fixedLength ? int.Parse(fields[2], System.Globalization.CultureInfo.InvariantCulture) : -1 };
                for (var part = 0; part < values.Length; part++)
                    AppendValue("StorageTypeDefinitions.Span:" + fixedLength + ":" + ordinal + ":" + part,
                        "storageBindingSpan(\"" + schema + "\", " + fixedLength.ToString().ToLowerInvariant() + ", " + ordinal + ", " + part + ")",
                        values[part].ToString(System.Globalization.CultureInfo.InvariantCulture));
                start += row.Length + 1;
                ordinal++;
            }
        }
        foreach (var index in new[] { -1, arrayIndex })
            AppendValue("StorageTypeDefinitions.AliasMissing:" + index, "arrayAliasValue(" + index + ", 0)", "-1");
        AppendValue("StorageTypeDefinitions.AliasPartMissing", "arrayAliasValue(0, 4)", "-1");
        foreach (var row in new (string Schema, bool Fixed, int Count)[] {
            ("A:B:0", true, 1), ("A:B:2147483647", true, 1),
            ("A:B:2147483648", true, -1), ("A:B:-1", true, -1), ("A:B:+1", true, -1),
            ("A:B:1x", true, -1), ("", true, -1), (":B:1", true, -1), ("A::1", true, -1),
            ("A:B:", true, -1), ("A:B", true, -1), ("A:B:1|", true, -1),
            ("A:B:1||C:D:2", true, -1), ("A:B:1|C:D:2", true, 2),
            ("A:B", false, 1), ("A:B|C:D", false, 2), ("", false, -1),
            ("A:B|", false, -1), (":B", false, -1), ("A:", false, -1), ("A", false, -1)
        })
            AppendValue("StorageTypeDefinitions.Parse:" + row.Fixed + ":" + row.Schema,
                "storageBindingCount(\"" + row.Schema + "\", " + row.Fixed.ToString().ToLowerInvariant() + ")",
                row.Count.ToString(System.Globalization.CultureInfo.InvariantCulture));
        void AppendValue(string label, string call, string value)
        {
            source.Append("    \"").Append(label).Append("\" -> println\n    ")
                .Append(call).Append(" -> println\n");
            expected.Append(label).Append('\n').Append(value).Append('\n');
        }
        source.Append("}\n");
        var sourcePath = Path.Combine(directory, "runtime-policy-probe.slg");
        File.WriteAllText(sourcePath, source.ToString().Replace("\r\n", "\n", StringComparison.Ordinal));
        var literalValues = new[] { "a\"b\\c", "$name $(value) \\n", "\"quoted\"", "left\"\"\"right",
            "\n  \n$", "first  \n  left\"\"\"right\n  tail", "\r\n  \r\n$" };
        var literalSource = new System.Text.StringBuilder();
        for (var index = 0; index < literalValues.Length; index++)
            literalSource.Append(RenderTextValue(compiler, "Value" + index, literalValues[index])).Append('\n');
        literalSource.Append("main {\n");
        var literalExpected = new System.Text.StringBuilder();
        for (var index = 0; index < literalValues.Length; index++)
        {
            literalSource.Append("    \"case:").Append(index).Append("\" -> println\n    value")
                .Append(index).Append("() -> println\n");
            literalExpected.Append("case:").Append(index).Append('\n')
                .Append(literalValues[index].Replace("\r\n", "\n", StringComparison.Ordinal)).Append('\n');
        }
        literalSource.Append("    \"end\" -> println\n}\n");
        literalExpected.Append("end");
        var literalPath = Path.Combine(directory, "literal-policy-probe.slg");
        File.WriteAllText(literalPath, literalSource.ToString());
        var contractPath = Path.Combine(directory, "runtime-policy-contract.json");
        File.WriteAllText(contractPath, JsonSerializer.Serialize(new
        {
            schemaVersion = 1,
            formatCheckSources = new[] { sourcePath, literalPath, Path.Combine(root, "selfhost/semantic/reference_type_ids.slg"),
                Path.Combine(root, "selfhost/semantic/type_name_policy.slg") },
            policyModules = names,
            scope = "Generated policies against compiled CSharp method results; exhaustive boolean inputs, UInt64 boundary products and every declared cache-key rule",
            cases = new object[] { new { id = "shared-policy-runtime", source = sourcePath,
                additionalSources = dependencies, exit = 0, stderr = "", stdout = expected.ToString().TrimEnd('\r', '\n') },
                new { id = "literal-policy-values", source = literalPath, additionalSources = Array.Empty<string>(),
                    exit = 0, stderr = "", stdout = literalExpected.ToString() } }
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

    private static string RenderTextValue(Assembly compiler, string name, string value) =>
        (string)compiler.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", true)!
            .GetMethod("RenderTextValue", BindingFlags.NonPublic | BindingFlags.Static)!
            .Invoke(null, [name, value, true])!;

    private static string EscapedText() => "a\"b\\c";
    private static string InterpolationText() => "$name $(value) \\n";
    private static string BoundaryQuoteText() => "\"quoted\"";
    private static string RepeatedQuoteText() => "left\"\"\"right";
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
