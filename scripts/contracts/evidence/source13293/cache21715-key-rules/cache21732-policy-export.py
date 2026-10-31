import json,hashlib,sys
from pathlib import Path
from datetime import datetime,timezone
sys.path.insert(0,'scripts')
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
r=Path.cwd(); b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def write(p,v): p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
out=b/'cache21732-policy-export';initialize_output(r,out,reusable_directories=[b/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);out.mkdir()
compiler=b/'managed21731/compiler/Sollang.Compiler.dll'; runner=b/'cache21717-test-runner/compiler/Sollang.ExampleTests.dll'
paths=[Path(__file__),compiler,runner,*[r/p for p in ['src/Sollang.Compiler/Shared/Policies/CodegenCachePolicy.cs','src/Sollang.Compiler/Shared/Policies/BorrowedTextReturnPolicy.cs','selfhost/llvm/generated/codegen_cache_policy.slg','selfhost/semantic/generated/borrowed_text_return_policy.slg']]]
from verification_fingerprints import managed_runtime_inputs
paths += [r/'src/Sollang.Compiler/Shared/Policies/CodegenCacheKeyPolicy.cs',r/'selfhost/llvm/generated/codegen_cache_key_policy.slg',*managed_runtime_inputs(compiler),*managed_runtime_inputs(runner),r/'src/Sollang.Compiler/Cli/SelfHostPolicyCompiler.cs',r/'tests/Sollang.ExampleTests/SelfHostPolicyTests.cs']
inputs={str(p.resolve()):sha(p) for p in paths};result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=inputs,claimsGoalComplete=False)
ex=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
try:
 for name,args in [('policy',['dotnet',str(runner),'--selfhost-policy-tests',str(compiler),str(out/'policy-tests.json')])]:
  done=ex.run(args,str(out/name),timeout=60)
  assert done.returncode==0,done.stderr+done.stdout
  inner=json.loads((out/'policy-tests.json').read_text());assert inner['status']=='passed' and inner['completed']==inner['total']==44,inner.get('failure');result['completed']+=1;ex.save()
 result['status']='passed'
except BaseException as x:err=x
finally:ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}))
if err:raise err
