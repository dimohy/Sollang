from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'reference12956-managed-controls';o.mkdir(exist_ok=False)
compiler=b/'managed12899/compiler/Sollang.Compiler.exe';h=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
fixtures=sorted((b/'reference12955-controls').glob('*.slg'));builder=b/'scratch12644-build.ps1'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=fixtures+[Path(__file__),builder,r/'scripts/verification_execution.py']+list(compiler.parent.glob('Sollang.Compiler.*'))+list(h.parent.glob('SemanticPreflight.*'))+list((r/'stdlib').rglob('*.slg'))
pins={str(p):sha(p) for p in inputs if p.is_file()};d=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='CSharp2 exact primary-input rejection oracles for direct runtime and ordinary function calls; diagnostic style controls before SLG renderer change.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 for f in fixtures:
  rejected=True;row={'id':f.stem};d['cases'].append(row)
  if rejected:
   a=x.run([str(h),str(compiler.with_suffix('.dll')),str(f)],o/(f.stem+'-semantic'),timeout=30);data=json.loads(a.stdout)
   assert data['status']=='failed' and data['codegenInvoked']==False and 'expects sys.path.Path but received ref sys.path.Path' in a.stderr
   row.update(expectedRejected=True,diagnostic=a.stderr)
  else:
   case=o/f.stem;case.mkdir();exe=case/'program.exe'
   a=x.run(['pwsh','-NoProfile','-File',str(builder),'-Compiler',str(compiler),'-Source',str(f),'-Output',str(exe)],case/'build',timeout=120)
   assert a.returncode==0 and not a.stderr.strip(),(f.stem,a.stdout,a.stderr)
   a=x.run([str(exe)],case/'run',timeout=10)
   assert a.returncode==0 and not a.stderr.strip() and a.stdout=='true\n'*4,(f.stem,a.stdout,a.stderr)
   row.update(stdout=a.stdout,runExit=a.returncode,buildExit=0)
  row['status']='passed';d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
