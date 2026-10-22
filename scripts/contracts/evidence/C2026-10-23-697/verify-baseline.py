from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent


def blocks(text):
    current = None
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*:', line):
            current = line[:-1]
        if ' = alloca ' in line:
            result[line.split(' = ', 1)[0]] = current
    return result


def verify():
    baseline = json.loads((HERE / 'baseline12580.json').read_text(encoding='utf-8-sig'))
    normal = baseline['normalBaseline']
    assert normal['status'] == 'passed' and normal['completed'] == normal['total'] == 1
    assert normal['inputsStable'] and normal['processesStopped']
    assert normal['cases'][0]['stdout'] == normal['cases'][0]['expectedStdout']
    windows = (HERE / 'windows-emitted-before.ll').read_text(encoding='utf-8-sig')
    linux = (HERE / 'linux-before.ll').read_text(encoding='utf-8-sig')
    assert blocks(windows) == {'%removed': 'wait', '%completion_flags': 'resolve_failure'}
    assert blocks(linux) == {'%wakeup_value': 'drain_wakeup'}
    assert 'br label %wait' in windows and 'br label %wait' in linux
    assert 'stackrestore' not in windows + linux
    print('Baseline normal1 passed; fixed scratch3 emitted in cyclic Windows/Linux waiter blocks. No exhaustion executed.')


if __name__ == '__main__':
    verify()
