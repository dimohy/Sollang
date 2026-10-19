using System.Text.RegularExpressions;

// An explicit canonical root can select the existing reusable driver only for
// a plain raw-source emitter wrapper. Additional executable behavior stays on
// the ordinary build/run path.
internal static class RawLlvmFixture
{
    internal static bool SupportsCanonicalProviderEmission(string source)
    {
        var raw = Regex.Matches(source, "\"\"\"\\r?\\n.*?\\r?\\n[ \\t]*\"\"\"", RegexOptions.Singleline);
        if (raw.Count == 0) return false;
        var shape = Regex.Replace(source, "\"\"\"\\r?\\n.*?\\r?\\n[ \\t]*\"\"\"", "SOURCE", RegexOptions.Singleline);
        shape = Regex.Replace(shape, @"(?m)^\s*#[^\r\n]*", "");
        return Regex.IsMatch(shape,
            @"\A\s*import\s+sollang\.compiler\.llvm\.text\s+as\s+(?<alias>[A-Za-z_][A-Za-z0-9_]*)\s+" +
            @"main\s*\{\s*\[\s*SOURCE(?:\s*,?\s*SOURCE)*\s*;\s*~\s*\]\s*=>\s*" +
            @"(?<binding>[A-Za-z_][A-Za-z0-9_]*)(?<mutable>!?)\s+\k<binding>\k<mutable>\s*->\s*" +
            @"\k<alias>\.emit(?:Linux|Wasm)?\s*\}\s*\z", RegexOptions.CultureInvariant);
    }
}
