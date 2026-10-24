from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
previous=json.loads((b/'managed13239/result.json').read_text(encoding='utf-8'))
command=[arg.replace('managed13239','managed13519') for arg in previous['processes'][0]['command']]
paths=[Path(p) for p in previous['inputHashes'] if Path(p).is_file() and 'managed13239' not in p]+[Path(__file__)]
pins={str(p):sha(p) for p in paths}
out=b/'managed13519';out.mkdir(exist_ok=False)
d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='Isolated finite bounded array type admission and async transferability CSharp source build; reuse known managed build command and supervision; no Native compiler-image build.',claimsGoalComplete=False)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 p=x.run(command,out/'build',timeout=180)
 assert p.returncode==0,p.stderr
 d.update(status='passed',completed=1,compilerDllSha256=sha(out/'compiler/Sollang.Compiler.dll'))
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure','compilerDllSha256']}));sys.exit(0 if d['status']=='passed' else 1)
