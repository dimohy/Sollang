from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def verify():
    contract = read(HERE / 'baseline-contract12549.json')
    managed = read(HERE / contract['managed'])
    native = read(HERE / contract['native'])
    assert managed['status'] == native['status'] == 'passed'
    assert managed['completed'] == managed['total'] == native['completed'] == native['total'] == 3
    assert managed['inputsStable'] and native['inputsStable']
    assert managed['processesStopped'] and native['processesStopped']
    for source in contract['sources']:
        assert hashlib.sha256((ROOT / source['source']).read_bytes()).hexdigest().upper() == source['sha256']
    for row in managed['cases']:
        case = row['id']
        match = next(item for item in native['cases'] if item['id'] == case)
        assert row['stdout'] == match['stdout'] == row['expectedStdout']
        assert row['runExit'] == match['runExit'] == 0
        assert row['stderr'] == match['stderr'] == ''
        before = (HERE / 'baseline-native' / case / 'emitted.llvm.txt').read_text(encoding='utf-8-sig')
        pointers = re.findall(r'(%v\d+_expression\d+)_ptr = getelementptr i32,', before)
        assert pointers
        for prefix in pointers:
            assert prefix + ' = load i32, ptr ' + prefix + '_ptr' in before
            assert prefix + '_in_bounds = icmp' not in before
            assert prefix + '_length = extractvalue' not in before
        csharp = (HERE / 'csharp' / case / 'emitted.llvm.txt').read_text(encoding='utf-8-sig')
        assert re.search(r'icmp ult i64 .*\n\s+br i1 .*bounds_ok', csharp)
    print('CSharp/native normal programs3/3; actual native interpolation array loads lack the checked-access branch present in CSharp. No invalid index executed.')


if __name__ == '__main__':
    verify()
