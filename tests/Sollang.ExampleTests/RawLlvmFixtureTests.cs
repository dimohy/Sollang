using System.Text.Json;

internal static class RawLlvmFixtureTests
{
    internal static int Run(string resultPath)
    {
        if (File.Exists(resultPath)) throw new IOException("Test result already exists.");
        var cases = new List<object>();
        string? failure = null;
        var source = "import sollang.compiler.llvm.text as llvm\nmain { [\n\"\"\"\nmain { }\n\"\"\"; ~ ] => sources!\nsources! -> llvm.emit\n}";
        void Check(string id, string text, bool expected)
        {
            if (RawLlvmFixture.SupportsCanonicalProviderEmission(text) != expected)
                throw new InvalidOperationException("Unexpected raw LLVM fixture classification: " + id);
            cases.Add(new { id, status = "passed" });
        }
        try
        {
            foreach (var name in new[] { "1123-selfhost-materialized-console-call", "613-selfhost-com-runtime", "662-selfhost-parallel-source-context" })
            {
                var rootPath = Path.Combine("examples", "regression", "expected", name + ".root.txt");
                if (!File.Exists(rootPath)) throw new InvalidOperationException("Explicit canonical root missing.");
                Check(name, File.ReadAllText(Path.Combine("examples", "regression", name + ".slg")), true);
            }
            Check("mutable-wrapper", source, true);
            Check("immutable-wrapper", source.Replace("sources!", "sources"), true);
            Check("linux-wrapper", source.Replace("llvm.emit", "llvm.emitLinux"), true);
            Check("wasm-wrapper", source.Replace("llvm.emit", "llvm.emitWasm"), true);
            Check("alias-wrapper", source.Replace("as llvm", "as backend").Replace("llvm.emit", "backend.emit"), true);
            Check("extra-effect-is-not-reusable", source.Replace("sources! ->", "7 -> println\nsources! ->"), false);
            Check("dynamic-input-is-not-reusable", source.Replace("=> sources!", "=> other!"), false);
            Check("extra-import-is-not-reusable", "import example.extra as extra\n" + source, false);
            Check("different-api-is-not-reusable", source.Replace("llvm.emit", "llvm.inspect"), false);
            Check("root-only-is-not-raw", "import sollang.compiler.llvm.text as llvm\nmain { sources -> llvm.emit }", false);
            Check("comment-is-not-source", "# " + source.Replace("\n", "\n# "), false);
        }
        catch (Exception error) { failure = error.ToString(); }
        AtomicResultFile.Write(resultPath, JsonSerializer.Serialize(new
        {
            status = failure is null ? "passed" : "failed", completed = cases.Count, total = 14,
            cases, failure
        }, new JsonSerializerOptions { WriteIndented = true }));
        return failure is null ? 0 : 1;
    }
}
