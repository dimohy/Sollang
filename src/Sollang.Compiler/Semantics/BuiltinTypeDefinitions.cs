namespace Sollang.Compiler.Semantics;

internal static class BuiltinTypeDefinitions
{
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
