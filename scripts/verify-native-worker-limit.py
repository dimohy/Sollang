"""Verify explicit CLI worker limits and the production native linker on a pinned LLVM fixture."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import time
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
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--llvm', type=Path, required=True)
    parser.add_argument('--fixture-llvm', type=Path, required=True)
    parser.add_argument('--fixture-proof', type=Path, required=True)
    parser.add_argument('--program', type=Path, required=True)
    args = parser.parse_args()
    compiler, llvm, fixture, proof_path, output = [p.resolve() for p in (
        args.compiler, args.llvm, args.fixture_llvm, args.fixture_proof, args.output)]
    proof = json.loads(proof_path.read_text(encoding='utf-8-sig'))
    if (proof.get('status') != 'passed' or proof.get('inputsStable') is not True
            or proof.get('processesStopped') is not True
            or proof.get('inputHashes', {}).get(str(fixture)) != sha(fixture)
            or not isinstance(proof.get('actualStdout'), str)):
        raise ValueError('NATIVE_WORKER_FIXTURE_IDENTITY_INVALID')
    project = ROOT / 'scripts/tools/CompilerLinkBridge/CompilerLinkBridge.csproj'
    dotnet = Path(shutil.which('dotnet')).resolve()
    inputs = list(dict.fromkeys([*managed_runtime_inputs(compiler), fixture, proof_path,
        args.program.resolve(), project, project.with_name('Program.cs'), dotnet, Path(__file__),
        *[llvm / 'bin' / tool for tool in ('clang.exe', 'llvm-split.exe', 'lld-link.exe', 'llvm-lib.exe', 'llvm-as.exe')],
        *[ROOT / name for name in ('src/Sollang.Compiler/Cli/CliOptions.cs',
            'src/Sollang.Compiler/Cli/CompilerApp.cs', 'src/Sollang.Compiler/Tooling/WindowsLinker.cs',
            'scripts/verification_execution.py', 'scripts/verification_contract_lease.py',
            'scripts/completed_artifact_plan.py', 'scripts/ArtifactLifecycle.ps1',
            'scripts/Invoke-CompletedArtifactCleanup.ps1', 'scripts/contracts/artifact-lifecycle.json')]]))
    if not all(p.is_file() for p in inputs):
        raise ValueError('NATIVE_WORKER_INPUT_MISSING')
    initialize_output(ROOT, output)
    output.mkdir(exist_ok=False)
    with VerificationContractLease(inputs):
        pins = {str(p): sha(p) for p in inputs}
        stable = lambda: all(p.is_file() and sha(p) == pins[str(p)] for p in inputs)
        record = dict(schemaVersion=1, status='running', completed=0, total=9, cases=[], inputHashes=pins,
            scope='CLI jobs admission and actual production worker-limited native link; historical LLVM is a backend fixture, not current compiler acceptance',
            compilerDllSha256=sha(compiler.with_suffix('.dll')), maximumRuns=1, timeoutSeconds=180,
            configuredWorkers=1, peakConcurrentClangMeasured=False, wholeGoalComplete=False)
        execution = VerificationExecution(ROOT, output, record, stable, sha)
        started = time.monotonic()
        error = None
        def run(command, name, expected_exit=0, stderr_contains=None):
            remaining = 180 - (time.monotonic() - started)
            if remaining <= 0:
                raise ValueError('NATIVE_WORKER_TOTAL_BUDGET_EXHAUSTED')
            result = execution.run([str(x) for x in command], output / name, timeout=remaining)
            stderr = (output / (name + '.stderr')).read_text(encoding='utf-8-sig').strip()
            if result.returncode != expected_exit or (stderr_contains is not None and stderr_contains not in stderr):
                raise ValueError('NATIVE_WORKER_STEP_FAILED:' + name)
            if expected_exit == 0 and stderr:
                raise ValueError('NATIVE_WORKER_UNEXPECTED_STDERR:' + name)
        def passed(name):
            record['cases'].append(dict(id=name, passed=True))
            record['completed'] += 1
            execution.save()
        try:
            if shutil.disk_usage(output).free < 512*1024*1024:
                raise ValueError('NATIVE_WORKER_STORAGE_PREFLIGHT')
            for index, value in enumerate(('0', '-1', 'x', '1.5', '2147483648')):
                name = 'invalid-jobs-' + str(index)
                run([compiler, 'build', args.program.resolve(), '--jobs', value], name,
                    expected_exit=1, stderr_contains='--jobs expects a positive integer')
                passed(name)
            run([compiler, 'build', args.program.resolve(), '--jobs'], 'missing-jobs',
                expected_exit=1, stderr_contains='--jobs')
            passed('missing-jobs')
            bridge = output / 'bridge'
            run([dotnet, 'build', project, '-c', 'Release', '-o', bridge, '--nologo'], 'bridge-build')
            work = output / 'native-work'
            work.mkdir()
            exe = output / 'fixture.exe'
            command = [dotnet, bridge / 'CompilerLinkBridge.dll', 'probe', compiler.with_suffix('.dll'),
                sha(compiler.with_suffix('.dll')), llvm, fixture, exe, work, '-O1', '1']
            run(command, 'probe-workers')
            observed = json.loads((output / 'probe-workers.stdout').read_text())
            if observed['maximumWorkers'] != 1 or observed['resolvedWorkerLimit'] != 1:
                raise ValueError('NATIVE_WORKER_RESOLVER_MISMATCH')
            passed('explicit-worker-resolver')
            program_exe = output / 'program.exe'
            run([compiler, 'build', args.program.resolve(), '--llvm', llvm, '--jobs', '1', '-O1', '-o', program_exe], 'cli-positive')
            run([program_exe], 'cli-positive-run')
            if (output / 'cli-positive-run.stdout').read_text().strip() != '7\n1':
                raise ValueError('NATIVE_WORKER_CLI_RUNTIME_MISMATCH')
            passed('explicit-jobs-cli-runtime')
            free_kib = int(subprocess.check_output(['pwsh', '-NoProfile', '-Command',
                '(Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory'], text=True).strip())
            record['memoryPreflight'] = dict(freeVirtualKiB=free_kib, minimumFreeVirtualKiB=2*1024*1024,
                reason='One optimization worker retains small partitions; this is a distinct execution plan from the 24-worker 4GiB plan')
            if free_kib < 2*1024*1024:
                raise ValueError('NATIVE_WORKER_MEMORY_PREFLIGHT')
            command[2] = 'link'
            run(command, 'native-link')
            progress = re.findall(r'\[native (\d+)/(\d+)\] optimized partition',
                (output / 'native-link.stdout').read_text())
            if not progress or len(progress) < 2 or [int(n) for n, _ in progress] != list(range(1, len(progress)+1)):
                raise ValueError('NATIVE_WORKER_SMALL_PARTITIONS_NOT_PRESERVED')
            if any(int(total) != len(progress) for _, total in progress):
                raise ValueError('NATIVE_WORKER_PARTITION_COMPLETION_MISMATCH')
            record['completedPartitions'] = len(progress)
            run([exe], 'fixture-run')
            actual = (output / 'fixture-run.stdout').read_text(encoding='utf-8-sig').strip()
            if actual != proof['actualStdout']:
                raise ValueError('NATIVE_WORKER_FIXTURE_RUNTIME_MISMATCH')
            record['fixtureStdout'] = actual
            passed('worker-limited-native-link-and-runtime')
            record['status'] = 'passed'
        except BaseException as caught:
            error = caught
        finally:
            execution.finalize(error, cleanup=error is None)
        print(json.dumps({k: record.get(k) for k in ('status', 'completed', 'total', 'inputsStable',
            'processesStopped', 'completedPartitions', 'failure')}))
        if error:
            raise error


if __name__ == '__main__':
    main()
