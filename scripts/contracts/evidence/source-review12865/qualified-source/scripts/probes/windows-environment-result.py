"""Execute bounded environment-result cases and the exact entry dispatch prefix.

The API substitute provides only synthetic data. The seven length observations
execute the emitted pre-validation CFG, with destination labels replaced by
domain markers; no large name is allocated, read, or queried.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


source, output = Path(sys.argv[1]), Path(sys.argv[2])
text = source.read_text(encoding='utf-8-sig')
names = ['sollang_track_environment_allocation', 'sollang_environment', 'sollang_dispose_environment']
functions = []
for name in names:
    match = re.search(r'^[ \t]*define internal (?:i1|void|%sollang.environment_result) @' + name + r'\([^\n]+\{\r?\n.*?^[ \t]*}', text, re.M | re.S)
    assert match, name
    functions.append('\n'.join(line.strip() for line in match.group().replace(' #0 {', ' {').splitlines()))
original = '\n\n'.join(functions)
entry = functions[1].split('entry:', 1)[1].split('validate:', 1)[0]
substituted = original
for name in ['sollang_alloc', 'malloc']:
    substituted = substituted.replace('@' + name + '(', '@probe_alloc(')
for name in ['sollang_free', 'free']:
    substituted = substituted.replace('@' + name + '(', '@probe_free(')
for name in ['SetLastError', 'GetLastError', 'GetEnvironmentVariableW', 'MultiByteToWideChar', 'WideCharToMultiByte']:
    substituted = substituted.replace('@' + name + '(', '@probe_' + name + '(')
header = '''%sollang.environment_result = type { ptr, i64, i1, i1 }
@sollang_environment_allocations = global ptr null
@sollang_environment_empty = constant [1 x i8] zeroinitializer
declare ptr @probe_alloc(i64)
declare void @probe_free(ptr)
declare void @probe_SetLastError(i32)
declare i32 @probe_GetLastError()
declare i32 @probe_GetEnvironmentVariableW(ptr, ptr, i32)
declare i32 @probe_MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)
declare i32 @probe_WideCharToMultiByte(i32, i32, ptr, i32, ptr, i32, ptr, ptr)
'''
wrapper = '''
define void @observe_lookup(ptr %name, i64 %length, ptr %data_slot, ptr %length_slot, ptr %present_slot, ptr %ok_slot) {
entry:
  %value = call %sollang.environment_result @sollang_environment(ptr %name, i64 %length)
  %data = extractvalue %sollang.environment_result %value, 0
  %size = extractvalue %sollang.environment_result %value, 1
  %present = extractvalue %sollang.environment_result %value, 2
  %ok = extractvalue %sollang.environment_result %value, 3
  %present8 = zext i1 %present to i8
  %ok8 = zext i1 %ok to i8
  store ptr %data, ptr %data_slot
  store i64 %size, ptr %length_slot
  store i8 %present8, ptr %present_slot
  store i8 %ok8, ptr %ok_slot
  ret void
}
define void @dispose_lookup() {
entry:
  call void @sollang_dispose_environment()
  ; The production disposer is a one-shot process finalizer. Each independent
  ; harness case starts with a fresh process-global allocation-list context.
  store ptr null, ptr @sollang_environment_allocations
  ret void
}
'''
witness = 'define i32 @observe_entry(i64 %name_len) {\nentry:' + entry + 'validate:\n ret i32 1\nmissing:\n ret i32 0\nerror:\n ret i32 2\n}\n'
output.mkdir(parents=True, exist_ok=False)
(output / 'production-helpers.ll.txt').write_bytes(original.encode())
(output / 'production-entry.ll.txt').write_bytes(entry.encode())
llvm = output / 'environment.ll'
llvm.write_bytes((header + substituted + wrapper + witness).encode())
clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
harness = ROOT / 'scripts/probes/windows-environment-result.c'
pins = {str(path.resolve()): sha(path) for path in [source, Path(__file__), llvm, harness, clang, ROOT / 'scripts/verification_execution.py']}
record = {'schemaVersion': 1, 'status': 'running', 'scope': '17 complete helper synthetic API/UTF8/allocation cases;7 exact emitted pre-validation dispatch witnesses, not whole huge-name executions. Real Windows character conversion, no real environment values queried.', 'inputHashes': pins, 'completed': 0, 'total': 24, 'claimsGoalComplete': False}
execution = VerificationExecution(ROOT, output, record, lambda: all(sha(path) == digest for path, digest in pins.items()), sha)
error = None
try:
    exe = output / 'environment.exe'
    build = execution.run([str(clang), '-O0', '-Wno-override-module', str(llvm), str(harness), '-o', str(exe)], output / 'build', timeout=30)
    assert build.returncode == 0 and not build.stderr.strip(), build.stderr
    run = execution.run([str(exe)], output / 'run', timeout=5)
    outcomes = [(1, 1, 7, 2), (0, 1, 0, 1), (1, 1, 0, 1), (0, 0, 0, 1), (0, 0, 0, 1), (0, 1, 0, 2), (0, 0, 0, 2), (1, 1, 0, 2), (0, 0, 0, 2), (0, 0, 0, 0), (0, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 0), (0, 0, 0, 2), (0, 0, 0, 1), (0, 0, 0, 2), (0, 0, 0, 2)]
    expected = [f'body:{mode}:{found}:{ok}:{length}:1:1:{queries}' for mode, (found, ok, length, queries) in enumerate(outcomes)]
    lengths = [0, 1, 2147483647, 2147483648, 4294967296, 4294967299, 18446744073709551615]
    expected += [f'entry:{length}:{0 if length == 0 else 1 if length <= 2147483647 else 2}' for length in lengths]
    actual = run.stdout.replace('\r\n', '\n').splitlines()
    record.update(actual=actual, expected=expected, runExit=run.returncode, completed=sum(a == b for a, b in zip(actual, expected)))
    assert run.returncode == 0 and not run.stderr.strip() and actual == expected, 'ENVIRONMENT_RESULT_OR_ENTRY_DOMAIN_ORACLE_FAILED'
    record['status'] = 'passed'
except BaseException as exc:
    error = exc
finally:
    execution.finalize(error, cleanup=False)
print(json.dumps({key: record.get(key) for key in ['status', 'completed', 'total', 'inputsStable', 'processesStopped', 'failure']}))
if record['status'] != 'passed':
    raise SystemExit(1)
