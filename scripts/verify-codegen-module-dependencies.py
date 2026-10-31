"""Compare actual managed dependency fields with the SLG compilation catalog."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import shutil

from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-result', type=Path)
    parser.add_argument('--emitter', type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    output = args.output.resolve()
    probe = ROOT / 'scripts/probes/codegen-module-dependencies'
    fixtures = [probe / name for name in ['A.slg', 'A_extra.slg', 'B.slg', 'C.slg', 'D.slg']]
    harness = ROOT / 'scripts/probes/codegen-identity/CodegenLimits.csproj'
    inputs = [Path(__file__), compiler, *managed_runtime_inputs(compiler), harness,
              harness.with_name('Limits.cs'), ROOT / 'Directory.Build.props', ROOT / 'global.json',
              *fixtures, *sorted((ROOT / 'stdlib').rglob('*.slg'))]
    sources = []
    if args.reference_result:
        reference = json.loads(args.reference_result.read_text(encoding='utf-8'))
        assert reference['status'] == 'passed' and reference['completed'] == reference['total'] == 2
        assert reference['inputsStable'] and reference['processesStopped']
        assert all(sha(p) == digest for p, digest in reference['inputHashes'].items())
        assert args.emitter, 'paired verification requires the current source emitter'
        manifest = probe / 'sources.txt'
        sources = [ROOT / s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
        producer_path = args.emitter.parent / 'result.json'
        producer = json.loads(producer_path.read_text(encoding='utf-8'))
        assert producer['status'] == 'passed' and producer['inputsStable'] and producer['processesStopped']
        assert all(sha(p) == digest for p, digest in producer['inputHashes'].items())
        inputs += [args.reference_result, manifest, *sources, args.emitter, producer_path,
                   *map(Path, producer['inputHashes'])]
    fingerprints = {str(p.resolve()): sha(p) for p in inputs}
    initialize_output(ROOT, output, reusable_directories=[B / p / 'compiler-build01'
                                                       for p in ['v18915', 'v20050', 'v21323']])
    output.mkdir()
    with VerificationContractLease(list(map(Path, fingerprints))):
        result = dict(schemaVersion=1, status='running', completed=0, total=8 if sources else 2,
                      cases=[], inputHashes=fingerprints, claimsGoalComplete=False,
                      scope='Actual CSharp dependency/ambient fields versus SLG catalog. Duplicates, '
                            'diamond imports, disconnected module and synthetic stdlib membership. '
                            'No actual cache reuse/publication or platform stdlib claim.')
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in fingerprints.items()), sha)
        error = None

        def run(command, label, timeout=180):
            done = execution.run(list(map(str, command)), output / label, timeout=timeout)
            assert done.returncode == 0 and not done.stderr, (label, done.returncode, done.stdout[-1500:], done.stderr)
            return done

        try:
            if not sources:
                run(['dotnet', 'build', '--disable-build-servers', '-nodeReuse:false',
                     '-p:UseSharedCompilation=false', harness, '-c', 'Release', '-o', output / 'harness',
                     '--artifacts-path', output / 'dotnet-artifacts'], 'build-harness')
                reference_sources = output / 'fixtures'
                reference_sources.mkdir()
                for fixture in fixtures:
                    shutil.copyfile(fixture, reference_sources / fixture.name)
                for label, mode in [('user', 'module-dependency-vectors'),
                                    ('standard', 'module-standard-dependency-vectors')]:
                    done = run(['dotnet', output / 'harness/CodegenLimits.dll', compiler.with_suffix('.dll'),
                                reference_sources, mode], label)
                    rows = [json.loads(line) for line in done.stdout.splitlines()]
                    assert len(rows) == 4 and len({r['ambientHash'] for r in rows}) == 1
                    for row in rows:
                        names = row['dependencyFields'][::2]
                        expected = {'cache.a': ['cache.b', 'cache.c'], 'cache.b': ['cache.c'], 'cache.c': [], 'cache.d': []}[row['name']]
                        assert names == expected and len(names) * 2 == len(row['dependencyFields']), row
                    result['cases'].append(dict(id=label, passed=True, rows=rows))
                    result['completed'] += 1
                assert result['cases'][0]['rows'][0]['ambientHash'] != result['cases'][1]['rows'][0]['ambientHash']
            else:
                observations = {c['id']: c['rows'] for c in reference['cases']}
                cases = [('user-forward', 'user', 0, fixtures),
                         ('user-reverse', 'user', 0, list(reversed(fixtures))),
                         ('standard-forward', 'standard', 2, fixtures),
                         ('standard-reverse', 'standard', 2, fixtures[1::-1] + fixtures[:1:-1])]
                for backend in ['managed', 'slg']:
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
                    for label, scenario, standard_count, paths in cases:
                        rows = observations[scenario]
                        expected = format(rows[0]['ambientHash'], '016x') + '\n'
                        for row in rows:
                            expected += '\n'.join([row['name'], *row['dependencyFields'], 'end-module']) + '\n'
                        done = run([executable, str(standard_count), *paths], backend + '-' + label, 10)
                        assert done.stdout == expected, (label, done.stdout, expected)
                        result['cases'].append(dict(id=backend + '-' + label, passed=True, stdout=done.stdout))
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
