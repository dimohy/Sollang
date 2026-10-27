from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
old=json.loads((b/'managed17069/result.json').read_text(encoding='utf-8'));command=[a.replace('managed17069','managed17430') for a in old['processes'][0]['command']];paths=[Path(p) for p in old['inputHashes'] if Path(p).is_file() and 'managed17069' not in p]+[Path(__file__)];out=b/'managed17430';out.mkdir(exist_ok=False)
with VerificationContractLease(paths):
 pins={str(p):sha(p) for p in paths};d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='C748 CSharp first: anonymous Task direct builtin consumer reuses exact ownership recognition; other heap owners and argument/async boundaries remain checked. Build180, no shared compiler overwrite.',claimsGoalComplete=False);x=VerificationExecution(r,out,d,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  p=x.run(command,out/'build',timeout=180);assert p.returncode==0,p.stderr;d.update(status='passed',completed=1,compilerDllSha256=sha(out/'compiler/Sollang.Compiler.dll'))
 except BaseException as e:error=e
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:d.get(k) for k in ['status','inputsStable','processesStopped','failure','compilerDllSha256']}))
 if error:raise error
