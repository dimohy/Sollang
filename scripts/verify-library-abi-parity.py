"""Check the original library ABI cases against current CSharp declarations."""
import argparse
import hashlib
import json
import re
import sys
import time
from pathlib import Path

from completed_artifact_plan import initialize_output, cleanup_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--contract', type=Path, default=ROOT / 'scripts/contracts/library-abi-focused.json')
    parser.add_argument('--native-compiler', type=Path)
    parser.add_argument('--managed-result', type=Path)
    parser.add_argument('--source-comparison', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    contract = read(args.contract)
    assert contract['schemaVersion'] == 1 and len(contract['cases']) == 7
    assert contract['target'] == 'windows-x64' and contract['optimization'] == 'O0'
    assert contract['jobs'] == 1 and contract['wholeCaseSeconds'] == 180
    compiler = args.compiler.resolve()
    paths = [Path(__file__), args.contract, compiler, *managed_runtime_inputs(compiler),
             ROOT / 'scripts/verification_execution.py', ROOT / 'scripts/verification_contract_lease.py',
             ROOT / 'scripts/verification_source_proof.py', ROOT / 'scripts/verification_fingerprints.py',
             *sorted((ROOT / 'stdlib').rglob('*.slg')),
             *[ROOT / c['source'] for c in contract['cases']], ROOT / contract['positive']['source']]
    reference = None
    if args.native_compiler:
        assert args.managed_result and args.source_comparison, 'Native requires current CSharp proof and source comparison'
        reference = read(args.managed_result)
        assert reference['status'] == 'passed' and reference['completed'] == reference['total'] == 8
        assert reference['inputsStable'] and reference['processesStopped']
        assert reference['inputHashes'][str(args.contract.resolve())] == sha(args.contract)
        assert all(sha(p) == h for p, h in reference['inputHashes'].items()), 'CSharp proof drift'
        comparison = read(args.source_comparison)
        assert comparison['status'] == 'compared-before-slg-edit'
        birth_path = args.native_compiler.parent / 'result.json'
        birth = read(birth_path)
        assert birth['compilerSha256'] == sha(args.native_compiler)
        paths += [args.native_compiler, birth_path, args.managed_result, args.source_comparison,
                  *current_build_inputs(ROOT, birth)]
        compiler = args.native_compiler.resolve()
    else:
        assert not args.managed_result and not args.source_comparison
    llvm = ROOT / '.tools/llvm-22.1.8'
    for name in ['clang.exe', 'llvm-as.exe', 'opt.exe', 'lld-link.exe']:
        paths.append(llvm / 'bin' / name)
    inputs = {str(p.resolve()): sha(p) for p in paths}
    output = args.output.resolve()
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    result = dict(schemaVersion=1, status='running', completed=0, total=8, cases=[],
                  scope=contract['scope'], inputHashes=inputs, claimsGoalComplete=False)
    with VerificationContractLease(list(map(Path, inputs))):
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in inputs.items()), sha)
        error = None
        try:
            rows = contract['cases'] + [dict(id='positive', **contract['positive'])]
            for row in rows:
                started = time.monotonic()
                remaining = lambda: max(0.001, 180 - (time.monotonic() - started))
                directory = output / row['id']
                directory.mkdir()
                dll = directory / 'math.dll'
                command = [str(compiler), 'build', str(ROOT / row['source']), '-o', str(dll),
                           '--library', '--target', 'windows-x64', '--llvm', str(llvm), '--jobs', '1', '-O0']
                if args.native_compiler:
                    command += ['--stdlib', str(ROOT / 'stdlib')]
                done = execution.run(command,
                                     directory / 'build', timeout=remaining())
                if row['id'] != 'positive':
                    assert done.returncode == 1 and not done.stdout
                    identity = None
                    if row.get('diagnostic') == 'fixed-width-type':
                        match = re.fullmatch(r"sollang: type '([0-9]+)' is not a fixed-width library ABI type\n", done.stderr)
                        assert match, (row['id'], done.stderr)
                        identity = int(match[1])
                    else:
                        assert done.stderr == row['stderr'], (row['id'], done.stderr)
                    if reference:
                        expected = next(c for c in reference['cases'] if c['id'] == row['id'])['stderr']
                        assert done.stderr == expected, (row['id'], expected, done.stderr)
                    result['cases'].append(dict(id=row['id'], passed=True, exit=1,
                                                stderr=done.stderr, diagnosticTypeId=identity))
                else:
                    assert done.returncode == 0 and not done.stderr, done.stdout + done.stderr
                    interface = directory / 'math.windows-x64.slglib.json'
                    metadata = read(interface)
                    if reference:
                        assert metadata == reference['interface'], 'Library interface differs from CSharp'
                    code = ('import ctypes,json,sys;from pathlib import Path;'
                            'j=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8-sig"));'
                            'lib=ctypes.CDLL(sys.argv[1]);f=getattr(lib,j["exports"][0]["symbol"]);'
                            'f.argtypes=[ctypes.c_int32];f.restype=ctypes.c_int32;print(f(int(sys.argv[3])))')
                    called = execution.run([sys.executable, '-c', code, str(dll), str(interface), str(row['argument'])],
                                           directory / 'call', timeout=remaining())
                    assert called.returncode == 0 and not called.stderr and called.stdout == str(row['expected']) + '\n'
                    result['interface'] = metadata
                    result['cases'].append(dict(id='positive', passed=True, exit=0, stdout=called.stdout))
                assert time.monotonic() - started <= 180
                result['completed'] += 1
                execution.save()
                print(row['id'] + ': PASS', flush=True)
            result['status'] = 'passed'
        except BaseException as failure:
            error = failure
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    assert result['status'] == 'passed' and result['inputsStable'] and result['processesStopped']
    cleanup_output(ROOT, output, reusable_directories=args.reusable_directory)
    print(json.dumps({k: result[k] for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
