from pathlib import Path
import sys,json,hashlib
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21681-csharp-view-rejections';CPP=B/'managed21645/compiler/Sollang.Compiler.exe';P=ROOT/'scripts/probes/codegen-unit-stream'
providers=[ROOT/p for p in ['selfhost/llvm/codegen_units.slg','selfhost/llvm/codegen_unit_stream.slg','selfhost/llvm/generated/codegen_cache_policy.slg']];subjects=[P/'reject-local-source.slg',P/'reject-moved-bytes.slg']
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),*providers,*subjects,*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,claimsGoalComplete=False)
ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
try:
 for subject in subjects:
  name=subject.stem;d=OUT/name;d.mkdir();exe=d/'program.exe';done=ex.run([str(CPP),'build',str(subject),*map(str,providers),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0'],d/'build',timeout=180)
  result['cases'].append(dict(id=name,exit=done.returncode,stdout=done.stdout,stderr=done.stderr,productExists=exe.exists()));ex.save()
  assert done.returncode!=0 and 'semantic error' in done.stderr and ('cannot return' in done.stderr or 'borrow' in done.stderr),done.stdout+done.stderr
  assert not exe.exists();result['completed']+=1;ex.save()
 result['status']='passed'
except BaseException as error:err=error
finally:ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}))
if err:raise err
