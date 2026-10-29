from pathlib import Path
import importlib.util,json,hashlib,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';output=b/'runtime18178-reused3'
source=b/'runtime18169-source12/result.json';previous=json.loads(source.read_text(encoding='utf-8'));contractPath=b/'runtime18167-source12.json';contract=json.loads(contractPath.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert previous['inputsStable'] and previous['processesStopped']
producer=previous['reusableCheckedProducer'];assert producer['status']=='built' and producer['buildExit']==0 and producer['buildStderr']=='' and producer['buildCount']==1
exe=Path(producer['executable']);assert sha(exe)==producer['executableSha256']
pins=dict(previous['inputHashes']);pins[str(source)]=sha(source);pins[str(exe)]=sha(exe)
validatorSpec=importlib.util.spec_from_file_location('checked_validator',root/'scripts/verify-checked-package-emitter.py');validator=importlib.util.module_from_spec(validatorSpec);validatorSpec.loader.exec_module(validator);validator.validate(contract,root)
runnerSpec=importlib.util.spec_from_file_location('numeric_verifier',root/'scripts/verify-c385-preir-call-numeric.py');numeric=importlib.util.module_from_spec(runnerSpec);runnerSpec.loader.exec_module(numeric)
selected=[c for c in contract['cases'] if c['id'] in ['reachable-text-materialize','reachable-process-capture','original42']];assert len(selected)==3
assert not any(c['id'] in {x['id'] for x in previous['cases']} for c in selected)
retained=[b/'v12432/compiler-build01',b/'v17599/compiler-build01',b/'v18092/compiler-build01']
initialize_output(root,output,reusable_directories=retained)
assert not output.exists();output.mkdir()
record={'schemaVersion':1,'status':'running','scope':'Remaining3 independent consumers of the same retained checked producer after unrelated original859 rejection; no rebuild, no changed compiler/source/expected input. Parent common39 failure remains.','executionChoice':'model-direct-with-existing-helpers','inputHashes':pins,'producerSourceRecord':str(source),'producerSha256':sha(exe),'producerBuildCount':0,'reusedProducerOriginalBuildCount':1,'caseBudgetSeconds':180,'completed':0,'total':3,'cases':[],'claimsGoalComplete':False}
def stable():return all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
assert stable()
with VerificationContractLease([Path(p) for p in pins]):
 execution=VerificationExecution(root,output,record,stable,sha);error=None
 def run(command,prefix):return execution.run(command,prefix,timeout=180)
 try:
  for case in selected:
   assert stable();folder=output/case['id'];folder.mkdir();row={'id':case['id'],'status':'running','programSource':case['programSource'],'observedSourceOrder':case['observedSourceOrder'],'producerSha256':sha(exe)};record['cases'].append(row);execution.save()
   result=run([str(exe),*case['runArguments']],folder/'emit');row['emissionExit']=result.returncode
   if result.returncode!=case.get('expectedRuntimeExit',0) or result.stderr.strip()!=case.get('runStderr',''):
    row.update(status='failed',failureId='EMISSION_DIAGNOSTIC_MISMATCH');execution.save();continue
   llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['emittedLlvmSha256']=sha(llvm)
   result=run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble');row['assemblyExit']=result.returncode
   if result.returncode or result.stderr.strip():row.update(status='failed',failureId='LLVM_ASSEMBLY_FAILED');execution.save();continue
   row['emittedEntryPoint']=validator.validate_emitted_entrypoint(llvm.read_text(encoding='utf-8'),'windows')
   native=folder/'emitted.exe';result=run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O1','-o',str(native),*numeric.WINDOWS_RUNTIME_LIBRARIES],folder/'native-link');row['nativeLinkExit']=result.returncode
   if result.returncode or result.stderr.strip():row.update(status='failed',failureId='NATIVE_LINK_FAILED');execution.save();continue
   result=run([str(native)],folder/'native-run');row.update(nativeRunExit=result.returncode,nativeRunStdout=result.stdout.strip(),nativeRunStderr=result.stderr.strip())
   if result.returncode!=case.get('expectedEmittedRuntimeExit',0) or result.stdout.strip()!=case['stdout'] or result.stderr.strip():row.update(status='failed',failureId='NATIVE_RUNTIME_MISMATCH');execution.save();continue
   if 'expectedAllocations' in case:
    audit,passed=numeric.audit_llvm_program(llvm,folder,case['expectedAllocations'],case['stdout'],run);row.update(audit)
    if not passed:row.update(status='failed',failureId='ALLOCATION_AUDIT_FAILED');execution.save();continue
   row.update(status='passed',passed=True);record['completed']+=1;execution.save();print(case['id']+': PASS',flush=True)
  record['status']='passed' if record['completed']==record['total'] else 'failed'
 except BaseException as exc:error=exc
 finally:execution.finalize(error,cleanup=False)
 print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}),flush=True)
 if error:raise error
 if record['status']!='passed':raise SystemExit(1)
