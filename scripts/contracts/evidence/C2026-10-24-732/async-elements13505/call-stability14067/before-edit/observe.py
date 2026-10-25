import argparse,hashlib,json,sys
from pathlib import Path
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
parser=argparse.ArgumentParser();parser.add_argument('--semantic-proof',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';inputs=b/'call-stability14067';proof_path=args.semantic_proof.resolve();proof=json.loads(proof_path.read_text());assert proof['status']=='passed' and proof['completed']==proof['total']==4 and proof['codegenInvoked'] is False and proof['inputsStable'] and proof['processesStopped'];schema=json.loads((inputs/'schema.json').read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert all(sha(root/p)==h for p,h in schema['sourceHashes'].items());sources=[root/p for p in (inputs/'sources.txt').read_text().splitlines() if p];out=args.output.resolve();assert not out.exists();pins=dict(proof['inputHashes'])
for p in [proof_path,inputs/'schema.json',inputs/'sources.txt',inputs/'generate.py',inputs/'words.py',Path(__file__).resolve()]:pins[str(p)]=sha(p)
exe=out/'probe.exe';binary_hash=None

def stable():
 return all(Path(p).is_file() and sha(p)==h for p,h in pins.items()) and (binary_hash is None or exe.is_file() and sha(exe)==binary_hash)

reusable=[b/'v12432/compiler-build01',b/'v13800/compiler-build01',b/'v14010/compiler-build01'];assert stable();initialize_output(root,out,reusable_directories=reusable);out.mkdir();d=dict(schemaVersion=1,status='running',scope='csharp-before-production-edit-complete-context-stability-baseline',completed=0,total=2,inputHashes=pins,buildMaximumSeconds=180,runtimeMaximumSeconds=30,maximumBuildInvocations=1,maximumRuntimeInvocations=1,claimsGoalComplete=False,claimsOriginal1290Passed=False);x=VerificationExecution(root,out,d,stable,sha);x.save();err=None
try:
 command=[str(b/'managed13673/compiler/Sollang.Compiler.exe'),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','-O1','--jobs','1','--llvm',str(root/'.tools/llvm-22.1.8')]
 p=x.run(command,out/'build',timeout=180);d['buildExit']=p.returncode;d['buildStderr']=(out/'build.stderr').read_text(encoding='utf-8-sig')
 if p.returncode!=0 or d['buildStderr']!='':raise ValueError('STABILITY_BASELINE_BUILD_REJECTED')
 binary_hash=sha(exe);d['executableSha256']=binary_hash;d['completed']=1;x.save();p=x.run([str(exe)],out/'runtime',timeout=30);stdout=(out/'runtime.stdout').read_text(encoding='utf-8-sig');stderr=(out/'runtime.stderr').read_text(encoding='utf-8-sig');d['runtimeExit']=p.returncode;d['runtimeStderr']=stderr;d['observedStdout']=stdout
 if p.returncode!=0 or stderr!='':raise ValueError('STABILITY_BASELINE_RUNTIME_REJECTED')
 lines=stdout.splitlines();expected=schema['corpus'];assert len(lines)==1+33*len(expected) and lines[0]=='call-fields:true';groups=[]
 for index,label in enumerate(expected):
  header=lines[1+33*index].split(':');assert len(header)==7 and header[0]==label and header[1]=='true',header
  counts=list(map(int,header[2:]));assert counts[0]>0 and counts[1]>0
  digest=list(map(int,lines[2+33*index:34+33*index]));assert len(digest)==32 and all(0<=v<=255 for v in digest)
  groups.append(dict(id=label,exactWords=counts[0],selectedCalls=counts[1],genericCalls=counts[2],moveArguments=counts[3],crossModuleCalls=counts[4],beforeSha256=bytes(digest).hex().upper()))
 d.update(status='passed',completed=2,conditionGroups=7,corpus=groups,goldenStdout=stdout.strip());(out/'golden.stdout.txt').write_text(stdout.strip()+'\n',encoding='utf-8',newline='\n')
except BaseException as ex:err=ex
finally:x.finalize(err,cleanup=False)
print(json.dumps({'status':d['status'],'completed':d['completed'],'buildStderr':d.get('buildStderr'),'groups':d.get('corpus',[]),'failure':str(err) if err else None}))
if err:sys.exit(1)
cleanup_output(root,out,execute=True,reusable_directories=reusable)
