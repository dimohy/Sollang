from pathlib import Path
import json,sys,hashlib,shutil
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler=b/'managed15595/compiler/Sollang.Compiler.dll';contract=b/'async15597-ownership14.json';original=json.loads((b/'managed15595/result.json').read_text(encoding='utf-8-sig'));c=json.loads(contract.read_text(encoding='utf-8-sig'));inputs=[Path(__file__),r/'scripts/verify-async-tail-ownership.ps1',r/'scripts/verification-process.ps1',contract,*[r/x['source'] for x in c['cases']],*[Path(p) for p in original['inputHashes']],*sorted((r/'stdlib').rglob('*.slg')),*compiler.parent.glob('*.dll'),compiler.parent/'Sollang.Compiler.deps.json',compiler.parent/'Sollang.Compiler.runtimeconfig.json'];out=b/'async15600-supervised'
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',completed=0,total=14,inputHashes=pins,scope='Original ASAN8 plus six expression-prefix owner normal/cancel controls; Windows14 first passed',claimsGoalComplete=False);run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  p=run.run([shutil.which('pwsh'),'-NoProfile','-File',str(r/'scripts/verify-async-tail-ownership.ps1'),'-Compiler',str(compiler),'-ExpectedCompilerSha256',sha(compiler),'-OutputDirectory',str(b/'async15600-asan14'),'-ContractFile',str(contract)],out/'asan',timeout=1200);assert p.returncode==0,'OWNERSHIP_ASAN_FAILED';j=json.loads((b/'async15600-asan14/result.json').read_text(encoding='utf-8-sig'));assert j['status']=='passed' and j['completed']==14 and j['inputsStable'] and j['processesStopped'];result.update(status='passed',completed=14)
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','processesStopped','failure']}))
