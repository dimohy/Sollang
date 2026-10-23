from pathlib import Path
import json,hashlib,sys
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'representation12725';o.mkdir(exist_ok=False)
compiler=b/'v12693/compiler-build01/compiler.exe';source=r/'examples/regression/1486-interpolation-capacity-receivers.slg'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert sha(compiler)=='FD2FA260E69EA622080A62372A932402A8633248BC26918ADA655021043B967E'
inputs=[Path(__file__),compiler,compiler.parent/'result.json',source,r/'.tools/llvm-22.1.8/bin/llvm-as.exe']+list((r/'stdlib').rglob('*.slg'));pins={str(p):sha(p) for p in inputs}
d={'schemaVersion':1,'status':'running','scope':'One genuine pre-C707 native raw checked-root emission to distinguish pre-existing representation/storage reservations from source changes; no new compiler build or goal qualification credit.','inputHashes':pins,'completed':0,'total':1,'cases':[],'claimsGoalComplete':False};x=VerificationExecution(r,o,d,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 a=x.run([str(compiler),'windows-stdlib',str(r/'stdlib'),'--jobs','4',str(source)],o/'emit',timeout=120)
 if a.returncode or a.stderr.strip():raise ValueError('RAW_EMISSION_FAILED '+a.stderr)
 p=o/'emitted.ll';p.write_bytes((o/'emit.stdout').read_bytes());a=x.run([str(r/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(p),'-o',str(o/'emitted.bc')],o/'assemble',timeout=60)
 if a.returncode or a.stderr.strip():raise ValueError('RAW_ASSEMBLY_FAILED '+a.stderr)
 d['cases']=[{'id':'pre-c707-raw-root','status':'passed','passed':True,'emissionExit':0,'assemblyExit':0,'emittedLlvmSha256':sha(p)}];d.update(status='passed',completed=1)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
