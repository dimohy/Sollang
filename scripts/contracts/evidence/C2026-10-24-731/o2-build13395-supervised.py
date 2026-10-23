from pathlib import Path
import hashlib,json,sys
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import verified_consumer_closure
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
proofs=[base/name/'result.json' for name in ['arraylayout13386-managed','arraylayout13391-semantic','arraylayout13389-stdlib','arraylayout13390-source']]
proofs.append(base/'arraylayout13394-source-positive6.json')
pins={}
for path in proofs:
    r=read(path)
    assert r['status']=='passed' and r['inputsStable'] and r['processesStopped'] and r['completed']==r['total']>0,str(path)
    for p,h in r['inputHashes'].items():
        assert Path(p).is_file() and sha(p)==h,str(p)
        assert p not in pins or pins[p]==h,str(p)
        pins[p]=h
    pins[str(path)]=sha(path)
old=base/'v13312/compiler-build01'
verified_consumer_closure(root,old,allow_missing_product=True)
assert not (old/'compiler.exe').exists(),'Old slot must be retired through canonical lifecycle before new product.'
wrapper=base/'o2-build13395.ps1'
for p in [wrapper,Path(__file__),root/'scripts/build-focused-selfhost-compiler.ps1',old/'consumer-closure.json']:
    pins[str(p)]=sha(p)
out=base/'o2-build13395-supervised'
out.mkdir(exist_ok=False)
result=dict(schemaVersion=1,status='running',scope='One current C731 source O2 compiler product after CSharp23/semantic4/std144/canonical source23; no Stage or final acceptance claim.',inputHashes=pins,completed=0,total=1,claimsGoalComplete=False,compilerBuildBudgetSeconds=600)
execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
error=None
try:
    built=execution.run(['pwsh','-NoProfile','-File',str(wrapper)],out/'build',timeout=600)
    assert built.returncode==0,built.stderr
    product=read(base/'v13395/compiler-build01/result.json')
    assert product['status']=='passed' and product['inputsStable']
    result.update(status='passed',completed=1,compilerSha256=product['compilerSha256'])
except BaseException as caught:error=caught
finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped','compilerSha256']}),flush=True)
sys.exit(0 if result['status']=='passed' else 1)
