from pathlib import Path
import hashlib,json,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';parent=b/'native18276-direct18/result.json';d=json.loads(parent.read_text());assert d['status']=='passed' and d['completed']==d['total']==18 and d['inputsStable'] and d['processesStopped']
out=b/'native18281-consumers';review=b/'oracle18085-review';checker=review/'bin/Release/net11.0/OracleReview.dll';common=root/'tests/Sollang.ExampleTests/bin/Release/net11.0/Sollang.ExampleTests.dll'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert sha(checker)=='63D4651FA7888C60550BD0D873F3BD6E70BA97EA1938EF1AEA3EED65F0C5197C'
assert sha(common)=='C8E1097366DA97E2509B1C6EC00C5392B5305A0386042393D5E6938584BA34E0'
for name in ['LlvmAssertionTests.cs','LlvmAssertions.cs','AtomicResultFile.cs']:assert sha(review/name)==sha(root/'tests/Sollang.ExampleTests'/name)
mapping={'38-stack-promoted-dynamic-array':'38-stack-promoted-dynamic-array','39-stack-promoted-int-dictionary':'39-stack-promoted-int-dictionary','40-nested-stack-slot-reuse':'40-nested-stack-slot-reuse','41-inline-function-stack-frame':'41-inline-function-stack-frame','original42':'42-fixed-array-placement','original51':'51-fixed-array-value-generics'}
inputs=[parent,common,checker,Path(__file__).resolve(),*[review/name for name in ['LlvmAssertionTests.cs','LlvmAssertions.cs','AtomicResultFile.cs']],*[p for p in checker.parent.iterdir() if p.suffix=='.json']]
for role in ['native18274-managed18','native18276-direct18']:
    for case,fixture in mapping.items():
        inputs.append(b/role/case/'probe.exe.ll')
        inputs.extend((root/'examples/regression/expected').glob(fixture+'.*llvm*.txt'))
pins={str(p):sha(p) for p in set(inputs)};stable=lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
initialize_output(root,out,reusable_directories=[b/'v12432/compiler-build01',b/'v18092/compiler-build01',b/'v18270/compiler-build01']);out.mkdir(exist_ok=False)
r={'schemaVersion':1,'status':'running','completed':0,'total':8,'inputHashes':pins,'cases':[],'scope':'Current direct18 remaining consumers: Native original42 common LLVM, CSharp original38-42 and51 common LLVM, Native original51 twelve selector/value/mutation controls. Prior Native38-41 common checks are reused.','claimsGoalComplete':False}
with VerificationContractLease([Path(p) for p in pins]):
    x=VerificationExecution(root,out,r,stable,sha);error=None
    try:
        work=[('native42-common',b/'native18276-direct18/original42/probe.exe.ll','42-fixed-array-placement')]+[('csharp-'+case,b/'native18274-managed18'/case/'probe.exe.ll',fixture) for case,fixture in mapping.items()]
        for name,llvm,fixture in work:
            result=out/(name+'.json');run=x.run(['dotnet',str(common),'--verify-common-llvm',str(llvm),fixture,'windows-x64',str(result)],out/name,timeout=180)
            item=json.loads(result.read_text());assert run.returncode==0 and item['status']=='passed' and item['inputsStable'],item
            r['cases'].append({'id':name,'status':'passed','passed':True});r['completed']+=1;x.save()
        run=x.run(['dotnet',str(checker),str(b/'native18276-direct18/original51/probe.exe.ll'),str(out/'native51-controls.json')],out/'native51-controls',timeout=180)
        controls=json.loads((out/'native51-controls.json').read_text());assert run.returncode==0 and controls['status']=='passed' and controls['completed']==controls['total']==12,controls
        r['cases'].append({'id':'native51-controls12','status':'passed','passed':True});r['completed']+=1;r.update(status='passed',original51ControlsCompleted=12,original51ControlsTotal=12)
    except BaseException as exc:error=exc
    finally:x.finalize(error,cleanup=False)
    print({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']})
    if error:raise error
