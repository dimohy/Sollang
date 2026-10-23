from pathlib import Path
import hashlib, json, sys

root = Path.cwd()
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution
from verification_source_proof import current_build_inputs

base = root / 'artifacts/scratch/resume-20261006-owner-continuation22'
mode = sys.argv[1]
assert mode in ('managed', 'native')
plan_path = base / 'retained13255-plan.json'
plan = json.loads(plan_path.read_text(encoding='utf-8-sig'))
out = base / ('retained13255-' + mode)
out.mkdir(exist_ok=False)
compiler = (base / 'managed13239/compiler/Sollang.Compiler.exe' if mode == 'managed'
            else base / 'v13220/compiler-build01/compiler.exe')

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()

paths = [plan_path, Path(__file__), root / 'scripts/verification_execution.py', compiler,
         *sorted((root / 'stdlib').rglob('*.slg')),
         *[root / source for case in plan['cases'] for source in case['sources']]]
if mode == 'managed':
    paths += list(compiler.parent.glob('Sollang.Compiler.*'))
else:
    managed = base / 'retained13255-managed/result.json'
    proof = json.loads(managed.read_text(encoding='utf-8-sig'))
    assert proof['status'] == 'passed' and proof['completed'] == proof['total'] == 10
    assert proof['inputsStable'] and proof['processesStopped']
    assert all(Path(p).is_file() and sha(p) == h for p, h in proof['inputHashes'].items())
    comparison = base / 'retained13256-source-comparison.json'
    compared = json.loads(comparison.read_text(encoding='utf-8-sig'))
    assert compared['status'] == 'compared-before-slg-edit'
    assert all(sha(root / p) == h for p, h in compared['sourceHashes'].items())
    build = compiler.parent / 'result.json'
    record = json.loads(build.read_text(encoding='utf-8-sig'))
    assert record['status'] == 'passed' and record['inputsStable']
    assert record['compilerSha256'] == sha(compiler)
    paths += [managed, comparison, build, *current_build_inputs(root, record)]
pins = {str(p): sha(p) for p in paths}
result = dict(schemaVersion=1, status='running', mode=mode, completed=0, total=10,
              inputHashes=pins, compilerSha256=sha(compiler), cases=[],
              budget=dict(buildSeconds=120, runSeconds=10, retries=0),
              scope=plan['scope'], claimsGoalComplete=False)
execution = VerificationExecution(root, out, result,
    lambda: all(Path(p).is_file() and sha(p) == h for p, h in pins.items()), sha)
error = None
try:
    for case in plan['cases']:
        folder = out / case['id']
        folder.mkdir()
        exe = folder / 'probe.exe'
        row = dict(id=case['id'], status='running', expectedExit=case['expectedExit'])
        result['cases'].append(row)
        execution.save()
        command = [str(compiler), 'build', *[str(root / p) for p in case['sources']],
                   '-o', str(exe), '--target', 'windows-x64', '--keep-temps', '--jobs', '1',
                   '--llvm', str(root / '.tools/llvm-22.1.8'), '-O0']
        if mode == 'native':
            command += ['--stdlib', str(root / 'stdlib')]
        process = execution.run(command, folder / 'build', timeout=120)
        row.update(buildExit=process.returncode, buildStderr=process.stderr)
        assert process.returncode == case['expectedExit'], case['id'] + ': build exit ' + process.stderr
        assert process.stderr.replace('\r\n', '\n') == case['expectedBuildStderr'], case['id'] + ': diagnostic ' + repr(process.stderr)
        if case['expectedExit']:
            assert not process.stdout and not exe.exists(), case['id'] + ': rejected output'
        else:
            process = execution.run([str(exe)], folder / 'run', timeout=10)
            row.update(runExit=process.returncode, runStdout=process.stdout, runStderr=process.stderr)
            assert process.returncode == 0 and not process.stderr, case['id'] + ': run'
            assert process.stdout.replace('\r\n', '\n') == case['expectedStdout'], case['id'] + ': stdout'
        row.update(status='passed', passed=True)
        result['completed'] += 1
        execution.save()
        print(case['id'], 'PASS', flush=True)
    result['status'] = 'passed'
except BaseException as caught:
    error = caught
finally:
    execution.finalize(error, cleanup=False)
print(json.dumps({k: result.get(k) for k in ('status','completed','total','inputsStable','processesStopped','failure')}))
sys.exit(0 if result['status'] == 'passed' else 1)
