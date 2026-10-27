from pathlib import Path
import sys,json,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
runner=b/'runner16766-build/bin/Sollang.ExampleTests.dll';lls=list((b/'llvm16772-roles/51-fixed-array-value-generics-native/runner/compiler-artifacts').glob('*.ll'));assert len(lls)==1
out=b/'llvm16774-controls51';out.mkdir(exist_ok=False)
inputs=[Path(__file__),lls[0],*runner.parent.glob('*.dll'),*runner.parent.glob('*.json'),*root.joinpath('examples/regression/expected').glob('51-fixed-array-value-generics*.txt'),root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py']
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(status='running',completed=0,total=12,inputHashes=pins,cases=[],claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  run=x.run(['dotnet',str(runner),'--llvm-assertion-tests',str(lls[0]),str(out/'controls.json')],out/'execution',timeout=180);inner=json.loads((out/'controls.json').read_text(encoding='utf-8-sig'));r['cases']=inner['cases'];r['completed']=inner['completed'];assert run.returncode==0 and inner['status']=='passed' and inner['completed']==inner['total']==12;r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
