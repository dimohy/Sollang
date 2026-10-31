import json,hashlib,sys
from pathlib import Path
from datetime import datetime,timezone
sys.path.insert(0,'scripts')
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
r=Path.cwd(); b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def write(p,v): p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
out=b/'cache21743-workflow-checks';initialize_output(r,out,reusable_directories=[b/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);out.mkdir()
paths=[r/'scripts/test_completed_artifacts.py',r/'scripts/completed_artifact_plan.py',r/'scripts/contracts/artifact-lifecycle.json',r/'scripts/contracts/fixtures/artifact-lifecycle-format-preflight-record.json',r/'scripts/verify-source-manifest-closure.ps1',r/'scripts/source-module-header.ps1',Path(__file__).resolve()]
manifests=[r/p for p in ['tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt','tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt','selfhost/browser_driver.sources.txt']]
paths += manifests + [r/line for m in manifests for line in m.read_text(encoding='utf-8-sig').splitlines() if line] + list((r/'stdlib').rglob('*.slg'))
inputs={str(p.resolve()):sha(p) for p in paths};result=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=inputs,claimsGoalComplete=False)
ex=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
try:
 done=ex.run(['python','-m','unittest','discover','-s','scripts','-p','test_completed_artifacts.py','-k','preflight'],str(out/'preflight-tests'),timeout=60)
 assert done.returncode==0,done.stderr;result['completed']+=1;ex.save()
 done=ex.run(['pwsh','-NoProfile','-Command',"& './scripts/verify-source-manifest-closure.ps1' -Manifest @('tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt','tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt','selfhost/browser_driver.sources.txt') -SourcePath @((Get-ChildItem -LiteralPath './stdlib' -Recurse -File -Filter '*.slg').FullName)"],str(out/'source-closure'),timeout=60)
 assert done.returncode==0,done.stderr;result['completed']+=1;result['status']='passed'
except BaseException as x:err=x
finally:ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}))
if err:raise err
