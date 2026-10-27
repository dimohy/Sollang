from pathlib import Path
import json,hashlib,sys
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();planpath=b/'duplicate16790-contract.json';p=json.loads(planpath.read_text(encoding='utf-8-sig'));producer=root/p['producer'];adapter=b/'duplicate16783-semantic/bin/Release/net11.0/SemanticPreflight.dll';compiler=b/'managed16362/compiler/Sollang.Compiler.dll';prior=b/'duplicate16783-semantic/result.json';proof=json.loads(prior.read_text(encoding='utf-8-sig'));assert proof['status']=='passed' and proof['completed']==proof['total']==4 and proof['inputsStable'] and proof['processesStopped']
inputs=[Path(__file__),planpath,producer,adapter,compiler,prior,*map(Path,proof['inputHashes']),*[root/k for k in p['providers']],*adapter.parent.glob('*.json'),*adapter.parent.glob('*.dll')];inputs=list(dict.fromkeys(inputs));out=b/'duplicate16791-semantic';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(k):sha(k) for k in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],retainedControlsReference=str(prior),scope='Reuse existing semantic preflight adapter and three unchanged controls; focused proof for changed cache test producer only, no LLVM generation',claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(k).is_file() and sha(k)==h for k,h in pins.items()),sha);error=None
 try:
  for id,cmd in [('format',['dotnet',str(compiler),'format','--check',str(producer)]),('focused',['dotnet',str(adapter),str(compiler),str(producer),*[str(root/k) for k in p['providers']]])]:
   executed=x.run(cmd,out/id,timeout=180);ok=executed.returncode==0 and not executed.stderr.strip();r['cases'].append(dict(id=id,passed=ok,status='passed' if ok else 'failed',exit=executed.returncode));assert ok,id;r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
