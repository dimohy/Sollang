"""Observe a managed-first case with a verified native compiler, without promotion."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution
from verification_source_proof import current_build_inputs


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('contract', 'managed-proof', 'build', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    contract_path, proof_path, build, output = [
        path.resolve() for path in (args.contract, args.managed_proof, args.build, args.output)]
    contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
    proof = json.loads(proof_path.read_text(encoding='utf-8-sig'))
    build_path = build / 'result.json'
    build_record = json.loads(build_path.read_text(encoding='utf-8-sig'))
    cases = contract['cases']
    if (contract['schemaVersion'] != 1 or len(cases) != 1 or cases[0]['exit'] not in (0, 1)
            or cases[0].get('additionalSources') or cases[0].get('emittedLlvm')
            or proof['status'] != 'passed' or proof['completed'] != 1
            or proof['total'] != 1 or not proof['inputsStable'] or not proof['processesStopped']):
        raise ValueError('NATIVE_OBSERVATION_MANAGED_FIRST_REQUIRED')
    compiler = build / 'compiler.exe'
    if (build_record['status'] != 'passed' or not build_record['inputsStable']
            or sha(compiler) != build_record['compilerSha256']):
        raise ValueError('NATIVE_OBSERVATION_BUILD_INVALID')
    if proof['inputHashes'].get(str(contract_path)) != sha(contract_path):
        raise ValueError('NATIVE_OBSERVATION_CONTRACT_NOT_COVERED')
    pins = dict(proof['inputHashes'])
    extra = [contract_path, proof_path, compiler, build_path, Path(__file__).resolve(),
             ROOT / 'scripts/verification_execution.py',
             *current_build_inputs(ROOT, build_record)]
    pins.update({str(path): sha(path) for path in extra})
    stable = lambda: all(Path(path).is_file() and sha(Path(path)) == value
                         for path, value in pins.items())
    if not stable():
        raise ValueError('NATIVE_OBSERVATION_INPUT_DRIFT')
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('NATIVE_OBSERVATION_FRESH_OUTPUT_REQUIRED')
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    result = dict(schemaVersion=1, status='running', inputHashes=pins,
                  scope='Auxiliary managed/native observation; no compiler unit promotion')
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        case = cases[0]
        source = (ROOT / case['source']).resolve()
        exe = output / 'probe.exe'
        run = runner.run([str(compiler), 'build', str(source), '-o', str(exe),
                          '--target', 'windows-x64', '--keep-temps', '--llvm',
                          str(ROOT / '.tools/llvm-22.1.8'), '--stdlib',
                          str(ROOT / 'stdlib'), '-O1'], output / 'build')
        if case['exit'] == 1:
            result.update(status='observed', expectedStderr=case['stderr'],
                          actualStderr=run.stderr.strip(), exit=run.returncode,
                          matchesManaged=(run.returncode == 1
                          and run.stderr.strip() == case['stderr']))
            print(json.dumps({key: result[key] for key in
                              ('status', 'actualStderr', 'matchesManaged')}))
            return
        if run.returncode or run.stderr.strip():
            raise ValueError('NATIVE_OBSERVATION_BUILD_FAILED')
        run = runner.run([str(exe)], output / 'run')
        result.update(status='observed', expectedStdout=case['stdout'],
                      actualStdout=run.stdout.strip(), stderr=run.stderr.strip(),
                      exit=run.returncode, matchesManaged=(run.returncode == 0
                      and run.stdout.strip() == case['stdout'] and not run.stderr.strip()))
        print(json.dumps({key: result[key] for key in
                          ('status', 'actualStdout', 'matchesManaged')}))
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error)


if __name__ == '__main__':
    main()
