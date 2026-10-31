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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-result', type=Path, required=True)
    parser.add_argument('--probe', choices=['reference', 'storage'], default='reference')
    parser.add_argument('--emitter', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    probe = ROOT / ('scripts/probes/codegen-registered-types' if args.probe == 'reference'
                    else 'scripts/probes/codegen-storage-capture')
    fixture = probe / 'input.slg'
    manifest = probe / 'sources.txt'
    sources = [ROOT / s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
    reference = json.loads(args.reference_result.read_text(encoding='utf-8'))
    assert reference['status'] == 'passed' and reference['completed'] == reference['total'] == 1
    assert reference['inputsStable'] and reference['processesStopped']
    assert reference['inputHashes'][str(fixture.resolve())] == sha(fixture)
    records = reference['cases'][0]['observation']['records']
    declaration = ('cache.registered' if args.probe == 'reference' else 'cache.storage') + '.Pair'
    pair = [r['Id'] for r in records['Structs'] if r['Name'] == declaration]
    assert len(pair) == 1
    assert len([r for r in records['References'] if r['ElementType'] == pair[0]]) == 1
    paths = [Path(__file__), compiler, *managed_runtime_inputs(compiler), args.reference_result,
             fixture, manifest, *sources, *sorted((ROOT / 'stdlib').rglob('*.slg'))]
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
                done = run([executable, fixture], backend + '-run', 20)
                lines = done.stdout.splitlines()
                if args.probe == 'reference':
                    assert len(lines) == 2 and re.fullmatch(r'reference:\d+:\d+', lines[0])
                    assert lines[0] == lines[1], lines
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
