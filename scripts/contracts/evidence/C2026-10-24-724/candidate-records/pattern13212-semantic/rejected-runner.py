from pathlib import Path
import sys,json,hashlib
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'pattern13212-semantic';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
manifest=r/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';canonical=[r/line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
cp=b/'pattern13202-contract.json';cases=json.loads(cp.read_text())['cases'];managed=b/'pattern13202-managed/result.json';mp=json.loads(managed.read_text(encoding='utf-8-sig'))
assert mp['status']=='passed' and mp['completed']==mp['total']==6 and mp['inputsStable'] and mp['processesStopped']
for p,h in mp['inputHashes'].items():assert sha(p)==h,p
old=json.loads((b/'pattern13203-observation/result.json').read_text(encoding='utf-8-sig'))
changed={'selfhost/semantic/diagnostics.slg':'semantic-diagnostics.before.slg','selfhost/llvm/emitter/diagnostics.slg':'emitter-diagnostics.before.slg'}
for p in canonical:
    relative=p.relative_to(r).as_posix()
    if relative in changed:assert old['inputHashes'][str(p)]==sha(r/'scripts/contracts/evidence/C2026-10-24-724'/changed[relative]) and old['inputHashes'][str(p)]!=sha(p)
    else:assert old['inputHashes'][str(p)]==sha(p),p
sources=[b/'pattern13212-semantic-driver.slg']+canonical[1:]
compiler=b/'managed13056/compiler/Sollang.Compiler.exe';harness=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
paths=sources+[r/c['source'] for c in cases]+[cp,managed,manifest,Path(__file__)]+list(compiler.parent.glob('Sollang.Compiler.*'))+list(harness.parent.glob('SemanticPreflight.*'))+list((r/'stdlib').rglob('*.slg'))
pins={str(p):sha(p) for p in paths if p.is_file()};j={'schemaVersion':1,'status':'running','scope':'C724 current SLG semantic-only replay before whole checked emitter. Empty IR verifies actual early diagnostic code72/source offset on direct ref subject, code0 on5 accepted controls. Not a native compiler image qualification.','inputHashes':pins,'completed':0,'total':6,'cases':[],'budget':{'producerBuilds':1,'frontendSeconds':60,'buildSeconds':180,'caseSeconds':60,'retryCount':0},'claimsGoalComplete':False}
x=VerificationExecution(r,out,j,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
    a=x.run([str(harness),str(compiler.with_suffix('.dll')),*map(str,sources)],out/'frontend',timeout=60)
    if a.returncode or a.stderr.strip():raise ValueError('C724_SEMANTIC_FRONTEND_FAILED '+a.stderr[:1000])
    f=json.loads(a.stdout)
    if f['warnings'] or f['codegenInvoked'] or f['sourceCount']!=151:raise ValueError('C724_SEMANTIC_FRONTEND_CONTRACT '+json.dumps(f))
    j['frontend']=f;x.save();exe=out/'semantic.exe'
    a=x.run([str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','--jobs','4','--llvm',str(r/'.tools/llvm-22.1.8')],out/'build',timeout=180)
    if a.returncode or a.stderr.strip():raise ValueError('C724_SEMANTIC_BUILD_FAILED '+a.stderr[:1000])
    j['producerSha256']=sha(exe);x.save()
    for c in cases:
        folder=out/c['id'];folder.mkdir();a=x.run([str(exe),c['source']],folder/'observe',timeout=60)
        if a.returncode or a.stderr.strip():raise ValueError('C724_SEMANTIC_EXECUTION_FAILED '+c['id']+' '+a.stderr[:1000])
        values=[int(line) for line in a.stdout.strip().splitlines()];assert len(values)==4
        expected=72 if c['exit']==1 else 0
        assert values[0]==expected,(c['id'],values,expected)
        if expected==72:assert values[3]==(r/c['source']).read_text().index('source -> borrow -> when')
        j['cases'].append({'id':c['id'],'status':'passed','diagnosticCode':values[0],'sourceOffset':values[3]});j['completed']+=1;x.save()
    j['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:j.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if j['status']!='passed':raise SystemExit(1)
