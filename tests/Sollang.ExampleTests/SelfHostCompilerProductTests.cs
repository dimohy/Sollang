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

            var driver = Path.Combine(Path.GetDirectoryName(manifest)!, "selfhost-sollangc-driver.slg");
            var bridge = Path.Combine(product, "CompilerLinkBridge.dll");
            var assembly = Path.Combine(product, "Sollang.Compiler.dll");
            var assembler = Path.Combine(product, "llvm-as.exe");
            var llvm = Path.Combine(product, "program.ll");
            var emissionManifest = Path.Combine(product, "emission-inputs.json");
            foreach (var file in new[] { driver, bridge, assembly, assembler, llvm })
                File.WriteAllText(file, Path.GetFileName(file));
            File.WriteAllText(manifest, "compiler.slg\ntests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg\n");
            var sourcePins = new[] { source, driver, standard }.ToDictionary(path => path, Hash);
            var emissionInputs = JsonSerializer.SerializeToNode(new
            {
                schemaVersion = 1, target = "windows-x64", outputKind = "executable",
                sourcePaths = new[] { driver, source }, inputHashes = sourcePins
            })!.AsObject();
            File.WriteAllText(emissionManifest, emissionInputs.ToJsonString());
            var separatedPins = new[] { manifest, bridge, assembly, assembler, emissionManifest }
                .Concat(sourcePins.Keys).ToDictionary(path => path, Hash);
            var assemblyHash = Hash(assembly);
            var productHash = Hash(executable);
            var separated = JsonSerializer.SerializeToNode(new
            {
                schemaVersion = 1, status = "passed", completed = 1, total = 1,
                inputsStable = true, processesStopped = true,
                phaseMode = "explicit-separated-emission-and-production-link",
                inputFingerprint = "same", finalInputFingerprint = "same",
                inputFingerprintKind = "sha256-canonical-input-json-v1",
                inputHashesStart = separatedPins, inputHashesEnd = separatedPins,
                compilerSha256 = productHash, compilerProduct = executable, product = executable, productSha256 = productHash,
                emission = new
                {
                    status = "passed", mode = "emit", warnings = Array.Empty<string>(),
                    sourceCount = 2, declaredInputCount = 3, compilerAssemblySha256 = assemblyHash,
                    outputSha256 = Hash(llvm), outputBytes = new FileInfo(llvm).Length
                },
                link = new
                {
                    status = "passed", mode = "link", entryPoint = "sollang_start",
                    optimization = "-O2", compilerAssemblySha256 = assemblyHash
                },
                processes = new[]
                {
                    new { exit = 0, shutdownConfirmed = true, command = new[] { "dotnet", bridge, "emit", assembly, assemblyHash, emissionManifest, llvm } },
                    new { exit = 0, shutdownConfirmed = true, command = new[] { assembler, llvm, "-o", Path.Combine(product, "program.bc") } },
                    new { exit = 0, shutdownConfirmed = true, command = new[] { "dotnet", bridge, "link", assembly, assemblyHash, product, llvm, executable, product, "-O2", "24" } }
                }
            })!.AsObject();
            Write(separated);
            void RejectSeparated(string id, Action<JsonObject> mutation)
            {
                Check(id, () =>
                {
                    var changed = separated.DeepClone().AsObject();
                    mutation(changed);
                    Write(changed);
                    Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, production));
                    Write(separated);
                });
            }
            Check("separated-product", () => SelfHostCompilerProduct.Validate(fixtures, product, production).AssertStable());
            RejectSeparated("separated-unconfirmed-process", value => value["processes"]![1]!["shutdownConfirmed"] = false);
            RejectSeparated("separated-grammar-failure", value => value["processes"]![1]!["exit"] = 1);
            RejectSeparated("separated-link-input-changed", value => value["processes"]![2]!["command"]![6] = driver);
            Check("separated-source-order-changed", () =>
            {
                var changed = separated.DeepClone().AsObject();
                var reordered = emissionInputs.DeepClone().AsObject();
                reordered["sourcePaths"] = new JsonArray(source, driver);
                File.WriteAllText(emissionManifest, reordered.ToJsonString());
                changed["inputHashesStart"]![emissionManifest] = Hash(emissionManifest);
                changed["inputHashesEnd"]![emissionManifest] = Hash(emissionManifest);
                Write(changed);
                Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, production));
                File.WriteAllText(emissionManifest, emissionInputs.ToJsonString());
                Write(separated);
            });
            Check("separated-llvm-changed", () =>
            {
                var before = File.ReadAllBytes(llvm);
                var admitted = SelfHostCompilerProduct.Validate(fixtures, product, production);
                File.AppendAllText(llvm, "changed\n");
                Reject(() => SelfHostCompilerProduct.Validate(fixtures, product, production));
                Reject(admitted.AssertStable);
                File.WriteAllBytes(llvm, before);
            });
        }
        catch (Exception error) { failure = error.ToString(); }
        Directory.CreateDirectory(Path.GetDirectoryName(resultPath)!);
        File.WriteAllText(resultPath, JsonSerializer.Serialize(new
        {
            status = failure is null ? "passed" : "failed", completed = cases.Count,
            total = 19, cases, failure, productionRootExplicit = true,
            fixtureInputsRewritten = false, productExecuted = false
        }, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"[selfhost product source roots] {cases.Count}/19 {(failure is null ? "PASS" : "FAIL")}");
        return failure is null ? 0 : 1;
    }
}
