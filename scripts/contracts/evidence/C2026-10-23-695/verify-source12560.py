from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def stable(record):
    assert record['inputsStable'] and record['processesStopped']
    for name, expected in record['inputHashes'].items():
        assert sha(Path(name)) == expected, name


def checked_array_loads(llvm, expected_count):
    pointers = re.findall(r'(%v(\d+)_expression(\d+))_ptr = getelementptr i32,', llvm)
    assert len(pointers) == expected_count, (len(pointers), expected_count)
    for prefix, label, node in pointers:
        valid = f'interpolation{label}_array{node}_valid'
        invalid = f'interpolation{label}_array{node}_invalid'
        assert re.search(re.escape(prefix) + r'_index = sext i32 .* to i64', llvm)
        assert prefix + '_length = extractvalue ' in llvm
        assert f'{prefix}_in_bounds = icmp ult i64 {prefix}_index, {prefix}_length' in llvm
        edge = f'br i1 {prefix}_in_bounds, label %{valid}, label %{invalid}'
        assert edge in llvm
        assert llvm.count('label %' + valid + '\n') == 0
        # One predecessor and a terminal failed edge make the checked block
        # dominate its element address/load. llvm-as checks SSA and LLVM types.
        assert llvm.count('label %' + valid + ',') + llvm.count('label %' + valid + '\n') == 1
        block = re.search(re.escape(invalid) + r':\n(.*?)' + re.escape(valid) + r':\n(.*?)(?=\n[^ ;\n][^\n]*:|\n})', llvm, re.S)
        assert block
        assert re.fullmatch(r'\s*call void @llvm.trap\(\)\s+unreachable\s*', block[1])
        assert f'{prefix}_data, i64 {prefix}_index' in block[2]
        assert f'{prefix} = load i32, ptr {prefix}_ptr' in block[2]


def verify():
    source = read(BASE / 'source12551-source/result.json')
    runtime = read(BASE / 'source12552-runtime/result.json')
    contract = read(BASE / 'source12551-contract.json')
    assert source['status'] == runtime['status'] == 'passed'
    assert source['completed'] == source['total'] == 43
    assert runtime['completed'] == runtime['total'] == 37
    stable(source)
    stable(runtime)
    assert source['producerBuildCount'] == 1
    assert sum(bool(row.get('admissionRejected')) for row in source['cases']) == 6
    counts = {'interpolation-array-index': 6, 'interpolation-reference-index': 2, 'interpolation-index-order': 4}
    for case, expected_count in counts.items():
        row = next(item for item in source['cases'] if item['id'] == case)
        assert row['status'] == 'passed' and row['assemblyExit'] == row['emissionExit'] == 0
        llvm_path = BASE / 'source12551-source' / case / 'emitted.ll'
        assert sha(llvm_path) == row['emittedLlvmSha256']
        checked_array_loads(llvm_path.read_text(encoding='utf-8-sig'), expected_count)
        run = next(item for item in runtime['cases'] if item['id'] == case)
        expected = next(item for item in contract['cases'] if item['id'] == case)
        assert run['stdout'] == expected['stdout'] and run['stderr'] == ''
    print('Source43/43 and normal runtime37/37; all12 new interpolation array loads have a checked predecessor and terminal trap edge. Fresh native and final gates remain separate.')


if __name__ == '__main__':
    verify()
