namespace Sollang.Compiler.Semantics;

internal static class BuiltinTypeDefinitions
{
    private static readonly IReadOnlyDictionary<string, TypeId> IdentityNames =
        Enum.GetNames<TypeId>().ToDictionary(name => name, Enum.Parse<TypeId>, StringComparer.Ordinal);
    private static readonly IReadOnlyDictionary<string, TypeId> IntrinsicStructs =
        ReadIntrinsicDefinitions(Shared.TypeNamePolicy.IntrinsicStructDefinitions());
    private static readonly IReadOnlyDictionary<string, TypeId> IntrinsicEnums =
        ReadIntrinsicDefinitions(Shared.TypeNamePolicy.IntrinsicEnumDefinitions());

    public static TypeId? IntrinsicNominal(string name, bool enumeration) =>
        (enumeration ? IntrinsicEnums : IntrinsicStructs).TryGetValue(name, out var type) ? type : null;

    private static IReadOnlyDictionary<string, TypeId> ReadIntrinsicDefinitions(string schema) =>
        schema.Split('|').Select(row => row.Split(':', 2)).ToDictionary(
            row => row.Length == 2 && row[1].Length > 0 ? row[1]
                : throw new InvalidOperationException("Intrinsic nominal definition requires an enum member and a declaration name."),
            row => IdentityNames[row[0]], StringComparer.Ordinal);

    public static BoundStructDefinition Range()
    {
        var parts = Shared.TypeNamePolicy.RangeDefinition().Split('|');
        var fields = parts.Skip(1).Select((field, index) =>
        {
            var pair = field.Split(':', 2);
            return new BoundStructField(pair[0], Enum.Parse<TypeId>(pair[1]), index, 0, 0);
        }).ToArray();
        return new BoundStructDefinition(TypeId.Range, parts[0], fields, 0, 0, IsPublic: true);
    }
}
