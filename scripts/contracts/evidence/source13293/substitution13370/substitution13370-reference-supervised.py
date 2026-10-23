from pathlib import Path
import hashlib,json,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler=b/'managed13239/compiler/Sollang.Compiler.dll';out=b/'substitution13370-reference-supervised';out.mkdir(exist_ok=False)
paths=[*managed_runtime_inputs(compiler),*sorted((r/'src/Sollang.Compiler/Semantics').rglob('*.cs')),*sorted((r/'src/Sollang.Compiler/CodeGen').rglob('*.cs')),r/'scripts/verify-generic-type-contexts.ps1',r/'scripts/contracts/fixtures/generic-type-context-harness.cs',r/'scripts/contracts/fixtures/1719-generic-readonly-slice-context.slg',r/'scripts/verification_execution.py',Path(__file__)];pins={str(p):sha(p) for p in paths}
d=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='Existing CSharp production method extraction and current DLL generic type/parser/place validator21; no Native qualification or phase closure.',claimsGoalComplete=False)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);err=None
try:
 y=x.run(['pwsh','-NoProfile','-File',str(r/'scripts/verify-generic-type-contexts.ps1'),'-ManagedCompiler',str(compiler),'-ManagedCompilerSha256',sha(compiler)],out/'reference',timeout=180)
 assert y.returncode==0,y.stderr
 records=[Path(z.strip()) for z in y.stdout.splitlines() if z.strip().endswith('result.json')];assert len(records)==1
 proof=json.loads(records[0].read_text(encoding='utf-8-sig'));assert proof['status']=='passed' and proof['completed']==proof['total']==21
 d.update(status='passed',completed=1,referenceConditions=21,referenceResult=str(records[0]))
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','failure','inputsStable','processesStopped','referenceConditions','referenceResult']}));sys.exit(0 if d['status']=='passed' else 1)
