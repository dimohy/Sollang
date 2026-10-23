from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'ownership12985-pair';o.mkdir(exist_ok=False)
fixtures=['1576-consuming-enum-match-cleanup','1577-consuming-enum-payload-transfer'];builder=b/'scratch12644-build.ps1'
compilers=[('managed',b/'managed12899/compiler/Sollang.Compiler.exe'),('native',b/'v12974/compiler-build01/compiler.exe')]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[builder,Path(__file__),r/'scripts/verification_execution.py',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',r/'.tools/llvm-22.1.8/bin/clang.exe',r/'.tools/llvm-22.1.8/bin/llvm-as.exe',b/'v12974/compiler-build01/result.json']+[p for _,p in compilers]+list(compilers[0][1].parent.glob('Sollang.Compiler.*'))+list((r/'stdlib').rglob('*.slg'))
for f in fixtures:inputs += [r/('examples/regression/'+f+'.slg'),r/('examples/regression/expected/'+f+'.stdout.txt')]
pins={str(p):sha(p) for p in inputs if p.is_file()};d=dict(schemaVersion=1,status='running',completed=0,total=4,inputHashes=pins,cases=[],scope='Original1576 cleanup and1577 payload transfer under current CSharp first then native; synchronous owned enum match audit only, no async/cancel or whole frozen-suite claim.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 for name,compiler in compilers:
  for fixture in fixtures:
   source=r/('examples/regression/'+fixture+'.slg');expected=r/('examples/regression/expected/'+fixture+'.stdout.txt');want=expected.read_text(encoding='utf-8-sig')
   folder=o/(name+'-'+fixture);folder.mkdir();exe=folder/'program.exe';row={'id':name+':'+fixture,'status':'running'};d['cases'].append(row)
   a=x.run(['pwsh','-NoProfile','-File',str(builder),'-Compiler',str(compiler),'-Source',str(source),'-Output',str(exe)],folder/'build',timeout=120);row['buildExit']=a.returncode
   assert a.returncode==0 and not a.stderr.strip(),(name,a.stdout,a.stderr)
   a=x.run([str(exe)],folder/'run',timeout=10);row.update(runExit=a.returncode,stdout=a.stdout,stderr=a.stderr)
   assert a.returncode==0 and not a.stderr.strip() and a.stdout==want,(name,a.stdout,want,a.stderr)
   row['status']='passed';d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
