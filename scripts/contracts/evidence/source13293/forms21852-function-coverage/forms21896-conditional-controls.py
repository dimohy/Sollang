from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'forms21896-conditional-controls';CPP=B/'forms21894-csharp-conditional-payload/program.exe';SLG=B/'forms21895-slg-conditional-payload/program.exe';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,SLG];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(paths):
 result=dict(schemaVersion=1,status='running',completed=0,total=3,cases=[],inputHashes=inputs,scope='Controls on the existing focused binaries: managed consumes and borrows, current Native borrows. The Native consuming arm is already a recorded heap failure. No full cache claim.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  for name,exe,args,expected in [('csharp-consume',CPP,[],'Int\n'),('csharp-borrow',CPP,['borrow'],''),('slg-borrow',SLG,['borrow'],'')]:
   done=ex.run([str(exe),*args],OUT/name,timeout=30);assert done.returncode==0 and done.stdout==expected and not done.stderr,(done.returncode,done.stdout,done.stderr);result['cases'].append(dict(id=name,passed=True,stdout=done.stdout));result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
