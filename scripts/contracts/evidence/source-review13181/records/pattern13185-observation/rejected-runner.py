from pathlib import Path
import sys, json, hashlib
root = Path.cwd()
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution
from verification_stdlib_source_preflight import validate
b = root / 'artifacts/scratch/resume-20261006-owner-continuation22'
out = b / 'pattern13185-observation'
out.mkdir(exist_ok=False)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler = b / 'managed13056/compiler/Sollang.Compiler.exe'
assert sha(compiler.with_suffix('.dll')) == '8310858A4407EF263ACE7292A2CF1EA70FB018DB6520E450CC100F2BE777394D'
manifest = root / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
canonical = [root / line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
pre = b / 'literal13140-preflight/result.json'
previous = json.loads(pre.read_text(encoding='utf-8-sig'))
assert previous['status'] == 'passed' and previous['inputsStable'] and previous['processesStopped']
for p in canonical: assert previous['inputHashes'][str(p)] == sha(p), str(p)
stdlib = b / 'literal13142-stdlib/result.json'
stdlib_validation = validate(root, stdlib)
contract = b / 'pattern13183-contract.json'
proof = b / 'pattern13183-managed/result.json'
managed = json.loads(proof.read_text(encoding='utf-8-sig'))
assert managed['status'] == 'passed' and managed['completed'] == managed['total'] == 3 and managed['inputsStable'] and managed['processesStopped']
for p,h in managed['inputHashes'].items(): assert sha(p) == h, p
cases = json.loads(contract.read_text(encoding='utf-8-sig'))['cases']
observer = root / 'scripts/probes/typed-pattern-scope/phase-observer.slg'
sources = [observer] + canonical[1:]
harness = b / 'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
inputs = sources + [root/c['source'] for c in cases] + [manifest, pre, stdlib, contract, proof, Path(__file__)] + list(compiler.parent.glob('Sollang.Compiler.*')) + list(harness.parent.glob('SemanticPreflight.*')) + list((root/'stdlib').rglob('*.slg'))
pins = {str(p):sha(p) for p in inputs if p.is_file()}
r = {'schemaVersion':1,'status':'running','scope':'Unmodified current SLG semantic and phase0/final3 observation for three accepted CSharp controls; no fallback reachability, compiler acceptance or phase closure claim from execution alone.','inputHashes':pins,'completed':0,'total':3,'cases':[],'stdlibPreflight':stdlib_validation,'budget':{'producerBuilds':1,'frontendSeconds':60,'buildSeconds':180,'caseSeconds':60,'retryCount':0},'claimsGoalComplete':False}
x = VerificationExecution(root, out, r, lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()), sha)
error = None
try:
    a = x.run([str(harness),str(compiler.with_suffix('.dll')),*map(str,sources)],out/'frontend',timeout=60)
    if a.returncode or a.stderr.strip(): raise ValueError('PATTERN_OBSERVER_FRONTEND_FAILED '+a.stderr[:1500])
    f = json.loads(a.stdout)
    assert not f['warnings'] and not f['codegenInvoked'] and f['sourceCount']==151
    r['frontend'] = f
    x.save()
    exe = out/'observer.exe'
    a = x.run([str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')],out/'build',timeout=180)
    if a.returncode or a.stderr.strip(): raise ValueError('PATTERN_OBSERVER_BUILD_FAILED '+a.stderr[:1500])
    r['observerSha256'] = sha(exe)
    x.save()
    for c in cases:
        folder = out/c['id']; folder.mkdir()
        a = x.run([str(exe),c['source']],folder/'observe',timeout=60)
        row = {'id':c['id'],'exit':a.returncode,'stdoutSha256':sha(folder/'observe.stdout'),'stderrSha256':sha(folder/'observe.stderr')}
        r['cases'].append(row); x.save()
        if a.returncode or a.stderr.strip() or not a.stdout.rstrip().endswith('observed-phases=2'): raise ValueError('PATTERN_OBSERVATION_FAILED '+c['id']+' '+a.stderr[:500])
        row['status'] = 'observed'; r['completed'] += 1; x.save()
    r['status'] = 'passed'
except BaseException as e: error = e
finally: x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if r['status']!='passed': raise SystemExit(1)
