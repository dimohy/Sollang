from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
mode=sys.argv[1];assert mode in ['native100','source111']
native=mode=='native100';total=100 if native else 111;budget=3600 if native else 20160
contract=b/('contextual15973-native100.json' if native else 'contextual15975-source111.json')
managed=b/('contextual15974-managed100.json' if native else 'contextual15971-managed111/result.json')
proof=json.loads(managed.read_text(encoding='utf-8-sig'))
assert proof['status']=='passed' and proof['completed']==proof['total']==total and proof['inputsStable'] and proof['processesStopped']
inputs=[Path(__file__),contract,managed,b/'contextual15976-plan.json',r/'scripts/verify-c385-preir-call-numeric.py',b/'managed15892/compiler/Sollang.Compiler.dll',*[Path(p) for p in proof['inputHashes']]]
if native:inputs += [b/'aggregate15925-source-comparison.json',b/'v15969/compiler-build01/compiler.exe',b/'v15969/compiler-build01/result.json']
else:inputs += [r/'scripts/contracts/evidence/source13293/whole-product14800-source111-contract.json',b/'contextual15971-managed111/result.json']
for p,h in proof['inputHashes'].items():assert sha(p)==h.upper(),p
focused=b/'contextual15972-native66/result.json';focused_proof=json.loads(focused.read_text(encoding='utf-8-sig'))
assert focused_proof['status']=='passed' and focused_proof['completed']==focused_proof['total']==66 and focused_proof['inputsStable'] and focused_proof['processesStopped'],'CURRENT_NATIVE66_REQUIRED_BEFORE_LARGE_COHORT'
for p,h in focused_proof['inputHashes'].items():assert sha(p)==h.upper(),p
from completed_artifact_plan import assert_output_shutdown
assert_output_shutdown(r,focused.parent)
inputs += [focused,*[Path(p) for p in focused_proof['inputHashes']]]
inputs=list(dict.fromkeys(inputs));inner=b/('contextual15977-native100' if native else 'contextual15978-source111');out=b/('contextual15977-supervised' if native else 'contextual15978-supervised')
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=total,scope='Mandatory unchanged original current-product '+mode,aggregateBudgetSeconds=budget,caseBudgetSeconds=180,producerBuildMaximum=0 if native else 1,producerBuildSeconds=180,retryCount=0,innerResult=str(inner/'result.json'),claimsGoalComplete=False)
 execution=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  command=[sys.executable,str(r/'scripts/verify-c385-preir-call-numeric.py'),'--mode','paired' if native else 'managed','--output',str(inner),'--contract',str(contract),'--managed-compiler',str(b/'managed15892/compiler/Sollang.Compiler.exe')]
  if native:command+=['--managed-proof',str(managed),'--build',str(b/'v15969/compiler-build01'),'--source-comparison',str(b/'aggregate15925-source-comparison.json')]
  else:command+=['--format-compiler',str(b/'v12432/compiler-build01/compiler.exe')]
  for n in ['v12432','v15778','v15969']:command+=['--reusable-compiler-directory',str(b/n/'compiler-build01')]
  observed=execution.run(command,out/'verification',timeout=budget)
  if observed.returncode:raise ValueError('CURRENT_ORIGINAL_COHORT_FAILED')
  j=json.loads((inner/'result.json').read_text(encoding='utf-8-sig'));assert j['status']=='passed' and j['completed']==j['total']==total and j['inputsStable'] and j['processesStopped']
  result.update(status='passed',completed=total,innerResultSha256=sha(inner/'result.json'))
 except BaseException as failure:error=failure
 finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','processesStopped']}))
