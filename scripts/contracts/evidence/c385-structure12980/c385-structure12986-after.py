from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'c385-structure12986-after';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[Path(__file__),r/'scripts/verify-expression-lowering-parity.ps1',r/'scripts/contracts/expression-lowering-parity.json',r/'scripts/contracts/expression-lowering-parity.schema.json',r/'selfhost/llvm/text/core_calls.slg',r/'scripts/verification_execution.py'];pins={str(p):sha(p) for p in inputs}
d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='Current C385 structural gate and 21 positive/negative self-controls; not dynamic coverage.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 a=x.run(['pwsh','-NoProfile','-File','scripts/verify-expression-lowering-parity.ps1','-SelfTest'],o/'check',timeout=30)
 d.update(actualExit=a.returncode,stdout=a.stdout,stderr=a.stderr)
 assert a.returncode==0, (a.stdout,a.stderr)
 d.update(status='passed',completed=1,scope='Current structural gate passed; dynamic evidence is recorded separately.')
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(d['status'])
if d['status']!='passed':raise SystemExit(1)
