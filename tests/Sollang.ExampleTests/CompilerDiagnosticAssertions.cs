using System;
using System.Text.RegularExpressions;

// An exact successful-build diagnostic contract does not permit additional
// warnings, notes, stdout diagnostics, or missing expected diagnostics.
internal static class CompilerDiagnosticAssertions
{
    internal static bool Verify(string stdout, string stderr, string? expectedExact, out string error)
    {
        const string diagnostic = @"(?m)^(?:warning S|note N)\d+\b";
        if (expectedExact is null)
        {
            error = (Regex.IsMatch(stdout, diagnostic, RegexOptions.CultureInvariant)
                || Regex.IsMatch(stderr, diagnostic, RegexOptions.CultureInvariant))
                ? "unexpected Sollang compiler warning or note" : "";
            return error.Length == 0;
        }
        var expected = expectedExact.Replace("\r\n", "\n", StringComparison.Ordinal);
        if (string.IsNullOrWhiteSpace(expected) || !expected.EndsWith('\n'))
        {
            error = "exact compiler diagnostic contract must be nonempty and newline terminated";
            return false;
        }
        foreach (var line in expected[..^1].Split('\n'))
        {
            if (!Regex.IsMatch(line, diagnostic, RegexOptions.CultureInvariant))
            {
                error = "exact compiler diagnostic contract must contain diagnostic lines only";
                return false;
            }
        }
        if (Regex.IsMatch(stdout, diagnostic, RegexOptions.CultureInvariant)
            || stderr.Replace("\r\n", "\n", StringComparison.Ordinal) != expected)
        {
            error = "compiler diagnostics differ from exact stderr contract";
            return false;
        }
        error = "";
        return true;
    }
}
