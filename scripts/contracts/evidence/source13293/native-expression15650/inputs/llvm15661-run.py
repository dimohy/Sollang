from pathlib import Path
import json,sys,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
seed=json.loads((b/'llvm15659-observed/result.json').read_text(encoding='utf-8-sig'));assert seed['runExit']==0 and seed['inputsStable'] and seed['processesStopped']
for p,h in seed['inputHashes'].items():assert sha(p)==h
names=['await-non-task','await-outside-async','cancel-non-task'];fixtures=r/'examples/regression/diagnostics';out=b/'llvm15661-diagnostic-controls';emitter=b/'llvm15659-observed/probe.exe';stdlib=sorted(r.glob('stdlib/**/*.slg'));inputs=[*[Path(p) for p in seed['inputHashes']],emitter,Path(__file__),*[fixtures/(n+s) for n in names for s in ['.slg','.stderr.contains.txt']]]
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='Original invalid task-operation diagnostics remain rejected before LLVM',inputHashes=pins,cases=[],completed=0,total=3)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for n in names:
   observed=run.run([str(emitter),*map(str,stdlib),str(fixtures/(n+'.slg'))],out/n,timeout=180);expected=(fixtures/(n+'.stderr.contains.txt')).read_text(encoding='utf-8-sig').strip();passed=observed.returncode==1 and not observed.stderr and expected in observed.stdout and 'target triple =' not in observed.stdout;result['cases'].append(dict(id=n,exit=observed.returncode,passed=passed,expectedDiagnostic=expected))
   if not passed:raise ValueError('ORIGINAL_DIAGNOSTIC_CHANGED:'+n)
   result['completed']+=1;run.save();print('PASSED '+n,flush=True)
  result['status']='passed'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
