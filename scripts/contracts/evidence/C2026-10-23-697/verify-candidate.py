from pathlib import Path
import hashlib
import json

from importlib.util import module_from_spec, spec_from_file_location

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = spec_from_file_location('baseline697', HERE / 'verify-baseline.py')
baseline = module_from_spec(spec)
spec.loader.exec_module(baseline)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def verify():
    q = read(HERE / 'qualification12593.json')
    assert q['CSharp'] == q['SLGSource'] == q['freshNative'] == [3, 3]
    assert q['combined'] == [9, 9] and q['compilerBuildCount'] == 1
    assert q['noExhaustionTest'] and not q['claimsGoalComplete']
    records = {}
    for row in q['records']:
        path = HERE / row['path']
        assert sha(path) == row['sha256']
        records[row['id']] = read(path)
    for key in ['waiter12582-managed', 'waiter12592-native']:
        d = records[key]
        assert d['status'] == 'passed' and d['completed'] == d['total'] == 1
        assert d['inputsStable'] and d['processesStopped']
        assert d['cases'][0]['stdout'] == d['cases'][0]['expectedStdout']
    assert records['waiter12582-managed']['cases'][0]['stdout'] == records['waiter12592-native']['cases'][0]['stdout']
    for managed, native in [('waiter12583-w07', 'waiter12592-w07'), ('waiter12584-l07', 'waiter12592-l07')]:
        a, b = records[managed], records[native]
        for d in [a, b]:
            assert d['status'] == 'passed' and d['inputStable'] and not d['failureIds']
            assert d['compileDiagnosticsClean'] and d['irAssertions']['waiterScratchInEntry']
            assert d['run']['exitCode'] == 0 and d['run']['peerObservedEof']
            assert not d['orphanProcessIds']
        assert a['run']['stdout'] == b['run']['stdout']
    source = records['waiter12587-source']
    assert source['status'] == 'passed' and source['completed'] == source['total'] == 3
    assert source['inputsStable'] and source['processesStopped']
    for row in source['cases']:
        assert row['status'] == 'passed' and row['assemblyExit'] == 0
    functions = {}
    for row in q['llvm']:
        path = HERE / row['function']
        assert sha(path) == row['functionSha256']
        text = path.read_text(encoding='utf-8-sig')
        expected = {'%removed': 'entry', '%completion_flags': 'entry'} if row['platform'] == 'windows' else {'%wakeup_value': 'entry'}
        assert baseline.blocks(text) == expected
        if row['platform'] == 'windows':
            assert text.count('store i32 0, ptr %removed, align 4') == 1
            assert text.count('store i32 0, ptr %completion_flags, align 4') == 1
        normalized = [line.strip() for line in text.splitlines()]
        if row['platform'] in functions:
            assert functions[row['platform']] == normalized
        functions[row['platform']] = normalized
    for name, expected in q['canonicalSourceHashes'].items():
        assert sha(ROOT / name) == expected
    print('C697 CSharp3/source3/fresh-native3 qualified; identical full waiter functions, fixed scratch in entry and per-use reset preserved. Focused candidate only.')


if __name__ == '__main__':
    verify()
