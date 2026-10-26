from pathlib import Path
import json,sys,hashlib,re,shutil,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
fixture=b/'locator16024/extended';cases=[b/'locator16052/local.slg'];out=b/'locator16054-local-boundary'
adapter=b/'locator16043/managed-probe/LocatorProbe.dll';compiler=b/'managed15892/compiler/Sollang.Compiler.exe'
probes=[b/'locator16019/slg-managed-v2/probe.exe',b/'locator16019/slg-native/probe.exe'];dotnet=Path(shutil.which('dotnet'))
inputs=[Path(__file__),*cases,adapter,adapter.with_suffix('.deps.json'),adapter.with_suffix('.runtimeconfig.json'),*managed_runtime_inputs(compiler),*probes,dotnet,r/'src/Sollang.Compiler/Semantics/AsyncSuspensionLocator.cs']
for name in ['slg-managed-v2','slg-native']:
 proof=json.loads((b/'locator16019'/name/'result.json').read_text(encoding='utf-8-sig'));assert proof['controlMatched'] and proof['inputsStable'] and proof['processesStopped']
 for p,h in proof['inputHashes'].items():assert sha(p)==h.upper(),p
 inputs.extend(Path(p) for p in proof['inputHashes'])
inputs.extend([b/'v15969/compiler-build01/compiler.exe',b/'v15969/compiler-build01/result.json']);inputs=list(dict.fromkeys(inputs))
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='Candidate source identity branch preparation, semantic validation before provider comparison; no decision or phase closure',inputHashes=pins,cases=[],matched=0,total=len(cases),claimsGoalComplete=False,claimsDecisionComplete=False,aggregateBudgetSeconds=1200,stepBudgetSeconds=180)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None;started=time.monotonic()
 def observe(command,prefix):
  if time.monotonic()-started+180>1200:raise ValueError('LOCATOR_BRANCH_AGGREGATE_BUDGET_EXHAUSTED_BEFORE_STEP')
  return run.run(command,prefix,timeout=180)
 try:
  commands=[
    [str(compiler),'build',str(cases[0]),'-o',str(out/'managed-unused.exe'),'--llvm',str(r/'.tools/llvm-22.1.8'),'--target','windows-x64','-O0','--jobs','1'],
    [str(b/'v15969/compiler-build01/compiler.exe'),'build',str(cases[0]),'-o',str(out/'native-unused.exe'),'--llvm',str(r/'.tools/llvm-22.1.8'),'--target','windows-x64','-O0','--jobs','1']]
  for index,command in enumerate(commands):
   observed=observe(command,out/('boundary'+str(index)))
   assert observed.returncode!=0 and 'async functions require a transferable result, a sendable input, and a non-local user declaration; owned inputs must use move' in observed.stderr,'LOCAL_ASYNC_BOUNDARY_DIFFERENCE'
   assert not (out/('managed-unused.exe' if index==0 else 'native-unused.exe')).exists()
  result.update(status='passed',matched=2,total=2)
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','matched','total','inputsStable','processesStopped','failure']}))

