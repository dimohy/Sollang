from pathlib import Path
import sys,json,hashlib,time
root=Path.cwd(); b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
runner=b/'runner16766-build/bin/Sollang.ExampleTests.dll';managed=b/'managed16362/compiler/Sollang.Compiler.dll';native=b/'v16730/compiler-build01/compiler.exe'
assert sha(managed)=='375D9B7D7448758904AFE49F1F8DDD9136E218EFFCC75A221E63C395B501DDB1'
assert sha(native)=='5184988C734374FC01D6E5078F1A90B54EF88018B0EE42D54E6E6EFB84DC35B1'
build=json.loads((b/'runner16766-build/result.json').read_text(encoding='utf-8-sig'));assert build['status']=='passed' and build['inputsStable'] and build['processesStopped']
for p,h in build['inputHashes'].items(): assert sha(p)==h,p
inputs=[Path(__file__),managed,native,b/'v16730/compiler-build01/result.json',b/'runner16766-build/result.json',*runner.parent.glob('*.dll'),*runner.parent.glob('*.json'),*managed.parent.glob('Sollang.Compiler.*'),*root.glob('Sollang.slnx'),*map(Path,build['inputHashes'])]
for part in ['examples/regression','stdlib']:
 inputs.extend(p for p in (root/part).rglob('*') if p.is_file() and p.suffix in ['.slg','.txt'])
inputs=list(dict.fromkeys(inputs));out=b/'llvm16772-roles';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=3,inputHashes=pins,cases=[],caseBudgetSeconds=180,scope='LLVM assertion prototype qualification only: unchanged original52 CSharp/Native, original51 Native to recover lifecycle-cleaned LLVM for backward controls; no integration66/source111/native100 repeat or final credit',claimsGoalComplete=False)
 x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for id,compiler,managedRole in [('52-multi-file-modules',managed,True),('52-multi-file-modules',native,False),('51-fixed-array-value-generics',native,False)]:
   label=id+('-csharp' if managedRole else '-native');folder=out/label;folder.mkdir();cmd=['dotnet',str(runner),'--compiler',str(compiler),'--skip-bootstrap','--suite','full','--target','windows-x64','--jobs','1','--output-directory',str(folder/'runner'),'--exact',id]
   if managedRole:cmd.append('--compare-compilers')
   run=x.run(cmd,folder/'execution',timeout=180);inner=json.loads((folder/'runner/result.json').read_text(encoding='utf-8-sig'));ok=run.returncode==0 and inner['status']=='passed' and inner['completed']==inner['total']==1 and inner['inputsStable'] and inner['processesStopped'];r['cases'].append(dict(id=label,status='passed' if ok else 'failed',passed=ok,resultPath=str(folder/'runner/result.json')));x.save()
   assert ok,label
   r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
