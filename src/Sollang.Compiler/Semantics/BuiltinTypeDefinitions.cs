namespace Sollang.Compiler.Semantics;

internal static class BuiltinTypeDefinitions
{
    private static readonly IReadOnlyDictionary<string, TypeId> IdentityNames =
        Enum.GetNames<TypeId>().ToDictionary(name => name, Enum.Parse<TypeId>, StringComparer.Ordinal);
    private static readonly IReadOnlyDictionary<string, TypeId> PredefinedNames =
        ReadTypeBindings(Shared.TypeNamePolicy.PredefinedTypeBindings());
    private static readonly IReadOnlyDictionary<string, TypeId> IntrinsicStructs =
        ReadTypeBindings(Shared.TypeNamePolicy.IntrinsicStructDefinitions());
    private static readonly IReadOnlyDictionary<string, TypeId> IntrinsicEnums =
        ReadTypeBindings(Shared.TypeNamePolicy.IntrinsicEnumDefinitions());

    public static Dictionary<string, TypeId> PredefinedTypeNames() => new(PredefinedNames, StringComparer.Ordinal);

    public static Dictionary<TypeId, TypeId> PredeclaredTasks() =>
        ReadTypeBindings(Shared.TypeNamePolicy.PredeclaredTaskBindings())
            .ToDictionary(pair => IdentityNames[pair.Key], pair => pair.Value);

    public static TypeId? IntrinsicNominal(string name, bool enumeration) =>
        (enumeration ? IntrinsicEnums : IntrinsicStructs).TryGetValue(name, out var type) ? type : null;

    private static IReadOnlyDictionary<string, TypeId> ReadTypeBindings(string schema) =>
        schema.Split('|').Select(row => row.Split(':', 2)).ToDictionary(
            row => row.Length == 2 && row[1].Length > 0 ? row[1]
                : throw new InvalidOperationException("Type binding requires an enum member and a type name."),
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
