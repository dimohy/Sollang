"""Replay the preserved C702-C705 focused proof without rebuilding products."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location('previous_proof', HERE.parent / 'source-review12635/verify.py')
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)
read, allocations = previous.read, previous.allocations


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def integer_slot(line):
    return bool(re.match(r'%(?:calltext|materialize)\d+_.*_buffer = alloca \[21 x i8\], align 1', line.strip()))


def without_integer_slots(text):
    return [line.strip() for line in text.splitlines() if not integer_slot(line)]


def verify(phase, defect):
    assert defect in ['C2026-10-23-'+str(i) for i in range(702,706)]
    b = read(HERE / 'baseline12648.json')
    managed = read(HERE / 'csharp12648-proof.json')
    assert managed['status'] == 'passed' and managed['completed'] == managed['total'] == 20
    assert managed['inputsStable'] and managed['processesStopped']
    oracles = {row['id']: row['stdout'].replace('\r\n', '\n') for row in managed['cases']}
    assert len(oracles) == 20
    for row in managed['cases']:
        assert row['passed'] and row['runExit'] == 0 and not row['stderr']
    originals = {}
    slots = []
    for row in b['llvm'] + b['retainedNative']:
        p = HERE / row['functions']
        assert sha(p) == row['sha256']
        text = p.read_text(encoding='utf-8-sig')
        originals[row['id']] = text
        slots += [a for a in allocations(text).values() if integer_slot(a[1])]
    assert len(originals) == 16 and len(slots) == 24 and all(block != 'entry' for block, _ in slots)
    for name in ['scratch12643-native', 'scratch12645-native', 'scratch12672-native']:
        d = read(HERE / (name + '-result.json'))
        assert d['inputsStable'] and d['processesStopped']
        for row in d['cases']:
            if row.get('passed'):
                assert row['runExit'] == 0 and not row['stderr']
                assert row['stdout'].replace('\r\n', '\n') == oracles[row['id']]
    assert len(b['failedLlvm']) == 2
    for row in b['failedLlvm']:
        p = HERE / row['functions']
        assert sha(p) == row['sha256'] and row['badTextExtractions'] > 0
        assert 'extractvalue %sollang.text %stream' in p.read_text(encoding='utf-8-sig')
    before_semantic = (HERE / 'records/diagnostic12671/run.stdout').read_text()
    after_semantic = (HERE / 'records/diagnostic12675/run.stdout').read_text()
    assert 'expression=38,type=0,status=0' in before_semantic
    assert 'expression=17,type=2,status=0' in before_semantic
    assert 'expression=38,type=2,status=0' in after_semantic
    failed = read(HERE / 'scratch12680-source-result.json')
    assert failed['status'] == 'failed' and failed['completed'] == 0 and 'multiple definition' in failed['failure']
    diagnostic = read(HERE / 'diagnostic12689-result.json')
    assert diagnostic['status'] == 'passed' and diagnostic['completed'] == diagnostic['total'] == 4
    outcomes = {row['id']: row['assemblyExit'] for row in diagnostic['cases']}
    assert outcomes == {'stream-control-nested': 1, 'stream-role-types': 1, 'integer-stream': 0, 'unit-bool-observation': 0}
    if phase == 'baseline':
        print(f'{defect}: CSharp20 passes; original native16 normal controls retained,24 cyclic integer buffers and2 failed stream type cases preserved. No exhaustion test.')
        return
    assert phase == 'candidate'
    q = read(HERE / 'qualification12695.json')
    assert q['CSharp'] == q['SLGSource'] == q['SLGNormalRuntime'] == q['freshNative'] == [20, 20]
    assert q['combined'] == [60, 60] and q['compilerBuildCount'] == 1 and q['sourceProducerBuildCount'] == 4
    for row in q['records']:
        p = HERE / row['path']
        assert sha(p) == row['sha256']
        d = read(p)
        if row['id'] in ['source', 'runtime', 'native']:
            assert d['status'] == 'passed' and d['completed'] == d['total'] == 20
            assert d['inputsStable'] and d['processesStopped']
        if row['id'] in ['runtime', 'native']:
            for case in d['cases']:
                assert case['passed'] and case['runExit'] == 0 and not case['stderr']
                assert case['stdout'].replace('\r\n', '\n') == oracles[case['id']]
    counts = {'source': 0, 'native': 0}
    covered = {'source': set(), 'native': set()}
    for row in q['llvm']:
        p = HERE / row['functions']
        assert sha(p) == row['sha256']
        text = p.read_text(encoding='utf-8-sig')
        covered[row['backend']].add(row['id'])
        assert 'freeze void' not in text
        stream_headers = re.findall(r'^stream\d+_header:', text, re.M)
        expected_headers = {'stream-control-map': 1, 'stream-control-nested': 2, 'stream-role-types': 4, 'integer-stream': 1, 'interpolation-stream': 1}
        if row['id'] in expected_headers:
            assert len(stream_headers) == len(set(stream_headers)) == expected_headers[row['id']], row['id']
        actual = allocations(text)
        integer = [a for a in actual.values() if integer_slot(a[1])]
        assert all(block == 'entry' for block, _ in integer)
        counts[row['backend']] += len(integer)
        if row['id'] in originals:
            old = originals[row['id']]
            assert without_integer_slots(old) == without_integer_slots(text), (row['backend'], row['id'])
            before = allocations(old)
            assert set(before) == set(actual)
            for key, (block, instruction) in before.items():
                assert actual[key] == ('entry' if integer_slot(instruction) else block, instruction)
        else:
            assert row['id'] in ['integer-stream', 'stream-role-types', 'stream-control-map', 'stream-control-nested']
            assert not re.search(r'extractvalue %sollang.text %stream\d+_item', text)
    assert counts == {'source': 27, 'native': 27}, counts
    assert covered['source'] == covered['native'] == set(oracles)
    for rel, expected in q['canonicalSourceHashes'].items():
        assert sha(ROOT / rel) == expected, rel
    print(f'{defect}: CSharp20/source20/fresh native20 pass60/60, with source runtime20. Integer buffers27 in entry per backend; original16 normal functions otherwise identical. Two stream type failures now assemble and run, including Int8/UInt64/Bool/Text. Final gates remain.')


if __name__ == '__main__':
    verify(*sys.argv[1:])
