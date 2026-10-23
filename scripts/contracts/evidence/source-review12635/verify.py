"""Verify the preserved C699-C701 focused epoch without rebuilding products."""
from pathlib import Path
import hashlib
import json
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def allocations(text):
    result = {}
    function = block = ''
    for line in text.splitlines():
        if line.startswith('define '):
            function = line
        if re.match(r'^[\w.$-]+:', line):
            block = line.split(':', 1)[0]
        if ' = alloca ' in line:
            key = (function, line.strip().split(' = ', 1)[0])
            assert key not in result
            result[key] = (block, line.strip())
    return result


def bool_rewrite(text):
    prefixes = re.findall(r'  (%\w+)_buffer = alloca \[5 x i8\], align 1', text)
    for prefix in prefixes:
        lines = [f'  {prefix}_buffer = alloca [5 x i8], align 1',
                 f'  {prefix}_ptr = getelementptr [5 x i8], ptr {prefix}_buffer, i64 0, i64 0']
        for i, a, b in [(0, 116, 102), (1, 114, 97), (2, 117, 108), (3, 101, 115)]:
            lines.append(f'  {prefix}_byte{i} = select i1 {prefix}_value, i8 {a}, i8 {b}')
        lines.append(f'  store i8 {prefix}_byte0, ptr {prefix}_ptr, align 1')
        for i in range(1, 5):
            lines.append(f'  {prefix}_ptr{i} = getelementptr i8, ptr {prefix}_ptr, i64 {i}')
            value = f'{prefix}_byte{i}' if i < 4 else '101'
            lines.append(f'  store i8 {value}, ptr {prefix}_ptr{i}, align 1')
        old = '\n'.join(lines)
        assert text.count(old) == 1, prefix
        new = f'  {prefix}_ptr = select i1 {prefix}_value, ptr @sollang_bool_true_bytes, ptr @sollang_bool_false_bytes'
        text = text.replace(old, new)
    return text, len(prefixes)


def normalized(text):
    return [line.strip() for line in text.splitlines() if ' = alloca ' not in line]


def verify(phase, defect):
    assert defect in ['C2026-10-23-699', 'C2026-10-23-700', 'C2026-10-23-701']
    b = read(HERE / 'baseline12635.json')
    managed = read(HERE / 'csharp12620-all-proof.json')
    assert managed['status'] == 'passed' and managed['completed'] == managed['total'] == 15
    assert managed['inputsStable'] and managed['processesStopped']
    oracles = {row['id']: row for row in managed['cases']}
    for row in oracles.values():
        assert row['passed'] and row['runExit'] == 0 and not row['stderr']
        assert row['stdout'].replace('\r\n', '\n') == row['expectedStdout']
    originals = {}
    for row in b['cases']:
        path = HERE / row['functions']
        assert sha(path) == row['sha256']
        originals[row['id']] = path.read_text(encoding='utf-8-sig')
        d = read(HERE / row['originalResult'])
        assert d['status'] == 'passed' and d['inputsStable'] and d['processesStopped']
        case = next(case for case in d['cases'] if case['id'] == row['id'])
        assert case['passed'] and case['runExit'] == 0 and not case['stderr']
        assert case['stdout'].replace('\r\n', '\n') == oracles[row['id']]['expectedStdout']
    ordinary = parser = bool_count = 0
    for text in originals.values():
        _, count = bool_rewrite(text)
        bool_count += count
        for _, instruction in allocations(text).values():
            if re.match(r'%v\d+_owner = alloca %sollang.bounded_dictionary|%bidx\d+_owner = alloca', instruction):
                ordinary += 1
            if re.match(r'%v\d+_expression\d+_(?:logical_slot|owner|data) = alloca|%interpolation\d+_try\d+_(?:slot|return_slot) = alloca|%iset\d+_\d+_query_addr = alloca', instruction):
                parser += 1
    assert (ordinary, parser, bool_count) == (9, 10, 4), (ordinary, parser, bool_count)
    if phase == 'baseline':
        print(f'{defect}: CSharp15 and preserved original native14 pass; dictionary9, parser10 and Boolean4 fixed storage sites identified. No exhaustion test.')
        return
    assert phase == 'candidate'
    q = read(HERE / 'qualification12635.json')
    assert q['CSharp'] == q['SLGSource'] == q['SLGNormalRuntime'] == q['freshNative'] == [15, 15]
    assert q['combined'] == [45, 45] and q['compilerBuildCount'] == 1
    for row in q['records']:
        p = HERE / row['path']
        assert sha(p) == row['sha256']
        d = read(p)
        if row['id'] in ['source', 'runtime', 'native']:
            assert d['status'] == 'passed' and d['completed'] == d['total'] == 15
            assert d['inputsStable'] and d['processesStopped']
        if row['id'] in ['runtime', 'native']:
            for case in d['cases']:
                assert case['passed'] and case['runExit'] == 0 and not case['stderr']
                assert case['stdout'].replace('\r\n', '\n') == oracles[case['id']]['expectedStdout']
    for row in q['llvm']:
        assert row['booleanGlobals'] == [
            '@sollang_bool_true_bytes = private constant [4 x i8] c"true"',
            '@sollang_bool_false_bytes = private constant [5 x i8] c"false"']
        path = HERE / row['functions']
        assert sha(path) == row['sha256']
        text = path.read_text(encoding='utf-8-sig')
        assert 'alloca [5 x i8]' not in text
        if row['id'] not in originals:
            continue
        old = originals[row['id']]
        expected, _ = bool_rewrite(old)
        assert normalized(expected) == normalized(text), (row['backend'], row['id'], 'non-allocation instructions changed')
        before, after = allocations(old), allocations(text)
        removed = {key for key, (_, line) in before.items() if 'alloca [5 x i8]' in line}
        extra = set(after) - (set(before) - removed)
        if row['id'] == 'interpolation-stream':
            assert len(extra) == 1 and next(iter(extra))[1] == '%v118111_expression0_logical_slot'
            assert after[next(iter(extra))][0] == 'entry'
        else:
            assert not extra, extra
        assert set(before) - set(after) == removed
        for key in set(before) & set(after):
            block, instruction = before[key]
            fixed = bool(re.match(r'%v\d+_owner = alloca %sollang.bounded_dictionary|%bidx\d+_owner = alloca|%v\d+_expression\d+_(?:logical_slot|owner|data) = alloca|%interpolation\d+_try\d+_(?:slot|return_slot) = alloca|%iset\d+_\d+_query_addr = alloca', instruction))
            assert after[key] == ('entry' if fixed else block, instruction), (row['id'], key)
    for path, expected in q['canonicalSourceHashes'].items():
        assert sha(ROOT / path) == expected, path
    assert len(q['llvm']) == 30
    print(f'{defect}: CSharp15/source15/fresh native15 pass (45/45); normal source runtime15 also passes. Dictionary9/parser10 entry slots, Boolean4 immutable byte selections, all other user-function instructions preserved. Final gates pending.')


if __name__ == '__main__':
    verify(*sys.argv[1:])
