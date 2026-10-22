from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def verify():
    baseline = read(HERE / 'baseline-contract12560.json')
    managed = read(HERE / baseline['managed'])
    assert managed['status'] == 'passed' and managed['completed'] == managed['total'] == 5
    assert managed['inputsStable'] and managed['processesStopped']
    for case in baseline['cases']:
        assert hashlib.sha256((ROOT / case['source']).read_bytes()).hexdigest().upper() == case['sourceSha256']
        folder = HERE / 'raw-parents' / Path(case['nativeRawParent']).parts[0]
        raw = read(folder / 'result.json')
        assert raw['inputsStable'] and raw['processesStopped']
        llvm = (HERE / 'native' / case['id'] / 'emitted.llvm.txt').read_text(encoding='utf-8-sig')
        if case['nativeBuildSucceeded']:
            row = next(item for item in raw['cases'] if item['id'] == case['id'])
            assert row['passed'] and row['runExit'] == 0 and row['stdout'] == case['stdout'] and not row['stderr']
            pointers = re.findall(r'(%v\d+_expression\d+)_address = getelementptr i8,', llvm)
            assert pointers
            for prefix in pointers:
                assert prefix + '_in_bounds = icmp' not in llvm
                assert prefix + '_length = extractvalue' not in llvm
        else:
            assert raw['status'] == 'failed' and raw['completed'] == 0
            assert raw['steps'] == []
            if case['id'] == 'reference-text-byte':
                assert 'extractvalue operand must be aggregate type' in raw['failure']
                assert re.search(r'extractvalue ptr %arg, 0', llvm)
            else:
                assert case['id'] == 'computed-text-byte'
                assert 'use of undefined value' in raw['failure']
    print('CSharp5/5; native3 valid byte/slice programs pass without byte guards, readonly/computed receivers produce two retained LLVM build failures. No invalid byte index or failed executable run.')


if __name__ == '__main__':
    verify()
