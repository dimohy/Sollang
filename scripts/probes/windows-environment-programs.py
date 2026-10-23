"""Run ordinary and parallel environment programs with synthetic child values."""
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


normal, parallel, output = map(Path, sys.argv[1:4])
runner = ROOT / 'scripts/probes/run-environment-fixture.py'
settings = ROOT / 'examples/regression/expected/84-process-environment.env.txt'
expected_normal = (ROOT / 'examples/regression/expected/84-process-environment.stdout.txt').read_text(encoding='utf-8-sig')
expected_parallel = 'count=64\n' + '24\n' * 64
pins = {str(p.resolve()): sha(p) for p in [normal, parallel, runner, settings, Path(__file__),
    ROOT / 'examples/regression/expected/84-process-environment.stdout.txt',
    ROOT / 'scripts/probes/windows-environment-parallel.slg',
    ROOT / 'examples/regression/84-process-environment.slg', ROOT / 'scripts/verification_execution.py']}
output.mkdir(parents=True, exist_ok=False)
record = dict(schemaVersion=1, status='running', completed=0, total=2,
              scope='Original84 and public parallel callback with 64 synthetic UTF8 lookups; '
                    'all 64 returned byte lengths checked. Allocation retention tested separately.',
              inputHashes=pins, claimsGoalComplete=False)
execution = VerificationExecution(ROOT, output, record,
                                  lambda: all(sha(p) == value for p, value in pins.items()), sha)
error = None
try:
    for name, program, arguments, expected in [
        ('normal', normal, [], expected_normal),
        ('parallel', parallel, ['synthetic'] * 63, expected_parallel)]:
        run = execution.run([sys.executable, '-X', 'utf8', str(runner), str(program),
                             str(settings), *arguments], output / name, timeout=15)
        assert run.returncode == 0 and not run.stderr.strip() and run.stdout == expected, \
            'ENVIRONMENT_PROGRAM_ORACLE_FAILED:' + name + ':' + run.stdout[:200]
        record['completed'] += 1
    record['status'] = 'passed'
except BaseException as exc:
    error = exc
finally:
    execution.finalize(error, cleanup=False)
print(json.dumps({key: record.get(key) for key in
                  ['status', 'completed', 'total', 'inputsStable', 'processesStopped', 'failure']}))
if record['status'] != 'passed':
    raise SystemExit(1)
