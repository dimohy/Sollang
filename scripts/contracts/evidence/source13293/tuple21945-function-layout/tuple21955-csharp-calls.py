from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'tuple21955-csharp-calls';CPP=B/'managed21954/compiler/Sollang.Compiler.exe';sources=[ROOT/'scripts/probes/codegen-function-tuples'/name for name in ['calls.slg','tuples.slg']];paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),*sources,*sorted((ROOT/'stdlib').rglob('*.slg'))];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=inputs,maximumCaseSeconds=60,scope='CSharp first: actual Int-to-Bool result-producing block and generic Text-to-Unit block calls; no full cache claim.',claimsGoalComplete=False);ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  exe=OUT/'program.exe';done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=60);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
  done=ex.run([str(exe)],OUT/'run',timeout=30);assert done.returncode==0 and done.stdout=='true\nname\n' and not done.stderr,(done.returncode,done.stdout,done.stderr)
  result['cases'].append(dict(id='actual-user-block-calls',passed=True,stdout=done.stdout));result['completed']=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
