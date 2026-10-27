from pathlib import Path
import sys,json,hashlib,os
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
b=root/'artifacts/scratch/resume-20261006-owner-continuation22'; frozen=b/'frozen16132';out=b/'runner16642-com604';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
catalog=json.loads((b/'catalog16494-remaining/result.json').read_text());case=next(c for c in catalog['cases'] if c['id']=='604-com-interface');prior=Path(case['resultPath']).parent.parent/'result.json';old=json.loads(prior.read_text());cmd=old['processes'][0]['command'].copy();cmd[1]=str(b/'frozen16132/artifacts/runner16642/Sollang.ExampleTests.dll');cmd[cmd.index('--output-directory')+1]=str(out/'runner')
inputs=[prior,root/'tests/Sollang.ExampleTests/Program.cs',root/'scripts/verification_execution.py',frozen/'scripts/build-com-interop-fixture.ps1',frozen/'tests/com-interop/com_fixture.c']
inputs.extend((b/'frozen16132/artifacts/runner16642').glob('*'))
inputs.extend((frozen/'examples/regression').glob('604-com-interface*'))
inputs.extend([Path(cmd[cmd.index('--compiler')+1]),frozen/'.tools/llvm-22.1.8/bin/clang.exe',frozen/'.tools/llvm-22.1.8/bin/lld-link.exe'])
inputs=[p for p in inputs if p.is_file()]
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r={'schemaVersion':1,'status':'running','completed':0,'total':1,'inputHashes':pins,'caseBudgetSeconds':180,'inheritedLlvmHome':os.environ.get('SOLLANG_LLVM_HOME'),'scope':'Original COM604 fixture and oracle, same selected managed compiler. Tests-only child toolchain propagation fix; prior runner also differs only in input hashing of lexer/grammar files. No global environment or frozen source/oracle edits.'};x=VerificationExecution(frozen,out,r,lambda:all(sha(Path(p))==h for p,h in pins.items()),sha);error=None
 try:
  p=x.run(cmd,out/'case',timeout=180)
  result=json.loads((out/'runner/result.json').read_text(encoding='utf-8-sig'))
  if p.returncode or result.get('failed',0):raise ValueError('ORIGINAL_COM604_FAILED')
  assert all(str(frozen) in key for key in result['fixtureInputHashes']), 'FROZEN_FIXTURE_ROOT_MISMATCH'
  r.update(status='passed',completed=1,runnerResult=result,additiveRunnerHost=str(b/'frozen16132/artifacts/runner16642'))
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
