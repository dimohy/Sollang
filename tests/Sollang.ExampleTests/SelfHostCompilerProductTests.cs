using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;

internal static class SelfHostCompilerProductTests
{
    internal static int Run(string resultPath)
    {
        resultPath = Path.GetFullPath(resultPath);
        if (File.Exists(resultPath) || Directory.Exists(resultPath + ".cases"))
            throw new IOException("Product test output already exists.");
        var root = resultPath + ".cases";
        var production = Path.Combine(root, "production");
        var fixtures = Path.Combine(root, "fixtures");
        var product = Path.Combine(root, "product");
        var manifest = Path.Combine(production, "tests", "Sollang.ExampleTests", "Fixtures",
            "selfhost-sollangc-driver.sources.txt");
        var source = Path.Combine(production, "compiler.slg");
        var standard = Path.Combine(production, "stdlib", "standard.slg");
        var executable = Path.Combine(product, "compiler.exe");
        foreach (var path in new[] { manifest, source, standard, executable })
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        Directory.CreateDirectory(fixtures);
        File.WriteAllText(manifest, "compiler.slg\n");
        File.WriteAllText(source, "production compiler input\n");
        File.WriteAllText(standard, "production standard library input\n");
        File.WriteAllText(executable, "identity-only fixture; never executed\n");
        static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
        var pins = new[] { manifest, source, standard }.ToDictionary(path => path, Hash);
        var original = JsonSerializer.SerializeToNode(new
        {
            status = "passed", inputsStable = true, managedSeed = true,
            optimization = "O2", inputFingerprint = "same", finalInputFingerprint = "same",
            inputHashesStart = pins, inputHashesEnd = pins,
            compilerSourceCount = 1, stdlibSourceCount = 1, compilerSha256 = Hash(executable)
        })!.AsObject();
        var record = Path.Combine(product, "result.json");
        void Write(JsonObject value) => File.WriteAllText(record, value.ToJsonString());
        Write(original);
        var cases = new List<object>();
        string? failure = null;
        void Check(string id, Action action)
        {
            action();
            cases.Add(new { id, status = "passed" });
        }
        void Reject(Action action)
        {
            try { action(); }
            catch (Exception error) when (error is InvalidOperationException or IOException)
            { return; }
            throw new InvalidOperationException("Changed or mismatched product was accepted.");
        }
        void Mutate(string id, Action<JsonObject> mutation)
        {
            Check(id, () =>
            {
                var changed = original.DeepClone().AsObject();
                mutation(changed);
                Write(changed);
                Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, production));
                Write(original);
            });
        }
        try
        {
            Check("default-production-root", () => SelfHostCompilerProduct.Validate(production, product));
            Check("snapshot-requires-explicit-production-root",
                () => Reject(() => SelfHostCompilerProduct.Validate(fixtures, product)));
            Check("explicit-production-root", () => SelfHostCompilerProduct.Validate(fixtures, product, production));
            Check("wrong-production-root", () => Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, fixtures)));
            Mutate("source-closure-missing", value => value["inputHashesStart"]!.AsObject().Remove(source));
            Mutate("both-source-pins-missing", value =>
            {
                value["inputHashesStart"]!.AsObject().Remove(source);
                value["inputHashesEnd"]!.AsObject().Remove(source);
            });
            Mutate("source-count-changed", value => value["compilerSourceCount"] = 2);
            Mutate("standard-count-changed", value => value["stdlibSourceCount"] = 2);
            Mutate("fingerprint-changed", value => value["finalInputFingerprint"] = "changed");
            Mutate("incomplete-build", value => value["status"] = "failed");
            Check("changed-production-source", () =>
            {
                var before = File.ReadAllBytes(source);
                File.AppendAllText(source, "changed\n");
                Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, production));
                File.WriteAllBytes(source, before);
            });
            Check("changed-product-binary", () =>
            {
                var before = File.ReadAllBytes(executable);
                File.AppendAllText(executable, "changed\n");
                Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, production));
                File.WriteAllBytes(executable, before);
            });
            Check("stable-after-controls", () => SelfHostCompilerProduct.Validate(fixtures, product, production).AssertStable());
        }
        catch (Exception error) { failure = error.ToString(); }
        Directory.CreateDirectory(Path.GetDirectoryName(resultPath)!);
        File.WriteAllText(resultPath, JsonSerializer.Serialize(new
        {
            status = failure is null ? "passed" : "failed", completed = cases.Count,
            total = 13, cases, failure, productionRootExplicit = true,
            fixtureInputsRewritten = false, productExecuted = false
        }, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"[selfhost product source roots] {cases.Count}/13 {(failure is null ? "PASS" : "FAIL")}");
        return failure is null ? 0 : 1;
    }
}
