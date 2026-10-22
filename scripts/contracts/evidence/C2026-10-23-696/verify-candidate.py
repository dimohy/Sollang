from pathlib import Path
import hashlib
import importlib.util
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'
SPEC = importlib.util.spec_from_file_location('array_proof', HERE.parent / 'C2026-10-23-695/verify-candidate.py')
arrays = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(arrays)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def checked_byte_loads(llvm, expected_count):
    pointers = re.findall(r'(%v(\d+)_expression(\d+))_address = getelementptr i8,', llvm)
    assert len(pointers) == expected_count, (len(pointers), expected_count)
    assert 'extractvalue ptr' not in llvm
    for prefix, label, node in pointers:
        valid = f'interpolation{label}_byte{node}_valid'
        invalid = f'interpolation{label}_byte{node}_invalid'
        assert re.search(re.escape(prefix) + r'_index = add i64 0, ', llvm)
        assert prefix + '_length = extractvalue ' in llvm
        assert f'{prefix}_in_bounds = icmp ult i64 {prefix}_index, {prefix}_length' in llvm
        assert f'br i1 {prefix}_in_bounds, label %{valid}, label %{invalid}' in llvm
        assert llvm.count('label %' + valid + ',') == 1
        block = re.search(re.escape(invalid) + r':\n(.*?)' + re.escape(valid) + r':\n(.*?)(?=\n[^ ;\n][^\n]*:|\n})', llvm, re.S)
        assert block
        assert re.fullmatch(r'\s*call void @llvm.trap\(\)\s+unreachable\s*', block[1])
        assert f'{prefix}_base, i64 {prefix}_index' in block[2]
        assert f'{prefix} = load i8, ptr {prefix}_address' in block[2]


def verify():
    arrays.verify()
    source = read(BASE / 'source12570-source/result.json')
    runtime = read(BASE / 'source12571-runtime/result.json')
    contract = read(BASE / 'source12570-contract.json')
    managed = read(HERE / 'csharp12560.json')
    expected_counts = {'text-byte': 1, 'source-text-byte': 1, 'text-byte-contexts': 2,
                       'reference-text-byte': 2, 'computed-text-byte': 1}
    assert managed['status'] == 'passed' and managed['completed'] == managed['total'] == 5
    for expected in managed['cases']:
        case = expected['id']
        assert hashlib.sha256((ROOT / expected['source']).read_bytes()).hexdigest().upper() == expected['sourceSha256']
        row = next(item for item in source['cases'] if item['id'] == case)
        assert row['status'] == 'passed' and row['assemblyExit'] == row['emissionExit'] == 0
        llvm = (BASE / 'source12570-source' / case / 'emitted.ll').read_text(encoding='utf-8-sig')
        checked_byte_loads(llvm, expected_counts[case])
        if case == 'reference-text-byte':
            assert re.search(r'_source = load %sollang.text, ptr %arg', llvm)
            assert re.search(r'_source = load %sollang.mapped_bytes, ptr %arg', llvm)
        run = next(item for item in runtime['cases'] if item['id'] == case)
        assert run['passed'] and run['runExit'] == 0 and run['stdout'] == expected['stdout'] and run['stderr'] == ''
        declared = next(item for item in contract['cases'] if item['id'] == case)
        assert declared['stdout'] == expected['stdout']
    boundary = 'text-byte-wide-literal'
    declared = next(item for item in contract['cases'] if item['id'] == boundary)
    assert declared['compileOnly'] and declared['runtimeRequired'] is False
    row = next(item for item in source['cases'] if item['id'] == boundary)
    assert row['status'] == 'passed' and row['assemblyExit'] == row['emissionExit'] == 0
    llvm = (BASE / 'source12570-source' / boundary / 'emitted.ll').read_text(encoding='utf-8-sig')
    checked_byte_loads(llvm, 1)
    assert re.search(r'_index = add i64 0, 4294967296\n', llvm)
    managed_boundary = (HERE / 'width12566/managed.llvm.txt').read_text(encoding='utf-8-sig')
    assert 'icmp ult i64 4294967296, 3' in managed_boundary
    assert runtime['runtimeSkipped'] == [{'id': boundary, 'status': 'skipped-not-tested',
                                          'reason': 'Explicit compile-only UIntSize boundary; no invalid index executed.'}]
    assert not any(item['id'] == boundary for item in runtime['cases'])
    print('C696 current source/runtime5 match CSharp5. Seven byte loads have checked predecessors; readonly carriers load canonical values and computed receivers define valid byte SSA. Native/final qualification remains separate.')
    print('UIntSize2^32 compilation-only boundary retains i64 index and checked access; its runtime is explicitly skipped-not-tested.')


if __name__ == '__main__':
    verify()
