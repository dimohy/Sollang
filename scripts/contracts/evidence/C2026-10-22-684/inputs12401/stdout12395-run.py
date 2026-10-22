from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'stdout12395-runtime-emitter';o.mkdir(exist_ok=False)
compiler=root/'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe';sources=[b/'stdout12395-runtime-emitter.slg',root/'selfhost/llvm/emitter/text_output_runtime.slg'];inputs=sources+[Path(__file__)]+list(compiler.parent.glob('Sollang.Compiler.*'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
pins={str(p):sha(p) for p in inputs if p.is_file()};r={'schemaVersion':1,'status':'running','scope':'Actual current SLG Linux text helper emission: ordinary and parallel LLVM assembly, not complete program runtime','inputHashes':pins,'completed':0,'total':2,'cases':[]}
x=VerificationExecution(root,o,r,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 exe=o/'emitter.exe';a=x.run([str(compiler),'build',*[str(p) for p in sources],'-o',str(exe),'--target','windows-x64','--llvm',str(root/'.tools/llvm-22.1.8')],o/'build',timeout=60)
 if a.returncode or a.stderr.strip():raise ValueError('BUILD_FAILED: '+a.stderr[:1000])
 for mode in ['ordinary','parallel']:
  a=x.run([str(exe),mode],o/(mode+'-emit'),timeout=30)
  if a.returncode or a.stderr.strip():raise ValueError('EMIT_FAILED')
  llvm=o/(mode+'.ll');preamble='declare void @sollang_memory_output_sink_append(ptr, ptr, i64)\n' if mode=='parallel' else ''
  llvm.write_bytes((preamble+a.stdout).encode());a=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(o/(mode+'.bc'))],o/(mode+'-assemble'),timeout=30)
  if a.returncode or a.stderr.strip():raise ValueError('ASSEMBLY_FAILED: '+a.stderr[:1000])
  r['cases'].append({'id':mode,'passed':True,'assemblyExit':a.returncode,'emittedLlvmSha256':sha(llvm)});r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure']}))
