from pathlib import Path
import json,hashlib,sys,copy
from datetime import datetime,timezone
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from completed_artifact_plan import assert_output_shutdown,terminal_consumer_process,consumer_closure_record
B=root/'artifacts/scratch/resume-20261006-owner-continuation22';old=B/'v14390/compiler-build01';out=B/'retirement14754';out.mkdir(exist_ok=False)
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
W=lambda p,j:Path(p).write_text(json.dumps(j,indent=2)+'\n',encoding='utf-8')
product=old/'compiler.exe';product_record=old/'result.json';mappings=[];observations=[]
for name in ['call14449-native-golden','call14451-native3','context14463-native-diagnostic','dictionary14455-native4','dictionary14430-native-geometry']:
 raw_path=B/name/'result.json';raw=R(raw_path)
 assert raw.get('processesStopped') is True and raw.get('inputsStable') is True,name
 assert_output_shutdown(root,raw_path.parent)
 pins={str(p):H(p) for p in [product,product_record,raw_path,Path(__file__).resolve()]}
 sources=[]
 if name=='call14451-native3':
  assert raw['status']=='timed-out' and raw['completed']==2 and raw['total']==3
  for case in raw['cases']:
   runner=Path(case['resultPath']);supervisor=runner.parent.parent/'result.json';s=R(supervisor)
   assert s['status'] in ['passed','timed-out'] and s['inputsStable'] and s['processesStopped']
   assert_output_shutdown(root,supervisor.parent)
   for p in [runner,supervisor,supervisor.parent/'execution.stdout',supervisor.parent/'execution.stderr']:pins[str(p)]=H(p)
   if s['status']=='timed-out':assert s['terminatedProcesses'] and all(p['scope']=='owned-windows-job' for p in s['terminatedProcesses'])
   for index,process in enumerate(s['processes']):sources.append((supervisor,index,process))
 else:
  for index,process in enumerate(raw['processes']):sources.append((raw_path,index,process))
 assert sources,name
 copied=[];validation=[]
 for path,index,process in sources:
  assert terminal_consumer_process(root,path.parent,process),(name,index,process.get('status'))
  assert process['shutdownConfirmed'] and process['shutdownScope']=='owned-windows-job'
  assert process['startedAtUtc'] and process['finishedAtUtc'] and type(process['exit']) is int
  command=process['command'];assert isinstance(command,list) and command
  if str(product) not in command:continue
  for key in ['stdoutPath','stderrPath']:
   if key in process:p=Path(process[key]);assert p.is_file();pins[str(p)]=H(p)
  if 'stdoutPath' in process:
   p=Path(str(process['stdoutPath'])[:-len('.stdout.log')]);assert p.is_file();pins[str(p)]=H(p)
  row=copy.deepcopy(process);row['capturedStatus']=row.get('status');row['status']='terminal';copied.append(row)
  validation.append(dict(original=str(path),processIndex=index,originalProcessSha256=hashlib.sha256(json.dumps(process,sort_keys=True).encode()).hexdigest().upper(),canonicalTerminalCheckPassed=True))
 assert copied,name
 assert all(Path(p).is_file() and H(p)==h for p,h in pins.items())
 d=out/name;d.mkdir(exist_ok=False);record=dict(schemaVersion=1,status='passed',scope='Authenticated terminal compiler-consumption observation only. No case, compiler acceptance or current source proof.',observedAtUtc=datetime.now(timezone.utc).isoformat(),inputsStable=True,processesStopped=True,inputHashes=pins,processes=copied,originalResult=str(raw_path),originalStatus=raw['status'],originalCompleted=raw.get('completed'),originalTotal=raw.get('total'),claimsTestPassed=False,claimsAcceptancePassed=False,claimsGoalComplete=False,originalTestCompletionAdded=0,representation='Existing retirement14602 uncounted terminal observation. Every process authenticated against original records/journals before status normalization; originals untouched.',processValidation=validation)
 assert not any(k in record for k in ['completed','total','cases'])
 W(d/'result.json',record);observations.append(d/'result.json');mappings.append(dict(original=str(raw_path),sha256=H(raw_path),observation=str(d/'result.json'),status=raw['status'],completed=raw.get('completed'),total=raw.get('total')))
proposal=consumer_closure_record(root,old,observations,B/'v14562/compiler-build01',legacy_terminal=True)
W(out/'proposal.json',proposal);W(out/'mappings.json',mappings)
assert all(H(p['original'])==p['sha256'] for p in mappings)
print(json.dumps(dict(status='read-only-qualified',observations=len(observations),originalTestsAdded=0,retirementExecuted=False)))
