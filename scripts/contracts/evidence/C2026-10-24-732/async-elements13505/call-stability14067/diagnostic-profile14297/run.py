"""Temporary single-attempt observer for the source-owned context clone."""
import argparse
import hashlib
import json
import re
import sys
import threading
import time
from pathlib import Path

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / 'scripts'))
from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution
from verification_json_records import write_json_atomic

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--semantic-proof', type=Path, required=True)
args = parser.parse_args()
base = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'
source = base / 'context-profile14291'
plan_path = source / 'plan.json'
plan = json.loads(plan_path.read_text())
output = args.output.resolve()
proof_path = args.semantic_proof.resolve()
proof = json.loads(proof_path.read_text())
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
assert proof['status'] == 'passed' and proof['completed'] == proof['total'] == 4
assert proof['codegenInvoked'] is False and proof['inputsStable'] and proof['processesStopped']
assert not output.exists()
canonical = Path(plan['source']).read_text()
start = canonical.index('prepareResolvedSnapshot request:')
original = canonical[start:canonical.index('\nprepare request:', start)].rstrip()
profile = (source / 'profile.slg').read_text()
start = profile.index('profileResolvedSnapshot request:')
body = profile[start:profile.index('\npublic profileResolvedFiles', start)].rstrip().split('\n', 1)[1]
unmarked = '\n'.join(line for line in body.splitlines() if not re.fullmatch(r'    "[a-z0-9-]+" -> profileMark', line))
assert original.split('\n', 1)[0] + '\n' + unmarked == original
assert sha(source / 'profile.slg') == plan['generatedProfileSha256']
assert sha(source / 'main.slg') == plan['generatedMainSha256']
contract = json.loads((base / 'context13817-contract.json').read_text())
sources = [source / 'main.slg', source / 'profile.slg', *(ROOT / path for path in contract['cases'][0]['additionalSources'])]
pins = dict(plan['inputHashes'])
pins.update(json.loads((base / 'v14280/compiler-build01/result.json').read_text())['inputHashesEnd'])
pins.update(proof['inputHashes'])
for path in [plan_path, proof_path, Path(__file__).resolve(), source / 'generate.py']:
    pins[str(path)] = sha(path)

def stable():
    return all(Path(path).is_file() and sha(path) == digest for path, digest in pins.items())

assert stable()
initialize_output(ROOT, output, reusable_directories=[base / 'v12432/compiler-build01', base / 'v14112/compiler-build01', base / 'v14280/compiler-build01'])
output.mkdir()
record = dict(schemaVersion=1, status='running', scope='temporary-context-stage-profile-diagnostic-only', completed=0, total=2, inputHashes=pins, buildMaximumSeconds=180, runtimeMaximumSeconds=180, maximumBuildInvocations=1, maximumRuntimeInvocations=1, semanticOnlyPreflight=str(proof_path), claimsOriginal1290Passed=False, claimsGoalComplete=False)
execution = VerificationExecution(ROOT, output, record, stable, sha)
execution.save()
stop = threading.Event()
observations = []
observer_errors = []
seen = 0
observer_started = 0.0

def read_markers():
    global seen
    path = output / 'runtime.stderr'
    if not path.exists():
        return
    content = path.read_text(encoding='utf-8-sig')
    lines = content.splitlines()
    if content and not content.endswith('\n'):
        lines = lines[:-1]
    if len(lines) < seen:
        raise ValueError('PROFILE_TRACE_TRUNCATED')
    for line in lines[seen:]:
        match = re.fullmatch(r'context-stage ([a-z0-9-]+)', line)
        if match is None:
            raise ValueError('PROFILE_TRACE_UNEXPECTED_LINE: ' + line)
        observations.append(dict(stage=match.group(1), observedAtElapsedMilliseconds=round((time.perf_counter() - observer_started) * 1000, 3)))
    if len(lines) > seen:
        write_json_atomic(output / 'stage-observations.json', dict(scope='sampled-observations-not-exact-call-entry-time', nominalPollMilliseconds=100, markers=observations))
    seen = len(lines)

def observe():
    try:
        while True:
            read_markers()
            if stop.wait(0.1):
                break
    except (OSError, UnicodeDecodeError, ValueError) as error:
        observer_errors.append(type(error).__name__ + ': ' + str(error))

error = None
observer = None
started = time.perf_counter()
try:
    executable = output / 'probe.exe'
    command = [str(base / 'managed13673/compiler/Sollang.Compiler.exe'), 'build', *map(str, sources), '-o', str(executable), '--target', 'windows-x64', '--keep-temps', '-O2', '--jobs', '4', '--llvm', str(ROOT / '.tools/llvm-22.1.8')]
    process = execution.run(command, output / 'build', timeout=180)
    record['buildExit'] = process.returncode
    record['buildStderr'] = (output / 'build.stderr').read_text(encoding='utf-8-sig')
    if process.returncode != 0 or record['buildStderr']:
        raise ValueError('PROFILE_BUILD_REJECTED')
    record['completed'] = 1
    pins[str(executable)] = sha(executable)
    record['executableSha256'] = pins[str(executable)]
    execution.save()
    budget = min(180, 360 - (time.perf_counter() - started))
    if budget <= 0:
        raise ValueError('PROFILE_PIPELINE_BUDGET_EXHAUSTED')
    record['runtimeBudgetSeconds'] = budget
    observer_started = time.perf_counter()
    observer = threading.Thread(target=observe, daemon=True)
    observer.start()
    process = execution.run([str(executable), *plan['paths']], output / 'runtime', timeout=budget)
    record['runtimeExit'] = process.returncode
    stdout = (output / 'runtime.stdout').read_text(encoding='utf-8-sig')
    record['runtimeStdout'] = stdout
    if process.returncode != 0 or stdout.strip() != 'profile diagnostics = 0':
        raise ValueError('PROFILE_RUNTIME_NOT_COMPLETE')
    stop.set()
    observer.join()
    read_markers()
    if observer_errors:
        raise ValueError('PROFILE_OBSERVER_FAILED: ' + str(observer_errors))
    record.update(status='passed', completed=2)
except BaseException as caught:
    error = caught
finally:
    stop.set()
    if observer is not None:
        observer.join()
        try:
            read_markers()
        except (OSError, UnicodeDecodeError, ValueError) as caught:
            observer_errors.append(type(caught).__name__ + ': ' + str(caught))
    record['observedStageMarkers'] = observations
    record['observerErrors'] = observer_errors
    if error is None and observer_errors:
        error = ValueError('PROFILE_OBSERVER_FAILED: ' + str(observer_errors))
    execution.finalize(error, cleanup=False)
print(json.dumps(dict(status=record['status'], completed=record['completed'], buildExit=record.get('buildExit'), buildStderr=record.get('buildStderr'), markers=observations[-3:])))
if error is not None:
    sys.exit(1)
