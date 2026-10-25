from pathlib import Path
import json,hashlib,sys,time,re,shutil
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
B=root/'artifacts/scratch/resume-20261006-owner-continuation22'
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
mp=B/'original14855-managed2/result.json';np=B/'original14858-native2/result.json'
m=R(mp);n=R(np);assert all(v['status']=='passed' and v['completed']==v['total']==2 and v['inputsStable'] and v['processesStopped'] for v in [m,n])
assert m['selectedCatalog']==n['selectedCatalog'] and [x['id'] for x in m['cases']]==[x['id'] for x in n['cases']]
runner=B/'runner14810/bin/Sollang.ExampleTests.dll';dotnet=shutil.which('dotnet');assert dotnet
pins={}
for parent in [m,n]:
 for p,h in parent['inputHashes'].items():assert Path(p).is_file() and H(p)==h;assert p not in pins or pins[p]==h;pins[p]=h
for p in [mp,np,runner,Path(dotnet),Path(__file__).resolve(),root/'scripts/verification_execution.py',root/'scripts/completed_artifact_plan.py']:
 pins[str(p)]=H(p)
for a,b in zip(m['cases'],n['cases']):
 assert a['id']==b['id'] and re.fullmatch('[A-Za-z0-9._-]+',a['id'])
 for row in [a,b]:assert row['status']=='passed';p=Path(row['resultPath']);assert p.is_file();pins[str(p)]=H(p)
stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
out=B/'original14860-compare2';initialize_output(root,out,reusable_directories=[B/'v12432/compiler-build01',B/'v14562/compiler-build01',B/'v14775/compiler-build01']);out.mkdir(exist_ok=False)
r=dict(schemaVersion=1,status='running',completed=0,total=2,steps=[],scope='Actual current original2 canonical managed/native comparisons; no source/oracle relaxation or final/Stage credit.',inputHashes=pins,maximumSeconds=180,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,H);error=None;started=time.monotonic()
try:
 for a,b in zip(m['cases'],n['cases']):
  remaining=180-(time.monotonic()-started);assert remaining>0,'ORIGINAL2_COMPARISON_BUDGET_EXHAUSTED'
  done=x.run([dotnet,str(runner),'--compare-results',a['resultPath'],b['resultPath']],out/(a['id']+'.compare'),timeout=min(30,remaining))
  assert done.returncode==0,done.stderr
  assert done.stdout.strip()=='PASS actual managed/native results 1/1',done.stdout
  r['steps'].append(dict(id=a['id'],status='complete',managed=a['resultPath'],native=b['resultPath'],stdout=str(out/(a['id']+'.compare.stdout'))))
  r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
