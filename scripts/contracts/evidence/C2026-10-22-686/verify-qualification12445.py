"""Check actual preserved focused executions; no compiler/program reruns."""
from pathlib import Path
import hashlib
import json
import sys

E = Path(__file__).resolve().parent
ROOT = E.parents[3]
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))
def require(record, total):
    assert record['status'] == 'passed'
    assert record['completed'] == record['total'] == total
    assert record['inputsStable'] and record['processesStopped']

contract = read(E / 'input-contract.json')
expected = {case['id']: case for case in contract['cases']}
assert len(expected) == 11
records = [read(E / name / 'result.json') for name in (
    'input12436-managed', 'input12441-input-runtime02', 'native12444-input-runtime')]
for record in records:
    require(record, 11)
    assert record['passed'] == 11
    assert {case['id'] for case in record['cases']} == set(expected)
    for case in record['cases']:
        wanted = expected[case['id']]
        assert case['passed'] and case['runExit'] == wanted['exit']
        assert case['stdout'].replace('\r\n', '\n') == wanted['stdout']
        assert case['stderr'].replace('\r\n', '\n') == wanted['stderr']
before = read(E / 'input12436-native-baseline/result.json')
assert before['completed'] == before['total'] == 11
assert before['passed'] == 4 and before['inputsStable'] and before['processesStopped']
misses = [case for case in before['cases'] if not case['passed']]
assert len(misses) == 7 and all(case['runExit'] == 0 for case in misses)
source_sha = hashlib.sha256((E / 'read.slg').read_bytes()).hexdigest().upper()
assert source_sha == read(E / 'baseline.json')['inputFingerprint']
managed_build = read(E / 'csharp-read-build.json')
assert managed_build['status'] == 'passed' and managed_build['inputsStable']
assert source_sha in managed_build['inputHashes'].values()
require(read(E / 'native12444-qualification/result.json'), 1)
qualification = read(E / 'native-qualification12445.json')
assert qualification['nativeReadBodyMatchesSourceExceptModuleSymbol'] is True
assert qualification['compilerSha256'] == read(E / 'native12443/result.json')['compilerSha256']
branch = read(E / 'input12441-read-branches02/result.json')
require(branch, 2)
metric = {'metric': 'misses', 'missKind': 'incorrect-success-on-invalid-input',
          'before': len(misses), 'after': sum(not case['passed'] for case in records[-1]['cases']),
          'genuineBaselineProgramExit': 0, 'candidateFailureProgramExit': 1,
          'sourceSha256': source_sha,
          'scope': 'Same frozen Linux readInt program. Seven prior input failures incorrectly continued and exited0; candidate rejects them before downstream value output. No runtime speed or final-goal claim.'}
if len(sys.argv) > 1 and sys.argv[1] == 'measurement':
    print(json.dumps(metric))
else:
    print(json.dumps({'CSharp': 11, 'SLGSource': 11, 'readBranchControls': 2,
                      'freshNativeInput': 11, 'freshNativeWindows': 1,
                      'distinctFreshNativeRuntime': 12, 'claimsGoalComplete': False,
                      'measurement': metric}))
