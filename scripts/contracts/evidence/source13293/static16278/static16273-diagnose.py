from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
import subprocess
verifier=r/'scripts/verify-selfhost-compiler-contracts.ps1'
tracked=subprocess.run(['git','ls-files','-z','--','selfhost','src','tests','examples','syntax','scripts','docs'],capture_output=True,check=True,cwd=r).stdout.decode().split('\0')
inputs=[Path(__file__),*[r/p for p in tracked if p and not p.startswith('scripts/contracts/evidence/') and (r/p).is_file()]]
inputs += [r/'scripts/test-selfhost-static-assertion-collection.ps1']
inputs=list(dict.fromkeys(inputs))
out=b/'static16273-diagnostic';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='Collect current source-contract discrepancies without skipping failures; this is a failed preflight when any assertion fails',claimsGoalComplete=False)
 execution=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  import shutil,re
  controls=execution.run([shutil.which('pwsh'),'-NoProfile','-File',str(r/'scripts/test-selfhost-static-assertion-collection.ps1')],out/'controls',timeout=180)
  if controls.returncode:raise ValueError('STATIC_COLLECTION_CONTROLS_FAILED')
  result['collectionControls']={'completed':16,'total':16,'status':'passed'}
  checked=execution.run([shutil.which('pwsh'),'-NoProfile','-File',str(verifier),'-StaticAssertionsOnly','-CollectStaticAssertionFailures'],out/'static',timeout=180)
  log=(out/'static.stdout').read_text(encoding='utf-8-sig')
  failures=[line for line in log.splitlines() if line.startswith('[static assertion failure] ')]
  result.update(failedAssertionCount=len(failures),failedAssertions=failures,fullStage2Acceptance=False)
  if checked.returncode:raise ValueError('STATIC_SOURCE_CONTRACT_FAILED:'+str(len(failures)))
  result.update(status='passed',completed=1)
 except BaseException as e:error=e
 finally:execution.finalize(error,cleanup=False)
 print(json.dumps({k:result.get(k) for k in ['status','completed','failure','processesStopped']}))
