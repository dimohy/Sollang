from pathlib import Path
import sys,json,hashlib,importlib.util
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
spec=importlib.util.spec_from_file_location('audit_harness',root/'scripts/verify-c385-preir-call-numeric.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cases=[c for c in json.loads((b/'contextual15944-positive6.json').read_text(encoding='utf-8-sig'))['cases'] if '-owned-' in c['id'] or '-projected-' in c['id']]
expected_counts={'contextual-owned-normal':10,'contextual-owned-cancel':11,'contextual-projected-normal':8,'contextual-projected-cancel':9}
# Each started task allocates context+control; owning arrays allocate once; each reached suspension creates one spill frame. Normal: owned 6+2+2; projected 4+3+1. Cancel: owned 8+1+2; projected 6+2+1. Child not completed at cancellation does not allocate its result array.
out=b/'contextual15955-allocation4';inputs=[Path(__file__),root/'scripts/verify-c385-preir-call-numeric.py',root/'tests/native-interop/owned_array_audit.c',b/'contextual15944-positive6.json',root/'.tools/llvm-22.1.8/bin/clang.exe',*[b/'contextual15950-slg6'/c['id']/'program.ll' for c in cases]]
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='actual-SLG-LLVM-allocation-audit-after-fix',inputHashes=pins,cases=[],completed=0,total=len(cases))
 run=VerificationExecution(root,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for c in cases:
   folder=out/c['id'];folder.mkdir();expected=expected_counts[c['id']]
   row,passed=module.audit_llvm_program(b/'contextual15950-slg6'/c['id']/'program.ll',folder,expected,c['stdout'].strip(),lambda cmd,p:run.run(cmd,p,timeout=180).returncode)
   row.update(id=c['id'],passed=passed);result['cases'].append(row)
   if passed:result['completed']+=1
   run.save();print(json.dumps(row),flush=True)
  result['status']='passed' if result['completed']==result['total'] else 'failed'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
