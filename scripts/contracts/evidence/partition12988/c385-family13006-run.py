from pathlib import Path
import sys,json,hashlib,shutil
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'c385-family13006';o.mkdir(exist_ok=False)
managed=b/'managed12899/compiler/Sollang.Compiler.dll';native=b/'v13003/compiler-build01/compiler.exe';script=r/'scripts/verify-c385-expression-family-batch.ps1';contract=r/'scripts/contracts/c385-expression-family-batch.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
c=json.loads(contract.read_text());inputs=[Path(__file__),script,contract,native,native.parent/'result.json',r/'scripts/contracts/c385-expression-family-batch.schema.json',r/'scripts/contracts/c385-expression-family-batch-result.schema.json',r/'scripts/contracts/expression-lowering-parity.json',r/'scripts/verification-process.ps1',r/'scripts/verification-compiler-product.ps1',r/'scripts/verify-llvm-direct-call-closure.ps1',r/'scripts/verification_execution.py',r/'.tools/llvm-22.1.8/bin/clang.exe',r/'.tools/llvm-22.1.8/bin/llvm-as.exe',Path(shutil.which('dotnet')),Path(shutil.which('pwsh'))]+list(managed.parent.glob('Sollang.Compiler.*'))+list((r/'stdlib').rglob('*.slg'))
for f in c['fixtures']:inputs += [r/f['source'],r/f['expected']]
pins={str(p):sha(p) for p in inputs if p.is_file()}
d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='One original C385 seven-fixture/28-family batch: AST/IR source identity + sequential/parallel equality +14 exact runtime compiler executions. This is not all42 families or frozen whole/source/Stage completion.',budget={'batchRuns':1,'snapshotCommands':21,'applicationBuilds':14,'buildJobs':4,'outerTimeoutSeconds':1200,'individualCommandTimeoutUnchanged':120},claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 a=x.run([shutil.which('pwsh'),'-NoProfile','-File',str(script),'-ManagedCompilerPath',str(managed),'-ExpectedManagedCompilerSha256',sha(managed),'-SelfhostCompilerPath',str(native),'-ExpectedSelfhostCompilerSha256',sha(native),'-OutputDirectory',str(o/'batch'),'-BuildJobs','4'],o/'batch-execution',timeout=1200)
 d.update(exitCode=a.returncode)
 inner=json.loads((o/'batch/result.json').read_text(encoding='utf-8-sig'));d.update(authority=inner['authority'],typedIr=inner['typedIr'],fixtureCount=len(inner['fixtures']),batchStatus=inner['status'],batchFailure=inner['failure'])
 assert a.returncode==0 and inner['status']=='passed' and inner['inputStable'] and not inner['inputDrift'],(a.stdout,a.stderr,inner['failure'])
 d.update(status='passed',completed=1)
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','fixtureCount','typedIr','inputsStable','processesStopped','failure','batchFailure']}))
if d['status']!='passed':raise SystemExit(1)
