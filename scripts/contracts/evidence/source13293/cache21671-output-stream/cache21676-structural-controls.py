import json,hashlib,sys
from pathlib import Path
from datetime import datetime,timezone
sys.path.insert(0,'scripts')
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
r=Path.cwd(); b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def write(p,v): p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
out=b/'cache21676-structural-controls';initialize_output(r,out,reusable_directories=[b/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);out.mkdir()
paths=[Path(__file__),r/'scripts/test-structural-phase-closure.py',r/'scripts/audit-structural-source-connections.py',r/'scripts/capture-structural-parity-inventory.py',r/'scripts/verify-structural-parity-detail.py',r/'scripts/contracts/structural-parity-detail.json',r/'scripts/contracts/active-goal-progress.json']
import runpy
scopes=runpy.run_path(str(r/'scripts/verify-structural-parity-detail.py'))
for phase in scopes['PHASE_SCOPES'].values():
 for side,extension in [('managed','.cs'),('selfhost','.slg')]:
  for relative in phase[side]:
   p=r/relative;paths += [p] if p.is_file() else list(p.rglob('*'+extension))
paths += [r/p for p in scopes['PARSING_SHARED_DEPENDENCIES']]
inputs={str(p.resolve()):sha(p) for p in paths};result=dict(schemaVersion=1,status='running',completed=0,total=3,inputHashes=inputs,claimsGoalComplete=False)
ex=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
try:
 for name,args in [('scope-tests',['scripts/test-structural-phase-closure.py','OwnershipSourceScopeTests']),('phase-closure',['scripts/verify-structural-parity-detail.py','--phase-closure-only']),('capture',['scripts/capture-structural-parity-inventory.py','--output',str(out/'source-inventory.json')])]:
  done=ex.run(['python',*args],str(out/name),timeout=60)
  assert done.returncode==0,done.stderr+done.stdout;result['completed']+=1;ex.save()
 result['status']='passed'
except BaseException as x:err=x
finally:ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}))
if err:raise err
