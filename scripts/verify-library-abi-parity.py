"""Check the original library ABI cases against current CSharp declarations."""
import argparse
import copy
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

LIBRARY_CALL_SOURCE = '''import ctypes,json,sys
from pathlib import Path
metadata=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8-sig"))
library=ctypes.CDLL(sys.argv[1])
types={"Int8":ctypes.c_int8,"Int16":ctypes.c_int16,"Int32":ctypes.c_int32,
       "Int64":ctypes.c_int64,"UInt8":ctypes.c_uint8,"UInt16":ctypes.c_uint16,
       "UInt32":ctypes.c_uint32,"UInt64":ctypes.c_uint64,
       "Float32":ctypes.c_float,"Float64":ctypes.c_double}
def abi_type(name,result=False):
    return (None if result else ctypes.c_uint8) if name=="Unit" else types[name]
exports={entry["name"]:entry for entry in metadata["exports"]}
results=[]
for call in json.loads(sys.argv[3]):
    entry=exports[call["export"]]
    assert len(call["arguments"])==len(entry["parameters"])
    function=getattr(library,entry["symbol"])
    function.argtypes=[abi_type(parameter["type"]) for parameter in entry["parameters"]]
    function.restype=abi_type(entry["result"],True)
    results.append(function(*call["arguments"]))
print(results[0] if sys.argv[4]=="single" else json.dumps(results))
'''


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
    if 'calls' in contract['positive']:
        calls = contract['positive']['calls']
        assert isinstance(calls, list) and calls, 'LIBRARY_CALL_MATRIX_EMPTY'
        assert all(isinstance(call, dict) and set(call) == {'export', 'arguments', 'expected'}
                   and isinstance(call['export'], str) and isinstance(call['arguments'], list)
                   for call in calls), 'LIBRARY_CALL_MATRIX_INVALID'
    compiler = args.compiler.resolve()
    paths = [Path(__file__), args.contract, compiler, *managed_runtime_inputs(compiler),
             ROOT / 'scripts/verification_execution.py', ROOT / 'scripts/verification_contract_lease.py',
             ROOT / 'scripts/verification_source_proof.py', ROOT / 'scripts/verification_fingerprints.py',
             *sorted((ROOT / 'stdlib').rglob('*.slg')),
             *[ROOT / c['source'] for c in contract['cases']], ROOT / contract['positive']['source']]
    consumer = contract['positive'].get('consumer')
    if consumer:
        assert set(consumer) == {'source', 'stdout'}, 'LIBRARY_CONSUMER_CONTRACT_INVALID'
        paths.append(ROOT / consumer['source'])
    metadata_controls = contract['positive'].get('metadataRejections', [])
    assert not metadata_controls or consumer, 'LIBRARY_METADATA_CONTROLS_REQUIRE_CONSUMER'
    for control in metadata_controls:
        assert set(control) == {'id', 'member', 'value', 'stderr'}, 'LIBRARY_METADATA_CONTROL_INVALID'
        assert control['member'] in {'name', 'symbol', 'parameterName'}, 'LIBRARY_METADATA_MEMBER_INVALID'
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
                    matrix = 'calls' in row
                    calls = row['calls'] if matrix else [dict(export=metadata['exports'][0]['name'],
                        arguments=[row['argument']], expected=row['expected'])]
                    call_inputs = [{key: call[key] for key in ('export', 'arguments')} for call in calls]
                    expected_output = (json.dumps([call['expected'] for call in calls]) if matrix
                                       else str(row['expected'])) + '\n'
                    called = execution.run([sys.executable, '-c', LIBRARY_CALL_SOURCE, str(dll), str(interface),
                                            json.dumps(call_inputs), 'matrix' if matrix else 'single'],
                                           directory / 'call', timeout=remaining())
                    assert called.returncode == 0 and not called.stderr and called.stdout == expected_output
                    if consumer:
                        consumer_source = directory / 'consumer.slg'
                        consumer_source.write_bytes((ROOT / consumer['source']).read_bytes())
                        executable = directory / 'consumer.exe'
                        consumer_command = [str(compiler), 'build', str(consumer_source), '-o', str(executable),
                                            '--target', 'windows-x64', '--llvm', str(llvm), '--jobs', '1', '-O0']
                        if args.native_compiler:
                            consumer_command += ['--stdlib', str(ROOT / 'stdlib')]
                        imported = execution.run(consumer_command, directory / 'consumer-build', timeout=remaining())
                        assert imported.returncode == 0 and not imported.stderr, imported.stdout + imported.stderr
                        executed = execution.run([str(executable)], directory / 'consumer-run', timeout=remaining())
                        assert executed.returncode == 0 and not executed.stderr and executed.stdout == consumer['stdout'], (
                            executed.returncode, executed.stdout, executed.stderr)
                        result['consumer'] = dict(passed=True, stdout=executed.stdout,
                                                  sourceSha256=sha(consumer_source))
                        original_interface = interface.read_bytes()
                        rejections = []
                        try:
                            for control in metadata_controls:
                                modified = copy.deepcopy(metadata)
                                exported = modified['exports'][0]
                                if control['member'] == 'parameterName':
                                    exported['parameters'][0]['name'] = control['value']
                                else:
                                    exported[control['member']] = control['value']
                                if control['member'] == 'name':
                                    prefix, separator, _ = exported['qualifiedName'].rpartition('.')
                                    exported['qualifiedName'] = prefix + separator + control['value']
                                # Keep integrity valid so a rejection proves identifier admission,
                                # rather than an unrelated name mismatch or stale hash.
                                for entry in modified['exports']:
                                    material = entry['name'] + '\0' + entry['symbol'] + '\0' + '\0'.join(
                                        p['name'] + ':' + p['type'] for p in entry['parameters']) + '\0->' + entry['result']
                                    entry['signatureHash'] = hashlib.sha256(material.encode('utf-8')).hexdigest()
                                abi_material = '\n'.join(entry['qualifiedName'] + '\0' + '\0'.join(
                                    p['type'] for p in entry['parameters']) + '\0->' + entry['result']
                                    for entry in sorted(modified['exports'], key=lambda entry: entry['qualifiedName']))
                                modified['abiHash'] = hashlib.sha256(abi_material.encode('utf-8')).hexdigest()
                                mutated_bytes = (json.dumps(modified, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
                                (directory / (control['id'] + '.json')).write_bytes(mutated_bytes)
                                interface.write_bytes(mutated_bytes)
                                rejected = execution.run(consumer_command, directory / control['id'], timeout=remaining())
                                expected_error = control['stderr'].replace('{interface}', str(interface))
                                assert rejected.returncode == 1 and not rejected.stdout and rejected.stderr == expected_error, (
                                    control['id'], rejected.returncode, rejected.stdout, rejected.stderr)
                                rejections.append(dict(id=control['id'], passed=True, stderr=rejected.stderr))
                        finally:
                            interface.write_bytes(original_interface)
                        result['metadataRejections'] = rejections
                    result['interface'] = metadata
                    result['cases'].append(dict(id='positive', passed=True, exit=0, stdout=called.stdout,
                                                actualLibraryCalls=len(calls)))
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
