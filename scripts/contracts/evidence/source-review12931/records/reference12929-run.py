from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'reference12929-admission';o.mkdir(exist_ok=False)
managed=b/'managed12899/compiler/Sollang.Compiler.dll';native=b/'v12915/compiler-build01/compiler.exe';h=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
fixtures=sorted((b/'reference12928-inputs').glob('*.slg'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=fixtures+[Path(__file__),native,b/'v12915/compiler-build01/result.json',r/'scripts/verification_execution.py']+list(managed.parent.glob('Sollang.Compiler.*'))+list(h.parent.glob('SemanticPreflight.*'))+list((r/'stdlib').rglob('*.slg'))
pins={str(p):sha(p) for p in inputs if p.is_file()}
d=dict(schemaVersion=1,status='running',completed=0,total=10,inputHashes=pins,cases=[],scope='Current CSharp semantic-only and native CLI admission for readonly reference input boundaries; positive native programs compile but are not executed. No implicit conversion feature added.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 for fixture in fixtures:
  rejected=fixture.stem in ['field-value-input','returned-value-input'];case={'id':fixture.stem,'expectedRejected':rejected};d['cases'].append(case)
  a=x.run([str(h),str(managed),str(fixture)],o/(fixture.stem+'-managed'),timeout=30);data=json.loads(a.stdout)
  assert data['codegenInvoked']==False and a.returncode==0
  assert data['status']==('failed' if rejected else 'passed'),(fixture.stem,a.stdout,a.stderr)
  if rejected:assert 'sys.directory.create expects sys.path.Path but received ref sys.path.Path' in a.stderr
  else:assert not data['warnings'] and not a.stderr.strip()
  case['managed']={'status':data['status'],'stderr':a.stderr};d['completed']+=1;x.save()
  output=o/(fixture.stem+'.exe')
  a=x.run([str(native),'build',str(fixture),'-o',str(output),'--target','windows-x64','--keep-temps','--llvm',str(r/'.tools/llvm-22.1.8')],o/(fixture.stem+'-native'),timeout=120)
  case['native']={'exit':a.returncode,'stdout':a.stdout,'stderr':a.stderr}
  assert a.returncode==(1 if rejected else 0),(fixture.stem,a.stdout,a.stderr)
  if rejected:
   assert 'sys.directory.create expects sys.path.Path but received ref sys.path.Path' in a.stderr
   assert not output.exists() and not output.with_suffix('.exe.ll').exists()
  else:assert output.is_file() and not a.stderr.strip()
  case['status']='passed';d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
