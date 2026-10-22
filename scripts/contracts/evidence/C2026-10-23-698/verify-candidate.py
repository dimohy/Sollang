from pathlib import Path
from importlib.util import module_from_spec, spec_from_file_location
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = spec_from_file_location('baseline698', HERE / 'verify-baseline.py')
baseline = module_from_spec(spec)
spec.loader.exec_module(baseline)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def verify():
    q = read(HERE / 'qualification12610.json')
    assert q['CSharp'] == q['SLGSource'] == q['freshNative'] == [8, 8]
    assert q['combined'] == [24, 24] and q['compilerBuildCount'] == 1
    records = {}
    for row in q['records']:
        path = HERE / row['path']
        assert sha(path) == row['sha256']
        records[row['id']] = read(path)
    for key, count in [('scratch12604-source', 8), ('scratch12607-runtime', 8), ('native12609', 8)]:
        d = records[key]
        assert d['status'] == 'passed' and d['completed'] == d['total'] == count
        assert d['inputsStable'] and d['processesStopped']
    managed = {}
    for name in ['scratch12595-managed', 'scratch12597-managed', 'scratch12598-managed']:
        d = read(HERE / (name + '.json'))
        for row in d['cases']:
            assert row['passed'] and row['stdout'] == row['expectedStdout']
            managed[row['id']] = row
    for d in [records['scratch12607-runtime'], records['native12609']]:
        for row in d['cases']:
            assert row['passed'] and row['runExit'] == 0
            assert row['stdout'].replace('\r\n', '\n') == managed[row['id']]['expectedStdout']
            assert not row['stderr']
    counts = {'range': 4, 'array': 2, 'text': 3, 'repeat': 2, 'arguments': 3,
              'async': 0, 'map-control': 0, 'map-maximum': 0}
    observed = {}
    for row in q['llvm']:
        path = HERE / row['functions']
        assert sha(path) == row['sha256']
        text = path.read_text(encoding='utf-8-sig')
        slots = baseline.storage(text)
        stack = [s for s in slots if ' = alloca ' in s[1]]
        persistent = [s for s in slots if 'getelementptr i8, ptr %async_context,' in s[1]]
        assert len(stack) == counts[row['case']]
        assert all(block == 'entry' for block, _ in slots)
        assert len(persistent) == (4 if row['case'] == 'async' else 0)
        functions = baseline.functions(text)
        original = HERE / (row['case'] + '-baseline-functions.ll')
        if original.exists():
            for key, body in baseline.functions(original.read_text(encoding='utf-8-sig')).items():
                assert key in functions
                assert baseline.without_cursor_allocations(body) == baseline.without_cursor_allocations(functions[key])
        observed.setdefault(row['backend'], set()).add(row['case'])
    assert observed == {'source': set(counts), 'native': set(counts)}
    build = read(HERE / 'native12608-build-result.json')
    assert build['status'] == 'passed' and build['inputsStable']
    assert build['inputHashesStart'] == build['inputHashesEnd']
    assert build['compilerSha256'] == q['nativeCompilerSha256']
    for name, expected in q['canonicalSourceHashes'].items():
        assert sha(ROOT / name) == expected
    assert q['noExhaustionTest'] and not q['claimsGoalComplete']
    print('C698 CSharp8/source8/fresh-native8 qualified:14 fixed cursor slots in entry,4 Task slots preserved, planned streams excluded;6 baseline function groups identical except allocation placement. Focused candidate only.')


if __name__ == '__main__':
    verify()
