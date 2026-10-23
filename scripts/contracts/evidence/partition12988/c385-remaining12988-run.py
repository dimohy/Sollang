from pathlib import Path
import sys,json,hashlib,shutil
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'c385-remaining12988';o.mkdir(exist_ok=False)
managed=b/'managed12899/compiler/Sollang.Compiler.dll';native=b/'v12974/compiler-build01/compiler.exe';script=r/'scripts/verify-c385-expression-family-batch.ps1';contract=r/'scripts/contracts/c385-expression-family-batch.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
plan=b/'c385-remaining12988-plan.json';c=json.loads(plan.read_text());inputs=[Path(__file__),plan,b/'c385-remaining12988-native.ps1',native,native.parent/'result.json',r/'scripts/verification_execution.py',r/'.tools/llvm-22.1.8/bin/clang.exe',r/'.tools/llvm-22.1.8/bin/llvm-as.exe',Path(shutil.which('dotnet')),Path(shutil.which('pwsh'))]+list(managed.parent.glob('Sollang.Compiler.*'))+list((r/'stdlib').rglob('*.slg'))+list((r/'scripts').glob('*.ps1'))+list((r/'scripts/contracts').glob('*.json'))
for f in set(ca['fixture'] for ca in c['cases']):
 inputs += [r/('examples/regression/'+f+'.slg'),r/('examples/regression/expected/'+f+'.stdout.txt')]
pins={str(p):sha(p) for p in inputs if p.is_file()}
d=dict(schemaVersion=1,status='running',completed=0,total=3,inputHashes=pins,scope='Remaining14 C385 family original12-fixture CSharp first, native second, source/AST/IR admission last; unchanged original oracles,120s per native command.',claimsGoalComplete=False,budget={'managedBuilds':12,'nativeBuilds':12,'nativeSharedJobs':4,'wholeRunLimitSeconds':1800})
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 commands=[('managed',[shutil.which('pwsh'),'-NoProfile','-File',str(r/'scripts/verify-c385-managed-expression-coverage-batch.ps1'),'-Compiler',str(managed),'-ExpectedCompilerSha256',sha(managed),'-ArtifactDirectory',str(o/'managed-artifacts'),'-ResultDirectory',str(o/'managed-results'),'-PlanPath',str(plan)]),('native',[shutil.which('pwsh'),'-NoProfile','-File',str(b/'c385-remaining12988-native.ps1')]),('structure',[shutil.which('pwsh'),'-NoProfile','-File',str(r/'scripts/verify-c385-expression-coverage.ps1'),'-PlanPath',str(plan),'-OutputDirectory',str(o/'coverage')])]
 for name,cmd in commands:
  a=x.run(cmd,o/name,timeout=600);d[name+'Exit']=a.returncode
  assert a.returncode==0,(name,a.stdout[-2000:],a.stderr[-3000:])
  d['completed']+=1;x.save();print(name+' passed',flush=True)
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
