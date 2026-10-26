from pathlib import Path
import sys,json,hashlib,shutil
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proofs=[b/name/'result.json' for name in ['epoch16093-semantic','epoch16098-managed66','epoch16094-stdlib','lifecycle16095']];inputs=[Path(__file__),b/'epoch16101-build.ps1',r/'scripts/build-focused-selfhost-compiler.ps1',r/'scripts/verification_execution.py',b/'v12432/compiler-build01/compiler.exe',*proofs]
for p in proofs:
 j=json.loads(p.read_text(encoding='utf-8-sig'));assert j['status']=='passed' and j['completed']==j['total'] and j['inputsStable'] and j['processesStopped'],p
 for path,h in j['inputHashes'].items():assert sha(path)==h.upper(),path
 inputs.extend(Path(v) for v in j['inputHashes'])
inputs=list(dict.fromkeys(inputs));out=b/'epoch16101-build-supervised'
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=1,claimsGoalComplete=False,scope='One current-source Native build after32 indentation-only SHA256 table lines and artifact lifecycle observation handling. Compiler semantic/codegen implementation unchanged. Current CSharp66, semantic4, full stdlib144 and lifecycle158 qualified; prior Native15778 retired after17 authenticated terminal consumers with0 diagnostic-observation test credit. No repeat ASAN/full runtime claim. Ordinary180 and preparation1200 retained; maximum one build.',aggregatePreparationBudgetSeconds=1200,programCaseBudgetSeconds=180)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  observed=run.run([shutil.which('pwsh'),'-NoProfile','-File',str(b/'epoch16101-build.ps1')],out/'build',timeout=1200)
  if observed.returncode:raise ValueError('NATIVE_PRODUCT_BUILD_FAILED')
  record=b/'v16101/compiler-build01/result.json';j=json.loads(record.read_text(encoding='utf-8-sig'));assert j['status']=='passed' and sha(record.parent/'compiler.exe')==j['compilerSha256'].upper()
  result.update(status='passed',completed=1,compilerResult=str(record),compilerSha256=j['compilerSha256'])
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','compilerSha256','failure','processesStopped']}))
