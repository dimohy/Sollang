from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'owner21689-csharp-source-owner';CPP=B/'managed21688/compiler/Sollang.Compiler.exe';P=ROOT/'scripts/probes/codegen-unit-stream'
providers=[ROOT/p for p in ['selfhost/llvm/codegen_units.slg','selfhost/llvm/codegen_unit_stream.slg','selfhost/llvm/generated/codegen_cache_policy.slg']]
cases=[(n,None) for n in ['reject-local-source','reject-moved-bytes','reject-local-source-direct','reject-local-source-ref','reject-carrier-source','reject-source-array']]+[('static-slice','prefix\n'),('carrier-text','prefix\n'),('source-ref','; soll\n')]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),*providers,*[P/(n+'.slg') for n,_ in cases],P/'input.txt',*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
result=dict(schemaVersion=1,status='running',completed=0,total=len(cases),cases=[],inputHashes=inputs,claimsGoalComplete=False)
ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
try:
 for name,expected in cases:
  d=OUT/name;d.mkdir();exe=d/'program.exe';start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));done=ex.run([str(CPP),'build',str(P/(name+'.slg')),*map(str,providers),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0'],d/'build',timeout=budget());diagnostic=done.stderr
  if expected is None:
   assert done.returncode!=0 and 'borrowed origin' in diagnostic and 'cannot escape function' in diagnostic,done.stdout+diagnostic
   assert not exe.exists();stdout=None
  else:
   assert done.returncode==0 and not diagnostic,done.stdout+diagnostic
   done=ex.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout+done.stderr;stdout=done.stdout
  result['cases'].append(dict(id=name,passed=True,expectedRejection=expected is None,diagnostic=diagnostic,stdout=stdout));result['completed']+=1;ex.save()
 result['status']='passed'
except BaseException as error:err=error
finally:ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}))
if err:raise err
