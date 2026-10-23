"""Check the two production stream algorithms and every Windows direct route."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]


def body(text, name):
    found = re.search(r'^[ \t]*define internal i32 @' + name + r'\([^\n]+\{\r?\n.*?^[ \t]*}', text, re.M | re.S)
    assert found, name
    return '\n'.join(line.strip() for line in found.group().replace(' #0 {', ' {').splitlines())


def verify(managed, selfhost):
    windows = selfhost.split('public emitLinuxTextRuntime', 1)[0]
    for name in ('sollang_write_stream_chunk', 'sollang_write_stream'):
        assert body(managed, name) == body(windows, name), 'SHARED_STREAM_BODY_DRIFT ' + name
    assert '%len32 = trunc i64 %len to i32' not in windows, 'WINDOWS_DIRECT_LENGTH_TRUNCATION'
    assert windows.count('%ok = call i32 @sollang_runtime_write_stdout_all(ptr %handle, ptr %data, i64 %len)') == 3, 'WINDOWS_DIRECT_ROUTE_MISSING'
    assert windows.count('%fits = icmp ule i64 %len, %available') == 2, 'WINDOWS_BUFFER_LENGTH_GUARD_MISSING'
    assert 'sollang_runtime_stdout_written' not in windows, 'SHARED_MUTABLE_WRITE_COUNT'
    assert '%direct_ok = call i32 @sollang_write_stream(ptr %stdout, ptr %data, i64 %len64' in managed


if __name__ == '__main__':
    managed = (ROOT / 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig')
    selfhost = (ROOT / 'selfhost/llvm/emitter/text_output_runtime.slg').read_text(encoding='utf-8-sig')
    verify(managed, selfhost)
    rejected = 0
    for stale in (selfhost.replace('%remaining = sub i64 %len64, %offset', '%remaining = sub i64 %len64, 0', 1), selfhost.replace('%ok = call i32 @sollang_runtime_write_stdout_all(ptr %handle, ptr %data, i64 %len)', '%len32 = trunc i64 %len to i32', 1)):
        try:
            verify(managed, stale)
        except AssertionError:
            rejected += 1
    assert rejected == 2
    print('Production shared bodies/routes passed; stale body and lost full-width route rejected2/2.')
