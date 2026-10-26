from pathlib import Path
import json,sys,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
source=r/'examples/regression/39-stack-promoted-int-dictionary.slg';expected=r/'examples/regression/expected/39-stack-promoted-int-dictionary.stdout.txt';contains=expected.with_name('39-stack-promoted-int-dictionary.llvm.contains.txt');excludes=expected.with_name('39-stack-promoted-int-dictionary.llvm.not-contains.txt');out=b/'dictionary16072-placement39';managed=b/'managed15892/compiler/Sollang.Compiler.exe';native=b/'v15969/compiler-build01/compiler.exe'
inputs=[Path(__file__),source,expected,contains,excludes,*managed_runtime_inputs(managed),native,r/'scripts/verification_execution.py']
with VerificationContractLease(inputs):
 out.mkdir();pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='Observe original39 runtime and original LLVM placement requirements separately; do not waive or rewrite its LLVM oracles.',inputHashes=pins,cases=[],caseBudgetSeconds=180,claimsDecisionComplete=False,claimsGoalComplete=False)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for name,compiler in [('managed',managed),('native',native)]:
   exe=out/(name+'.exe');built=run.run([str(compiler),'build',str(source),'-o',str(exe),'--llvm',str(r/'.tools/llvm-22.1.8'),'--target','windows-x64','-O0','--jobs','1','--keep-temps'],out/(name+'-build'),timeout=180)
   assert built.returncode==0 and not built.stderr,(name,'PLACEMENT_BUILD_FAILED',built.stderr)
   observed=run.run([str(exe)],out/(name+'-run'),timeout=180)
   assert observed.returncode==0 and not observed.stderr and observed.stdout.strip()==expected.read_text(encoding='utf-8-sig').strip(),(name,'PLACEMENT_RUNTIME_FAILED')
   paths=[p for p in [Path(str(exe)+'.ll'),exe.with_suffix('.ll')] if p.is_file()];assert len(paths)==1,'EXPLICIT_RETAINED_LLVM_MISSING'
   ir=paths[0].read_text(encoding='utf-8-sig')
   required=contains.read_text(encoding='utf-8-sig').splitlines();forbidden=excludes.read_text(encoding='utf-8-sig').splitlines()
   row=dict(provider=name,runtimeMatched=True,llvmRequiredMissing=[x for x in required if x and x not in ir],llvmForbiddenPresent=[x for x in forbidden if x and x in ir],llvmSha256=sha(paths[0]),llvmPath=str(paths[0]))
   row['originalLlvmOracleMatched']=not row['llvmRequiredMissing'] and not row['llvmForbiddenPresent'];result['cases'].append(row);run.save()
  result['status']='observed-not-qualified'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
 print(json.dumps({k:result.get(k) for k in ['status','cases','failure','inputsStable','processesStopped']}))
