using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private void DeclareTraitImplementations()
    {
        foreach (var declaration in _program.Implementations ?? [])
        {
            _currentModuleName = declaration.ModuleName;
            if (declaration.TraitName is null)
            {
                if (declaration.AssociatedTypes.Count > 0)
                    throw Error(declaration.Line, declaration.Column, "associated type bindings require a trait impl");
                continue;
            }
            if (!_traits.TryGetValue(declaration.TraitName, out var trait))
                throw Error(declaration.Line, declaration.Column, $"unknown trait '{declaration.TraitName}'");
            EnsureTraitVisible(trait, declaration.Line, declaration.Column);
            var receiver = ParseType(declaration.OwnerType, declaration.Line, declaration.Column);
            if (!_types.IsStruct(receiver) && !_types.IsEnum(receiver))
                throw Error(declaration.Line, declaration.Column, "trait methods require a user type self receiver");
            var associated = declaration.AssociatedTypes.ToDictionary(
                static pair => pair.Key,
                pair => ParseType(pair.Value, declaration.Line, declaration.Column),
                StringComparer.Ordinal);
            var unknown = associated.Keys.FirstOrDefault(name => !trait.AssociatedTypes.Any(type => type.Name == name));
            if (unknown is not null)
                throw Error(declaration.Line, declaration.Column, $"trait '{trait.Name}' has no associated type '{unknown}'");
            var missing = trait.AssociatedTypes.FirstOrDefault(type => !associated.ContainsKey(type.Name));
            if (missing is not null)
                throw Error(declaration.Line, declaration.Column, $"impl {trait.Name} requires associated type '{missing.Name}'");
            var key = (trait.Name, receiver);
            if (_traitImplementations.TryGetValue(key, out var previous))
            {
                if (previous.ImplAssociatedTypes.Count != associated.Count
                    || previous.ImplAssociatedTypes.Any(pair => !associated.TryGetValue(pair.Key, out var value) || value != pair.Value))
                    throw Error(declaration.Line, declaration.Column, $"impl {trait.Name} has conflicting associated type bindings");
                continue;
            }
            _traitImplementations.Add(key, new BoundTraitImplementation(
                trait.Name, receiver, associated, declaration.ModuleName, declaration.Line, declaration.Column));
        }
    }
}
