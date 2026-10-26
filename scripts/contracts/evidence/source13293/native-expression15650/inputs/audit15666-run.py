from pathlib import Path
import sys,json,hashlib,importlib.util
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
spec=importlib.util.spec_from_file_location('audit_harness',root/'scripts/verify-c385-preir-call-numeric.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cases=[c for c in json.loads((b/'llvm15644-cases.json').read_text(encoding='utf-8-sig'))['cases'] if c['id'].startswith('expression-result-')]
out=b/'audit15666-compound';inputs=[Path(__file__),root/'scripts/verify-c385-preir-call-numeric.py',root/'tests/native-interop/owned_array_audit.c',b/'llvm15644-cases.json',root/'.tools/llvm-22.1.8/bin/clang.exe',*[b/'llvm15660-candidates'/c['id']/'program.ll' for c in cases]]
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='actual-SLG-LLVM-allocation-audit-after-fix',inputHashes=pins,cases=[],completed=0,total=len(cases))
 run=VerificationExecution(root,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for c in cases:
   folder=out/c['id'];folder.mkdir();expected=((11 if c['id'].endswith('cancel') else 9) if c['id'].startswith('expression-result-') else (8 if c['id'].endswith('cancel') else 6))
   row,passed=module.audit_llvm_program(b/'llvm15660-candidates'/c['id']/'program.ll',folder,expected,c['stdout'].strip(),lambda cmd,p:run.run(cmd,p,timeout=180).returncode)
   row.update(id=c['id'],passed=passed);result['cases'].append(row)
   if passed:result['completed']+=1
   run.save();print(json.dumps(row),flush=True)
  result['status']='passed' if result['completed']==result['total'] else 'failed'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
