"""Run the emitted allocation tracker unchanged under bounded Windows threads."""
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


source, output = map(Path, sys.argv[1:3])
text = source.read_text(encoding='utf-8-sig')
functions = []
for name, result in [('sollang_track_environment_allocation', 'i1'),
                     ('sollang_dispose_environment', 'void')]:
    match = re.search(r'^[ \t]*define internal ' + result + ' @' + name +
                      r'\([^\n]+\{\r?\n.*?^[ \t]*}', text, re.M | re.S)
    assert match, name
    functions.append(match.group().replace(' #0 {', ' {'))
original = '\n\n'.join(functions)
bound = original
for name in ['sollang_alloc', 'malloc']:
    bound = bound.replace('@' + name + '(', '@probe_alloc(')
for name in ['sollang_free', 'free']:
    bound = bound.replace('@' + name + '(', '@probe_free(')
header = '''@sollang_environment_allocations = global ptr null, align 8
declare ptr @probe_alloc(i64)
declare void @probe_free(ptr)
'''
wrapper = '''
define i8 @observe_track(ptr %allocation) {
  %ok = call i1 @sollang_track_environment_allocation(ptr %allocation)
  %byte = zext i1 %ok to i8
  ret i8 %byte
}
define ptr @observe_head() {
  %head = load ptr, ptr @sollang_environment_allocations, align 8
  ret ptr %head
}
define void @observe_dispose() {
  call void @sollang_dispose_environment()
  ret void
}
'''
output.mkdir(parents=True, exist_ok=False)
(output / 'production-helpers.ll.txt').write_bytes(original.encode())
llvm = output / 'tracker.ll'
llvm.write_bytes((header + bound + wrapper).encode())
clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
harness = Path(__file__).with_suffix('.c')
pins = {str(p.resolve()): sha(p) for p in [source, Path(__file__), llvm, harness,
                                         clang, ROOT / 'scripts/verification_execution.py']}
record = dict(schemaVersion=1, status='running', completed=0, total=1,
              scope='Exact emitted tracker/disposer; allocator/release observation bindings; '
                    '8 joined Windows threads, 1024 allocations each; no environment API substitution needed.',
              inputHashes=pins, claimsGoalComplete=False)
execution = VerificationExecution(ROOT, output, record,
                                  lambda: all(sha(p) == value for p, value in pins.items()), sha)
error = None
try:
    exe = output / 'tracker.exe'
    build = execution.run([str(clang), '-O0', '-Wno-override-module', str(llvm),
                           str(harness), '-o', str(exe)], output / 'build', timeout=30)
    assert build.returncode == 0 and not build.stderr.strip(), build.stderr
    run = execution.run([str(exe)], output / 'run', timeout=30)
    expected = 'accepted=8192 retained=8192 nodes=8192 payloads=8192 errors=0'
    record.update(actual=run.stdout.strip(), expected=expected, runExit=run.returncode)
    assert run.returncode == 0 and not run.stderr.strip() and run.stdout.strip() == expected, \
        'ENVIRONMENT_CONCURRENT_OWNERSHIP_FAILED'
    record.update(status='passed', completed=1)
except BaseException as exc:
    error = exc
finally:
    execution.finalize(error, cleanup=False)
print(json.dumps({key: record.get(key) for key in
                  ['status', 'completed', 'total', 'actual', 'inputsStable', 'processesStopped', 'failure']}))
if record['status'] != 'passed':
    raise SystemExit(1)
