using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Diagnostics;

internal static class ImportDiagnostics
{
    public static string AmbiguousSymbol(string name, IReadOnlyList<OpenImportCandidate> candidates)
    {
        var choices = string.Join(", ", candidates.Select(static candidate => $"'{string.Join('.', candidate.Path)}'"));
        var qualified = candidates[0].ModuleAlias + "." + name;
        return $"imported symbol '{name}' is ambiguous between {choices}; use a qualified name such as '{qualified}' or an import alias for the module";
    }
}
