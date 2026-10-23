"""Require the same atomic environment ownership publication in both compilers."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]


def tracker(text):
    match = re.search(r'^[ \t]*define internal i1 @sollang_track_environment_allocation'
                      r'\([^\n]+\{\r?\n.*?^[ \t]*}', text, re.M | re.S)
    assert match, 'ENVIRONMENT_TRACKER_MISSING'
    return '\n'.join(line.strip() for line in match.group().replace(' #0 {', ' {')
                     .replace('@sollang_alloc(', '@malloc(').splitlines())


def verify(managed, selfhost):
    code = tracker(managed)
    assert code == tracker(selfhost.split('public emitLinuxRuntime', 1)[0]), 'TRACKER_SOURCE_DRIFT'
    assert 'load atomic ptr, ptr @sollang_environment_allocations acquire, align 8' in code
    assert '%head = phi ptr [ %initial_head, %store ], [ %observed_head, %publish ]' in code
    assert 'cmpxchg ptr @sollang_environment_allocations, ptr %head, ptr %node acq_rel acquire, align 8' in code
    assert 'br i1 %published, label %done, label %publish' in code
    assert code.index('store ptr %allocation') < code.index('cmpxchg')
    assert code.index('store ptr %head, ptr %next_slot') < code.index('cmpxchg')


if __name__ == '__main__':
    managed = (ROOT / 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig')
    selfhost = (ROOT / 'selfhost/llvm/emitter/environment_runtime.slg').read_text(encoding='utf-8-sig')
    verify(managed, selfhost)
    stale = selfhost.replace('label %done, label %publish', 'label %done, label %done', 1)
    try:
        verify(managed, stale)
    except AssertionError:
        print('Atomic tracker source equality passed; discarded-CAS-retry mutation rejected.')
    else:
        raise AssertionError('LOST_RETRY_MUTATION_ACCEPTED')
