from pathlib import Path
import json,sys,time,hashlib,math
root=Path.cwd();base=root/'artifacts/scratch/resume-20261006-owner-continuation22';task=base/'context14654';a=root/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067/matching-inputs14373';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
previous_path=base/'context14644/supervised/result.json';previous=read(previous_path);assert previous['status']=='passed' and previous['completed']==previous['total']==1
maximum=1260000;used=previous['diagnosticCumulativeUpperBoundMilliseconds'];shutdown_reserve=10;available=math.floor((maximum-used)/1000)-shutdown_reserve;assert available==407
reference_path=base/'context14653-semantic/result.json';reference=read(reference_path);assert reference['status']=='passed' and reference['completed']==reference['total']==4 and reference['inputsStable'] and reference['processesStopped'];assert all(Path(p).is_file() and sha(p)==h for p,h in reference['inputHashes'].items())
comparison=a/'context267-14652/plan.json';contract=base/'context14652-profile/plan.json';build=base/'v14562/compiler-build01';compiler=build/'compiler.exe';build_record=read(build/'result.json');assert build_record['status']=='passed' and build_record['inputsStable'] and sha(compiler)==build_record['compilerSha256']
assert read(contract)['maximumSeconds']==180 and read(contract)['buildMaximumSeconds']==180
pins=dict(reference['inputHashes']);pins.update({str(p):sha(p) for p in [Path(__file__).resolve(),previous_path,reference_path,comparison,contract,compiler,build/'result.json']})
out=task/'supervised';retained=[base/n/'compiler-build01' for n in ['v12432','v14390','v14562']];initialize_output(root,out,reusable_directories=retained);out.mkdir(exist_ok=False)
result=dict(schemaVersion=1,status='running',scope='First full original267 file-backed context profile after actual mapped-owner loader repair; source and oracle unchanged. Aggregate1260s preserves prior842184ms; each build/runtime180s unchanged. Diagnostic only, no original Native1290 or Stage acceptance.',completed=0,total=1,inputHashes=pins,maximumDiagnosticCompilerAndRuntimeMilliseconds=maximum,priorCompilerAndRuntimeUpperBoundMilliseconds=used,maximumInvocationWallSeconds=available,shutdownReserveSeconds=shutdown_reserve,caseBudgetSeconds=180,retryCount=0,claimsGoalComplete=False)
execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None;started=time.monotonic()
try:
 command=[sys.executable,'-X','utf8',str(root/'scripts/verify-context-phase-profile.py'),'--source-directory',str(base/'context14652-profile'),'--build',str(build),'--managed-compiler',str(base/'managed14487/compiler/Sollang.Compiler.exe'),'--semantic-proof',str(reference_path),'--output',str(base/'context14655-execution')]
 for retained_path in retained:command+=['--reusable-directory',str(retained_path)]
 done=execution.run(command,out/'native',timeout=available);assert done.returncode==0,'Focused profile failed: '+done.stderr
 proof=read(base/'context14655-execution/result.json');assert proof['status']=='passed' and proof['completed']==proof['total']==2 and proof['inputsStable'] and proof['processesStopped'];result.update(status='passed',completed=1)
except BaseException as caught:error=caught
finally:
 result['invocationWallMilliseconds']=int((time.monotonic()-started)*1000);result['diagnosticCumulativeUpperBoundMilliseconds']=used+result['invocationWallMilliseconds'];execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped','invocationWallMilliseconds','diagnosticCumulativeUpperBoundMilliseconds']}));sys.exit(0 if result['status']=='passed' else 1)
