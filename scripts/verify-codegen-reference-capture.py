"""Verify reference cache records captured from an actual semantic arena."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from collections import Counter

from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def verify_nominal(lines, records, builtin_ids):
    definitions = [r for group in ('Structs', 'Enums') for r in records[group]
                   if r['ModuleName'] == 'cache.nominal']
    definitions += [r for r in records['DynTraits']
                    if r['TraitName'].startswith('cache.nominal.')]
    raw = [line for line in lines if not line.startswith(('definition:', 'resolved:'))]
    verify_resolved_definitions(raw, definitions, builtin_ids)
    affine = {r['Name']: r for r in definitions if r.get('NativeHandle') or r.get('ComInterface')}
    expected = {}
    resolved = {}
    for line in lines:
        if line.startswith('struct:'):
            _, identity, name, _ = line.split(':')
            if name in affine:
                expected[int(identity)] = name
        elif line.startswith('resolved:'):
            _, identity, name = line.split(':')
            assert int(identity) not in resolved
            resolved[int(identity)] = name
    assert len(expected) == len(affine) and resolved == expected


def synthetic_definitions(records, builtin, pair):
    definitions = []
    for labels, types in [(['head', 'tail'], [builtin['Int64'], builtin['Float32']]),
                          (['_0', '_1'], [builtin['Int'], builtin['Bool']])]:
        rows = [r for r in records['Structs'] if r['IsProduct']
                and [f['Name'] for f in r['Fields']] == labels
                and [f['Type'] for f in r['Fields']] == types]
        assert len(rows) == 1
        definitions += rows
    for payloads in ([None, pair], [pair, builtin['Bool']]):
        rows = [r for r in records['Enums'] if r['ModuleName'] == ''
                and [v['PayloadType'] for v in r['Variants']] == payloads]
        assert len(rows) == 1
        definitions += rows
    return definitions


def verify_synthetic(lines, records, builtin, pair):
    verify_resolved_definitions(lines, synthetic_definitions(records, builtin, pair), builtin, {'Pair': pair})


def verify_resolved_definitions(lines, definitions, builtin, declared=None, expected_layouts=None):
    expected = {r.get('Name', r.get('TraitName')): r for r in definitions}
    identities = {-1: -1}
    observed = {}
    layouts = {}
    current = None
    for line in lines:
        if line.startswith('layout:'):
            _, name, size, alignment = line.split(':')
            assert name not in layouts
            layouts[name] = (int(size), int(alignment))
        elif line.startswith('builtin:'):
            _, name, identity = line.split(':')
            identities[int(identity)] = builtin[name]
        elif line.startswith('declared:'):
            _, name, identity = line.split(':')
            identities[int(identity)] = declared[name]
        elif line.startswith(('struct:', 'enum:', 'dyn:')):
            kind, identity, rest = line.split(':', 2)
            parts = [rest] if kind == 'dyn' else rest.rsplit(':', 1 if kind == 'struct' else 2)
            name = parts[0]
            assert name in expected and name not in observed
            identities[int(identity)] = expected[name]['Id']
            observed[name] = [[kind, identity, *parts]]
            current = observed[name]
        elif line == 'end-definition':
            assert current is not None
            current = None
        else:
            assert current is not None
            current.append(line.split(':'))
    assert current is None and set(observed) == set(expected)
    assert layouts == (expected_layouts or {}), (layouts, expected_layouts)
    for name, rows in observed.items():
        reference = expected[name]
        for row in rows:
            coordinate = 1 if row[0] in ('struct', 'enum', 'dyn') else 3
            row[coordinate] = str(identities[int(row[coordinate])])
        if rows[0][0] == 'struct':
            target = [['struct', reference['Id'], name, reference['ModuleName']]]
            target += [['field', f['Index'], f['Name'], f['Type']] for f in reference['Fields']]
        elif rows[0][0] == 'enum':
            target = [['enum', reference['Id'], name, reference['ModuleName'], reference['PayloadWords']]]
            target += [['variant', v['Tag'], v['Name'], v['PayloadType'] if v['PayloadType'] is not None else -1]
                       for v in reference['Variants']]
        else:
            target = [['dyn', reference['Id'], reference['TraitName']]]
        assert rows == [[str(p) for p in row] for row in target], (name, rows, target)


def verify_catalog(lines, records, builtin):
    declared = [r for r in records['Structs'] if r['ModuleName'] == 'cache.catalog']
    assert len(declared) == 1
    pair = declared[0]['Id']
    ranges = [r for r in records['Structs'] if r['Id'] == builtin['Range']]
    dynamic = [r for r in records['DynTraits'] if r['TraitName'].startswith('cache.catalog.')]
    assert len(ranges) == len(dynamic) == 1
    enumerations = [r for r in records['Enums'] if r['ModuleName'] == 'cache.catalog']
    definitions = [*declared, *enumerations, *ranges, *dynamic, *synthetic_definitions(records, builtin, pair)]
    by_name = {r.get('Name', r.get('TraitName')): r for r in definitions}
    identities = {}
    meta = []
    storage = []
    current = False
    range_names = []
    for line in lines:
        if line.startswith('builtin:'):
            _, name, identity = line.split(':')
            identities[int(identity)] = builtin[name]
            meta.append(line)
            continue
        if line.startswith('range-name:'):
            range_names.append(line[len('range-name:'):])
            continue
        assert line.startswith('record:')
        raw = line[len('record:'):]
        parts = raw.split(':')
        if parts[0] in ('struct', 'enum', 'dyn'):
            if current:
                meta.append('end-definition')
            kind, identity, rest = raw.split(':', 2)
            name = rest if kind == 'dyn' else rest.rsplit(':', 1 if kind == 'struct' else 2)[0]
            identities[int(identity)] = by_name[name]['Id']
            meta.append(raw)
            current = True
        elif parts[0] in ('field', 'variant'):
            assert current
            meta.append(raw)
        else:
            if current:
                meta.append('end-definition')
                current = False
            storage.append(parts)
    if current:
        meta.append('end-definition')
    assert range_names == [ranges[0]['Name']]
    verify_resolved_definitions(meta, definitions, builtin)
    elements = {pair, *(r['Id'] for r in enumerations), builtin['Text'], builtin['Int'], builtin['Bool']}
    expected = []
    for group, prefix, attributes in [
        ('Boxes', 'box', ['ElementType', 'Size', 'Alignment']),
        ('References', 'reference', ['ElementType']),
        ('StaticArrays', 'static-array', ['ElementType', 'ElementSize', 'ElementAlignment', 'FixedLength']),
        ('DynamicArrays', 'dynamic-array', ['ElementType', 'ElementSize', 'ElementAlignment']),
        ('Dictionaries', 'dictionary', ['KeyType', 'ValueType', 'KeySize', 'KeyAlignment', 'ValueOffset', 'ValueSize', 'ValueAlignment', 'EntryStride'])]:
        rows = records[group]
        if group == 'Boxes': rows = [r for r in rows if r['ElementType'] in elements]
        elif group == 'References': rows = [r for r in rows if r['ElementType'] == pair]
        elif group == 'StaticArrays': rows = [r for r in rows if r['ElementType'] == builtin['Int'] and r['FixedLength'] == 3]
        elif group == 'DynamicArrays': rows = [r for r in rows if r['ElementType'] == pair]
        else: rows = [r for r in rows if r['KeyType'] == builtin['Int'] and r['ValueType'] == builtin['Bool']]
        if group == 'DynamicArrays':
            assert len(rows) <= 1
        else:
            assert len(rows) == (5 + len(enumerations) if group == 'Boxes' else 1), (group, len(rows))
        expected += [(prefix, *(r[a] for a in attributes)) for r in rows]
    observed = []
    observed_ids = set()
    for row in storage:
        prefix, identity, *values = row
        assert int(identity) not in observed_ids
        observed_ids.add(int(identity))
        values = list(map(int, values))
        values[0] = identities[values[0]]
        if prefix == 'dictionary': values[1] = identities[values[1]]
        observed.append((prefix, *values))
    assert Counter(observed) == Counter(expected), (observed, expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-result', type=Path, required=True)
    parser.add_argument('--fixture-directory', type=Path)
    parser.add_argument('--probe', choices=['reference', 'storage', 'nominal', 'synthetic', 'finaltypes', 'registration', 'boxes', 'catalog'], default='reference')
    parser.add_argument('--emitter', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    probe = ROOT / {'reference': 'scripts/probes/codegen-registered-types',
                    'storage': 'scripts/probes/codegen-storage-capture',
                    'nominal': 'scripts/probes/codegen-nominal-capture',
                    'synthetic': 'scripts/probes/codegen-synthetic-capture',
                    'finaltypes': 'scripts/probes/codegen-final-type-capture',
                    'registration': 'scripts/probes/codegen-registration-capture',
                    'boxes': 'scripts/probes/codegen-box-registration',
                    'catalog': 'scripts/probes/codegen-registered-universe'}[args.probe]
    fixtures = sorted((args.fixture_directory or probe).glob('*.slg'))
    assert fixtures and (args.probe == 'nominal' or len(fixtures) == 1)
    manifest = probe / 'sources.txt'
    sources = [ROOT / s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
    reference = json.loads(args.reference_result.read_text(encoding='utf-8'))
    assert reference['status'] == 'passed' and reference['completed'] == reference['total'] == 1
    assert reference['inputsStable'] and reference['processesStopped']
    for fixture in fixtures:
        assert reference['inputHashes'][str(fixture.resolve())] == sha(fixture)
    records = reference['cases'][0]['observation']['records']
    declaration = {'reference': 'cache.registered', 'storage': 'cache.storage',
                   'nominal': 'cache.nominal', 'synthetic': 'cache.synthetic', 'finaltypes': 'cache.finaltypes', 'registration': 'cache.registration', 'boxes': 'cache.boxregistration', 'catalog': 'cache.catalog'}[args.probe] + ('.Used' if args.probe in ('registration', 'boxes') else '.Wide' if args.probe == 'finaltypes' else '.Pair')
    pair = [r['Id'] for r in records['Structs'] if r['Name'] == declaration]
    assert len(pair) == 1
    assert len([r for r in records['References'] if r['ElementType'] == pair[0]]) == 1
    paths = [Path(__file__), compiler, *managed_runtime_inputs(compiler), args.reference_result,
             *fixtures, manifest, *sources, *sorted((ROOT / 'stdlib').rglob('*.slg'))]
    if args.emitter:
        producer_path = args.emitter.parent / 'result.json'
        producer = json.loads(producer_path.read_text(encoding='utf-8'))
        assert producer['status'] == 'passed' and producer['inputsStable'] and producer['processesStopped']
        assert all(sha(p) == digest for p, digest in producer['inputHashes'].items())
        paths += [args.emitter, producer_path, *map(Path, producer['inputHashes'])]
    inputs = {str(p.resolve()): sha(p) for p in paths}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    with VerificationContractLease(list(map(Path, inputs))):
        result = dict(schemaVersion=1, status='running', completed=0, total=2 if args.emitter else 1,
                      cases=[], inputHashes=inputs, claimsGoalComplete=False,
                      scope=f'Actual semantic {args.probe} records bound to Pair declaration; '
                            'compare CSharp registered contract and both executions. Canonical registration selection pending.')
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in inputs.items()), sha)
        error = None

        def run(command, label, timeout=180):
            done = execution.run(list(map(str, command)), output / label, timeout=timeout)
            assert done.returncode == 0 and not done.stderr, (label, done.stdout[-2000:], done.stderr)
            return done

        try:
            expected = None
            for backend in (['managed', 'slg'] if args.emitter else ['managed']):
                executable = output / (backend + '.exe')
                if backend == 'managed':
                    run([compiler, 'build', *sources, '-o', executable, '--target', 'windows-x64',
                         '--llvm', ROOT / '.tools/llvm-22.1.8', '--jobs', 24, '-O2'], 'managed-build')
                else:
                    done = run([args.emitter, 'plain-windows', ROOT / 'stdlib', output / 'unused.semantic',
                                output / 'unused-stage.semantic', *sources], 'emit')
                    llvm = output / 'program.ll'
                    llvm.write_text(done.stdout, encoding='utf-8', newline='\n')
                    run([ROOT / '.tools/llvm-22.1.8/bin/llvm-as.exe', llvm, '-o', output / 'program.bc'], 'assemble')
                    run([ROOT / '.tools/llvm-22.1.8/bin/clang.exe', llvm, '-O0', '-Wno-override-module',
                         '-o', executable, '-lkernel32', '-lshell32', '-lws2_32', '-lbcrypt'], 'link')
                done = run([executable, *fixtures], backend + '-run', 20)
                lines = done.stdout.splitlines()
                if args.probe == 'reference':
                    assert len(lines) == 2 and re.fullmatch(r'reference:\d+:\d+', lines[0])
                    assert lines[0] == lines[1], lines
                elif args.probe == 'nominal':
                    verify_nominal(lines, records, reference['cases'][0]['observation']['builtinTypeIds'])
                elif args.probe == 'catalog':
                    verify_catalog(lines, records, reference['cases'][0]['observation']['builtinTypeIds'])
                elif args.probe == 'boxes':
                    builtin = reference['cases'][0]['observation']['builtinTypeIds']
                    named = {r['Name']: r['Id'] for group in ('Structs', 'Enums')
                             for r in records[group] if r['ModuleName'] == 'cache.boxregistration'}
                    assert len(named) == 4
                    identities = {}
                    observed = []
                    box_ids = set()
                    for line in lines:
                        if line.startswith('builtin:'):
                            _, name, identity = line.split(':')
                            identities[int(identity)] = builtin[name]
                        elif line.startswith('declared:'):
                            _, name, identity = line.split(':')
                            identities[int(identity)] = named[name]
                        else:
                            kind, identity, element, size, alignment = line.split(':')
                            assert kind == 'box' and int(identity) not in box_ids
                            box_ids.add(int(identity))
                            observed.append((identities[int(element)], int(size), int(alignment)))
                    elements = {*named.values(), builtin['Text'], builtin['Int'], builtin['Bool']}
                    expected_boxes = [(r['ElementType'], r['Size'], r['Alignment'])
                                      for r in records['Boxes'] if r['ElementType'] in elements]
                    assert len(observed) == len(expected_boxes) == 8
                    assert Counter(observed) == Counter(expected_boxes), (observed, expected_boxes)
                elif args.probe in ('finaltypes', 'registration'):
                    builtin = reference['cases'][0]['observation']['builtinTypeIds']
                    namespace = 'cache.finaltypes' if args.probe == 'finaltypes' else 'cache.registration'
                    declared = [r for group in ('Structs', 'Enums') for r in records[group]
                                if r['ModuleName'] == namespace]
                    assert len(declared) == 4
                    optional = []
                    if args.probe == 'finaltypes':
                        outer = next(r for r in declared if r['Name'] == namespace + '.Outer')
                        optional = [r for r in records['Enums']
                                    if [v['PayloadType'] for v in r['Variants']] == [None, outer['Id']]]
                        assert len(optional) == 1
                    dynamic = [r for r in records['DynTraits'] if r['TraitName'].endswith(namespace + '.Value')]
                    assert len(dynamic) == 1
                    layouts = {}
                    for definition in declared:
                        boxes = [r for r in records['Boxes'] if r['ElementType'] == definition['Id']]
                        assert len(boxes) == 1
                        layouts[definition['Name']] = (boxes[0]['Size'], boxes[0]['Alignment'])
                    verify_resolved_definitions(lines, [*declared, *optional, *dynamic], builtin, expected_layouts=layouts)
                elif args.probe == 'synthetic':
                    verify_synthetic(lines, records, reference['cases'][0]['observation']['builtinTypeIds'], pair[0])
                else:
                    assert len(lines) == 8, lines
                    observed = {}
                    elements = []
                    for header, field in zip(lines[::2], lines[1::2]):
                        identity, kind, first, second, length = map(int, header.split(':'))
                        parts = field.split(':')
                        assert int(parts[1]) == identity
                        assert kind not in observed
                        if kind in (6, 3, 4):
                            assert int(parts[2]) == first
                            elements.append(first)
                            observed[kind] = tuple(map(int, parts[3:]))
                            assert parts[0] == {6: 'box', 3: 'dynamic-array', 4: 'static-array'}[kind]
                            if kind == 4:
                                assert int(parts[-1]) == length
                        else:
                            assert kind == 5 and parts[0] == 'dictionary'
                            assert tuple(map(int, parts[2:4])) == (first, second)
                            elements.append(second)
                            observed[kind] = tuple(map(int, parts[4:]))
                    assert len(set(elements)) == 1
                    expected_layouts = {}
                    for category, kind, attributes in [
                        ('Boxes', 6, ['Size', 'Alignment']),
                        ('StaticArrays', 4, ['ElementSize', 'ElementAlignment', 'FixedLength']),
                        ('DynamicArrays', 3, ['ElementSize', 'ElementAlignment']),
                        ('Dictionaries', 5, ['KeySize', 'KeyAlignment', 'ValueOffset', 'ValueSize', 'ValueAlignment', 'EntryStride'])]:
                        rows = [row for row in records[category]
                                if row.get('ElementType', row.get('ValueType')) == pair[0]]
                        assert len(rows) == 1, (category, rows)
                        expected_layouts[kind] = tuple(rows[0][a] for a in attributes)
                    assert observed == expected_layouts, (observed, expected_layouts)
                if expected is None:
                    expected = done.stdout
                else:
                    assert done.stdout == expected
                result['cases'].append(dict(id=backend, passed=True, stdout=done.stdout,
                                            declaration=declaration))
                result['completed'] += 1
            result['status'] = 'passed'
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
