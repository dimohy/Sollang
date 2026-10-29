from pathlib import Path
import json,hashlib,importlib.util,sys,time
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';contractPath=b/'c74218121-contract11.json';managedPath=b/'c74218122-managed11/result.json';build=b/'v18270/compiler-build01';out=b/'c74218289-native7'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
c=json.loads(contractPath.read_text());m=json.loads(managedPath.read_text());product=json.loads((build/'result.json').read_text())
assert m['status']=='passed' and m['completed']==m['total']==11 and m['inputsStable'] and m['processesStopped']
assert m['inputHashes'][str(contractPath.resolve())]==sha(contractPath)
assert product['status']=='passed' and product['inputsStable'] and sha(build/'compiler.exe')==product['compilerSha256']
assert not c.get('harnessBuildOptimization') and not c.get('harnessBuildJobs') and not c.get('reusableCheckedProducer')
cases=[case for case in c['cases'] if case['id'].startswith(('fixed-int-repeat-','c749-'))]
assert len(cases)==7 and all(case['exit']==0 and not case['stderr'] and not case.get('additionalSources') and 'expectedAllocations' in case for case in cases)
assert all(any(row['id']==case['id'] and row['passed'] for row in m['cases']) for case in cases)
spec=importlib.util.spec_from_file_location('existing_numeric',root/'scripts/verify-c385-preir-call-numeric.py');numeric=importlib.util.module_from_spec(spec);spec.loader.exec_module(numeric)
pins=dict(m['inputHashes'])
for path in [contractPath,managedPath,Path(__file__).resolve(),build/'compiler.exe',build/'result.json',*current_build_inputs(root,product),root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py',root/'tests/native-interop/owned_array_audit.c',root/'.tools/llvm-22.1.8/bin/llvm-as.exe',root/'.tools/llvm-22.1.8/bin/clang.exe']:pins[str(path.resolve())]=sha(path)
stable=lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
assert stable();initialize_output(root,out,reusable_directories=[b/'v12432/compiler-build01',b/'v18092/compiler-build01',build]);out.mkdir(exist_ok=False)
r={'schemaVersion':1,'status':'running','completed':0,'total':7,'mode':'focused-native-reused-managed','inputHashes':pins,'cases':[],'scope':'Only current Native boundary3 and async4 remain. Reuse unchanged CSharp11 and current Native originals38-42; no repeated completed cases and no new compiler build. Existing numeric allocation helper is reused.','nativeCompiler':str(build/'compiler.exe'),'nativeCompilerSha256':product['compilerSha256'],'managedProof':str(managedPath),'caseBudgetSeconds':180,'claimsGoalComplete':False}
with VerificationContractLease([Path(p) for p in pins]):
    x=VerificationExecution(root,out,r,stable,sha);error=None
    def run(command,prefix):
        remaining=deadline-time.monotonic()
        if remaining<=0:raise TimeoutError('CASE_180_SECOND_BUDGET_EXHAUSTED')
        return x.run(command,prefix,timeout=min(180,remaining))
    try:
        for case in cases:
            deadline=time.monotonic()+180;folder=out/case['id'];folder.mkdir();exe=folder/'probe.exe';row={'id':case['id'],'status':'running','passed':False,'source':case['source'],'sourceSha256':sha(root/case['source'])};r['cases'].append(row);x.save()
            step=run([str(build/'compiler.exe'),'build',str(root/case['source']),'-o',str(exe),'--target','windows-x64','--keep-temps','--llvm',str(root/'.tools/llvm-22.1.8'),'--stdlib',str(root/'stdlib')],folder/'build');row.update(buildExit=step.returncode,buildStderr=step.stderr.strip());assert step.returncode==0 and step.stderr.strip()==case['stderr'],step.stderr
            step=run([str(exe)],folder/'run');row.update(runExit=step.returncode,runStdout=step.stdout.strip(),runStderr=step.stderr.strip());assert step.returncode==0 and step.stdout.strip()==case['stdout'] and not step.stderr.strip(),(step.returncode,step.stdout,step.stderr)
            llvm=Path(str(exe)+'.ll');assert llvm.is_file();row['llvmSha256']=sha(llvm)
            step=run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'probe.bc')],folder/'assemble');row['assemblyExit']=step.returncode;assert step.returncode==0 and not step.stderr.strip(),step.stderr
            audit,passed=numeric.audit_llvm_program(llvm,folder,case['expectedAllocations'],case['stdout'],lambda command,prefix:run(command,prefix).returncode);row.update(audit);assert passed,audit
            row.update(status='passed',passed=True,elapsedSeconds=round(180-(deadline-time.monotonic()),6));r['completed']+=1;x.save();print(case['id']+': PASS',flush=True)
        r['status']='passed'
    except BaseException as exc:
        error=exc
        if r['cases'] and r['cases'][-1]['status']=='running':r['cases'][-1].update(status='failed',passed=False)
    finally:x.finalize(error,cleanup=False)
    print({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']},flush=True)
    if error:raise error
