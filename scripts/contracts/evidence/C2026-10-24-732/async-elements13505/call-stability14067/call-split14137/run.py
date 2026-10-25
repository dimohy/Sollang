import argparse,hashlib,json,sys,subprocess
from pathlib import Path
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--semantic-proof',type=Path,required=True);args=parser.parse_args();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';source=b/'call-split14137';plan_path=source/'plan.json';plan=read(plan_path);proof_path=args.semantic_proof.resolve();proof=read(proof_path);assert proof['status']=='passed' and proof['completed']==proof['total']==4 and proof['codegenInvoked'] is False and proof['inputsStable'] and proof['processesStopped'];assert plan['maximumBuildInvocations']==plan['maximumRuntimeInvocations']==1 and plan['retryCount']==0 and plan['runtimeMaximumSeconds']==plan['buildMaximumSeconds']==180
pins=dict(plan['inputHashes'])
for p,h in proof['inputHashes'].items():assert p not in pins or pins[p]==h;pins[p]=h
for p in [plan_path,proof_path,Path(__file__).resolve(),root/'scripts/verification_execution.py',root/'scripts/completed_artifact_plan.py',root/'.tools/llvm-22.1.8/bin/clang.exe']:pins[str(p)]=sha(p)
output=args.output.resolve();exe=output/'profile.exe';binary_hash=None;reusable=[b/n/'compiler-build01' for n in ['v12432','v14010','v14112']]
def stable():return all(Path(p).is_file() and sha(p)==h for p,h in pins.items()) and (binary_hash is None or exe.is_file() and sha(exe)==binary_hash)
assert stable();build=[str(root/plan['compiler']),'build',*[str(root/p) for p in plan['harnessSources']],'-o',str(exe),'--target','windows-x64','--keep-temps','-O2','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')];runtime=[str(exe),*plan['paths']];assert len(subprocess.list2cmdline(build))<32767 and len(subprocess.list2cmdline(runtime))<32767
initialize_output(root,output,reusable_directories=reusable);output.mkdir();d={'schemaVersion':1,'status':'running','scope':'Existing public call-context profiling API; initial core versus completion, raw stdlib0; diagnostic only, no production acceptance.','completed':0,'total':2,'inputHashes':pins,'buildMaximumSeconds':180,'runtimeMaximumSeconds':180,'maximumBuildInvocations':1,'maximumRuntimeInvocations':1,'claimsOriginal1290Passed':False,'claimsPerformanceImprovement':False,'claimsGoalComplete':False};x=VerificationExecution(root,output,d,stable,sha);error=None
try:
 p=x.run(build,output/'build',timeout=180);assert p.returncode==0 and not p.stderr,p.stderr;binary_hash=sha(exe);d.update(completed=1,executableSha256=binary_hash);x.save();p=x.run(runtime,output/'runtime',timeout=180);assert p.returncode==0 and not p.stderr,p.stderr;lines=p.stdout.splitlines();assert len(lines)==10 and lines[0:2]==['prepare-files','resolve-call-context'] and lines[2::2]==['initial-core-ms','completion-ms','selected-calls','resolved-types'],lines;values=list(map(int,lines[3::2]));assert all(v>=0 for v in values) and values[2]>0 and values[3]>0;d.update(status='passed',completed=2,initialCoreMilliseconds=values[0],completionMilliseconds=values[1],selectedCalls=values[2],resolvedTypes=values[3],observedStdout=p.stdout)
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','initialCoreMilliseconds','completionMilliseconds','selectedCalls','resolvedTypes','failure','inputsStable','processesStopped']}));
if error:sys.exit(1)
cleanup_output(root,output,execute=True,reusable_directories=reusable)
