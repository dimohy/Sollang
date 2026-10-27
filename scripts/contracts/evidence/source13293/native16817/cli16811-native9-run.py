from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';contractpath=b/'cli16811-native9.json';plan=json.loads(contractpath.read_text(encoding='utf-8-sig'));fixture=Path(plan['fixtureRoot']);runner=Path(plan['runner']);compiler=b/'v16808/compiler-build01/compiler.exe';out=b/'cli16811-native9';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
buildpath=compiler.parent/'result.json';build=json.loads(buildpath.read_text(encoding='utf-8-sig'));assert build['status']=='passed' and build['inputsStable'] and sha(compiler)==build['compilerSha256'];inputs=[contractpath,Path(__file__),root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py',fixture/'Sollang.slnx',compiler,buildpath,*runner.parent.glob('*.dll'),*runner.parent.glob('*.json')]
for part in ['examples/regression','stdlib','tests/Sollang.ExampleTests']:
 inputs.extend(p for p in (fixture/part).rglob('*') if p.is_file() and p.suffix in ['.slg','.txt','.cs'])
for reference in plan['referenceProofs']:
 proofpath=root/reference;proof=json.loads(proofpath.read_text(encoding='utf-8-sig'));assert proof['status']=='passed' and proof['completed']==proof['total'] and proof['inputsStable'] and proof['processesStopped']
 for name,expected in proof['inputHashes'].items():assert Path(name).is_file() and sha(name)==expected.upper(),name
 inputs.extend([proofpath,*map(Path,proof['inputHashes'])])
inputs=list(dict.fromkeys(inputs))
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r={'schemaVersion':1,'status':'running','completed':0,'total':len(plan['ids']),'cases':[],'inputHashes':pins,'caseBudgetSeconds':180,'scope':plan['scope'],'dependencyClosure':'Pin every fixture program, helper, oracle, all144 frozen stdlib files, runner producer/runtime and selected compiler. Selected Native binary and immutable build record are pinned; its actual program and diagnostic outputs must match the original CSharp references.','claimsGoalComplete':False};x=VerificationExecution(fixture,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for id in plan['ids']:
   folder=out/hashlib.sha256(id.encode()).hexdigest()[:20];folder.mkdir();cmd=['dotnet',str(runner),'--compiler',str(compiler),'--skip-bootstrap','--suite','full','--target','windows-x64','--jobs','1','--output-directory',str(folder/'runner'),'--exact',id];result=x.run(cmd,folder/'execution',timeout=180);inner=json.loads((folder/'runner/result.json').read_text(encoding='utf-8-sig'));assert all(str(fixture) in p for p in inner['fixtureInputHashes']);ok=result.returncode==0 and inner['status']=='passed' and inner['completed']==inner['total']==1 and inner['inputsStable'] and inner['processesStopped'];r['cases'].append({'id':id,'status':'passed' if ok else 'failed','resultPath':str(folder/'runner/result.json')})
   if not ok:raise ValueError('C741_CURRENT_NATIVE_FAILED:'+id)
   r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']})
 if error:raise error
