namespace Sollang.Compiler.Semantics;

internal static class SemanticTypeRegistrationNames
{
    private static readonly HashSet<string> PrimitiveBoxes =
        Shared.TypeNamePolicy.PrimitiveBoxNames().Split('|').ToHashSet(StringComparer.Ordinal);
    private static readonly HashSet<string> ExcludedStructures =
        Shared.TypeNamePolicy.BoxExcludedStructNames().Split('|').ToHashSet(StringComparer.Ordinal);
    private static readonly HashSet<string> ExcludedNominals =
        Shared.TypeNamePolicy.BoxExcludedNominalNames().Split('|').ToHashSet(StringComparer.Ordinal);

    public static bool BoxName(string name, bool structure, bool enumeration, string declarationName) =>
        Shared.TypeNamePolicy.CanRegisterBoxName(PrimitiveBoxes.Contains(name), structure, enumeration,
            ExcludedStructures.Contains(declarationName), ExcludedNominals.Contains(declarationName));
}
