from pathlib import Path
import json,hashlib,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';base=b/'literal13139';out=b/'literal13141-semantic';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler=b/'managed13056/compiler/Sollang.Compiler.exe';assert sha(compiler.with_suffix('.dll'))=='8310858A4407EF263ACE7292A2CF1EA70FB018DB6520E450CC100F2BE777394D'
pre=b/'literal13140-preflight/result.json';pr=json.loads(pre.read_text(encoding='utf-8-sig'));assert pr['status']=='passed' and pr['inputsStable'] and pr['processesStopped']
manifest=root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
canonical=[root/l.strip() for l in manifest.read_text(encoding='utf-8-sig').splitlines() if l.strip()]
for p in canonical:assert pr['inputHashes'][str(p)]==sha(p),str(p)
source=base/'semantic-driver.slg';sources=[source]+canonical[1:]
planPath=base/'semantic-plan.json';plan=json.loads(planPath.read_text());cases=plan['cases']
for c in cases:assert sha(root/c['source'])==c['sourceSha256']
harness=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
inputs=sources+[root/c['source'] for c in cases]+[planPath,manifest,pre,Path(__file__)]+list(compiler.parent.glob('Sollang.Compiler.*'))+list(harness.parent.glob('SemanticPreflight.*'))+list((root/'stdlib').rglob('*.slg'))
pins={str(p):sha(p) for p in inputs if p.is_file()}
r={'schemaVersion':1,'status':'running','scope':plan['scope'],'inputHashes':pins,'completed':0,'total':len(cases),'cases':[],'budget':plan['producerBudget'],'claimsSourceGatePassed':False,'claimsCandidateQualified':False,'claimsGoalComplete':False}
x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 a=x.run([str(harness),str(compiler.with_suffix('.dll')),*map(str,sources)],out/'frontend',timeout=60)
 if a.returncode or a.stderr.strip():raise ValueError('SEMANTIC_DRIVER_FRONTEND_FAILED '+a.stderr[:1200])
 f=json.loads(a.stdout);assert not f['warnings'] and not f['codegenInvoked'];r['frontend']=f;x.save()
 exe=out/'semantic.exe';a=x.run([str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')],out/'build',timeout=180)
 if a.returncode or a.stderr.strip():raise ValueError('SEMANTIC_DRIVER_BUILD_FAILED '+a.stderr[:1200])
 r['semanticDriverSha256']=sha(exe);x.save()
 for c in cases:
  folder=out/c['id'];folder.mkdir();a=x.run([str(exe),c['source']],folder/'observe',timeout=180)
  row={'id':c['id'],'exit':a.returncode,'stdout':a.stdout,'stderr':a.stderr};r['cases'].append(row);x.save()
  if a.returncode or a.stderr.strip():raise ValueError('SEMANTIC_REPLAY_EXECUTION_FAILED '+c['id'])
  values=[int(v) for v in a.stdout.strip().splitlines()];assert len(values)==4
  assert values[0]==c['code'],(c['id'],values,c)
  if c['count'] is not None:assert values[1:3]==[c['count'],c['bound']],(c['id'],values)
  if c['code']==38:
   text=(root/c['source']).read_text();assert values[3]==text.index('256'),(c['id'],values)
  row['status']='passed';r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if r['status']!='passed':raise SystemExit(1)
