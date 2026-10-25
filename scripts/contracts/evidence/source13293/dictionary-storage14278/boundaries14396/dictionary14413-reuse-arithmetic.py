from pathlib import Path
import json,hashlib,sys
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';P=R/'scripts/probes/dictionary-storage-boundaries';sys.path.insert(0,str(R/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
parent=B/'dictionary14412-managed-arithmetic';prior=json.loads((parent/'result.json').read_text(encoding='utf-8-sig'));assert prior['status']=='failed' and prior['inputsStable'] and prior['processesStopped'];assert len(prior['processes'])==1 and prior['processes'][0]['exit']==0 and prior['processes'][0]['shutdownConfirmed'];assert not (parent/'build.stderr').read_text(encoding='utf-8-sig');assert '<TreatWarningsAsErrors>true</TreatWarningsAsErrors>' in (parent/'Arithmetic.csproj').read_text(encoding='utf-8')
pins=dict(prior['inputHashes']);pins.update(prior['generatedOutputHashes'])
for p,h in pins.items():assert Path(p).is_file() and sha(p)==h,p
for p in [parent/'result.json',parent/'build.stdout',parent/'build.stderr',Path(__file__).resolve()]:pins[str(p)]=sha(p)
data=json.loads((P/'arithmetic.json').read_text(encoding='utf-8'));expected=[','.join(str(row[k]) for k in ['length','capacity','entriesOffset','allocationBytes']) for row in data['rows']]+['layout=4,8,4']
out=B/'dictionary14414-managed-arithmetic';retained=[B/'v12432/compiler-build01',B/'v14280/compiler-build01'];initialize_output(R,out,reusable_directories=retained);out.mkdir(exist_ok=False)
record=dict(schemaVersion=1,status='running',scope='Actual CSharp helper source arithmetic; reuse succeeded warning-as-error build after previous adapter falsely required English log text. Original failed record and outputs preserved.',inputHashes=pins,completed=0,total=len(expected),cases=[],buildInvocations=0,reusedBuildResult=str(parent/'result.json'),caseBudgetSeconds=180,claimsGoalComplete=False)
x=VerificationExecution(R,out,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 dotnet=prior['processes'][0]['command'][0];run=x.run([dotnet,str(parent/'bin/Release/net11.0/Arithmetic.dll'),str(P/'arithmetic.json')],out/'run',timeout=180);assert run.returncode==0 and not run.stderr,run.stderr;actual=run.stdout.strip().splitlines();assert actual==expected,(actual,expected)
 record.update(status='passed',completed=len(expected),cases=[dict(id='arithmetic-'+str(i),status='passed',passed=True,buildExit=0,runExit=0,expected=v,actual=actual[i]) for i,v in enumerate(expected)])
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
if record['status']=='passed' and record['inputsStable'] and record['processesStopped']:cleanup_output(R,out,execute=True,reusable_directories=retained)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}));sys.exit(0 if record['status']=='passed' else 1)
