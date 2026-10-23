from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'stdin12806-emitter';o.mkdir(exist_ok=False)
comp=b/'managed12799/compiler/Sollang.Compiler.exe';fixture=r/'scripts/probes/source-review-boundaries/windows-stdin-emitter.slg';runtime=r/'selfhost/llvm/runtime.slg';formatter=b/'v12432/compiler-build01/compiler.exe'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[fixture,runtime,formatter]+list(comp.parent.glob('Sollang.Compiler.*'))+list((r/'stdlib').rglob('*.slg'))
pins={str(p):sha(p) for p in inputs};record={'schemaVersion':1,'status':'running','inputHashes':pins,'completed':0,'total':1,'claimsGoalComplete':False};x=VerificationExecution(r,o,record,lambda:all(sha(p)==h for p,h in pins.items()),sha);err=None
try:
 a=x.run([str(formatter),'format','--check',str(fixture)],o/'format',timeout=30);assert a.returncode==0 and not a.stderr.strip(),a.stderr
 exe=o/'emit.exe';a=x.run([str(comp),'build',str(fixture),str(runtime),'-o',str(exe),'--target','windows-x64','--keep-temps','--llvm',str(r/'.tools/llvm-22.1.8')],o/'build',timeout=90);assert a.returncode==0 and not a.stderr.strip(),a.stderr
 a=x.run([str(exe)],o/'emit',timeout=5);assert a.returncode==0 and not a.stderr.strip(),a.stderr
 (o/'emitted.ll').write_bytes((o/'emit.stdout').read_bytes());record['emittedSha256']=sha(o/'emitted.ll');record.update(status='passed',completed=1)
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
