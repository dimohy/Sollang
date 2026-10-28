using System.Security.Cryptography;
using System.Text.Json;

internal static class CommonLlvmVerification
{
    internal static int Run(string repository, string input, string fixture, string target, string result)
    {
        if (fixture != Path.GetFileName(fixture) || fixture.IndexOfAny(['/', '\\']) >= 0
            || string.IsNullOrWhiteSpace(fixture) || target is not ("windows-x64" or "linux-x64"))
            throw new ArgumentException("A fixture name and supported target are required.");
        result = Path.GetFullPath(result);
        if (File.Exists(result)) throw new IOException("A new result path is required.");
        input = Path.GetFullPath(input);
        var expected = Path.Combine(repository, "examples", "regression", "expected");
        var paths = LlvmAssertions.SelectCommonPaths(expected, fixture, target);
        var assertions = new[] { paths.Contains, paths.NotContains, paths.RegexCounts };
        if (!assertions.Any(path => File.Exists(path) && !string.IsNullOrWhiteSpace(File.ReadAllText(path))))
            throw new InvalidDataException("The common LLVM assertion contract must not be empty.");
        var inputs = new[] { input, typeof(CommonLlvmVerification).Assembly.Location,
                Path.Combine(repository, "tests", "Sollang.ExampleTests", "LlvmAssertions.cs") }
            .Concat(assertions.Where(File.Exists)).Distinct().ToArray();
        static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
        var assertionStates = assertions.ToDictionary(path => path,
            path => File.Exists(path) ? Hash(path) : null);
        var before = inputs.ToDictionary(path => path, Hash);
        var accepted = LlvmAssertions.Verify(input, paths.Contains, paths.NotContains, paths.RegexCounts, out var error);
        var after = inputs.ToDictionary(path => path, Hash);
        var stable = before.All(pair => after[pair.Key] == pair.Value)
            && assertionStates.All(pair => (File.Exists(pair.Key) ? Hash(pair.Key) : null) == pair.Value)
            && LlvmAssertions.SelectCommonPaths(expected, fixture, target) == paths;
        AtomicResultFile.Write(result, JsonSerializer.Serialize(new
        {
            schemaVersion = 1, status = accepted && stable ? "passed" : "failed",
            fixture, target, criterion = "common-original-llvm", completed = accepted && stable ? 1 : 0,
            total = 1, inputsStable = stable, inputHashes = before, inputHashesEnd = after,
            assertions, assertionStates,
            failure = !stable ? "COMMON_LLVM_INPUT_CHANGED" : accepted ? null : error,
            claimsCompilerParityComplete = false
        }, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"[common LLVM] {fixture}: {(accepted && stable ? "PASS" : "FAIL")} {error}");
        return accepted && stable ? 0 : 1;
    }
}
