from pathlib import Path
import sys,json,hashlib
r=Path.cwd();sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_source_proof import current_build_inputs
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'slice13083-native';o.mkdir(exist_ok=False);cp=b/'slice13057-managed-contract.json';c=json.loads(cp.read_text());build=b/'v13072/compiler-build01';product=json.loads((build/'result.json').read_text(encoding='utf-8-sig'));compiler=build/'compiler.exe';builder=b/'scratch12644-build.ps1'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert product['status']=='passed' and product['inputsStable'] and sha(compiler)==product['compilerSha256'];inputs=current_build_inputs(r,product)+[cp,compiler,build/'result.json',Path(__file__),builder,r/'scripts/verification_execution.py',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',r/'.tools/llvm-22.1.8/bin/llvm-as.exe']+[r/x['source'] for x in c['cases']];pins={str(p):sha(p) for p in inputs};d={'schemaVersion':1,'status':'running','scope':'Fresh native current complete-input product on17 focused slice projections; original487 and original full gates remain separate.','inputHashes':pins,'completed':0,'total':17,'cases':[]};x=VerificationExecution(r,o,d,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  folder=o/case['id'];folder.mkdir();exe=folder/'program.exe';row={'id':case['id'],'status':'running'};d['cases'].append(row);x.save();a=x.run(['pwsh','-NoProfile','-File',str(builder),'-Compiler',str(compiler),'-Source',str(r/case['source']),'-Output',str(exe)],folder/'build',timeout=180);row['buildExit']=a.returncode;assert a.returncode==0 and not a.stderr,(case['id'],a.stderr)
  a=x.run([str(r/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(exe)+'.ll','-o',str(folder/'program.bc')],folder/'assemble',timeout=30);row['assemblyExit']=a.returncode;assert a.returncode==0 and not a.stderr
  a=x.run([str(exe)],folder/'run',timeout=30);row.update(runExit=a.returncode,stdout=a.stdout,stderr=a.stderr);assert a.returncode==0 and a.stdout.replace('\r\n','\n')==case['stdout']+'\n' and not a.stderr,(case['id'],a.stdout,a.stderr);row['status']='passed';d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
