from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'retirement12428';o.mkdir(exist_ok=False)
old=b/'v12304/compiler-build01';replacement=b/'v12405/compiler-build01'
probe=o/'smoke.slg';probe.write_bytes(b'main { "retirement-control" -> println }\n')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[Path(__file__),probe,old/'compiler.exe',old/'result.json',replacement/'compiler.exe',replacement/'result.json'];pins={str(p):sha(p) for p in inputs}
r={'schemaVersion':1,'status':'running','scope':'Terminal old V12304 consumer for product retirement only. Verified V12405 replacement remains protected. No C684/final gate qualification.','inputHashes':pins,'completed':0,'total':1,'cases':[],'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 exe=o/'probe.exe';a=x.run([str(old/'compiler.exe'),'build',str(probe),'-o',str(exe),'--target','windows-x64','--llvm',str(root/'.tools/llvm-22.1.8'),'--keep-temps'],o/'build',timeout=60)
 row={'id':'retirement-smoke','status':'running','expectedBuildExit':0,'buildExit':a.returncode,'buildStderr':a.stderr};r['cases'].append(row)
 if a.returncode or a.stderr.strip():raise ValueError('RETIREMENT_BUILD_FAILED '+a.stderr)
 a=x.run([str(exe)],o/'run',timeout=30);row.update(runExit=a.returncode,runStdout=a.stdout.strip(),runStderr=a.stderr)
 if a.returncode or a.stderr.strip() or a.stdout.strip()!='retirement-control':raise ValueError('RETIREMENT_RUNTIME_FAILED')
 row.update(status='passed',passed=True);r.update(status='passed',completed=1)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
