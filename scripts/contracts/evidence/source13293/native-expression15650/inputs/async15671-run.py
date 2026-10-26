from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
names=['encoding4','shared16','unknown13'];contracts=[b/f'async15670-{n}.json' for n in names];proofs=[b/'async15662-semantic/result.json',b/'async15663-stdlib/result.json']
inputs=[Path(__file__),*contracts,*proofs,r/'scripts/verify-c385-preir-call-numeric.py']
for p in proofs:
 j=json.loads(p.read_text(encoding='utf-8-sig'));assert j['status']=='passed' and j['completed']==j['total'] and j['inputsStable'] and j['processesStopped'],p
 for path,h in j['inputHashes'].items():assert sha(path)==h.upper(),path
 inputs.extend(Path(v) for v in j['inputHashes'])
inputs=list(dict.fromkeys(inputs));out=b/'async15671-managed-supervised'
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=len(names),cases=[],claimsGoalComplete=False)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for name,contract in zip(names,contracts):
   output=b/f'async15671-managed-{name}';cmd=[sys.executable,str(r/'scripts/verify-c385-preir-call-numeric.py'),'--mode','managed','--output',str(output),'--contract',str(contract),'--managed-compiler',str(b/'managed15595/compiler/Sollang.Compiler.exe'),'--format-compiler',str(b/'v14775/compiler-build01/compiler.exe')]
   for n in ['v12432','v14775']:cmd+=['--reusable-compiler-directory',str(b/n/'compiler-build01')]
   observed=run.run(cmd,out/name,timeout=1200);row=dict(id=name,exit=observed.returncode);result['cases'].append(row)
   if observed.returncode:raise ValueError('MANAGED_COHORT_FAILED:'+name)
   result['completed']+=1;run.save();print('PASSED '+name,flush=True)
  result['status']='passed'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
