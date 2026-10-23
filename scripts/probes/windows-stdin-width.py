"""Execute the exact Windows stdin LLVM helper with bounded API substitutes.

This observes transfer counts and error handling, never a multi-gigabyte buffer.
The original helper text is preserved in the result directory before linking.
"""
from pathlib import Path
import hashlib
import json
import re
import sys
import textwrap

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    source, backend, output = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    assert backend in ('managed', 'selfhost')
    name = 'sollang_read_stdin' if backend == 'managed' else 'sollang_runtime_read_standard_input_chunk'
    text = source.read_text(encoding='utf-8-sig')
    match = re.search(r'^[ \t]*define internal (?:i32|i64) @' + name + r'\([^\n]+\{\r?\n.*?^[ \t]*}', text, re.M | re.S)
    assert match, 'PRODUCTION_HELPER_NOT_FOUND'
    original = match.group()
    helper = textwrap.dedent(original).replace(' #0 {', ' {')
    # Keep the production body, remapping only external symbols to avoid
    # colliding with the CRT's imported Windows API symbols at link time.
    for api in ('ReadFile', 'GetLastError', 'GetStdHandle'):
        helper = helper.replace('@' + api + '(', '@probe_' + api + '(')
    output.mkdir(parents=True, exist_ok=False)
    (output / 'production-helper.ll.txt').write_text(original, encoding='utf-8')
    header = '''declare i32 @probe_ReadFile(ptr, ptr, i32, ptr, ptr)
declare i32 @probe_GetLastError()
declare ptr @probe_GetStdHandle(i32)
'''
    if backend == 'managed':
        wrapper = '''define i64 @exercise(i64 %capacity) {
entry:
  %read = alloca i32
  store i32 123, ptr %read
  %ok = call i32 @sollang_read_stdin(ptr null, ptr null, i64 %capacity, ptr %read)
  %success = icmp ne i32 %ok, 0
  %count = load i32, ptr %read
  %wide = zext i32 %count to i64
  %answer = select i1 %success, i64 %wide, i64 -1
  ret i64 %answer
}
'''
    else:
        wrapper = '''define i64 @exercise(i64 %capacity) {
entry:
  %answer = call i64 @sollang_runtime_read_standard_input_chunk(ptr null, i64 %capacity)
  ret i64 %answer
}
'''
    llvm = output / 'probe.ll'
    llvm.write_text(header + helper + '\n' + wrapper, encoding='utf-8')
    harness = output / 'api-substitutes.c'
    harness.write_text('''#include <stdint.h>
#include <stdio.h>
static uint32_t observed, mode;
int32_t probe_ReadFile(void *h, void *data, uint32_t count, uint32_t *read, void *overlapped) {
    observed = count;
    if (mode) return 0;
    *read = count > 7 ? 7 : count;
    return 1;
}
uint32_t probe_GetLastError(void) { return mode == 1 ? 109 : 5; }
void *probe_GetStdHandle(int32_t kind) { return 0; }
extern int64_t exercise(uint64_t capacity);
int main(void) {
    const uint64_t capacities[] = {0, 1, 4096, 2147483648ULL, 4294967295ULL, 4294967296ULL, UINT64_MAX};
    for (unsigned i=0; i<sizeof(capacities)/sizeof(capacities[0]); ++i) {
        int64_t result = exercise(capacities[i]);
        printf("%llu:%u:%lld\\n", (unsigned long long)capacities[i], observed, (long long)result);
    }
    for (mode=1; mode<=2; ++mode) {
        int64_t result = exercise(4096);
        printf("error%u:%lld\\n", mode, (long long)result);
    }
    return 0;
}
''', encoding='utf-8')
    clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
    inputs = [source, Path(__file__), clang, llvm, harness, ROOT / 'scripts/verification_execution.py']
    pins = {str(p.resolve()): sha(p) for p in inputs}
    record = {'schemaVersion': 1, 'status': 'running', 'scope': 'Exact production stdin helper transfer-count and error ABI; substituted APIs, no large allocation or real large IO', 'inputHashes': pins, 'backend': backend, 'completed': 0, 'total': 9, 'claimsGoalComplete': False}
    execution = VerificationExecution(ROOT, output, record, lambda: all(sha(p) == h for p, h in pins.items()), sha)
    error = None
    try:
        exe = output / 'probe.exe'
        build = execution.run([str(clang), '-O0', '-Wno-override-module', str(llvm), str(harness), '-o', str(exe)], output / 'build', timeout=30)
        assert build.returncode == 0 and not build.stderr.strip(), build.stderr
        run = execution.run([str(exe)], output / 'run', timeout=5)
        capacities = [0, 1, 4096, 2147483648, 4294967295, 4294967296, 18446744073709551615]
        expected = [f'{n}:{min(n, 4294967295)}:{min(n, 7)}' for n in capacities] + ['error1:0', 'error2:-1']
        actual = run.stdout.replace('\r\n', '\n').splitlines()
        record.update(actual=actual, expected=expected, runExit=run.returncode)
        record['completed'] = sum(a == b for a, b in zip(actual, expected))
        assert run.returncode == 0 and not run.stderr.strip() and actual == expected, 'TRANSFER_COUNT_OR_ERROR_ORACLE_FAILED'
        record['status'] = 'passed'
    except BaseException as exc:
        error = exc
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({k: record.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped', 'failure']}))
    if record['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
