from pathlib import Path
import json,hashlib,sys,shutil
from datetime import datetime,timezone
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
managed=b/'interpolation16289-managed13/result.json';proof=json.loads(managed.read_text(encoding='utf-8-sig'));contract=b/'interpolation16288-unknown13.json';frozen=b/'aggregate15806-unknown13.json';build=b/'v16219/compiler-build01'
assert proof['status']=='passed' and proof['completed']==proof['total']==13 and proof['inputsStable'] and proof['processesStopped']
assert json.loads(contract.read_text(encoding='utf-8-sig'))['cases']==json.loads(frozen.read_text(encoding='utf-8-sig'))['cases']
for p,h in proof['inputHashes'].items():assert sha(p)==h.upper(),p
assert json.loads((build/'result.json').read_text(encoding='utf-8-sig'))['optimization']=='O2'
comparison=b/'interpolation16290-source-comparison.json'
previous=b/'aggregate15808-unknown13-source-comparison.json';prior=json.loads(previous.read_text(encoding='utf-8-sig'))
prior.update(managedFirst=str(managed),observedAtUtc=datetime.now(timezone.utc).isoformat(),observedChronology='Current managed original13 passed before Native execution; no SLG compiler source edits in this requalification.',previousComparison=str(previous),sourceHashes={name:sha(r/name) for name in prior['sourceHashes']})
comparison.write_text(json.dumps(prior,indent=2)+'\n',encoding='utf-8')
inputs=[Path(__file__),managed,contract,frozen,comparison,build/'result.json',build/'compiler.exe',r/'scripts/verify-c385-preir-call-numeric.py',*[Path(p) for p in proof['inputHashes']]]
inputs=list(dict.fromkeys(inputs));out=b/'interpolation16290-native13-supervised';inner=b/'interpolation16290-native13'
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=13,scope='Current exact original lexical unknown13 Native side; exact original case objects, ordered sources and stdout/stderr; original programO1/case180, current compiler productO2.',aggregateBudgetSeconds=3600,caseBudgetSeconds=180,compilerProductOptimization='O2',userProgramOptimization='O1',maximumAttemptsPerCase=1,claimsGoalComplete=False,innerResult=str(inner/'result.json'))
 execution=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  command=[sys.executable,str(r/'scripts/verify-c385-preir-call-numeric.py'),'--mode','paired','--output',str(inner),'--managed-compiler',str(b/'managed15892/compiler/Sollang.Compiler.exe'),'--contract',str(contract),'--managed-proof',str(managed),'--build',str(build),'--source-comparison',str(comparison)]
  command+=['--format-compiler',str(b/'v12432/compiler-build01/compiler.exe')]
  for n in ['v12432','v16203','v16219']:command+=['--reusable-compiler-directory',str(b/n/'compiler-build01')]
  observed=execution.run(command,out/'verification',timeout=3600)
  if observed.returncode:raise ValueError('CURRENT_NATIVE_UNKNOWN13_FAILED')
  current=json.loads((inner/'result.json').read_text(encoding='utf-8-sig'));assert current['status']=='passed' and current['completed']==current['total']==13 and current['inputsStable'] and current['processesStopped']
  result.update(status='passed',completed=13,innerResultSha256=sha(inner/'result.json'))
 except BaseException as failure:error=failure
 finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','processesStopped']}))

