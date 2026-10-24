from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
source=r/'scripts/probes/declared-value-layout/bounded-interpolation-call.slg'
program=b/'bounded13582-trace.slg';literal=json.dumps(source.read_bytes().decode('utf-8'))
program.write_text((b/'bounded13582-template.slg').read_text(encoding='utf-8'),encoding='utf-8')
contract=json.loads((b/'bounded13527-contract.json').read_text(encoding='utf-8'));sources=[r/p for p in contract['reusableCheckedProducer']['additionalSources']]
compiler=b/'managed13519/compiler/Sollang.Compiler.exe';formatter=b/'v12432/compiler-build01/compiler.exe'
inputs=[Path(__file__),b/'bounded13582-template.slg',program,source,compiler,compiler.with_suffix('.dll'),compiler.with_suffix('.deps.json'),compiler.with_suffix('.runtimeconfig.json'),formatter,*sources]
pins={str(p):sha(p) for p in inputs};out=b/'bounded13582-trace';out.mkdir(exist_ok=False)
d=dict(schemaVersion=1,status='running',completed=0,total=1,scope='Actual SLG interpolation lowering and arity checker controls4: original zero-argument call accepted, existing three negative arities rejected. Not general compiler/native/runtime acceptance.',sourceSha256=sha(source),producerBuildBudget=1,originalSourceRunsAdded=0,claimsGoalComplete=False,inputHashes=pins)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 p=x.run([str(formatter),'format',str(program)],out/'format',timeout=30);assert p.returncode==0,p.stderr
 # Formatting is an explicit pre-build input mutation, so re-pin the exact
 # canonical bytes before any build or execution; the final record retains it.
 pins[str(program)]=sha(program);d['inputHashes']=dict(pins)
 cmd=[str(compiler),'build',str(program),*[str(p) for p in sources],'-o',str(out/'probe.exe'),'--target','windows-x64','--llvm',str(r/'.tools/llvm-22.1.8'),'-O0','--jobs','4','--keep-temps']
 p=x.run(cmd,out/'build',timeout=180);assert p.returncode==0,p.stderr
 p=x.run([str(out/'probe.exe')],out/'run',timeout=30);assert p.returncode==0 and not p.stderr and 'ARITY_CHECKS_PASSED' in p.stdout,p.stderr
 d.update(status='passed',completed=1)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if d['status']=='passed' else 1)
