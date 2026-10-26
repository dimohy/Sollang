from pathlib import Path
import sys,json,hashlib,math
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
managed=b/'parity15812-managed-context1/result.json';proof=json.loads(managed.read_text(encoding='utf-8-sig'))
assert proof['status']=='passed' and proof['completed']==proof['total']==1 and proof['inputsStable'] and proof['processesStopped']
for p,h in proof['inputHashes'].items():assert sha(p)==h.upper(),p
managed_ms=sum(p['durationMilliseconds'] for p in proof['processes'] if len(p['command'])>1 and p['command'][1]=='build')
remaining=1200-math.ceil(managed_ms/1000);assert remaining>=180
inner=b/'parity15817-native-context1';out=b/'parity15817-supervised';inputs=[Path(__file__),managed,b/'parity15811-context1.json',b/'parity15813-context1-source-comparison.json',b/'v15778/compiler-build01/compiler.exe',b/'v15778/compiler-build01/result.json',r/'scripts/contracts/context-fixture-pair-plan.json',r/'scripts/verify-c385-preir-call-numeric.py',*[Path(p) for p in proof['inputHashes']]]
inputs=list(dict.fromkeys(inputs))
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=1,scope='Original four-invariant suite current Native requalification',aggregatePreparationBudgetSeconds=1200,observedManagedBuildMilliseconds=managed_ms,effectiveRemainingSeconds=remaining,generatedProgramCaseBudgetSeconds=180,originalNativePreparationAuthority='scripts/contracts/context-fixture-pair-plan.json',invocationMode='supervised-inner-canonical-runner',innerResult=str(inner/'result.json'),claimsGoalComplete=False)
 execution=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  command=[sys.executable,str(r/'scripts/verify-c385-preir-call-numeric.py'),'--mode','paired','--output',str(inner),'--contract',str(b/'parity15811-context1.json'),'--managed-compiler',str(b/'managed15734/compiler/Sollang.Compiler.exe'),'--managed-proof',str(managed),'--build',str(b/'v15778/compiler-build01'),'--source-comparison',str(b/'parity15813-context1-source-comparison.json')]
  for n in ['v12432','v14775','v15778']:command+=['--reusable-compiler-directory',str(b/n/'compiler-build01')]
  observed=execution.run(command,out/'verification',timeout=remaining)
  if observed.returncode:raise ValueError('CURRENT_CONTEXT_NATIVE_QUALIFICATION_FAILED')
  j=json.loads((inner/'result.json').read_text(encoding='utf-8-sig'));assert j['status']=='passed' and j['completed']==j['total']==1 and j['inputsStable'] and j['processesStopped']
  result.update(status='passed',completed=1,innerResultSha256=sha(inner/'result.json'))
 except BaseException as failure:error=failure
 finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','effectiveRemainingSeconds','failure','processesStopped']}))
