"""Bind Windows environment algorithm equality before costly compiler builds."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]


def body(text):
    match = re.search(r'^[ \t]*define internal %sollang.environment_result @sollang_environment\([^\n]+\{\r?\n.*?^[ \t]*}', text, re.M | re.S)
    assert match, 'ENVIRONMENT_HELPER_MISSING'
    value = match.group().replace(' #0 {', ' {').replace('@sollang_alloc(', '@malloc(').replace('@sollang_free(', '@free(')
    return '\n'.join(line.strip() for line in value.splitlines())


def verify(managed, selfhost):
    windows = selfhost.split('public emitLinuxRuntime', 1)[0]
    assert body(managed) == body(windows), 'WINDOWS_ENVIRONMENT_BODY_DRIFT'
    code = body(managed)
    prefix = code.split('validate:', 1)[0]
    assert '%name_fits_i32 = icmp ule i64 %name_len, 2147483647' in prefix, 'NAME_WIDTH_BEFORE_SCAN_GUARD_MISSING'
    assert '%zero_error = phi i32 [ %last_error, %zero_result ], [ %value_error, %free_wide_empty ]' in code
    assert '%empty_succeeded = icmp eq i32 %zero_error, 0' in code
    assert code.count('call void @SetLastError(i32 0)') == 2
    read = code.split('value_read:', 1)[1].split('free_wide_empty:', 1)[0]
    assert read.index('@GetEnvironmentVariableW') < read.index('@GetLastError') < read.index('@free')


if __name__ == '__main__':
    managed = (ROOT / 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig')
    selfhost = (ROOT / 'selfhost/llvm/emitter/environment_runtime.slg').read_text(encoding='utf-8-sig')
    verify(managed, selfhost)
    stale = selfhost.replace('%empty_succeeded = icmp eq i32 %zero_error, 0', '%empty_succeeded = icmp ne i32 %zero_error, 203', 1)
    try:
        verify(managed, stale)
    except AssertionError:
        print('Current environment bodies/guards passed; stale zero-error classification rejected.')
    else:
        raise AssertionError('STALE_BODY_WAS_ACCEPTED')
