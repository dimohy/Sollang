from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def functions(text):
    return {m[0].split('\n', 1)[0]: m[0] for m in
            re.finditer(r'^define [^\n]+\{\n.*?^}', text, re.M | re.S)}


def storage(text):
    block = None
    rows = []
    for line in text.splitlines():
        if re.match(r'^[\w.$-]+:', line):
            block = line.split(':', 1)[0]
        if re.search(r'%each\d+_(?:index|limit)_slot = (?:alloca|getelementptr)', line):
            rows.append((block, line.strip()))
    return rows


def without_cursor_allocations(text):
    return [line.strip() for line in text.splitlines()
            if not re.search(r'%each\d+_(?:index|limit)_slot = alloca', line)]


def verify():
    for name, count in [('scratch12595-managed', 5), ('scratch12595-native', 5),
                        ('scratch12597-managed', 1), ('scratch12597-native', 1),
                        ('scratch12598-managed', 2)]:
        d = read(HERE / (name + '.json'))
        assert d['status'] == 'passed' and d['completed'] == d['total'] == count
        assert d['inputsStable'] and d['processesStopped']
        for row in d['cases']:
            assert row['passed'] and row['stdout'] == row['expectedStdout']
    for epoch in [12595, 12597]:
        a = read(HERE / f'scratch{epoch}-managed.json')
        b = read(HERE / f'scratch{epoch}-native.json')
        assert [r['stdout'] for r in a['cases']] == [r['stdout'] for r in b['cases']]
    slots = []
    for case in ['range', 'array', 'text', 'repeat', 'arguments']:
        slots.extend(storage((HERE / (case + '-baseline-functions.ll')).read_text(encoding='utf-8-sig')))
    assert len(slots) == 14 and sum(block != 'entry' for block, _ in slots) == 7
    async_slots = storage((HERE / 'async-baseline-functions.ll').read_text(encoding='utf-8-sig'))
    assert len(async_slots) == 4
    assert all(block == 'entry' and 'getelementptr i8, ptr %async_context,' in line for block, line in async_slots)
    print('C698 CSharp normal8 and original native normal6 pass;14 direct cursor slots include7 cyclic allocations. Async Task slots4 preserved. No exhaustion executed.')


if __name__ == '__main__':
    verify()
