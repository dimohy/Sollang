import sys,json,hashlib,importlib.util
from pathlib import Path
ROOT=Path.cwd();B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
spec=importlib.util.spec_from_file_location('existing_numeric_audit',ROOT/'scripts/verify-c385-preir-call-numeric.py');numeric=importlib.util.module_from_spec(spec);spec.loader.exec_module(numeric)
base=B/'async17469-managed2';proof=json.loads((base/'result.json').read_text(encoding='utf-8'));assert proof['status']=='passed' and proof['completed']==2 and proof['inputsStable'] and proof['processesStopped']
out=B/'async17470-managed-audit2';reusable=[B/f'{n}/compiler-build01' for n in ['v12432','v16382','v16808']];initialize_output(ROOT,out,reusable_directories=reusable);out.mkdir(exist_ok=True)
data=[('fixed-after-await',6,'4'),('fixed-cancel-after-yield',8,'parent-start\ncancelled:1,1')]
inputs=[base/'result.json',*[base/n/'probe.exe.ll' for n,_,_ in data],ROOT/'tests/native-interop/owned_array_audit.c',ROOT/'scripts/verify-c385-preir-call-numeric.py',*[ROOT/'.tools/llvm-22.1.8/bin'/n for n in ['clang.exe','llvm-as.exe']]]
pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,scope='C749 C# backing cleanup completion/cancellation audit2; exact6/8 allocations derived from emitted Task context+control pairs(2/3 Tasks), one fixed8-byte backing, one16-byte spill frame. Same expected release counts and invalid/double release rejection from unchanged owned_array_audit.c.',status='running',completed=0,total=2,inputHashes=pins,cases=[])
execution=VerificationExecution(ROOT,out,result,lambda:all(Path(p).is_file() and sha(p)==v for p,v in pins.items()),sha)
error=None
try:
    for name,count,stdout in data:
        folder=out/name;folder.mkdir();row=dict(id=name,status='running',passed=False,expectedAllocations=count);result['cases'].append(row);execution.save()
        observation,passed=numeric.audit_llvm_program(base/name/'probe.exe.ll',folder,count,stdout,lambda cmd,prefix:execution.run(cmd,prefix,timeout=180).returncode)
        row.update(observation,passed=passed,status='passed' if passed else 'failed');result['completed']+=int(passed);execution.save()
        if not passed:raise ValueError('CSHARP_BACKING_AUDIT_FAILED: '+name)
    result['status']='passed'
except BaseException as failure:error=failure
finally:execution.finalize(error,cleanup=False)
if error:raise error
assert result['inputsStable'] and result['processesStopped'];cleanup_output(ROOT,out,execute=True,reusable_directories=reusable)
cleanup_output(ROOT,base,execute=True,reusable_directories=reusable)
print(json.dumps({k:result[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
