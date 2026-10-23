from pathlib import Path
import hashlib,json,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler=b/'managed13239/compiler/Sollang.Compiler.exe';source=r/'examples/regression/diagnostics/1857-interpolation-float32-parser-boundary.slg';oracle=source.with_suffix('.stderr.contains.txt');out=b/'numeric13366-float32-managed-observation';out.mkdir(exist_ok=False)
paths=[*managed_runtime_inputs(compiler),source,oracle,r/'src/Sollang.Compiler/Semantics/SemanticCompiler.cs',*sorted((r/'stdlib').rglob('*.slg'))];pins={str(p):sha(p) for p in paths}
d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='Unchanged original1857 CSharp diagnostic oracle observation only; exact old required fragment retained.',claimsGoalComplete=False)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);err=None
try:
 y=x.run([str(compiler),'build',str(source),'-o',str(out/'probe.exe'),'--target','windows-x64','--llvm',str(r/'.tools/llvm-22.1.8'),'--jobs','1','-O1'],out/'build',timeout=180)
 d.update(actualBuildExit=y.returncode,actualStderr=y.stderr,requiredOriginalDiagnostic=oracle.read_text(encoding='utf-8-sig').strip());assert y.returncode==1 and d['requiredOriginalDiagnostic'] in y.stderr,'Original1857 diagnostic contract not satisfied'
 d.update(status='passed',completed=1)
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','actualBuildExit','actualStderr','failure','inputsStable','processesStopped']},ensure_ascii=False));sys.exit(0 if d['status']=='passed' else 1)
