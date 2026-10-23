from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'partition12996-managed';o.mkdir(exist_ok=False)
fixtures=['797-partition-first-match-direct-dispatch', '1705-selfhost-control-region-stream', '218-loop-control-and-cleanup', 'range-break-control'];builder=b/'scratch12644-build.ps1'
compilers=[('managed',b/'managed12899/compiler/Sollang.Compiler.exe')]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[builder,Path(__file__),r/'scripts/verification_execution.py',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',r/'.tools/llvm-22.1.8/bin/clang.exe',r/'.tools/llvm-22.1.8/bin/llvm-as.exe',b/'v12974/compiler-build01/result.json']+[p for _,p in compilers]+list(compilers[0][1].parent.glob('Sollang.Compiler.*'))+list((r/'stdlib').rglob('*.slg'))
for f in fixtures:inputs += [(b/'partition12996-inputs'/ (f+'.slg') if f=='range-break-control' else r/('examples/regression/'+f+'.slg')),(b/'partition12996-inputs'/ (f+'.stdout.txt') if f=='range-break-control' else r/('examples/regression/expected/'+f+'.stdout.txt'))]
pins={str(p):sha(p) for p in inputs if p.is_file()};d=dict(schemaVersion=1,status='running',completed=0,total=4,inputHashes=pins,cases=[],scope='Original partition, nested stream, while transfer, and direct-iteration transfer CSharp controls before source fix qualification.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 for name,compiler in compilers:
  for fixture in fixtures:
   source=(b/'partition12996-inputs'/(fixture+'.slg') if fixture=='range-break-control' else r/('examples/regression/'+fixture+'.slg'));expected=(b/'partition12996-inputs'/(fixture+'.stdout.txt') if fixture=='range-break-control' else r/('examples/regression/expected/'+fixture+'.stdout.txt'));want=expected.read_text(encoding='utf-8-sig')
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
