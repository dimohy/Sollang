from pathlib import Path
import sys,json,hashlib
r=Path.cwd();sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'slice13036-native-baseline';o.mkdir(exist_ok=False);contract=b/'slice13035/managed-contract.json';c=json.loads(contract.read_text(encoding='utf-8'));compiler=b/'v13003/compiler-build01/compiler.exe';builder=b/'scratch12644-build.ps1'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[Path(__file__),contract,compiler,builder,r/'scripts/verification_execution.py',r/'scripts/verification-compiler-build.ps1',r/'scripts/verification-process.ps1',r/'scripts/contracts/verification-compiler-build.json']+[r/x['source'] for x in c['cases']]+list((r/'stdlib').rglob('*.slg'))+list((r/'selfhost').rglob('*.slg'));pins={str(p):sha(p) for p in inputs};d={'schemaVersion':1,'status':'running','scope':'Observed current native baseline on5 exact original focused inputs; not candidate approval. Original487 LLVM failure is separately retained.','inputHashes':pins,'completed':0,'total':5,'cases':[]};x=VerificationExecution(r,o,d,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  folder=o/case['id'];folder.mkdir();exe=folder/'program.exe';a=x.run(['pwsh','-NoProfile','-File',str(builder),'-Compiler',str(compiler),'-Source',str(r/case['source']),'-Output',str(exe)],folder/'build',timeout=180);row={'id':case['id'],'buildExit':a.returncode,'status':'observed','source':case['source'],'stdout':a.stdout,'stderr':a.stderr}
  if a.returncode:
   assert 'undefined value' in a.stderr,case['id']+a.stderr;row['classification']='undefined-llvm-value'
  else:
   a=x.run([str(exe)],folder/'run',timeout=30);assert a.returncode==0 and a.stdout.strip()==case['stdout'] and not a.stderr;row['classification']='passing-control'
  d['cases'].append(row);d['completed']+=1;x.save()
 d['status']='passed';d['baselineReproducedCount']=sum(z['classification']=='undefined-llvm-value' for z in d['cases']);assert d['baselineReproducedCount']>0
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','baselineReproducedCount','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
