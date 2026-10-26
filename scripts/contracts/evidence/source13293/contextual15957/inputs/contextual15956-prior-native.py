from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
out=b/'contextual15956-prior-native-control';exe=b/'v15778/compiler-build01/compiler.exe';source=r/'scripts/probes/dictionary/c385-contextual-record-ordinary-unknown-key.slg';inputs=[Path(__file__),exe,source,*sorted((r/'stdlib').rglob('*.slg'))]
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='historical Native A0 diagnostic ordering observation only; not acceptance',inputHashes=pins,claimsGoalComplete=False)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  observed=run.run([str(exe),'build',str(source),'-o',str(out/'program.exe'),'--target','windows-x64','--keep-temps','-O1','--llvm',str(r/'.tools/llvm-22.1.8'),'--stdlib',str(r/'stdlib')],out/'build',timeout=180)
  result.update(status='observed-not-qualified',observedExit=observed.returncode,diagnostic=observed.stderr.strip())
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','observedExit','diagnostic','processesStopped']},ensure_ascii=False))
