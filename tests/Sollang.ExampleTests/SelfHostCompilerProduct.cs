using System.Security.Cryptography;
using System.Text.Json;

// Reuse the canonical product only with its immutable build/source proof.
// This proves product identity and current inputs, not compiler equivalence.
internal sealed record SelfHostCompilerProduct(string CompilerPath, Dictionary<string, string> InputHashes)
{
    internal static SelfHostCompilerProduct Validate(string repoRoot, string directory,
        string? productionRoot = null)
    {
        directory = Path.GetFullPath(directory, repoRoot);
        // A frozen fixture tree can differ from the source tree that produced
        // the reused compiler. Its production closure must still match every
        // absolute path and hash in the original build record.
        productionRoot = Path.GetFullPath(productionRoot ?? repoRoot, repoRoot);
        var recordPath = Path.Combine(directory, "result.json");
        var compilerPath = Path.Combine(directory, "compiler.exe");
        var recordBytes = File.ReadAllBytes(recordPath);
        using var document = JsonDocument.Parse(recordBytes);
        var record = document.RootElement;
        var separated = record.TryGetProperty("phaseMode", out var mode)
            && mode.GetString() == "explicit-separated-emission-and-production-link";
        if (record.GetProperty("status").GetString() != "passed"
            || !record.GetProperty("inputsStable").GetBoolean()
            // This is the compiler product's optimization, not the fixture's.
            // Reusing a verified O2 compiler must not change program build options.
            || (!separated && (!record.GetProperty("managedSeed").GetBoolean()
                || record.GetProperty("optimization").GetString() is not ("O1" or "O2")))
            || string.IsNullOrEmpty(record.GetProperty("inputFingerprint").GetString())
            || record.GetProperty("inputFingerprint").GetString() != record.GetProperty("finalInputFingerprint").GetString())
            throw new InvalidOperationException("SELFHOST_PRODUCT_BUILD_PROOF_INCOMPLETE");

        var start = JsonSerializer.Deserialize<Dictionary<string, string>>(record.GetProperty("inputHashesStart"))
            ?? throw new InvalidOperationException("SELFHOST_PRODUCT_INPUT_PROOF_INCOMPLETE");
        var end = JsonSerializer.Deserialize<Dictionary<string, string>>(record.GetProperty("inputHashesEnd"))
            ?? throw new InvalidOperationException("SELFHOST_PRODUCT_INPUT_PROOF_INCOMPLETE");
        if (start.Count == 0 || start.Count != end.Count
            || start.Any(pin => !end.TryGetValue(pin.Key, out var hash) || hash != pin.Value))
            throw new InvalidOperationException("SELFHOST_PRODUCT_INPUT_PROOF_INCOMPLETE");
        var manifest = Path.Combine(productionRoot, "tests", "Sollang.ExampleTests", "Fixtures", "selfhost-sollangc-driver.sources.txt");
        var sources = File.ReadLines(manifest).Where(line => !string.IsNullOrWhiteSpace(line))
            .Select(line => Path.GetFullPath(line.Trim(), productionRoot)).ToArray();
        var stdlib = Directory.GetFiles(Path.Combine(productionRoot, "stdlib"), "*.slg", SearchOption.AllDirectories);
        if (sources.Length == 0 || sources.Distinct(StringComparer.OrdinalIgnoreCase).Count() != sources.Length
            || (!separated && (sources.Length != record.GetProperty("compilerSourceCount").GetInt32()
                || stdlib.Length != record.GetProperty("stdlibSourceCount").GetInt32()))
            || sources.Concat(stdlib).Append(manifest).Any(path => !start.ContainsKey(path)))
            throw new InvalidOperationException("SELFHOST_PRODUCT_CANONICAL_SOURCE_CLOSURE_MISSING");

        AssertInputs(start);
        var productHash = record.GetProperty("compilerSha256").GetString();
        if (productHash is null || Hash(compilerPath) != productHash)
            throw new InvalidOperationException("SELFHOST_PRODUCT_BINARY_CHANGED");
        if (separated)
            ValidateSeparated(record, directory, productionRoot, compilerPath, productHash, sources, stdlib, start);
        start.Add(recordPath, Convert.ToHexString(SHA256.HashData(recordBytes)));
        start.Add(compilerPath, productHash);
        return new SelfHostCompilerProduct(compilerPath, start);
    }

    private static void ValidateSeparated(JsonElement record, string directory, string productionRoot,
        string compilerPath, string productHash, string[] sources, string[] stdlib,
        Dictionary<string, string> inputs)
    {
        var emission = record.GetProperty("emission");
        var link = record.GetProperty("link");
        var processes = record.GetProperty("processes").EnumerateArray().ToArray();
        var manifest = Path.Combine(directory, "emission-inputs.json");
        var llvm = Path.Combine(directory, "program.ll");
        if (record.GetProperty("schemaVersion").GetInt32() != 1
            || record.GetProperty("completed").GetInt32() != 1 || record.GetProperty("total").GetInt32() != 1
            || !record.GetProperty("processesStopped").GetBoolean()
            || record.GetProperty("inputFingerprintKind").GetString() != "sha256-canonical-input-json-v1"
            || record.GetProperty("compilerProduct").GetString() != compilerPath
            || record.GetProperty("product").GetString() != compilerPath
            || record.GetProperty("productSha256").GetString() != productHash
            || emission.GetProperty("status").GetString() != "passed" || emission.GetProperty("mode").GetString() != "emit"
            || emission.GetProperty("warnings").GetArrayLength() != 0
            || emission.GetProperty("sourceCount").GetInt32() != sources.Length
            || emission.GetProperty("declaredInputCount").GetInt32() != sources.Length + stdlib.Length
            || link.GetProperty("status").GetString() != "passed" || link.GetProperty("mode").GetString() != "link"
            || link.GetProperty("entryPoint").GetString() != "sollang_start"
            || link.GetProperty("optimization").GetString() is not ("-O1" or "-O2")
            || processes.Length != 3
            || processes.Any(process => process.GetProperty("exit").GetInt32() != 0
                || !process.GetProperty("shutdownConfirmed").GetBoolean())
            || !inputs.ContainsKey(manifest))
            throw new InvalidOperationException("SELFHOST_PRODUCT_SEPARATED_PROOF_INCOMPLETE");

        var commands = processes.Select(process => process.GetProperty("command").EnumerateArray()
            .Select(argument => argument.GetString() ?? "").ToArray()).ToArray();
        var emit = commands[0];
        var assemble = commands[1];
        var nativeLink = commands[2];
        var assemblyHash = emission.GetProperty("compilerAssemblySha256").GetString();
        if (emit.Length != 7 || assemble.Length != 4 || nativeLink.Length != 11
            || emit[2] != "emit" || nativeLink[2] != "link" || emit[1] != nativeLink[1]
            || !inputs.ContainsKey(emit[1]) || !inputs.ContainsKey(assemble[0])
            || Path.GetFileName(assemble[0]) != "llvm-as.exe"
            || Path.GetFileName(emit[3]) != "Sollang.Compiler.dll"
            || !inputs.TryGetValue(emit[3], out var pinnedAssembly) || pinnedAssembly != assemblyHash
            || emit[3] != nativeLink[3] || emit[4] != assemblyHash || nativeLink[4] != assemblyHash
            || link.GetProperty("compilerAssemblySha256").GetString() != assemblyHash
            || emit[5] != manifest || emit[6] != llvm || assemble[1] != llvm || nativeLink[6] != llvm
            || nativeLink[7] != compilerPath || nativeLink[9] != link.GetProperty("optimization").GetString())
            throw new InvalidOperationException("SELFHOST_PRODUCT_SEPARATED_COMMAND_MISMATCH");

        using var document = JsonDocument.Parse(File.ReadAllBytes(manifest));
        var emissionInputs = document.RootElement;
        var driver = Path.Combine(productionRoot, "tests", "Sollang.ExampleTests", "Fixtures", "selfhost-sollangc-driver.slg");
        var orderedSources = sources.Where(source => source != driver).Prepend(driver);
        var sourcePaths = emissionInputs.GetProperty("sourcePaths").EnumerateArray().Select(path => path.GetString());
        var sourcePins = JsonSerializer.Deserialize<Dictionary<string, string>>(emissionInputs.GetProperty("inputHashes"));
        if (emissionInputs.GetProperty("schemaVersion").GetInt32() != 1
            || emissionInputs.GetProperty("target").GetString() != "windows-x64"
            || emissionInputs.GetProperty("outputKind").GetString() != "executable"
            || !sources.Contains(driver) || !sourcePaths.SequenceEqual(orderedSources)
            || sourcePins is null || sourcePins.Count != sources.Length + stdlib.Length
            || sources.Concat(stdlib).Any(path => !sourcePins.TryGetValue(path, out var hash) || hash != inputs[path]))
            throw new InvalidOperationException("SELFHOST_PRODUCT_SEPARATED_SOURCE_CLOSURE_MISSING");

        var llvmHash = Hash(llvm);
        if (llvmHash != emission.GetProperty("outputSha256").GetString()
            || new FileInfo(llvm).Length != emission.GetProperty("outputBytes").GetInt64())
            throw new InvalidOperationException("SELFHOST_PRODUCT_SEPARATED_LLVM_CHANGED");
        inputs.Add(llvm, llvmHash);
    }

    // Recheck after the runner acquires read-only leases for all these paths.
    internal void AssertStable() => AssertInputs(InputHashes);

    private static void AssertInputs(Dictionary<string, string> inputs)
    {
        foreach (var (path, expected) in inputs)
            if (!Path.IsPathFullyQualified(path) || Hash(path) != expected)
                throw new InvalidOperationException("SELFHOST_PRODUCT_INPUT_CHANGED: " + path);
    }

    private static string Hash(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream));
    }
}
