namespace Sollang.Compiler.Semantics;

internal static class SemanticTypeDisplayNames
{
    private static readonly IReadOnlyDictionary<string, string> BuiltinOverrides =
        Shared.TypeNamePolicy.BuiltinDisplayOverrides().Split('|')
            .Select(entry => entry.Split('=', 2))
            .ToDictionary(entry => entry[0], entry => entry[1], StringComparer.Ordinal);

    public static string Builtin(TypeId type)
    {
        var name = type.ToString();
        return BuiltinOverrides.TryGetValue(name, out var display) ? display : name;
    }
}
