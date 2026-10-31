"""Verify reference cache records captured from an actual semantic arena."""
from pathlib import Path
import argparse
import hashlib
import json
import re

from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def verify_nominal(lines, records, builtin_ids):
    prefix = 'cache.nominal.'
    native_ids = {}
    blocks = {}
    current = None
    for line in lines:
        if line.startswith('builtin:'):
            _, name, identity = line.split(':')
            native_ids[int(identity)] = builtin_ids[name]
        elif line.startswith('definition:'):
            _, name, identity = line.split(':')
            assert name not in blocks
            if name == 'Value':
                rows = [r for r in records['DynTraits'] if r['TraitName'].endswith(prefix + name)]
            else:
                rows = [r for r in records['Structs' if name == 'Pair' else 'Enums']
                        if r['Name'] == prefix + name]
            assert len(rows) == 1
            native_ids[int(identity)] = rows[0]['Id']
            blocks[name] = dict(reference=rows[0], observed=[])
            current = blocks[name]['observed']
        elif line == 'end-definition':
            assert current is not None
            current = None
        else:
            assert current is not None
            current.append(line.split(':'))
    assert set(blocks) == {'Pair', 'Choice', 'Value'} and current is None
    native_ids[-1] = -1
    for name, block in blocks.items():
        reference, observed = block['reference'], block['observed']
        for row in observed:
            coordinate = 1 if row[0] in ('struct', 'enum', 'dyn') else 3
            row[coordinate] = str(native_ids[int(row[coordinate])])
        if name == 'Pair':
            expected = [['struct', reference['Id'], reference['Name'], reference['ModuleName']]]
            expected += [['field', f['Index'], f['Name'], f['Type']]
                         for f in sorted(reference['Fields'], key=lambda f: f['Index'])]
        elif name == 'Choice':
            expected = [['enum', reference['Id'], reference['Name'], reference['ModuleName'], reference['PayloadWords']]]
            expected += [['variant', v['Tag'], v['Name'], v['PayloadType'] if v['PayloadType'] is not None else -1]
                         for v in sorted(reference['Variants'], key=lambda v: v['Tag'])]
        else:
            expected = [['dyn', reference['Id'], reference['TraitName']]]
        assert observed == [[str(part) for part in row] for row in expected], (name, observed, expected)


def verify_synthetic(lines, records, builtin, pair):
    definitions = []
    for labels, types in [(['head', 'tail'], [builtin['Int64'], builtin['Float32']]),
                          (['_0', '_1'], [builtin['Int'], builtin['Bool']])]:
        rows = [r for r in records['Structs'] if r['IsProduct']
                and [f['Name'] for f in r['Fields']] == labels
                and [f['Type'] for f in r['Fields']] == types]
        assert len(rows) == 1
        definitions += rows
    for payloads in ([None, pair], [pair, builtin['Bool']]):
        rows = [r for r in records['Enums'] if [v['PayloadType'] for v in r['Variants']] == payloads]
        assert len(rows) == 1
        definitions += rows
    verify_resolved_definitions(lines, definitions, builtin, {'Pair': pair})


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-result', type=Path, required=True)
    parser.add_argument('--fixture-directory', type=Path)
    parser.add_argument('--probe', choices=['reference', 'storage', 'nominal', 'synthetic', 'finaltypes'], default='reference')
    parser.add_argument('--emitter', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    probe = ROOT / {'reference': 'scripts/probes/codegen-registered-types',
                    'storage': 'scripts/probes/codegen-storage-capture',
                    'nominal': 'scripts/probes/codegen-nominal-capture',
                    'synthetic': 'scripts/probes/codegen-synthetic-capture',
                    'finaltypes': 'scripts/probes/codegen-final-type-capture'}[args.probe]
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
                   'nominal': 'cache.nominal', 'synthetic': 'cache.synthetic', 'finaltypes': 'cache.finaltypes'}[args.probe] + ('.Wide' if args.probe == 'finaltypes' else '.Pair')
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
                elif args.probe == 'finaltypes':
                    builtin = reference['cases'][0]['observation']['builtinTypeIds']
                    declared = [r for group in ('Structs', 'Enums') for r in records[group]
                                if r['ModuleName'] == 'cache.finaltypes']
                    assert len(declared) == 4
                    outer = next(r for r in declared if r['Name'] == 'cache.finaltypes.Outer')
                    optional = [r for r in records['Enums']
                                if [v['PayloadType'] for v in r['Variants']] == [None, outer['Id']]]
                    dynamic = [r for r in records['DynTraits'] if r['TraitName'].endswith('cache.finaltypes.Value')]
                    assert len(optional) == len(dynamic) == 1
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
