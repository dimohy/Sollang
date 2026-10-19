"""Exercise the actual SLG worker-runtime emitters with both compiler producers.

Windows LLVM is assembled, linked and executed; Linux LLVM is assembled only.
This focused leaf test does not certify a freshly built selfhost compiler.
"""
import argparse
import hashlib
import json
from pathlib import Path

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--managed', type=Path, required=True)
    parser.add_argument('--selfhost', type=Path, required=True)
    parser.add_argument('--formatter', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reusable', type=Path, action='append', required=True)
    args = parser.parse_args()
    managed, selfhost, formatter, output = (p.resolve() for p in (args.managed, args.selfhost, args.formatter, args.output))
    fixture = ROOT / 'scripts/contracts/fixtures/worker-runtime-emitter.slg'
    probe = fixture.with_name('worker-runtime-probe.ll.txt')
    sources = [fixture, ROOT / 'selfhost/llvm/emitter/compute_runtime.slg',
               ROOT / 'selfhost/llvm/emitter/text_output_runtime.slg']
    llvm = ROOT / '.tools/llvm-22.1.8'
    inputs = list(dict.fromkeys([*managed_runtime_inputs(managed), selfhost, formatter, *sources, probe,
        *sorted((ROOT / 'stdlib').rglob('*.slg')), Path(__file__).resolve(),
        llvm / 'bin/llvm-as.exe', llvm / 'bin/clang.exe',
        ROOT / 'selfhost/llvm/text/context_prepare.slg',
        *[ROOT / 'scripts' / name for name in ('verification_execution.py',
          'verification_contract_lease.py', 'completed_artifact_plan.py', 'ArtifactLifecycle.ps1',
          'Invoke-CompletedArtifactCleanup.ps1', 'contracts/artifact-lifecycle.json')]]))
    if output.exists() or not all(p.is_file() for p in inputs):
        raise ValueError('WORKER_RUNTIME_PREFLIGHT_FAILED')
    initialize_output(ROOT, output, reusable_directories=[p.resolve() for p in args.reusable])
    output.mkdir()
    with VerificationContractLease(inputs):
        pins = {str(p): sha(p) for p in inputs}
        stable = lambda: all(p.is_file() and sha(p) == pins[str(p)] for p in inputs)
        record = dict(schemaVersion=1, status='running', completed=0, total=8,
                      scope='actual worker-runtime leaf emission; Windows native, Linux assembly only',
                      inputHashes=pins, cases=[], fullCompilerVerified=False, linuxExecuted=False)
        execution = VerificationExecution(ROOT, output, record, stable, sha)
        error = None

        def run(command, name, timeout=20):
            result = execution.run([str(x) for x in command], output / name, timeout=timeout)
            if result.returncode or (output / (name + '.stderr')).read_text(encoding='utf-8-sig').strip():
                raise ValueError('WORKER_RUNTIME_STEP_FAILED:' + name)
            return (output / (name + '.stdout')).read_text(encoding='utf-8-sig')

        try:
            for index, source in enumerate(sources):
                run([formatter, 'format', source, '--check'], 'format-preflight-' + str(index))
            windows_triple = run([llvm / 'bin/clang.exe', '-print-effective-triple'], 'target-preflight').strip()
            if not windows_triple.startswith('x86_64-pc-windows-msvc'):
                raise ValueError('WORKER_RUNTIME_TARGET_UNSUPPORTED:' + windows_triple)
            record['windowsTargetTriple'] = windows_triple
            outputs = {}
            for producer, compiler in [('managed', managed), ('selfhost', selfhost)]:
                exe = output / (producer + '-emitter.exe')
                command = [compiler, 'build', *sources, '--llvm', llvm, '-O1', '-o', exe]
                if producer == 'selfhost':
                    command += ['--stdlib', ROOT / 'stdlib']
                run(command, producer + '-build', timeout=120)
                emitted = run([exe], producer + '-emit')
                windows, linux = emitted.split('; worker-platform-linux\n')
                windows = windows.removeprefix('; worker-platform-windows\n')
                for platform, runtime in [('windows', windows), ('linux', linux)]:
                    if producer == 'selfhost' and outputs[platform] != runtime:
                        raise ValueError('WORKER_RUNTIME_PRODUCER_MISMATCH:' + platform)
                    outputs[platform] = runtime
                    common = 'declare ptr @malloc(i64)\ndeclare void @free(ptr)\ndeclare void @llvm.trap()\n'
                    declarations = ('declare dllimport ptr @CreateThread(ptr, i64, ptr, ptr, i32, ptr)\n'
                                    'declare dllimport i32 @WaitForSingleObject(ptr, i32)\n') if platform == 'windows' else (
                                    'declare i32 @pthread_create(ptr, ptr, ptr, ptr)\n'
                                    'declare i32 @pthread_join(i64, ptr)\n')
                    triple = windows_triple if platform == 'windows' else 'x86_64-unknown-linux-gnu'
                    name = producer + '-' + platform
                    ll = output / (name + '.ll')
                    ll.write_text('target triple = "' + triple + '"\n' + common + declarations + runtime + probe.read_text(), encoding='utf-8')
                    run([llvm / 'bin/llvm-as.exe', ll, '-o', output / (name + '.bc')], name + '-assemble')
                    if platform == 'windows':
                        native = output / (name + '.exe')
                        run([llvm / 'bin/clang.exe', '--target=' + triple, ll, '-O1', '-o', native], name + '-link')
                        for mode, arguments in [('configured', []), ('workers-only', ['workers']), ('peak-only', ['peak', 'only'])]:
                            actual = run([native, *arguments], name + '-' + mode)
                            if actual != 'worker-runtime-ok\n':
                                raise ValueError('WORKER_RUNTIME_OUTPUT_MISMATCH:' + name + '-' + mode)
                            record['cases'].append(dict(id=name + '-' + mode, passed=True))
                            record['completed'] += 1
                            execution.save()
                    else:
                        record['cases'].append(dict(id=name + '-assembly', passed=True, executed=False))
                        record['completed'] += 1
                        execution.save()
            record['status'] = 'passed'
        except BaseException as caught:
            error = caught
        finally:
            record['inputHashesEnd'] = {str(p): sha(p) for p in inputs}
            execution.finalize(error, cleanup=error is None)
        print(json.dumps({k: record.get(k) for k in ('status', 'completed', 'total', 'failure', 'inputsStable', 'processesStopped')}))
        if error:
            raise error


if __name__ == '__main__':
    main()
