from pathlib import Path
import json,hashlib,sys
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();compiler=b/'managed16362/compiler/Sollang.Compiler.dll';expected='375D9B7D7448758904AFE49F1F8DDD9136E218EFFCC75A221E63C395B501DDB1';assert sha(compiler)==expected
project=root/'tests/Sollang.ExampleTests/Sollang.ExampleTests.csproj';inputs=[Path(__file__),project,compiler,root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py',*[p for p in project.parent.rglob('*.cs') if not any(x in p.relative_to(project.parent).parts for x in ['bin','obj'])],*[p for p in root.glob('Directory.Build.*') if p.is_file()]];inputs += [root/'artifacts/scratch/resume-20261006-owner-continuation22/readonly17039-reference13.json'];inputs += list((root/'stdlib').rglob('*.slg'));inputs=list(dict.fromkeys(inputs));out=b/'readonly17039-reference13';out.mkdir(exist_ok=False)
product=b/'candidates17000-reference19/bin/Sollang.ExampleTests.dll';build=json.loads((b/'candidates17000-reference19/result.json').read_text(encoding='utf-8'));assert sha(product)==build['generatedOutputHashes'][str(product)]
inputs += [product,product.with_name('Sollang.ExampleTests.deps.json'),product.with_name('Sollang.ExampleTests.runtimeconfig.json')]
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='Tests-only build and production StoragePlacementAnalyzer source-frame10 reference. Compiler project references are not built and selected375 DLL must remain identical.',claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  r['cases'].append(dict(id='reuse-qualified-tests-only-build',status='passed',passed=True))
  checked=x.run(['dotnet',str(b/'candidates17000-reference19/bin/Sollang.ExampleTests.dll'),'--storage-placement-reference',str(compiler),str(root/'artifacts/scratch/resume-20261006-owner-continuation22/readonly17039-reference13.json'),str(out/'source-frame-result.json')],out/'candidate-reference',timeout=180);assert checked.returncode==0
  proof=json.loads((out/'source-frame-result.json').read_text(encoding='utf-8'));assert proof['completed']==13 and proof['total']==13 and proof['inputsStable']
  r['cases'].append(dict(id='production-source-frame10',status='passed',passed=True,referenceResult=str(out/'source-frame-result.json')))
  r.update(status='passed',completed=2,managedCompilerDllSha256After=sha(compiler))
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
