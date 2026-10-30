using System.Text;
using System.Text.RegularExpressions;

internal static class LlvmAssertions
{
    internal static bool IsManagedProducer(string compilerPath) =>
        Path.GetExtension(compilerPath).Equals(".dll", StringComparison.OrdinalIgnoreCase)
        || (File.Exists(Path.ChangeExtension(compilerPath, ".dll"))
            && File.Exists(Path.ChangeExtension(compilerPath, ".runtimeconfig.json")));

    internal static (string Contains, string NotContains, string RegexCounts) SelectPaths(
        string expectedDirectory, string name, string target, bool managedProducer)
    {
        var producer = managedProducer ? "csharp" : "slg";
        string PathFor(string suffix, string? family = null) => Path.Combine(expectedDirectory,
            name + (family is null ? "" : "." + family) + suffix);
        string Select(string suffix, string? family = null)
        {
            var targetPath = PathFor("." + target + suffix, family);
            return target == "linux-x64" && File.Exists(targetPath) ? targetPath : PathFor(suffix, family);
        }
        var producerPaths = (Contains: Select(".llvm.contains.txt", producer),
            NotContains: Select(".llvm.not-contains.txt", producer),
            RegexCounts: Select(".llvm.regex-counts.txt", producer));
        if (!File.Exists(producerPaths.Contains) && !File.Exists(producerPaths.NotContains)
            && !File.Exists(producerPaths.RegexCounts))
            return SelectCommonPaths(expectedDirectory, name, target);
        if (!new[] { producerPaths.Contains, producerPaths.NotContains, producerPaths.RegexCounts }
            .SelectMany(ReadAssertions).Any())
            throw new InvalidDataException("Producer-specific LLVM assertions must not be empty.");
        return producerPaths;
    }

    internal static (string Contains, string NotContains, string RegexCounts) SelectCommonPaths(
        string expectedDirectory, string name, string target)
    {
        string Select(string suffix)
        {
            var targetPath = Path.Combine(expectedDirectory, name + "." + target + suffix);
            return target == "linux-x64" && File.Exists(targetPath)
                ? targetPath : Path.Combine(expectedDirectory, name + suffix);
        }
        return (Select(".llvm.contains.txt"), Select(".llvm.not-contains.txt"),
            Select(".llvm.regex-counts.txt"));
    }

    internal static bool Verify(
        string llvmPath,
        string containsPath,
        string notContainsPath,
        string regexCountsPath,
        out string error)
    {
        if (!File.Exists(llvmPath))
        {
            error = $"LLVM file not found: {llvmPath}";
            return false;
        }

        var llvm = NormalizeLlvmTypeIdentities(File.ReadAllText(llvmPath, Encoding.UTF8));
        foreach (var expected in ReadAssertions(containsPath))
        {
            var normalizedExpected = NormalizeLlvmTypeIdentities(expected);
            if (!llvm.Contains(normalizedExpected, StringComparison.Ordinal))
            {
                error = $"LLVM does not contain '{expected}'";
                return false;
            }
        }

        foreach (var forbidden in ReadAssertions(notContainsPath))
        {
            var normalizedForbidden = NormalizeLlvmTypeIdentities(forbidden);
            if (llvm.Contains(normalizedForbidden, StringComparison.Ordinal))
            {
                error = $"LLVM unexpectedly contains '{forbidden}'";
                return false;
            }
        }

        // This additional contract is shared by both producers, even when a
        // producer-specific legacy contract is selected above.
        var sharedPath = SharedRegexCountsPath(regexCountsPath);
        var sharedAssertions = sharedPath is null ? Array.Empty<string>() : ReadAssertions(sharedPath).ToArray();
        if (sharedPath is not null && File.Exists(sharedPath) && sharedAssertions.Length == 0)
        {
            error = "Shared LLVM regex-count assertions must not be empty.";
            return false;
        }
        foreach (var assertion in ReadAssertions(regexCountsPath).Concat(sharedAssertions))
        {
            var separator = assertion.IndexOf('\t');
            if (separator <= 0
                || !int.TryParse(assertion[..separator], out var expectedCount)
                || expectedCount < 0)
            {
                error = $"invalid LLVM regex-count assertion '{assertion}'; expected '<count><TAB><regex>'";
                return false;
            }
            var pattern = assertion[(separator + 1)..];
            var actualCount = Regex.Matches(
                llvm,
                pattern,
                RegexOptions.CultureInvariant).Count;
            if (actualCount != expectedCount)
            {
                error = $"LLVM regex '{pattern}' matched {actualCount} time(s), expected {expectedCount}";
                return false;
            }
        }

        error = "";
        return true;
    }

    internal static string? SharedRegexCountsPath(string regexCountsPath)
    {
        var name = Path.GetFileName(regexCountsPath);
        var shared = Regex.Replace(name,
            @"(?:\.(?:csharp|slg|selfhost))?(?:\.linux-x64)?\.llvm\.regex-counts\.txt$",
            ".common.llvm.regex-counts.txt", RegexOptions.CultureInvariant);
        return shared == name ? null : Path.Combine(Path.GetDirectoryName(regexCountsPath)!, shared);
    }

    static string NormalizeLlvmTypeIdentities(string value) =>
        Regex.Replace(
            Regex.Replace(
                Regex.Replace(
                    value,
                    @"%sollang\.(struct|enum)\.\d+",
                    "%sollang.$1.#"),
                @"@sollang_drop_\d+",
                "@sollang_drop_#"),
            @"@sollang_fn_[A-Za-z0-9_]+(?=\(|\s|$)",
            static match => Regex.Replace(
                Regex.Replace(match.Value, @"_\d+", "_#"),
                @"(?<=_t)\d+",
                "#"));

    static IEnumerable<string> ReadAssertions(string path)
    {
        return File.Exists(path)
            ? File.ReadLines(path, Encoding.UTF8).Where(line => !string.IsNullOrWhiteSpace(line))
            : [];
    }

}
