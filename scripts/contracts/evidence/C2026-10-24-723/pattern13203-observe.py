from pathlib import Path
import sys, json, hashlib
root = Path.cwd()
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution
b = root / 'artifacts/scratch/resume-20261006-owner-continuation22'
out = b / 'pattern13203-observation'
out.mkdir(exist_ok=False)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler = b / 'managed13056/compiler/Sollang.Compiler.exe'
assert sha(compiler.with_suffix('.dll')) == '8310858A4407EF263ACE7292A2CF1EA70FB018DB6520E450CC100F2BE777394D'
manifest = root / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
canonical = [root / line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
old = json.loads((b/'literal13140-preflight/result.json').read_text(encoding='utf-8-sig'))
changed = root/'selfhost/ir/typed/source_lowering.slg'
before = root/'scripts/contracts/evidence/C2026-10-24-723/source_lowering.before.slg'
assert old['inputHashes'][str(changed)] == sha(before) and sha(changed) != sha(before)
for p in canonical:
    if p != changed: assert old['inputHashes'][str(p)] == sha(p), str(p)
proof = b/'pattern13202-managed/result.json'
mp = json.loads(proof.read_text(encoding='utf-8-sig'))
assert mp['status']=='passed' and mp['completed']==mp['total']==6 and mp['inputsStable'] and mp['processesStopped']
for p,h in mp['inputHashes'].items(): assert sha(p)==h,p
contract = b/'pattern13202-contract.json'
cases = [c for c in json.loads(contract.read_text())['cases'] if c['exit']==0]
assert len(cases)==5
observer = root/'scripts/probes/typed-pattern-scope/phase-observer.slg'
sources = [observer]+canonical[1:]
harness = b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
inputs = sources+[root/c['source'] for c in cases]+[manifest,proof,contract,before,Path(__file__)]+list(compiler.parent.glob('Sollang.Compiler.*'))+list(harness.parent.glob('SemanticPreflight.*'))+list((root/'stdlib').rglob('*.slg'))
pins = {str(p):sha(p) for p in inputs if p.is_file()}
j = {'schemaVersion':1,'status':'running','scope':'Diagnostic-only current SLG phase0/final3 payload observation after C723 source correction. CSharp151-source frontend required before one observer build. No SLG LLVM emission, full stdlib source acceptance, fresh Native or phase closure claimed.','inputHashes':pins,'completed':0,'total':5,'cases':[],'budget':{'observerBuilds':1,'frontendSeconds':60,'buildSeconds':180,'caseSeconds':60,'retryCount':0},'currentFullStdlibSlgPreflight':'pending','claimsCandidateQualified':False,'claimsGoalComplete':False}
x = VerificationExecution(root,out,j,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
error = None
try:
    a = x.run([str(harness),str(compiler.with_suffix('.dll')),*map(str,sources)],out/'frontend',timeout=60)
    if a.returncode or a.stderr.strip(): raise ValueError('C723_OBSERVER_FRONTEND_FAILED '+a.stderr[:1000])
    f = json.loads(a.stdout)
    if f['warnings'] or f['codegenInvoked'] or f['sourceCount']!=151: raise ValueError('C723_FRONTEND_CONTRACT_FAILED '+json.dumps(f))
    j['frontend']=f; x.save()
    exe = out/'observer.exe'
    a = x.run([str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')],out/'build',timeout=180)
    if a.returncode or a.stderr.strip(): raise ValueError('C723_OBSERVER_BUILD_FAILED '+a.stderr[:1000])
    j['observerSha256']=sha(exe); x.save()
    for c in cases:
        folder=out/c['id'];folder.mkdir()
        a=x.run([str(exe),c['source']],folder/'observe',timeout=60)
        if a.returncode or a.stderr.strip() or not a.stdout.rstrip().endswith('observed-phases=2'):raise ValueError('C723_OBSERVATION_FAILED '+c['id']+' '+a.stderr[:500])
        nodes=[list(map(int,line.split()[1:])) for line in a.stdout.splitlines() if line.startswith('ir ')]
        payloads=[n for n in nodes if n[3]==29]
        assert len(payloads)==2 and {n[0] for n in payloads}=={0,3},(c['id'],payloads)
        assert all(n[5:9]==[1,1,-1,2] for n in payloads),(c['id'],payloads)
        j['cases'].append({'id':c['id'],'status':'passed','earlyAndFinalPayloads':payloads,'stdoutSha256':sha(folder/'observe.stdout')});j['completed']+=1;x.save()
    j['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:j.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if j['status']!='passed':raise SystemExit(1)
