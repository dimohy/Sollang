from pathlib import Path
import json,hashlib,sys
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();compiler=b/'managed17069/compiler/Sollang.Compiler.dll';expected='672CD039C491A57E7C26472FEEFB886552DF2A6560DCDC0673467DA7B7B82B98';assert sha(compiler)==expected
project=root/'tests/Sollang.ExampleTests/Sollang.ExampleTests.csproj';inputs=[Path(__file__),project,compiler,root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py',*[p for p in project.parent.rglob('*.cs') if not any(x in p.relative_to(project.parent).parts for x in ['bin','obj'])],*[p for p in root.glob('Directory.Build.*') if p.is_file()]];inputs += [root/'tests/Sollang.ExampleTests/Fixtures/storage-placement-frame-merge.json'];inputs += list((root/'stdlib').rglob('*.slg'));inputs=list(dict.fromkeys(inputs));out=b/'merge17125-reference6';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='Tests-only build and production StoragePlacementAnalyzer frame merge6 reference. Compiler project references are not built and selected672 DLL must remain identical.',claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  cmd=['dotnet','build',str(project),'-c','Release','--no-restore','--nologo','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false','-p:BuildProjectReferences=false','-warnaserror','--output',str(out/'bin')];built=x.run(cmd,out/'build',timeout=180);ok=built.returncode==0 and sha(compiler)==expected;r['cases'].append(dict(id='tests-only-module-llvm-controls',status='passed' if ok else 'failed',passed=ok,buildExit=built.returncode,expectedBuildExit=0));assert ok
  checked=x.run(['dotnet',str(out/'bin/Sollang.ExampleTests.dll'),'--storage-placement-reference',str(compiler),str(root/'tests/Sollang.ExampleTests/Fixtures/storage-placement-frame-merge.json'),str(out/'source-frame-result.json')],out/'candidate-reference',timeout=180);assert checked.returncode==0
  proof=json.loads((out/'source-frame-result.json').read_text(encoding='utf-8'));assert proof['completed']==6 and proof['total']==6 and proof['inputsStable']
  r['cases'].append(dict(id='production-frame-merge6',status='passed',passed=True,referenceResult=str(out/'source-frame-result.json')))
  r.update(status='passed',completed=2,managedCompilerDllSha256After=sha(compiler))
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
