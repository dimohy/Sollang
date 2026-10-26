from pathlib import Path
import json,hashlib,sys,shutil
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();out=b/'async15622-preflight-controls';original=json.loads((r/'scripts/contracts/async-tail-ownership.json').read_text(encoding='utf-8-sig'));bad=dict(original);bad['scope']='wrong';p=b/'async15622-wrong-scope.json';p.write_text(json.dumps(bad),encoding='utf-8');dupe=dict(original);dupe['cases']=[original['cases'][0],original['cases'][0]];q=b/'async15622-duplicate.json';q.write_text(json.dumps(dupe),encoding='utf-8');empty=b/'async15622-empty-llvm';empty.mkdir(exist_ok=False)
compiler=b/'managed15595/compiler/Sollang.Compiler.dll';script=r/'scripts/verify-async-tail-ownership.ps1';cases=[('outside','ASYNC_TAIL_CONTRACT_PATH',['-ContractFile','C:/Windows/outside-contract.json']),('wrong-scope','ASYNC_TAIL_CONTRACT',['-ContractFile',str(p)]),('missing-llvm','ASYNC_TAIL_LLVM_TOOL_MISSING',['-LlvmHome',str(empty)]),('duplicate','ASYNC_TAIL_CASE_ID',['-ContractFile',str(q)])];inputs=[Path(__file__),script,compiler,r/'scripts/verification-process.ps1',p,q,r/'scripts/contracts/async-tail-ownership.json']
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',completed=0,total=4,inputHashes=pins,cases=[],claimsGoalComplete=False);run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for name,expected,extra in cases:
   target=out/(name+'-unstarted');process=run.run([shutil.which('pwsh'),'-NoProfile','-File',str(script),'-Compiler',str(compiler),'-ExpectedCompilerSha256',sha(compiler),'-OutputDirectory',str(target),*extra],out/name,timeout=20);stderr=(out/(name+'.stderr')).read_text(encoding='utf-8-sig');assert process.returncode!=0 and expected in stderr and not target.exists(),(name,stderr);result['cases'].append(dict(id=name,passed=True,expectedFailureId=expected,blockedBeforeOutputAndToolExecution=True));result['completed']+=1
  result['status']='passed'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','processesStopped','failure']}))
