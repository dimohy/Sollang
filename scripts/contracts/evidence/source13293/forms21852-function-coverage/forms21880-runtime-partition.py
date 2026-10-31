from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'forms21880-runtime-partition';failedPath=B/'forms21868-slg-live-declarations/result.json';failed=json.loads(failedPath.read_text(encoding='utf-8-sig'));EXE=failedPath.parent/'program.exe';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert failed['status']=='failed' and failed['inputsStable'] and failed['processesStopped'];fixtures=[ROOT/'scripts/probes/codegen-interface-fields/before.slg',*[ROOT/'scripts/probes/codegen-live-declarations'/name for name in ['traits.slg','functions.slg','remaining-functions.slg','impl-context-controls.slg']]];paths=[Path(__file__),failedPath,EXE,*fixtures];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(paths):
 result=dict(schemaVersion=1,status='running',completed=0,total=6,cases=[],inputHashes=inputs,scope='Diagnostic only: reuse the failed current Native binary without recompiling, partition runtime data to distinguish package loading, ordinary declarations, constraints/native and impl owners. Six executions, aggregate60s. No original goal qualification.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,60-(time.monotonic()-start))
 try:
  for name,args in [('empty',[]),*[(p.stem,[str(p)]) for p in fixtures]]:
   done=ex.run([str(EXE),*args],OUT/name,timeout=budget());case=dict(id=name,exit=done.returncode,stdout=done.stdout,stderr=done.stderr,passed=done.returncode==0);result['cases'].append(case);result['completed']+=1;print(json.dumps(dict(id=name,exit=done.returncode,stdoutLines=len(done.stdout.splitlines()))))
  result['status']='passed' if all(case['passed'] for case in result['cases']) else 'failed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
