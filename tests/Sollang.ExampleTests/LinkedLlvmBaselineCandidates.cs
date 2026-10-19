using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

// A maintenance result proves the existing LLVM/runtime/reference assertions,
// not acceptance against a replacement snapshot. It never edits an oracle.
internal sealed class LinkedLlvmBaselineCandidates
{
    private readonly string output;
    internal string[] InputPaths { get; }
    internal const string Scope = "linked-llvm-baseline-candidates";

    internal LinkedLlvmBaselineCandidates(string planPath, string repoRoot, string output,
        string expectedDirectory, string[] selected, Func<string, bool> reusable,
        Func<string, string> targetMode)
    {
        this.output = Path.Combine(output, "baseline-candidates");
        planPath = RepositoryFile(repoRoot, planPath);
        using var plan = JsonDocument.Parse(File.ReadAllBytes(planPath));
        var root = plan.RootElement;
        if (root.GetProperty("schemaVersion").GetInt32() != 1)
            throw new InvalidOperationException("BASELINE_CANDIDATE_PLAN_INVALID");
        var authorityPath = RepositoryFile(repoRoot, root.GetProperty("frozenSelectionAuthority").GetString()!);
        using var authority = JsonDocument.Parse(File.ReadAllBytes(authorityPath));
        var frozen = authority.RootElement.GetProperty("selectedCatalog").EnumerateArray()
            .Select(item => item.GetString()!).ToHashSet(StringComparer.Ordinal);
        var candidates = root.GetProperty("candidates").EnumerateArray()
            .Select(item => item.GetString()!).ToArray();
        if (frozen.Count != 2708 || candidates.Length == 0
            || candidates.Distinct(StringComparer.Ordinal).Count() != candidates.Length
            || candidates.Any(name => !frozen.Contains(name)) || selected.Length == 0)
            throw new InvalidOperationException("BASELINE_CANDIDATE_SCOPE_INVALID");
        foreach (var file in selected)
        {
            var name = Path.GetFileName(file)[..^".stdout.txt".Length];
            var sourcePath = Path.Combine(repoRoot, "examples", "regression", name + ".slg");
            if (!candidates.Contains(name, StringComparer.Ordinal) || !reusable(file)
                || File.Exists(Path.Combine(expectedDirectory, name + ".root.txt"))
                || !File.Exists(Path.Combine(expectedDirectory, name + ".stdout.llvm.execute.txt"))
                || targetMode(File.ReadAllText(sourcePath)) is not ("windows" or "linux"))
                throw new InvalidOperationException("BASELINE_CANDIDATE_CASE_OUTSIDE_CONTRACT: " + name);
        }
        InputPaths = [planPath, authorityPath];
    }

    internal void Write(string name, string originalExpectedPath, string actual)
    {
        Directory.CreateDirectory(output);
        var path = Path.Combine(output, name + ".stdout.txt");
        if (File.Exists(path)) throw new InvalidOperationException("BASELINE_CANDIDATE_ALREADY_EXISTS");
        File.WriteAllText(path, actual, new UTF8Encoding(false));
        AtomicResultFile.Write(Path.Combine(output, name + ".json"), JsonSerializer.Serialize(new
        {
            id = name, verificationScope = Scope,
            originalExpectedPath, originalExpectedSha256 = Hash(originalExpectedPath),
            candidatePath = path, candidateSha256 = Hash(path),
            llvmAndRuntimeAndManagedReferencePassed = true,
            originalOracleChanged = false, claimsRegressionAcceptance = false
        }, new JsonSerializerOptions { WriteIndented = true }));
    }

    private static string RepositoryFile(string root, string path)
    {
        path = Path.GetFullPath(path, root);
        if (!path.StartsWith(Path.GetFullPath(root) + Path.DirectorySeparatorChar,
                StringComparison.OrdinalIgnoreCase) || !File.Exists(path))
            throw new InvalidOperationException("BASELINE_CANDIDATE_INPUT_BOUNDARY");
        return path;
    }

    private static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
}
