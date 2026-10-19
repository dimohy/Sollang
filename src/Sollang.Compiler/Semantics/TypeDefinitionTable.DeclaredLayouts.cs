namespace Sollang.Compiler.Semantics;

internal sealed partial class TypeDefinitionTable
{
    public void RegisterDeclaredLayouts(
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int Length)> fixedArrays,
        IReadOnlyDictionary<TypeId, TypeId> dynamicArrays,
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int Capacity)> boundedArrays,
        IReadOnlyDictionary<TypeId, (TypeId KeyType, TypeId ValueType, int MaxEntries)> boundedDictionaries,
        IReadOnlyDictionary<TypeId, int> bitSets,
        IReadOnlyDictionary<TypeId, (TypeId KeyType, TypeId ValueType)> dictionaries)
    {
        // Reserve the complete declared identity range before a bounded
        // dictionary registers its associated heap dictionary type.
        var maximumDeclaredId = fixedArrays.Keys.Concat(dynamicArrays.Keys)
            .Concat(boundedArrays.Keys).Concat(boundedDictionaries.Keys).Concat(bitSets.Keys).Concat(dictionaries.Keys)
            .Select(static id => (int)id).DefaultIfEmpty(_nextParametricTypeId - 1).Max();
        _nextParametricTypeId = Math.Max(_nextParametricTypeId, checked(maximumDeclaredId + 1));
        RegisterBitSets(bitSets);

        // Handles have an identity and a descriptor layout independently of
        // their element layout. Publish those identities before walking values;
        // finish their element metadata only after all value dependencies.
        RegisterStaticArrayIdentities(fixedArrays.ToDictionary(
            static pair => pair.Key,
            static pair => (pair.Value.ElementType, (int?)pair.Value.Length)), deferElementLayout: true);
        RegisterDynamicArrayIdentities(dynamicArrays, deferElementLayout: true);
        foreach (var (id, shape) in dictionaries)
        {
            // Publish the heap descriptor identity before following value
            // layouts. Entry geometry is completed after those dependencies.
            _dictionaries.Add(id, new BoundDictionaryDefinition(
                id, shape.KeyType, shape.ValueType, 0, 1, 0, 0, 1, 0));
            _dictionariesByTypes.Add(shape, id);
        }

        var states = new Dictionary<TypeId, byte>();
        foreach (var id in _structs.Keys.Concat(_enums.Keys)
                     .Concat(boundedArrays.Keys).Concat(boundedDictionaries.Keys).ToArray())
            Visit(id);

        foreach (var id in dictionaries.Keys)
            CompleteDictionary(id);

        foreach (var (id, definition) in _staticArrays.ToArray())
            _staticArrays[id] = definition with
            {
                ElementSize = InlineSizeOf(definition.ElementType),
                ElementAlignment = AlignmentOf(definition.ElementType)
            };
        foreach (var (id, definition) in _dynamicArrays.ToArray())
            _dynamicArrays[id] = definition with
            {
                ElementSize = InlineSizeOf(definition.ElementType),
                ElementAlignment = AlignmentOf(definition.ElementType)
            };
        FinalizeDeclaredBoxLayouts();
        RecordTypeGraphMutation();

        void CompleteDictionary(TypeId id)
        {
            var dictionary = _dictionaries[id];
            var layout = DictionaryEntryLayout(dictionary.KeyType, dictionary.ValueType);
            _dictionaries[id] = dictionary with
            {
                KeySize = layout.KeySize,
                KeyAlignment = layout.KeyAlignment,
                ValueOffset = layout.ValueOffset,
                ValueSize = layout.ValueSize,
                ValueAlignment = layout.ValueAlignment,
                EntryStride = layout.EntryStride
            };
        }

        void Visit(TypeId id)
        {
            if (states.TryGetValue(id, out var state))
            {
                if (state == 1)
                    throw new InvalidOperationException($"declared value layout cycle at type '{(int)id}'");
                return;
            }
            states[id] = 1;
            if (_structs.TryGetValue(id, out var structure))
            {
                foreach (var field in structure.Fields)
                    Visit(field.Type);
            }
            else if (_enums.TryGetValue(id, out var enumeration))
            {
                foreach (var variant in enumeration.Variants)
                    if (variant.PayloadType is { } payloadType)
                        Visit(payloadType);
                var payloadBytes = enumeration.Variants
                    .Where(static variant => variant.PayloadType is not null)
                    .Select(variant => InlineSizeOf(variant.PayloadType!.Value))
                    .DefaultIfEmpty(0).Max();
                _enums[id] = enumeration with { PayloadWords = checked(payloadBytes + 7) / 8 };
            }
            else if (boundedArrays.TryGetValue(id, out var array))
            {
                Visit(array.ElementType);
                RegisterBoundedArrays(new Dictionary<TypeId, (TypeId ElementType, int Capacity)>
                {
                    [id] = array
                });
            }
            else if (boundedDictionaries.TryGetValue(id, out var dictionary))
            {
                Visit(dictionary.KeyType);
                Visit(dictionary.ValueType);
                if (_dictionariesByTypes.TryGetValue((dictionary.KeyType, dictionary.ValueType), out var heap)
                    && dictionaries.ContainsKey(heap))
                    CompleteDictionary(heap);
                RegisterBoundedDictionaries(new Dictionary<TypeId, (TypeId KeyType, TypeId ValueType, int MaxEntries)>
                {
                    [id] = dictionary
                });
            }
            // Box/reference and array handles terminate by-value dependency
            // edges. Their element metadata is finalized after this walk.
            states[id] = 2;
        }
    }
}
