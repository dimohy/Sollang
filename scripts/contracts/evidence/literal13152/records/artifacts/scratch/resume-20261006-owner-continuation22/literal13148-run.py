from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'literal13148-native-build';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proof=json.loads((b/'literal13145-runtime/result.json').read_text());inputs=[Path(p) for p in proof['inputHashes']]+[Path(__file__),b/'literal13148-build.ps1',b/'literal13140-preflight/result.json',b/'literal13147-managed/result.json',b/'literal13144-source/result.json',b/'literal13145-runtime/result.json',b/'literal13142-stdlib/result.json']+list((r/'scripts').glob('*.ps1'))+list((r/'scripts/contracts').glob('*.json'));pins={str(p):sha(p) for p in inputs if p.is_file()}
d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='One new current-source selfhost image after CSharp17/source17/runtime11 executed controls; original root gates remain open.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 a=x.run(['pwsh','-NoProfile','-File',str(b/'literal13148-build.ps1')],o/'check',timeout=600)
 d.update(actualExit=a.returncode,stdout=a.stdout,stderr=a.stderr)
 assert a.returncode==0, (a.stdout,a.stderr)
 d.update(status='passed',completed=1,scope='New compiler image built; focused native and full original gates remain pending.')
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(d['status'])
if d['status']!='passed':raise SystemExit(1)
