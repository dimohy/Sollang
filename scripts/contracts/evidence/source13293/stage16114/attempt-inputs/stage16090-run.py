from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_step_diagnostics import SlowStepDiagnostics
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
previous=b/'stage16082/producer/result.json';old=json.loads(previous.read_text(encoding='utf-8-sig'));exe=b/'stage16082/producer/probe.exe'
assert old['status']=='failed' and old['inputsStable'] and old['processesStopped'] and old['failure'].startswith('TimeoutExpired:')
assert sha(exe)==old['generatedOutputHashes'][str(exe)]
for p,h in old['inputHashes'].items():assert sha(p)==h,p
out=b/'stage16090-preparation';out.mkdir()
plan=dict(stage='exact-stage-package-178-checked-preparation',softLimitSeconds=30,hardTimeoutSeconds=1200,sampleIntervalSeconds=5,maxSamples=244)
planPath=out/'diagnostics-plan.json';planPath.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8')
inputs=[Path(__file__),previous,exe,planPath,r/'scripts/verification_execution.py',r/'scripts/verification_step_diagnostics.py',*[Path(p) for p in old['inputHashes']]]
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='Exact178-source Stage package preparation only; not user-program execution or formal Stage2. Reuse the authenticated existing O0 diagnostic producer; no compiler rebuild.',priorFailure=str(previous),priorPreparationMilliseconds=sum(v['durationMilliseconds'] for v in old['processes']),additionalPreparationBudgetSeconds=1200,programCaseBudgetSeconds=180,producerBuildCount=0,claimsStagePassed=False,claimsGoalComplete=False,decisionReason='Previous180-second full compiler-package preparation stopped with an active CPU observation and no diagnostics. Namespace closure is now complete. Use the separately approved1200 preparation domain once with bounded sampling; preserve original180 failure and do not alter ordinary program limits.')
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  observed=run.run([str(exe)],out/'prepare',timeout=1200,diagnostics=SlowStepDiagnostics(plan,out/'prepare.diagnostics.json'))
  result['observedExit']=observed.returncode
  if observed.returncode!=0 or observed.stderr or observed.stdout.strip()!='stage diagnostics=0 invariants=0 sources=178':raise ValueError('EXACT_STAGE_PACKAGE_PREPARATION_FAILED')
  result.update(status='passed',completed=1,cases=[dict(id='exact-stage-package-178',status='passed',passed=True,runExit=0,sourceCount=178,semanticDiagnosticCount=0,irInvariantDiagnosticCount=0)])
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
 print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','processesStopped']}))
