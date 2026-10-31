"""Verify actual C# type-universe cache fields against frozen layout vectors."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

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
    parser.add_argument('--baseline-result', type=Path)
    parser.add_argument('--emitter', type=Path)
    parser.add_argument('--verify-source', action='store_true')
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    output = args.output.resolve()
    harness = ROOT / 'scripts/probes/codegen-identity/CodegenLimits.csproj'
    vectors = ROOT / 'scripts/probes/codegen-type-universe/vectors.json'
    inputs = [Path(__file__), compiler, *managed_runtime_inputs(compiler), harness,
              harness.with_name('Limits.cs'), vectors, ROOT / 'Directory.Build.props', ROOT / 'global.json']
    baseline = None
    if args.baseline_result:
        baseline = json.loads(args.baseline_result.read_text(encoding='utf-8'))
        assert baseline['status'] == 'passed' and baseline['completed'] == baseline['total'] == 9
        assert baseline['inputsStable'] and baseline['processesStopped']
        # The new compiler is expected to change; frozen input vectors must not.
        assert baseline['inputHashes'][str(vectors.resolve())] == sha(vectors)
        inputs.append(args.baseline_result)
    sources = []
    if args.emitter or args.verify_source:
        assert baseline, 'paired format proof requires the frozen CSharp reference'
        manifest = ROOT / 'scripts/probes/codegen-type-universe/sources.txt'
        sources = [ROOT / line for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line]
        inputs += [manifest, *sources]
        if args.emitter:
            producer_path = args.emitter.parent / 'result.json'
            producer = json.loads(producer_path.read_text(encoding='utf-8'))
            assert producer['status'] == 'passed' and producer['inputsStable'] and producer['processesStopped']
            assert all(sha(p) == digest for p, digest in producer['inputHashes'].items())
            inputs += [args.emitter, producer_path, *map(Path, producer['inputHashes'])]
    fingerprints = {str(p.resolve()): sha(p) for p in inputs}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    with VerificationContractLease(list(map(Path, fingerprints))):
        result = dict(schemaVersion=1, status='running', completed=0, total=18 if args.emitter else 9, cases=[],
                      inputHashes=fingerprints, claimsGoalComplete=False,
                      scope='Actual BuildTypeUniverseHash and table records: eight registered layout categories, '
                            'field/variant/type order, null fixed length, Unicode and category mutations. '
                            'Metadata-only; no Native type-pool selection or cache reuse claim.')
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in fingerprints.items()), sha)
        error = None
        try:
            if sources:
                expected = ''.join('\n'.join([*case['observation']['fields'],
                    format(case['observation']['hash'], '016x')]) + '\n' for case in baseline['cases'])
                def run(command, label, timeout=180):
                    done = execution.run(list(map(str, command)), output / label, timeout=timeout)
                    assert done.returncode == 0 and not done.stderr, (label, done.stdout[-1500:], done.stderr)
                    return done
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
                    done = run([executable], backend + '-run', 10)
                    assert done.stdout == expected, (backend, done.stdout, expected)
                    result['cases'] += [dict(id=backend + ':' + case['id'], passed=True,
                                            observation=case['observation']) for case in baseline['cases']]
                    result['completed'] += 9
                result['status'] = 'passed'
            else:
                shutil.copyfile(vectors, output / 'vectors.json')
                built = execution.run(['dotnet', 'build', '--disable-build-servers', '-nodeReuse:false',
                                       '-p:UseSharedCompilation=false', str(harness), '-c', 'Release',
                                       '-o', str(output / 'harness'), '--artifacts-path', str(output / 'dotnet-artifacts')],
                                      output / 'build', timeout=180)
                assert built.returncode == 0, built.stdout + built.stderr
                done = execution.run(['dotnet', str(output / 'harness/CodegenLimits.dll'),
                                      str(compiler.with_suffix('.dll')), str(output), 'type-universe-vectors'],
                                     output / 'run', timeout=180)
                assert done.returncode == 0 and not done.stderr, done.stdout + done.stderr
                rows = [json.loads(line) for line in done.stdout.splitlines()]
                assert len(rows) == 9
                if baseline:
                    assert rows == [case['observation'] for case in baseline['cases']]
                result.update(status='passed', completed=9,
                              cases=[dict(id=row['id'], passed=True, observation=row) for row in rows])
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
