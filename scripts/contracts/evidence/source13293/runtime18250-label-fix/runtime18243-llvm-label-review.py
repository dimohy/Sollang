from pathlib import Path
import json,hashlib,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';parent=b/'runtime18238-source18/result.json';contract=b/'runtime18237-source18.json';source=b/'runtime18238-source18/859-collection-reserve/emitted.ll';out=b/'runtime18243-llvm-label-review';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest().upper()
text=source.read_text();fixed=text.replace('_dict_allocated:', '_dict_grow_complete:').replace('_dict_allocated\n','_dict_grow_complete\n').replace('_dict_allocated ]','_dict_grow_complete ]')
assert fixed!=text
llvm=out/'review.ll';llvm.write_text(fixed,encoding='utf-8')
pins={str(p):sha(p) for p in [parent,contract,source,llvm,Path(__file__).resolve()]}
stable=lambda:all(Path(p).is_file() and sha(Path(p))==h for p,h in pins.items())
r={'schemaVersion':1,'status':'running','scope':'Diagnostic review of retained failing LLVM only; rename dictionary grow basic-block labels to separate them from the existing allocation-result value. Not source compiler qualification.','completed':0,'total':1,'inputHashes':pins,'claimsGoalComplete':False}
with VerificationContractLease([Path(p) for p in pins]):
    x=VerificationExecution(root,out,r,stable,sha);error=None
    try:
        run=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(out/'review.bc')],out/'assemble',timeout=180);assert run.returncode==0 and not run.stderr.strip(),run.stderr
        run=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O1','-o',str(out/'review.exe'),'-lws2_32','-lbcrypt','-luser32','-lole32','-loleaut32','-luuid'],out/'link',timeout=180);assert run.returncode==0 and not run.stderr.strip(),run.stderr
        run=x.run([str(out/'review.exe')],out/'run',timeout=180);expected=next(c['stdout'] for c in json.loads(contract.read_text())['cases'] if c['id']=='859-collection-reserve');assert run.returncode==0 and not run.stderr.strip() and run.stdout.strip()==expected,(run.returncode,run.stdout,run.stderr)
        r.update(status='passed',completed=1,actualStdout=run.stdout.strip())
    except BaseException as exc:error=exc
    finally:x.finalize(error,cleanup=False)
    print({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']})
    if error:raise error
