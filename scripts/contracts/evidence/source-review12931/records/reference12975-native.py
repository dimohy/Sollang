from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'reference12975-native';o.mkdir(exist_ok=False)
managed=b/'managed12899/compiler/Sollang.Compiler.dll';native=b/'v12974/compiler-build01/compiler.exe';h=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
fixtures=sorted((b/'reference12928-inputs').glob('*.slg'))+sorted((b/'reference12955-controls').glob('*.slg'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=fixtures+[b/'scratch12644-build.ps1',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',r/'.tools/llvm-22.1.8/bin/llvm-as.exe',r/'.tools/llvm-22.1.8/bin/clang.exe',Path(__file__),native,b/'v12974/compiler-build01/result.json',r/'scripts/verification_execution.py']+list(managed.parent.glob('Sollang.Compiler.*'))+list(h.parent.glob('SemanticPreflight.*'))+list((r/'stdlib').rglob('*.slg'))
oracles={}
for parent in ['reference12930-managed','reference12956-managed-controls']:
 proof=b/parent/'result.json';inputs.append(proof)
 for row in json.loads(proof.read_text(encoding='utf-8-sig'))['cases']:
  if row.get('expectedRejected'):oracles[row['id']]=row['diagnostic']
pins={str(p):sha(p) for p in inputs if p.is_file()}
d=dict(schemaVersion=1,status='running',completed=0,total=7,inputHashes=pins,cases=[],scope='C716/C717 native3 actual executions and4 exact type rejection/style controls. Original direct reference expressions still reject; named reads load referenced values. No implicit conversion feature added.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 for fixture in fixtures:
  rejected=fixture.stem in ['field-value-input','returned-value-input','direct-runtime-reference','ordinary-function-reference'];case={'id':fixture.stem,'expectedRejected':rejected};d['cases'].append(case)
  caseOutput=o/fixture.stem;caseOutput.mkdir();output=caseOutput/'program.exe'
  a=x.run(['pwsh','-NoProfile','-File',str(b/'scratch12644-build.ps1'),'-Compiler',str(native),'-Source',str(fixture),'-Output',str(output)],o/(fixture.stem+'-native'),timeout=120)
  case['native']={'exit':a.returncode,'stdout':a.stdout,'stderr':a.stderr}
  assert a.returncode==(1 if rejected else 0),(fixture.stem,a.stdout,a.stderr)
  if rejected:
   assert a.stderr==oracles[fixture.stem],(fixture.stem,a.stderr,oracles[fixture.stem])
   assert not output.exists() and not output.with_suffix('.exe.ll').exists()
  else:
   assert output.is_file() and not a.stderr.strip()
   executed=x.run([str(output)],caseOutput/'run',timeout=10)
   assert executed.returncode==0 and not executed.stderr.strip() and executed.stdout=='true\n'*4,(fixture.stem,executed.stdout,executed.stderr)
   case.update(runExit=executed.returncode,stdout=executed.stdout)
  case['status']='passed';d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
