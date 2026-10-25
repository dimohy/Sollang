from pathlib import Path
import hashlib,json,sys
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from completed_artifact_plan import assert_output_shutdown,terminal_consumer_process
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
old=b/'v13800/compiler-build01';out=b/'retirement14102-observation';assert not out.exists()
names=['async13941-native9','async24913946-native','next3213911-native29','remaining3213931-native32','remaining813961-native8','interpolation13845-dynamic4']
pins={str(p):sha(p) for p in [old/'compiler.exe',old/'result.json',Path(__file__).resolve(),root/'scripts/verification_execution.py',root/'scripts/completed_artifact_plan.py']};observations=[]
def pin(p):pins[str(p.resolve())]=sha(p)
for name in names:
 p=b/name/'result.json';record=read(p);pin(p);assert record['inputsStable'] and record['processesStopped'];assert record['status'] in ['passed','failed','timed-out'];rows=[]
 if 'cases' in record:
  for case in record['cases']:
   runner=Path(case['resultPath']);supervisor=runner.parent.parent/'result.json';s=read(supervisor);pin(runner);pin(supervisor);assert s['status'] in ['passed','failed','timed-out'] and s['inputsStable'] and s['processesStopped'];assert s['processes'];assert_output_shutdown(root,supervisor.parent)
   for process in s['processes']:
    assert terminal_consumer_process(root,supervisor.parent,process) and process['shutdownConfirmed'] and process['shutdownScope']=='owned-windows-job';assert '--compiler' in process['command'] and str(old/'compiler.exe') in process['command'];assert process['startedAtUtc'] and process['finishedAtUtc'];assert type(process['exit']) is int
   if s['status']=='timed-out':assert s['terminatedProcesses'] and all(x['scope']=='owned-windows-job' for x in s['terminatedProcesses'])
   for stream in ['execution.stdout','execution.stderr']:pin(supervisor.parent/stream)
   rows.append({'case':case['id'],'supervisor':str(supervisor),'status':s['status'],'ownedRunnerExit':s['processes'][-1]['exit'],'processesStopped':True,'claimsTestPassed':False})
 else:
  assert record['inputHashesStart']==record['inputHashesEnd'];assert record['status']=='passed' and record['completed']==record['total']==4;assert_output_shutdown(root,p.parent)
  for journal in sorted(p.parent.glob('*.execution.json')):
   row=read(journal)
   if 'command' not in row:continue
   assert terminal_consumer_process(root,p.parent,row),journal;pin(journal);pin(Path(row['stdoutPath']));pin(Path(row['stderrPath']));rows.append({'journal':str(journal),'exit':row['exit'],'processesStopped':True,'claimsTestPassed':False})
  assert len(rows)>=32
 observations.append({'source':str(p),'status':record['status'],'originalCompleted':record['completed'],'originalTotal':record['total'],'terminalObservations':rows,'originalRecordChanged':False})
assert all(Path(p).is_file() and sha(p)==h for p,h in pins.items());out.mkdir();d={'schemaVersion':1,'status':'running','scope':'Retirement-only terminal journal observation, not test requalification. Preserve original catalog failures, unfinished inner runners and expected runtime traps. One fresh version probe is the only new executed case.','inputHashes':pins,'completed':0,'total':1,'cases':[],'historicalConsumerObservations':observations,'claimsCompilerAcceptance':False,'claimsGoalComplete':False,'originalTestsAdded':0};x=VerificationExecution(root,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);err=None
try:
 run=x.run([str(old/'compiler.exe'),'--version'],out/'version',timeout=30);assert run.returncode==0 and not run.stderr;d['cases']=[{'id':'retiring-product-version-only','status':'passed','passed':True,'buildExit':0,'observedStdout':run.stdout.strip(),'scope':'CLI identity only; no compiler acceptance'}];d.update(status='passed',completed=1)
except BaseException as caught:err=caught
finally:x.finalize(err,cleanup=False)
print(json.dumps({'status':d['status'],'historicalConsumerCount':len(observations),'versionProbeCount':d['completed'],'originalTestsAdded':0,'failure':str(err) if err else None}));assert not err
