from pathlib import Path
import sys,json,hashlib,re
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_step_diagnostics import SlowStepDiagnostics
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
out=b/'lifecycle16095';inputs=[Path(__file__),Path(sys.executable),*[r/'scripts'/p for p in ['test_completed_artifacts.py','completed_artifact_plan.py','ArtifactLifecycle.ps1','Invoke-CompletedArtifactCleanup.ps1','contracts/artifact-lifecycle.json','verification_execution.py','verification_contract_lease.py','verification_step_diagnostics.py']]]
with VerificationContractLease(inputs):
 out.mkdir();pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',completed=0,total=158,inputHashes=pins,cases=[],scope='Current complete artifact lifecycle155 plus3 unqualified diagnostic observation controls; includes negative mutations and original output preservation.',claimsGoalComplete=False,priorFailedRun=dict(toolSession=77022,exit=1,tests=158,failures=1,errors=2,reason='Fixture helper name collided and source edits occurred after the first runner loaded its module. Fixed names/timestamps now frozen under the input lease; previous run is not a pass.'))
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  plan=dict(stage='artifact-lifecycle158',softLimitSeconds=30,hardTimeoutSeconds=600,sampleIntervalSeconds=5,maxSamples=124)
  observed=run.run([sys.executable,str(r/'scripts/test_completed_artifacts.py')],out/'tests',timeout=600,diagnostics=SlowStepDiagnostics(plan,out/'tests.diagnostics.json'))
  result['exit']=observed.returncode
  match=re.search(r'Ran (\d+) tests in ',observed.stderr);assert match and int(match.group(1))==158,'LIFECYCLE_TEST_SCOPE'
  assert observed.returncode==0 and observed.stderr.rstrip().endswith('OK'),'LIFECYCLE_TEST_FAILED'
  names=re.findall(r'^(test_\w+) .* \.\.\. ok$',observed.stderr,re.M)
  assert len(names)==158,'LIFECYCLE_CASE_RESULTS_MISSING'
  result.update(status='passed',completed=158,cases=[dict(id=n,status='passed',passed=True) for n in names])
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
 print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','processesStopped']}))
