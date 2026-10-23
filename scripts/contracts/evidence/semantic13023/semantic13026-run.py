from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'semantic13026-roots-negative';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
script=r/'scripts/verify-c385-preir-call-numeric.py';contract=b/'semantic13023-mutable-contract.json'
inputs=[Path(__file__),script,contract,r/'scripts/completed_artifact_plan.py',r/'scripts/contracts/artifact-lifecycle.json',r/'scripts/verification_execution.py'];pins={str(p):sha(p) for p in inputs}
d=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='Actual focused CLI boundaries: default stale reparse roots still rejected; explicit four roots still exceed unchanged maximum3. Both before output/codegen.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 base=['python','-X','utf8',str(script),'--mode','managed','--managed-compiler',str(b/'managed12899/compiler/Sollang.Compiler.exe'),'--contract',str(contract),'--artifact-cleanup','plan-only']
 for case,roots,errorId in [('default-reparse',[],'ARTIFACT_REPARSE_POINT'),('four-roots',['v12432','v12974','v13003','v12939'],'ARTIFACT_REUSABLE_COMPILER_LIMIT_EXCEEDED')]:
  output=o/(case+'-output');cmd=base+['--output',str(output)]
  for name in roots:cmd+=['--reusable-compiler-directory',str(b/name/'compiler-build01')]
  a=x.run(cmd,o/case,timeout=30);assert a.returncode==1 and errorId in a.stderr and not output.exists(),(case,a.stdout,a.stderr)
  d['cases'].append({'id':case,'actualExit':a.returncode,'failureId':errorId,'outputCreated':False,'status':'passed'});d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
