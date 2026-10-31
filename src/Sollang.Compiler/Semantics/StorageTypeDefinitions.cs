namespace Sollang.Compiler.Semantics;

internal static class StorageTypeDefinitions
{
    public static Dictionary<TypeId, (TypeId ElementType, int Length)> FixedArrays(
        IReadOnlyDictionary<string, TypeId> names) =>
        Shared.TypeNamePolicy.PredeclaredFixedArrays().Split('|')
            .Select(row => row.Split(':'))
            .ToDictionary(row => Enum.Parse<TypeId>(row[0]),
                row => (names[row[1]], int.Parse(row[2], System.Globalization.CultureInfo.InvariantCulture)));

    public static Dictionary<TypeId, TypeId> DynamicArrays(IReadOnlyDictionary<string, TypeId> names) =>
        Shared.TypeNamePolicy.PredeclaredDynamicArrays().Split('|')
            .Select(row => row.Split(':', 2))
            .ToDictionary(row => Enum.Parse<TypeId>(row[0]), row => names[row[1]]);
}
