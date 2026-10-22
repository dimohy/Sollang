from pathlib import Path
import importlib.util
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'
spec = importlib.util.spec_from_file_location('source_proof', HERE / 'verify-candidate.py')
source_proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_proof)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def verify():
    source_proof.verify()
    native = read(BASE / 'native12574-qualification/result.json')
    build = read(BASE / 'v12573/compiler-build01/result.json')
    contract = read(BASE / 'source12570-contract.json')
    runtime = read(BASE / 'source12571-runtime/result.json')
    assert native['status'] == build['status'] == 'passed'
    assert native['completed'] == native['total'] == 14
    assert build['inputHashesStart'] == build['inputHashesEnd']
    assert build['inputsStable'] and native['compilerSha256'] == build['compilerSha256']
    assert hashlib.sha256((BASE / 'v12573/compiler-build01/compiler.exe').read_bytes()).hexdigest().upper() == build['compilerSha256']
    source_proof.arrays.stable(native)
    assert sum(bool(row.get('admissionRejected')) for row in native['cases']) == 2
    array_counts = {'interpolation-array-index': 6, 'interpolation-reference-index': 2, 'interpolation-index-order': 4}
    byte_counts = {'text-byte': 1, 'source-text-byte': 1, 'text-byte-contexts': 2, 'reference-text-byte': 2, 'computed-text-byte': 1, 'text-byte-wide-literal': 1}
    runs = 0
    skips = 0
    for expected in contract['cases']:
        case = next(row for row in native['cases'] if row['id'] == expected['id'])
        assert case['status'] == 'passed' and case['passed']
        record = read(BASE / 'native12574-qualification' / (case['id'] + '.exe.compiler-build.json'))
        source_proof.arrays.stable(record)
        if expected.get('admitted') is False:
            assert case['admissionRejected'] and case['buildExit'] == 1 and 'runExit' not in case
            assert (case['stdout'] + case['stderr']).count('parallel callback SourceText is supported only as a direct top-level tryParallel Result payload') == 1
            continue
        assert case['buildExit'] == 0
        llvm_path = BASE / 'native12574-qualification' / (case['id'] + '.exe.ll')
        assert hashlib.sha256(llvm_path.read_bytes()).hexdigest().upper() == record['llvmSha256']
        llvm = llvm_path.read_text(encoding='utf-8-sig')
        if case['id'] in array_counts:
            source_proof.arrays.checked_array_loads(llvm, array_counts[case['id']])
        if case['id'] in byte_counts:
            source_proof.checked_byte_loads(llvm, byte_counts[case['id']])
        if expected.get('compileOnly'):
            assert expected['runtimeRequired'] is False and case['compileOnly']
            assert case['runtimeStatus'] == 'skipped-not-tested' and 'runExit' not in case
            assert '_index = add i64 0, 4294967296' in llvm
            assert not (BASE / 'native12574-qualification' / (case['id'] + '.execution.json')).exists()
            skips += 1
            continue
        source_run = next(row for row in runtime['cases'] if row['id'] == case['id'])
        assert case['runExit'] == expected['exit'] == source_run['runExit'] == 0
        assert case['stdout'].replace('\r\n', '\n') == expected['stdout'] == source_run['stdout']
        assert case['stderr'] == expected['stderr'] == source_run['stderr'] == ''
        runs += 1
    assert runs == 11 and skips == 1 and len(native['steps']) == 11
    print('Fresh canonical native14/14 passed: normal runtime11, required semantic rejection2, compile-only UIntSize boundary1 explicitly not executed. Source/runtime11 match exact native output; all20 new array/byte loads have checked predecessors. C695/C696 focused candidates only; final gates remain pending.')
    return native


if __name__ == '__main__':
    verify()
