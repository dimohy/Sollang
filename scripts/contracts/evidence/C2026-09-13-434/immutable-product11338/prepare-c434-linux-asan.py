"""Temporary C434 object preparation driver; remove after immutable gate closure.
Reuse existing supervisor; runtime execution remains under Linux supervisor.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution

p = argparse.ArgumentParser()
p.add_argument('--build', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
build, out = a.build.resolve(), a.output.resolve()
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proof = build / 'result.json'
pd = json.loads(proof.read_text(encoding='utf-8-sig'))
assert pd['status'] == 'passed' and pd['inputsStable']
compiler = build / 'compiler.exe'
cases = [
    {'id': 'native-capacity-close-child', 'source': 'scripts/probes/async-task-observability/capacity-close-child.slg', 'expectedStdout': 'closed\n7'},
    {'id': 'native-runtime-file-task-inheritance', 'source': 'scripts/probes/async-task-observability/runtime-file-task-inheritance.slg', 'expectedStdout': '110\ntracked=2 untracked=0'},
]
pins = dict(pd['inputHashesStart'])
pins.update({str(p): sha(p) for p in [proof, compiler, Path(__file__), root / '.tools/llvm-22.1.8/bin/llvm-nm.exe', *(root / c['source'] for c in cases)]})
stable = lambda: all(Path(p).is_file() and sha(p) == h.upper() for p, h in pins.items())
assert stable()
out.mkdir(exist_ok=False)
r = {'schemaVersion': 1, 'status': 'running', 'completed': 0, 'total': 2, 'inputHashes': pins, 'cases': [], 'scope': 'Current immutable native Linux ASan object preparation; actual Linux execution separate', 'nativeCompilerSha256': sha(compiler)}
ex = VerificationExecution(root, out, r, stable, sha)
error = None
try:
    for case in cases:
        folder = out / case['id']
        folder.mkdir()
        cp = ex.run([str(compiler), 'linux-stdlib', str(root / 'stdlib'), str(root / case['source'])], folder / 'emit', timeout=180)
        assert cp.returncode == 0 and not cp.stderr, (cp.returncode, cp.stderr)
        raw = folder / 'raw.ll'
        raw.write_text(cp.stdout, encoding='utf-8')
        lines, count = [], 0
        for line in cp.stdout.splitlines():
            if line.startswith('define '):
                opening, depth, closing = line.index('(', line.index('@')), 0, None
                for i in range(opening, len(line)):
                    if line[i] == '(':
                        depth += 1
                    elif line[i] == ')':
                        depth -= 1
                        if depth == 0:
                            closing = i
                            break
                assert closing is not None
                brace = line.index('{', closing + 1)
                line = line[:brace] + 'sanitize_address ' + line[brace:]
                count += 1
            lines.append(line)
        ll, obj = folder / 'instrumented.ll', folder / 'instrumented.o'
        ll.write_text('\n'.join(lines) + '\n', encoding='utf-8')
        for cmd, name in [([str(root / '.tools/llvm-22.1.8/bin/llvm-as.exe'), str(ll), '-o', str(folder / 'instrumented.bc')], 'as'), ([str(root / '.tools/llvm-22.1.8/bin/clang.exe'), '--target=x86_64-unknown-linux-gnu', '-O0', '-fsanitize=address', '-fno-omit-frame-pointer', '-c', str(ll), '-o', str(obj)], 'object')]:
            cp = ex.run(cmd, folder / name, timeout=60)
            assert cp.returncode == 0, (name, cp.stderr)
        cp = ex.run([str(root / '.tools/llvm-22.1.8/bin/llvm-nm.exe'), '--undefined-only', str(obj)], folder / 'nm', timeout=30)
        assert cp.returncode == 0 and '__asan_report_load' in cp.stdout and '__asan_report_store' in cp.stdout
        r['cases'].append({**case, 'status': 'passed', 'instrumentedFunctionCount': count, 'asanLoadStoreReferencesVerified': True, 'rawLlvmSha256': sha(raw), 'instrumentedLlvmSha256': sha(ll), 'instrumentedObjectSha256': sha(obj)})
        r['completed'] += 1
        ex.save()
    r['status'] = 'passed'
except BaseException as e:
    error = e
finally:
    ex.finalize(error, cleanup=False)
print(json.dumps({k: r.get(k) for k in ['status', 'completed', 'failure', 'inputsStable', 'processesStopped']}))
if error:
    raise error
