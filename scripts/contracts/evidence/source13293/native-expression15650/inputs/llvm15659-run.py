from pathlib import Path
import json,sys,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'llvm15659-observed';compiler=b/'managed15595/compiler/Sollang.Compiler.exe';source=b/'llvm15476-emitter.slg'
contract=json.loads((b/'async15309-concrete-ir-contract.json').read_text(encoding='utf-8-sig'))
sources=[source,*[root/p for p in contract['cases'][0]['additionalSources']]]
inputs=[*sorted((root/'stdlib').rglob('*.slg')),b/'async15589-right-binary.slg',*managed_runtime_inputs(compiler),*sources,Path(__file__),root/'scripts/verification_execution.py']
with VerificationContractLease(inputs):
    out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,claimsTestPassed=False,claimsGoalComplete=False)
    run=VerificationExecution(root,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
    try:
        exe=out/'probe.exe';command=[str(compiler),'build',*map(str,sources),'-o',str(exe),'--llvm',str(root/'.tools/llvm-22.1.8'),'--target','windows-x64','-O0','--jobs','1']
        built=run.run(command,out/'build',timeout=180);result['buildExit']=built.returncode
        if built.returncode==0:
            observed=run.run([str(exe),*[str(p) for p in sorted((root/'stdlib').rglob('*.slg'))],str(b/'async15589-right-binary.slg')],out/'run',timeout=180);result['runExit']=observed.returncode
        result['status']='observed-not-qualified'
    except BaseException as failure:error=failure
    finally:run.finalize(error,cleanup=False)
    assert error is None,error
print(json.dumps({k:result.get(k) for k in ['status','buildExit','runExit','processesStopped']}))
