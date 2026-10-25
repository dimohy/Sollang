from pathlib import Path
import json,sys,time,hashlib,math
root=Path.cwd();base=root/'artifacts/scratch/resume-20261006-owner-continuation22';task=base/'aggregate14622';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
authority=root/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067/matching-inputs14373/context-authority14473/qualification.json'
prior=read(authority)['boundedDiagnosticSegment'];assert prior['additionalWholeRunAllowed'] is False
maximum=prior['maximumCompilerAndRuntimeSeconds']*1000;used=prior['actualCompilerAndRuntimeMilliseconds'];available=math.floor((maximum-used)/1000);assert available==298
component=read(task/'component-contract.json');assert len(component['runtimeInputFiles'])==3 and len(component['cases'])==1
assert max((root/p).stat().st_size for p in component['runtimeInputFiles'])<=4000
assert component['budget']==dict(caseSeconds=180,retryCount=0)
reference=read(task/'reference-contract.json');assert len(reference['cases'])==3 and reference['budget']==dict(caseSeconds=180,retryCount=0)
paths=[Path(__file__).resolve(),authority,task/'reference-contract.json',task/'component-contract.json',root/'scripts/probes/diagnostic-aggregation/interpolation-main.slg',root/'scripts/probes/diagnostic-aggregation/facts.slg',root/'scripts/verify-c385-preir-call-numeric.py',root/'scripts/verification_execution.py',root/'scripts/completed_artifact_plan.py']+[root/p for p in component['runtimeInputFiles']]
pins={str(p):sha(p) for p in paths};out=task/'supervised';retained=[base/n/'compiler-build01' for n in ['v12432','v14390','v14562']];initialize_output(root,out,reusable_directories=retained);out.mkdir(exist_ok=False)
result=dict(schemaVersion=1,status='running',scope='One small interpolation aggregate diagnostic: CSharp reference3 then component3 runtime inputs. No full267 runtime, no original1290 acceptance or compiler source edit.',completed=0,total=2,inputHashes=pins,maximumDiagnosticCompilerAndRuntimeMilliseconds=maximum,priorCompilerAndRuntimeMilliseconds=used,maximumInvocationWallSeconds=available,caseBudgetSeconds=180,retryCount=0,claimsGoalComplete=False)
execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None;started=time.monotonic()
try:
 for label,contract,output,count in [('reference',task/'reference-contract.json',base/'aggregate14623-reference3',3),('component',task/'component-contract.json',base/'aggregate14624-component1',1)]:
  remaining=available-(time.monotonic()-started)
  if remaining<=0:raise ValueError('SMALL_DIAGNOSTIC_TOTAL_BUDGET_EXHAUSTED')
  command=[sys.executable,'-X','utf8',str(root/'scripts/verify-c385-preir-call-numeric.py'),'--mode','managed','--contract',str(contract),'--output',str(output),'--managed-compiler',str(base/'managed14487/compiler/Sollang.Compiler.exe'),'--format-compiler',str(base/'v12432/compiler-build01/compiler.exe')]
  for retained_path in retained:command+=['--reusable-compiler-directory',str(retained_path)]
  completed=execution.run(command,out/label,timeout=remaining)
  assert completed.returncode==0,label+' failed: '+completed.stderr
  proof=read(output/'result.json');assert proof['status']=='passed' and proof['completed']==proof['total']==count and proof['inputsStable'] and proof['processesStopped'],label
  result['completed']+=1
 result['status']='passed'
except BaseException as caught:error=caught
finally:
 result['invocationWallMilliseconds']=int((time.monotonic()-started)*1000)
 result['diagnosticCumulativeUpperBoundMilliseconds']=used+result['invocationWallMilliseconds']
 execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped','invocationWallMilliseconds','diagnosticCumulativeUpperBoundMilliseconds']}));sys.exit(0 if result['status']=='passed' else 1)
