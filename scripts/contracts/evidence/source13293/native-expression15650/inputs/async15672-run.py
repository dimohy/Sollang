from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cases=[('locator','base5','generic-interpolation-suspension-locator'),('product','base5','labelled-product-cache'),('legacy','legacy6',None)]
out=b/'async15672-managed-warm-supervised';out.mkdir(exist_ok=False);inputs=[Path(__file__),r/'scripts/verify-zero-input-generic-async.py',*[b/f'async15665-managed-{c[1]}/result.json' for c in cases]];pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=3,cases=[])
run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for name,cohort,warm in cases:
  cmd=[sys.executable,str(r/'scripts/verify-zero-input-generic-async.py'),'--compiler',str(b/'managed15595/compiler/Sollang.Compiler.exe'),'--compiler-kind','managed','--cold-proof',str(b/f'async15665-managed-{cohort}/result.json'),'--contract',str(b/f'async15664-{cohort}.json'),'--output',str(b/f'async15672-managed-{name}')]
  if warm:cmd+=['--warm-case',warm]
  x=run.run(cmd,out/name,timeout=1200);result['cases'].append(dict(id=name,exit=x.returncode))
  if x.returncode:raise ValueError('MANAGED_WARM_FAILED:'+name)
  result['completed']+=1;run.save();print('PASSED '+name,flush=True)
 result['status']='passed'
except BaseException as failure:error=failure
finally:run.finalize(error,cleanup=False)
