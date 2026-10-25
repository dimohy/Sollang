"""Observe one mechanically checked context clone using current pinned inputs."""
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
from completed_artifact_plan import initialize_output, cleanup_output
from verification_source_proof import current_build_inputs
from verification_execution import VerificationExecution
from context_profile_source_contract import validate_loader
from verification_json_records import write_json_atomic

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-directory', type=Path, required=True)
parser.add_argument('--build', type=Path, required=True)
parser.add_argument('--managed-compiler', type=Path, required=True)
parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--semantic-proof', type=Path, required=True)
args = parser.parse_args()
base = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'
source = args.source_directory.resolve()
build = args.build.resolve()
managed = args.managed_compiler.resolve()
reusable = [item.resolve() for item in args.reusable_directory]
plan_path = source / 'plan.json'
plan = json.loads(plan_path.read_text(encoding='utf-8-sig'))
output = args.output.resolve()
proof_path = args.semantic_proof.resolve()
proof = json.loads(proof_path.read_text(encoding='utf-8-sig'))
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
assert proof['status'] == 'passed' and proof['completed'] == proof['total'] == 4
assert proof['codegenInvoked'] is False and proof['inputsStable'] and proof['processesStopped']
assert not output.exists()
canonical = Path(plan['source']).read_text(encoding='utf-8-sig')
start = canonical.index('prepareResolvedSnapshot request:')
original = canonical[start:canonical.index('\nprepare request:', start)].rstrip()
profile = (source / 'profile.slg').read_text(encoding='utf-8-sig')
start = profile.index('profileResolvedSnapshot request:')
body = profile[start:profile.index('\npublic profileResolvedFiles', start)].rstrip().split('\n', 1)[1]
unmarked = '\n'.join(line for line in body.splitlines() if not re.fullmatch(r'    "[a-z0-9-]+" -> profileMark', line))
assert original.split('\n', 1)[0] + '\n' + unmarked == original
assert sha(source / 'profile.slg') == plan['generatedProfileSha256']
assert sha(source / 'main.slg') == plan['generatedMainSha256']
sources = [Path(path).resolve() for path in plan['harnessSources']]
if any(not path.is_relative_to(ROOT) or not path.is_file() for path in sources):
    raise ValueError('PROFILE_HARNESS_SOURCE_MISSING')
if len(sources) != len(set(sources)) or sources[:2] != [source / 'main.slg', source / 'profile.slg']:
    raise ValueError('PROFILE_HARNESS_ORDER_INVALID')
if 'verifiedStandardLibraryPrefixCount' in plan:
    prefix_count = plan['verifiedStandardLibraryPrefixCount']
    runtime_paths = [Path(path).resolve() for path in plan['paths']]
    stdlib_root = Path(plan['standardLibraryRoot']).resolve()
    stdlib = set((ROOT / 'stdlib').rglob('*.slg'))
    if (stdlib_root != (ROOT / 'stdlib').resolve() or type(prefix_count) is not int
            or prefix_count != len(stdlib) or set(runtime_paths[:prefix_count]) != stdlib):
        raise ValueError('PROFILE_STDLIB_PREFIX_MISMATCH')
validate_loader(profile, plan.get('verifiedStandardLibraryPrefixCount'))
pins = dict(plan['inputHashes'])
build_record = json.loads((build / 'result.json').read_text(encoding='utf-8-sig'))
for path in current_build_inputs(ROOT, build_record):
    digest = sha(path)
    if str(path) in pins and pins[str(path)] != digest:
        raise ValueError('PROFILE_PLAN_BUILD_INPUT_MISMATCH: ' + str(path))
    pins[str(path)] = digest
for path, digest in proof['inputHashes'].items():
    if path in pins and pins[path] != digest:
        raise ValueError('PROFILE_SEMANTIC_INPUT_MISMATCH: ' + path)
    pins[path] = digest
for path in sources:
    if proof['inputHashes'].get(str(path.resolve())) != sha(path):
        raise ValueError('PROFILE_SOURCE_NOT_SEMANTICALLY_QUALIFIED: ' + str(path))
if not plan['mechanicalBodyIdentityVerified'] or plan['maximumBuildInvocations'] != 1 or plan['maximumInvocations'] != 1:
    raise ValueError('PROFILE_SINGLE_ATTEMPT_CONTRACT_REQUIRED')
if plan['buildMaximumSeconds'] != 180 or plan['maximumSeconds'] != 180:
    raise ValueError('PROFILE_ORIGINAL_180S_REQUIRED')
for path in [managed, managed.with_suffix('.dll'), managed.with_suffix('.deps.json'), managed.with_suffix('.runtimeconfig.json')]:
    if proof['inputHashes'].get(str(path)) != sha(path):
        raise ValueError('PROFILE_MANAGED_COMPILER_NOT_QUALIFIED: ' + str(path))
for path in [plan_path, proof_path, Path(__file__).resolve(), Path(plan.get('generator', source / 'generate.py')),
             ROOT / 'scripts/verification_execution.py', ROOT / 'scripts/verification_json_records.py',
             ROOT / 'scripts/completed_artifact_plan.py', ROOT / 'scripts/context_profile_source_contract.py', ROOT / '.tools/llvm-22.1.8/bin/clang.exe']:
    pins[str(path)] = sha(path)

def stable():
    return all(Path(path).is_file() and sha(path) == digest for path, digest in pins.items())

assert stable()
initialize_output(ROOT, output, reusable_directories=reusable)
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
    command = [str(managed), 'build', *map(str, sources), '-o', str(executable), '--target', 'windows-x64', '--keep-temps', '-O2', '--jobs', '4', '--llvm', str(ROOT / '.tools/llvm-22.1.8')]
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

cleanup_output(ROOT, output, execute=True, reusable_directories=reusable)
