"""Exercise real Windows UTF-8 conversion with bounded simulated console writes."""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


source, output = Path(sys.argv[1]), Path(sys.argv[2])
text = source.read_text(encoding='utf-8-sig')
assert text.count('@sollang_stdout_line_buffered = global i1 false') == 1
text = text.replace('@sollang_stdout_line_buffered = global i1 false', '@sollang_stdout_line_buffered = global i1 true')
assert '@sollang_write_stream(' in text
text += '''
define i32 @exercise_console(ptr %data, i64 %length) {
entry:
  %written = alloca i32
  %ok = call i32 @sollang_write_stream(ptr inttoptr (i64 11 to ptr), ptr %data, i64 %length, ptr %written, i1 true)
  ret i32 %ok
}
'''
output.mkdir(parents=True, exist_ok=False)
llvm = output / 'console.ll'
llvm.write_text(text, encoding='utf-8')
harness = ROOT / 'scripts/probes/windows-output-console.c'
clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
pins = {str(path.resolve()): sha(path) for path in [source, Path(__file__), llvm, harness, clang, ROOT / 'scripts/verification_execution.py']}
record = {'schemaVersion': 1, 'status': 'running', 'scope': 'Real MultiByteToWideChar and heap APIs, simulated full/partial console writes; <=one MiB+16 source bytes. UTF-8 3/4-byte boundaries, invalid sequences and failure/free controls.', 'inputHashes': pins, 'completed': 0, 'total': 23, 'claimsGoalComplete': False}
execution = VerificationExecution(ROOT, output, record, lambda: all(sha(path) == digest for path, digest in pins.items()), sha)
error = None
try:
    exe = output / 'console.exe'
    build = execution.run([str(clang), '-O0', '-Wno-override-module', str(llvm), str(harness), '-o', str(exe)], output / 'build', timeout=30)
    assert build.returncode == 0 and not build.stderr.strip(), build.stderr
    run = execution.run([str(exe)], output / 'run', timeout=10)
    expected = [f'{kind}:{mode}:1:1:1' for mode in range(2) for kind in range(8)] + ['8:0:0:1:1', '9:0:0:1:1'] + [f'1:{mode}:0:1:1' for mode in range(2, 7)]
    actual = run.stdout.replace('\r\n', '\n').splitlines()
    record.update(actual=actual, expected=expected, runExit=run.returncode, completed=sum(a == b for a, b in zip(actual, expected)))
    assert run.returncode == 0 and not run.stderr.strip() and actual == expected, 'CONSOLE_UTF8_OR_PROGRESS_OR_RELEASE_ORACLE_FAILED'
    record['status'] = 'passed'
except BaseException as exc:
    error = exc
finally:
    execution.finalize(error, cleanup=False)
print(json.dumps({key: record.get(key) for key in ['status', 'completed', 'total', 'inputsStable', 'processesStopped', 'failure']}))
if record['status'] != 'passed':
    raise SystemExit(1)
