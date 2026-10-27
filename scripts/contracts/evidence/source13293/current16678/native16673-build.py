from pathlib import Path
import sys,json,hashlib,subprocess
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
from verification_source_proof import current_build_inputs
from verification_fingerprints import managed_runtime_inputs
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';planpath=b/'native16673-plan.json';plan=json.loads(planpath.read_text(encoding='utf-8-sig'));out=Path(plan['supervisor']);product=Path(plan['product']);managed=Path(plan['managedCompiler'])
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def quote(s):return "'"+str(s).replace("'","''")+"'"
assert product.resolve().is_relative_to(b.resolve()) and out.resolve().is_relative_to(b.resolve());assert not product.exists() and not out.exists();assert sha(managed.with_suffix('.dll'))==plan['expectedManagedDllSha256']
proofs=[Path(x) for x in plan['prerequisites']];inputs=[planpath,Path(__file__),root/'scripts/build-focused-selfhost-compiler.ps1',root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py',*managed_runtime_inputs(managed),Path(plan['formatter']),*proofs]
for p in proofs:
 d=json.loads(p.read_text(encoding='utf-8-sig'));assert d['status']=='passed' and d['completed']==d['total'] and d['inputsStable'] and d['processesStopped'],str(p)
 for name,h in d['inputHashes'].items():
  source=Path(name);assert source.is_file() and sha(source)==h.upper(),name;inputs.append(source)
inputs=list(dict.fromkeys(inputs));reusable=[Path(x) for x in plan['reusableCompilerDirectories']]
command="& './scripts/build-focused-selfhost-compiler.ps1' -SeedCompiler "+quote(managed)+" -OutputDirectory "+quote(product)+" -Optimization O1 -Jobs 1 -FormatCompiler "+quote(plan['formatter'])+" -ReusableCompilerDirectories @("+','.join(quote(x) for x in reusable)+") -ManagedProofRecord "+quote(plan['canonicalSemanticProof'])+" -SlgEmissionProofRecord "+quote(plan['slgEmissionProof'])+" -StdlibSourceProofRecord "+quote(plan['stdlibProof'])
initialize_output(root,out,reusable_directories=reusable);out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r={'schemaVersion':1,'status':'running','completed':0,'total':1,'inputHashes':pins,'timeoutSeconds':180,'product':str(product),'scope':'New third general Native product after canonical six-source integration. Current semantic driver4, fixed checked-source8, direct CSharp8 and full stdlib144 required. O1/jobs1/180-second budget unchanged. Old16219 product retired through authenticated consumer closure; failed outputs preserved.','reusableCompilerDirectories':[str(x) for x in reusable],'claimsGoalComplete':False};x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  result=x.run(['pwsh','-NoProfile','-Command',command],out/'build',timeout=180)
  if result.returncode:raise ValueError('CURRENT_NATIVE16673_BUILD_FAILED')
  record=json.loads((product/'result.json').read_text(encoding='utf-8-sig'));assert record['status']=='passed' and record['inputsStable'];current_build_inputs(root,record);r.update(status='passed',completed=1,compilerSha256=sha(product/'compiler.exe'))
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure','compilerSha256']}))
 if error:raise error
