from pathlib import Path
import json,hashlib,sys
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();manifest=root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';providers=[root/s.strip() for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s.strip() and not s.strip().endswith('selfhost-sollangc-driver.slg')];probes=[root/'scripts/probes'/s for s in ['module-identity/tryparallel-type-observer.slg','library-interop/checked-calls.slg','library-interop/cached-source-anchor.slg']];adapter=b/'epoch16799-semantic-driver/bin/Release/net11.0/SemanticPreflight.dll';managed=b/'managed16362/compiler/Sollang.Compiler.dll';out=b/'probe16803-semantic';out.mkdir(exist_ok=False);inputs=[Path(__file__),manifest,*providers,*probes,*adapter.parent.glob('*.dll'),*adapter.parent.glob('*.json'),*managed.parent.glob('Sollang.Compiler.*')]
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=len(probes),inputHashes=pins,cases=[],scope='Focused managed semantic checks for all three additional live consumers of extended CheckedPreparation; unchanged production semantic adapter, no LLVM generation',claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for p in probes:
   id=p.stem;run=x.run(['dotnet',str(adapter),str(managed),str(p),*map(str,providers)],out/id,timeout=180);ok=run.returncode==0 and not run.stderr.strip();r['cases'].append(dict(id=id,status='passed' if ok else 'failed',passed=ok,exit=run.returncode,codegenInvoked=False));assert ok,id;r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
