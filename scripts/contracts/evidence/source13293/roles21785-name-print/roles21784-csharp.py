from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'roles21784-csharp';CPP=B/'managed21775/compiler/Sollang.Compiler.exe';P=ROOT/'scripts/probes/each-role-display'
providers=[]
cases=[('text-entry','entry\n한글\n'),('text-function','function\ntyped\n'),('bool-control','true\nfalse\n'),('int-control','-1\n2\n'),('member','member\n'),('stream','2\n2\n')]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),*providers,*[(P/(n+'.slg') if n!='stream' else ROOT/'scripts/probes/source-review-boundaries/scratch-integer-stream.slg') for n,_ in cases],*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
result=dict(schemaVersion=1,status='running',completed=0,total=len(cases),cases=[],inputHashes=inputs,claimsGoalComplete=False)
ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
try:
 for name,expected in cases:
  d=OUT/name;d.mkdir();exe=d/'program.exe';start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));done=ex.run([str(CPP),'build',str(P/(name+'.slg') if name!='stream' else ROOT/'scripts/probes/source-review-boundaries/scratch-integer-stream.slg'),*map(str,providers),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0'],d/'build',timeout=budget());diagnostic=done.stderr
  assert done.returncode==0 and not diagnostic,done.stdout+diagnostic
  done=ex.run([str(exe)],d/'run',timeout=budget())
  if expected is None:assert done.returncode!=0 and not done.stdout,done.stdout+done.stderr
  else:assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout+done.stderr
  stdout=done.stdout
  result['cases'].append(dict(id=name,passed=True,expectedRuntimeTrap=expected is None,diagnostic=diagnostic,stdout=stdout));result['completed']+=1;ex.save()
 result['status']='passed'
except BaseException as error:err=error
finally:ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}))
if err:raise err
