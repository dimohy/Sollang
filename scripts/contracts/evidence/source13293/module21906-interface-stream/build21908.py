import json,hashlib,sys
from pathlib import Path
from datetime import datetime,timezone
sys.path.insert(0,'scripts')
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
r=Path.cwd(); b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def write(p,v): p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
baseline=json.loads((b/'module21910-csharp-baseline/result.json').read_text());assert baseline['status']=='passed' and baseline['completed']==3 and baseline['inputsStable'] and baseline['processesStopped']
out=b/'managed21908';initialize_output(r,out,reusable_directories=[b/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);out.mkdir()
sources=[p for p in (r/'src').rglob('*') if p.is_file() and p.suffix in {'.cs','.csproj','.props','.targets'} and not {'bin','obj'}.intersection(p.relative_to(r/'src').parts)]
sources += [r/'syntax/sollang.grammar',r/'syntax/sollang.lexer']
sources += [p for p in r.iterdir() if p.is_file() and (p.name.startswith('Directory.') or p.name in {'global.json','NuGet.Config'})]
inputs={str(p.resolve()):sha(p) for p in [*sources,Path(__file__).resolve()]}
result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=inputs,scope='CSharp first: generated declaration-category plan consumed by actual PublicInterfaceFields; preserve all existing interface field strings and module hashes.',claimsGoalComplete=False)
ex=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha)
err=None
try:
 c=ex.run(['dotnet','build','src/Sollang.Compiler/Sollang.Compiler.csproj','-c','Release','--no-restore','--nologo','-v','minimal','-o',str(out/'compiler'),'/nodeReuse:false','/p:UseSharedCompilation=false','/warnaserror'],str(out/'build'),timeout=180)
 if c.returncode: raise RuntimeError('build failed')
 result['completed']=1
 result['status']='passed'
except BaseException as x: err=x
finally: ex.finalize(err,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','failure','inputsStable','processesStopped']}))

if err: raise err
