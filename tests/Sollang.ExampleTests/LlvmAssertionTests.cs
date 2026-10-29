using System.Text.Json;
using System.Text.RegularExpressions;

internal static class LlvmAssertionTests
{
    internal static int Run(string inputPath, string resultPath,
        string name = "51-fixed-array-value-generics")
    {
        if (name is not ("51-fixed-array-value-generics" or "52-multi-file-modules"))
            throw new ArgumentException("Unsupported LLVM assertion fixture.", nameof(name));
        if (File.Exists(resultPath)) throw new IOException("Test result already exists.");
        var directory = Path.GetDirectoryName(Path.GetFullPath(resultPath))!;
        Directory.CreateDirectory(directory);
        var expectedDirectory = Path.Combine("examples", "regression", "expected");
        var paths = LlvmAssertions.SelectPaths(expectedDirectory, name, "windows-x64", false);
        var original = File.ReadAllText(inputPath);
        var cases = new List<object>();
        string? failure = null;
        void Check(string id, bool condition)
        {
            if (!condition) throw new InvalidOperationException("LLVM assertion control failed: " + id);
            cases.Add(new { id, status = "passed" });
        }
        void Verify(string id, string llvm, bool accepted)
        {
            var path = Path.Combine(directory, id + ".ll");
            File.WriteAllText(path, llvm);
            var actual = LlvmAssertions.Verify(path, paths.Contains, paths.NotContains, paths.RegexCounts, out var error);
            Check(id, actual == accepted && (accepted || !string.IsNullOrWhiteSpace(error)));
        }
        string ReplaceFirst(string pattern, string replacement) => new Regex(pattern).Replace(original, replacement, 1);
        try
        {
            Check("slg-selector", paths.RegexCounts.EndsWith(".slg.llvm.regex-counts.txt", StringComparison.Ordinal));
            var managed = LlvmAssertions.SelectPaths(expectedDirectory, name, "windows-x64", true);
            Check("csharp-original-selector", managed.Contains == Path.Combine(expectedDirectory, name + ".llvm.contains.txt"));
            var common = LlvmAssertions.SelectPaths(expectedDirectory, "509-readonly-reference-last-use", "windows-x64", false);
            Check("common-assertions-preserved", common.Contains.EndsWith("509-readonly-reference-last-use.llvm.contains.txt", StringComparison.Ordinal));
            var emptyDirectory = Path.Combine(directory, "empty-override");
            Directory.CreateDirectory(emptyDirectory);
            File.WriteAllText(Path.Combine(emptyDirectory, name + ".slg.llvm.regex-counts.txt"), "");
            var emptyRejected = false;
            try { LlvmAssertions.SelectPaths(emptyDirectory, name, "windows-x64", false); }
            catch (InvalidDataException) { emptyRejected = true; }
            Check("empty-override-rejected", emptyRejected);
            Verify("valid-slg", original, true);
            if (name == "52-multi-file-modules")
            {
                Verify("wrong-multiplier", ReplaceFirst(@"(= mul i32 %arg, )2(\r?\n)", "${1}3${2}"), false);
                Verify("wrong-call-argument", ReplaceFirst(@"(call i32 @sollang_m\d+_s0\(i32 )21(\))", "${1}22${2}"), false);
                Verify("wrong-return-value", ReplaceFirst(@"(?ms)(^define i32 @sollang_m\d+_s0\(i32 %arg\) \{\r?\nentry:\r?\n  %v\d+ = mul i32 %arg, 2\r?\n  ret i32 )%v\d+", "${1}%arg"), false);
                Verify("missing-function", ReplaceFirst(@"(?ms)^define i32 @sollang_m\d+_s0\(i32 %arg\) \{\r?\nentry:\r?\n  %v\d+ = mul i32 %arg, 2\r?\n  ret i32 %v\d+\r?\n\}\r?\n", ""), false);
            }
            else
            {
                Verify("missing-specialization", ReplaceFirst(@"(?ms)^define i32 @sollang_m144_s5_g\d+\([^\r\n]+\r?\n.*?^\}\r?\n", ""), false);
                var calls = Regex.Matches(original, @"call i32 (?<target>@sollang_m144_s5_g\d+)\(%sollang\.int_slice (?<argument>%v\d+)\)");
                if (calls.Count != 5) throw new InvalidOperationException("Expected five pinned specialization calls.");
                var second = calls[1].Groups["target"];
                Verify("duplicate-target", original[..second.Index] + calls[0].Groups["target"].Value + original[(second.Index + second.Length)..], false);
                var firstArgument = calls[0].Groups["argument"];
                Verify("wrong-type-binding", original[..firstArgument.Index] + calls[2].Groups["argument"].Value + original[(firstArgument.Index + firstArgument.Length)..], false);
                Verify("unspecialized-template", original + "\ndeclare i32 @sollang_m144_s5(%sollang.int_slice)\n", false);
                Verify("wrong-first-load", ReplaceFirst(@"(?s)(define %sollang\.text @sollang_m144_s9_g\d+\([^\n]+\n(?:(?!\n\}).)*?load )%sollang\.text", "${1}i32"), false);
                Verify("wrong-length-binding", ReplaceFirst(@"(= insertvalue %sollang\.int_slice %v\d+_0, i64 )3(, 1)", "${1}4${2}"), false);
                Verify("wrong-fixed-length-result", ReplaceFirst(@"(?s)(define i32 @sollang_m144_s5_g\d+\(%sollang\.int_slice %arg\) \{.*?ret i32 )%v\d+", "${1}999"), false);
            }
        }
        catch (Exception error) { failure = error.ToString(); }
        AtomicResultFile.Write(resultPath, JsonSerializer.Serialize(new
        {
            status = failure is null ? "passed" : "failed", completed = cases.Count,
            total = name == "52-multi-file-modules" ? 9 : 12,
            cases, failure
        }, new JsonSerializerOptions { WriteIndented = true }));
        return failure is null ? 0 : 1;
    }
}
