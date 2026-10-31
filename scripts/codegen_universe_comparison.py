"""Compare complete registered metadata by structural and declared identity."""
from collections import Counter


def native_universe(lines):
    nodes, names, aliases, errors = {}, {}, {}, []
    current = None
    count = None
    groups = {'box': 'Boxes', 'reference': 'References', 'static-array': 'StaticArrays',
              'dynamic-array': 'DynamicArrays', 'dictionary': 'Dictionaries'}
    for line in lines:
        if line.startswith('universe:'):
            count = int(line.split(':')[1])
        elif line.startswith('name:'):
            _, identity, name = line.split(':', 2)
            assert int(identity) not in names
            names[int(identity)] = name
        elif line.startswith('alias:'):
            _, source, target = line.split(':')
            assert int(source) not in aliases
            aliases[int(source)] = int(target)
        elif line.startswith('name-error:'):
            errors.append(int(line.split(':')[1]))
        else:
            assert line.startswith('record:'), line
            raw = line[len('record:'):]
            tag, rest = raw.split(':', 1)
            if tag in ('struct', 'enum', 'dyn'):
                identity, rest = rest.split(':', 1)
                assert int(identity) not in nodes
                group = {'struct': 'Structs', 'enum': 'Enums', 'dyn': 'DynTraits'}[tag]
                row = dict(group=group, Id=int(identity))
                if tag == 'struct':
                    row['Name'], row['ModuleName'] = rest.rsplit(':', 1)
                    row['Fields'] = []
                elif tag == 'enum':
                    row['Name'], row['ModuleName'], words = rest.rsplit(':', 2)
                    row['PayloadWords'] = int(words)
                    row['Variants'] = []
                else:
                    row['TraitName'] = rest
                nodes[row['Id']] = row
                current = row
            elif tag in ('field', 'variant'):
                ordinal, name, member_type = rest.split(':')
                assert current is not None
                if tag == 'field':
                    assert current['group'] == 'Structs'
                    current['Fields'].append(dict(Index=int(ordinal), Name=name, Type=int(member_type)))
                else:
                    assert current['group'] == 'Enums'
                    current['Variants'].append(dict(Tag=int(ordinal), Name=name,
                                                   PayloadType=None if member_type == '-1' else int(member_type)))
            else:
                assert tag in groups, tag
                values = list(map(int, rest.split(':')))
                identity = values.pop(0)
                assert identity not in nodes
                attrs = {'box': ['ElementType', 'Size', 'Alignment'],
                         'reference': ['ElementType'],
                         'static-array': ['ElementType', 'ElementSize', 'ElementAlignment', 'FixedLength'],
                         'dynamic-array': ['ElementType', 'ElementSize', 'ElementAlignment'],
                         'dictionary': ['KeyType', 'ValueType', 'KeySize', 'KeyAlignment', 'ValueOffset',
                                        'ValueSize', 'ValueAlignment', 'EntryStride']}[tag]
                assert len(values) == len(attrs), (tag, values)
                nodes[identity] = dict(group=groups[tag], Id=identity, **dict(zip(attrs, values)))
                current = None
    assert count is not None and count == len(nodes), (count, len(nodes))
    return nodes, names, aliases, errors


def normalized_records(nodes, names, aliases):
    memo, visiting = {}, set()

    def identity(value):
        if value is None or value == -1:
            return ('none',)
        if value in aliases:
            return identity(aliases[value])
        if value in memo:
            return memo[value]
        assert value not in visiting, ('structural-type-cycle', value)
        visiting.add(value)
        row = nodes.get(value)
        if row is None:
            assert value in names, ('missing-type-name', value)
            result = ('leaf', names[value])
        else:
            group = row['group']
            named_struct = group == 'Structs' and not row.get('IsProduct', row.get('Name', '').startswith('('))
            named_enum = group == 'Enums' and not row.get('Name', '').startswith(('Option<', 'Result<'))
            if named_struct or named_enum:
                result = (group, row['ModuleName'], row['Name'])
            elif group == 'Structs':
                result = ('product', tuple((f['Name'], identity(f['Type']))
                                           for f in sorted(row['Fields'], key=lambda f: f['Index'])))
            elif group == 'Enums':
                result = ('enum', tuple((v['Tag'], v['Name'], identity(v['PayloadType']))
                                        for v in sorted(row['Variants'], key=lambda v: v['Tag'])))
            elif group == 'DynTraits':
                result = ('dyn', row['TraitName'])
            elif group == 'Dictionaries':
                result = (group, identity(row['KeyType']), identity(row['ValueType']))
            else:
                result = (group, identity(row['ElementType']))
                if group == 'StaticArrays':
                    result += (row['FixedLength'] if row['FixedLength'] is not None else -1,)
        visiting.remove(value)
        memo[value] = result
        return result

    records = Counter()
    for value, row in nodes.items():
        key, group = identity(value), row['group']
        if group in ('Structs', 'Enums'):
            header = (group, key, row['Name'], row['ModuleName'])
            if group == 'Enums':
                header += (row['PayloadWords'],)
            records[header] += 1
            if group == 'Structs':
                for field in row['Fields']:
                    records[('field', key, field['Index'], field['Name'], identity(field['Type']))] += 1
            else:
                for variant in row['Variants']:
                    records[('variant', key, variant['Tag'], variant['Name'], identity(variant['PayloadType']))] += 1
        elif group == 'DynTraits':
            records[(group, key, row['TraitName'])] += 1
        else:
            attrs = {'Boxes': ['ElementType', 'Size', 'Alignment'], 'References': ['ElementType'],
                     'StaticArrays': ['ElementType', 'ElementSize', 'ElementAlignment', 'FixedLength'],
                     'DynamicArrays': ['ElementType', 'ElementSize', 'ElementAlignment'],
                     'Dictionaries': ['KeyType', 'ValueType', 'KeySize', 'KeyAlignment', 'ValueOffset',
                                      'ValueSize', 'ValueAlignment', 'EntryStride']}[group]
            values = tuple(identity(row[a]) if a in ('ElementType', 'KeyType', 'ValueType')
                           else -1 if row[a] is None else row[a] for a in attrs)
            records[(group, key, *values)] += 1
    return records


def compare_universe(lines, observation):
    native, names, aliases, errors = native_universe(lines)
    managed = {row['Id']: dict(group=group, **row)
               for group, rows in observation['records'].items() for row in rows}
    expected = normalized_records(managed, {int(k): v for k, v in observation['typeNames'].items()}, {})
    actual = normalized_records(native, names, aliases)
    return dict(equal=actual == expected,
                managedCounts=dict(Counter(row['group'] for row in managed.values())),
                nativeCounts=dict(Counter(row['group'] for row in native.values())),
                missing=[dict(record=record, count=count) for record, count in (expected - actual).items()],
                extra=[dict(record=record, count=count) for record, count in (actual - expected).items()],
                unrelatedNameErrors=errors,
                scope='Declared/structural identity and complete metadata records, retaining alias multiplicity; not numeric cache-key equality.')
