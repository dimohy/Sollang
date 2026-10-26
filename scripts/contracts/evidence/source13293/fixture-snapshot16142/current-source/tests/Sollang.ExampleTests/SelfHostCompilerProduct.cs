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
        if (record.GetProperty("status").GetString() != "passed"
            || !record.GetProperty("inputsStable").GetBoolean()
            || !record.GetProperty("managedSeed").GetBoolean()
            // This is the compiler product's optimization, not the fixture's.
            // Reusing a verified O2 compiler must not change program build options.
            || record.GetProperty("optimization").GetString() is not ("O1" or "O2")
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
            || sources.Length != record.GetProperty("compilerSourceCount").GetInt32()
            || stdlib.Length != record.GetProperty("stdlibSourceCount").GetInt32()
            || sources.Concat(stdlib).Append(manifest).Any(path => !start.ContainsKey(path)))
            throw new InvalidOperationException("SELFHOST_PRODUCT_CANONICAL_SOURCE_CLOSURE_MISSING");

        AssertInputs(start);
        var productHash = record.GetProperty("compilerSha256").GetString();
        if (productHash is null || Hash(compilerPath) != productHash)
            throw new InvalidOperationException("SELFHOST_PRODUCT_BINARY_CHANGED");
        start.Add(recordPath, Convert.ToHexString(SHA256.HashData(recordBytes)));
        start.Add(compilerPath, productHash);
        return new SelfHostCompilerProduct(compilerPath, start);
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
