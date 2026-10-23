from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'retirement12944-v12915';o.mkdir(exist_ok=False)
compiler=b/'v12915/compiler-build01/compiler.exe';fixture=r/'scripts/probes/source-review-boundaries/platform-directory-reference.slg'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
pins={str(p):sha(p) for p in [compiler,compiler.parent/'result.json',fixture,Path(__file__),r/'scripts/verification_execution.py']}
d=dict(schemaVersion=1,status='running',completed=0,total=1,scope='Real terminal formatter consumer for retiring old verified native product only. No C716/C717 repair or final qualification credit.',inputHashes=pins)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 a=x.run([str(compiler),'format','--check',str(fixture)],o/'format',timeout=30)
 assert a.returncode==0 and not a.stderr.strip(),(a.stdout,a.stderr)
 d.update(status='passed',completed=1)
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(d['status'])
if d['status']!='passed':raise SystemExit(1)
