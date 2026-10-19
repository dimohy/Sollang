"""Verify frozen CLI diagnostic cases without backend or negative execution."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_step_diagnostics import SlowStepDiagnostics


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--contract', required=True, type=Path)
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    contract_path = args.contract.resolve()
    compiler = args.compiler.resolve()
    output = args.output.resolve()
    contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
    assert contract['schemaVersion'] == 1 and contract['mode'] == 'exact-cli-diagnostics', 'CLI_CONTRACT_KIND'
    cases = contract['cases']
    assert cases and len({case['id'] for case in cases}) == len(cases), 'CLI_CASE_IDENTITY'
    inputs = [contract_path, compiler, Path(__file__).resolve()]
    if compiler.with_suffix('.dll').is_file():
        inputs.append(compiler.with_suffix('.dll'))
    inputs += [Path(p) for p in contract['inputFiles']]
    for case in cases:
        assert case['exit'] == 1 and case['args'][0] == 'build', 'CLI_NEGATIVE_ONLY'
        assert '-o' not in case['args'] and '--output' not in case['args'], 'CLI_OUTPUT_OWNERSHIP'
        assert case['args'].count('--project') + case['args'].count('--workspace') == 1, 'CLI_ENTRY_CONTRACT'
        inputs += [Path(case['stderrFile']), Path(case['stdoutFile'])]
        for flag in ['--project', '--workspace']:
            if flag in case['args']:
                inputs.append(Path(case['args'][case['args'].index(flag) + 1]))
    assert all(p.is_file() for p in inputs), 'CLI_INPUT_MISSING'
    hashes = {str(p): sha(p) for p in inputs}
    assert all(hashes.get(p) == digest for p, digest in contract['inputHashes'].items()), 'CLI_CONTRACT_INPUT_DRIFT'
    stable = lambda: all(Path(p).is_file() and sha(Path(p)) == h for p, h in hashes.items())
    plan_path = repo / 'scripts/contracts/focused-step-diagnostics-plan.json'
    diagnostics = json.loads(plan_path.read_text(encoding='utf-8-sig'))
    hashes[str(plan_path)] = sha(plan_path)
    initialize_output(repo, output)
    output.mkdir(exist_ok=False)
    result = {'status': 'running', 'completed': 0, 'total': len(cases), 'inputHashes': hashes,
              'scope': 'exact CLI stderr/stdout and exit; negative executable never run', 'cases': []}
    execution = VerificationExecution(repo, output, result, stable, sha)
    execution.save()
    error = None
    try:
        with VerificationContractLease([Path(p) for p in hashes]):
            for index, case in enumerate(cases):
                case_output = output / ('case-' + str(index).zfill(2))
                case_output.mkdir()
                binary = case_output / 'probe.exe'
                command = [str(compiler), *case['args'], '-o', str(binary)]
                row = {'id': case['id'], 'status': 'running'}
                result['cases'].append(row)
                process = execution.run(command, case_output / 'build', timeout=180,
                                        diagnostics=SlowStepDiagnostics(diagnostics, case_output / 'build.diagnostics.json'))
                row['buildExit'] = process.returncode
                assert process.returncode == case['exit'], 'CLI_EXIT:' + case['id']
                stdout = (case_output / 'build.stdout').read_bytes()
                stderr = (case_output / 'build.stderr').read_bytes()
                assert stdout == Path(case['stdoutFile']).read_bytes(), 'CLI_STDOUT:' + case['id']
                assert stderr == Path(case['stderrFile']).read_bytes(), 'CLI_STDERR:' + case['id']
                assert not binary.exists(), 'CLI_NEGATIVE_PUBLISHED:' + case['id']
                row.update(status='passed', stdoutSha256=sha(case_output / 'build.stdout'),
                           stderrSha256=sha(case_output / 'build.stderr'))
                result['completed'] += 1
                execution.save()
            result['status'] = 'passed'
    except BaseException as failure:
        error = failure
        if result['cases']:
            result['cases'][-1]['status'] = 'failed'
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'failure', 'inputsStable', 'processesStopped']}))
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
