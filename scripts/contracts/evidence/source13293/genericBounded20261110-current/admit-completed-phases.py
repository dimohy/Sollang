"""Admit this completed build without rewriting its failed harness result."""
from pathlib import Path
import hashlib
import json
import runpy
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution

base = Path(__file__).resolve().parent
raw_path = base / 'native-build01/result.json'
raw = json.loads(raw_path.read_text(encoding='utf-8-sig'))
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
assert raw['status'] == 'failed'
assert raw['failure'] == 'AssertionError: SOURCE_LINK_PARTITION_OUTPUT_INVALID'
assert raw['inputsStable'] is True and raw['processesStopped'] is True
assert not raw.get('activeProcess')
runner = ROOT / 'scripts/build-focused-source-emitter.py'
archive = base / 'build-focused-source-emitter.before.py'
assert sha(archive) == raw['inputHashes'][str(runner)]
pins = {}
for name, expected in raw['inputHashes'].items():
    path = Path(name)
    assert path == runner or sha(path) == expected, name
    pins[name] = sha(path)
for phase, budget in [('emit', 180), ('grammar', 30), ('link', 240)]:
    matches = [p for p in raw['processes']
               if Path(p['stdoutPath']).name == phase + '.stdout']
    assert len(matches) == 1
    process = matches[0]
    assert process['exit'] == 0 and process['shutdownConfirmed'] is True
    assert process['durationMilliseconds'] <= budget * 1000
    for channel in ('stdout', 'stderr'):
        path = Path(process[channel + 'Path'])
        assert sha(path) == process[channel + 'Sha256']
        if channel == 'stderr':
            assert path.read_bytes() == b''
        pins[str(path)] = sha(path)
compiler = base / 'managed-build02/compiler/Sollang.Compiler.dll'
emission = json.loads((raw_path.parent / 'emit.stdout').read_text(encoding='utf-8-sig'))
llvm = raw_path.parent / 'program.ll'
assert emission['status'] == 'passed' and emission['warnings'] == []
assert emission['compilerAssemblySha256'] == sha(compiler)
assert emission['outputSha256'] == sha(llvm)
validate = runpy.run_path(str(runner))['validate_link_output']
link = validate((raw_path.parent / 'link.stdout').read_text(encoding='utf-8-sig'),
                sha(compiler), '-O2', 24)
product = raw_path.parent / 'compiler.exe'
assert sha(product) == raw['generatedOutputHashes'][str(product)]
for path in (Path(__file__), archive, raw_path, llvm, product,
             ROOT / 'scripts/verification_execution.py', ROOT / 'scripts/verification_source_proof.py'):
    pins[str(path)] = sha(path)
output = base / 'native-admission01'
reusable = [base / 'managed-build02',
            ROOT / 'artifacts/scratch/resume-20261106-review/bounded-operands-native-build01',
            ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22/v20050/compiler-build01']
with VerificationContractLease(list(map(Path, pins))):
    initialize_output(ROOT, output, reusable_directories=reusable)
    output.mkdir()
    copied = output / 'compiler.exe'
    shutil.copyfile(product, copied)
    assert sha(copied) == sha(product)
    fingerprint = hashlib.sha256(json.dumps(dict(inputs=pins, optimization='O2', jobs=24,
        target='windows-x64'), sort_keys=True, separators=(',', ':')).encode()).hexdigest().upper()
    result = dict(schemaVersion=1, status='running', completed=0, total=1,
        scope='Completed production phase admission; compiler behavior and final gates pending.',
        inputHashes=pins, inputHashesStart=pins, inputHashesEnd=pins,
        inputFingerprint=fingerprint, finalInputFingerprint=fingerprint,
        inputFingerprintKind='sha256-canonical-input-json-v1',
        originalFailedResult=str(raw_path), originalFailurePreserved=True,
        phaseMode='admitted-completed-separated-phases', emission=emission, link=link,
        originalCombinedBudgetPassed=False, compilerProduct=str(copied), product=str(copied),
        productSha256=sha(copied), compilerSha256=sha(copied), claimsGoalComplete=False)
    execution = VerificationExecution(ROOT, output, result,
        lambda: all(sha(path) == value for path, value in pins.items()), sha)
    error = None
    try:
        done = execution.run([str(copied), '--version'], output / 'version', timeout=30)
        assert done.returncode == 0 and done.stderr == ''
        assert done.stdout.strip() == 'Sollang 0.4.260817', done.stdout
        result.update(status='passed', completed=1,
                      cases=[dict(id='completed-phase-admission', passed=True)])
    except BaseException as caught:
        error = caught
        raise
    finally:
        execution.finalize(error, cleanup=False)
print(json.dumps({key: result[key] for key in ('status', 'completed', 'total',
    'inputsStable', 'processesStopped', 'compilerSha256')}))
