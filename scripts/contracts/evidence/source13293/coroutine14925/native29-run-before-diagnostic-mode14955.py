from pathlib import Path
import json,sys,hashlib,time
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
config=Path(__file__).with_suffix('.json');c=R(config);pins=c['inputHashes'];pins[str(config.resolve())]=H(config);pins[str(Path(__file__).resolve())]=H(Path(__file__))
stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
assert stable(),'COROUTINE_CURRENT_INPUT_DRIFT_BEFORE_EXECUTION'
out=Path(c['output']);initialize_output(root,out,reusable_directories=list(map(Path,c['reusableDirectories'])));out.mkdir(exist_ok=False)
r=dict(schemaVersion=1,status='running',scope='Exact original Native29 command sequence with current compiler; original95 build/assembly/closure/runtime commands, source/oracles/profiles/targets retained.',completed=0,total=29,inputHashes=pins,cases=[],pendingAllocationAudit=True,maximumCaseSeconds=180,maximumAggregateSeconds=c['totalBudgetSeconds'],retryCount=0,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,H);error=None;start=time.monotonic();norm=lambda p:Path(p).read_bytes().replace(b'\r\n',b'\n')
try:
 for group in c['cases']:
  case=group['case'];folder=out/case['id'];folder.mkdir();row=dict(id=case['id'],status='running',passed=False,expectedBuildExit=case['expectedBuildExit'],target=case['target']);r['cases'].append(row);x.save();caseStart=time.monotonic()
  for step in group['steps']:
   remaining=min(180-(time.monotonic()-caseStart),c['totalBudgetSeconds']-(time.monotonic()-start));assert remaining>0,'COROUTINE_EXECUTION_BUDGET_EXHAUSTED'
   prefix=folder/step['kind'];done=x.run(step['command'],prefix,timeout=min(180,remaining));assert done.returncode==step['expectedExit'],(case['id'],step['kind'],done.returncode,step['expectedExit'])
   row[dict(build='buildExit',assemble='llvmAsExit',closure='v004Exit',run='runtimeExit')[step['kind']]]=done.returncode
   old=Path(step['originalLog'])
   if step['kind']=='build':
    assert norm(prefix.with_suffix('.stderr'))==norm(old.with_suffix('.stderr')),(case['id'],'ORIGINAL_BUILD_STDERR_MISMATCH')
    if case['expectedBuildExit']!=0:assert case['diagnostic'] in prefix.with_suffix('.stderr').read_text(encoding='utf-8-sig')
   if step['kind']=='run':
    assert norm(prefix.with_suffix('.stdout'))==norm(old.with_suffix('.stdout')),(case['id'],'ORIGINAL_RUNTIME_STDOUT_MISMATCH')
    assert norm(prefix.with_suffix('.stderr'))==norm(old.with_suffix('.stderr')),(case['id'],'ORIGINAL_RUNTIME_STDERR_MISMATCH');row['stdoutExact']=True
  row.update(status='passed',passed=True,durationMilliseconds=round((time.monotonic()-caseStart)*1000,3));r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
