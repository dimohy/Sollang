from pathlib import Path
import json,hashlib,sys
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(R/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import assert_output_shutdown,terminal_consumer_process,consumer_closure_record
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
old=B/'v14010/compiler-build01';out=B/'retirement14248-observation';out.mkdir(exist_ok=False)
pins={str(p):sha(p) for p in [old/'compiler.exe',old/'result.json',Path(__file__).resolve(),R/'scripts/verification_execution.py',R/'scripts/completed_artifact_plan.py']}
parent=B/'returned14032-native3/result.json';d=load(parent);pins[str(parent)]=sha(parent)
assert d['status']=='timed-out' and d['completed']==2 and d['total']==3 and d['inputsStable'] and d['processesStopped']
observations=[]
for case in d['cases']:
    runner=Path(case['resultPath']);supervisor=runner.parent.parent/'result.json';s=load(supervisor)
    assert s['status'] in ['passed','timed-out'] and s['inputsStable'] and s['processesStopped']
    assert_output_shutdown(R,supervisor.parent)
    for p in [runner,supervisor,supervisor.parent/'execution.stdout',supervisor.parent/'execution.stderr']:pins[str(p)]=sha(p)
    for process in s['processes']:
        assert terminal_consumer_process(R,supervisor.parent,process) and process['shutdownConfirmed'] and process['shutdownScope']=='owned-windows-job'
        assert '--compiler' in process['command'] and str(old/'compiler.exe') in process['command']
        assert process['startedAtUtc'] and process['finishedAtUtc'] and type(process['exit']) is int
    if s['status']=='timed-out':assert s['terminatedProcesses'] and all(x['scope']=='owned-windows-job' for x in s['terminatedProcesses'])
    observations.append(dict(case=case['id'],runner=str(runner),supervisor=str(supervisor),status=s['status'],processesStopped=True,claimsTestPassed=False))
record=dict(schemaVersion=1,status='running',scope='Retirement-only authenticated terminal observation of a legacy three-case catalog. Preserve original2/3 and timeout, all inner results and outputs. One fresh CLI version probe is not compiler acceptance.',inputHashes=pins,completed=0,total=1,cases=[],historicalConsumerObservations=observations,claimsCompilerAcceptance=False,claimsGoalComplete=False,originalTestsAdded=0)
x=VerificationExecution(R,out,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
    probe=x.run([str(old/'compiler.exe'),'--version'],out/'version',timeout=30)
    assert probe.returncode==0 and not probe.stderr
    record.update(status='passed',completed=1,cases=[dict(id='retiring-cli-version-only',status='passed',passed=True,buildExit=0,observedStdout=probe.stdout.strip(),scope='CLI identity only; no original-test acceptance')])
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
assert error is None,error
consumers=[B/n/'result.json' for n in ['case129014040','case129014043-validate','result14035-native12']]+[out/'result.json']
proposal=consumer_closure_record(R,old,consumers,B/'v14112/compiler-build01',legacy_terminal=True)
(out/'proposed-consumer-closure.json').write_text(json.dumps(proposal,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(status='proposal-validated',consumers=len(consumers),historicalCasesObserved=len(observations),originalTestsAdded=0,retirementExecuted=False)))
