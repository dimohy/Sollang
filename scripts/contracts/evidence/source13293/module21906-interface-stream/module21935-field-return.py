from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';fixed=len(sys.argv)>1 and sys.argv[1]=='fixed';OUT=B/('module21935-fixed-field-return' if fixed else 'module21928-field-return');CPP=B/('managed21934' if fixed else 'managed21908')/'compiler/Sollang.Compiler.exe';source=ROOT/'scripts/probes/codegen-function-owner/conditional-field-return.slg';paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),source,*sorted((ROOT/'stdlib').rglob('*.slg'))];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=3,cases=[],inputHashes=inputs,maximumCaseSeconds=60,scope='CSharp focused reproduction: borrowed, implicit and explicit return of an owned struct field from a matched owned Result payload. All must retain live siblings and drop each owner once.',claimsGoalComplete=False);ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  exe=OUT/'program.exe';done=ex.run([str(CPP),'build',str(source),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=60);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
  for mode in ['tail','borrow','early']:
   done=ex.run([str(exe),mode],OUT/mode,timeout=30);result['cases'].append(dict(id=mode,passed=done.returncode==0 and done.stdout=='n\n' and not done.stderr,exit=done.returncode,stdout=done.stdout));assert result['cases'][-1]['passed'],(done.returncode,done.stdout,done.stderr);result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
