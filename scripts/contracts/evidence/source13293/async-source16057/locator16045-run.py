from pathlib import Path
import json,sys,hashlib,re,shutil,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
fixture=b/'locator16024/extended';cases=[b/'locator16043/generic.slg'];out=b/'locator16045-guard'
adapter=b/'locator16043/managed-probe/LocatorProbe.dll';compiler=b/'managed15892/compiler/Sollang.Compiler.exe'
probes=[b/'locator16019/slg-managed-v2/probe.exe',b/'locator16019/slg-native/probe.exe'];dotnet=Path(shutil.which('dotnet'))
inputs=[Path(__file__),*cases,adapter,adapter.with_suffix('.deps.json'),adapter.with_suffix('.runtimeconfig.json'),*managed_runtime_inputs(compiler),*probes,dotnet,r/'src/Sollang.Compiler/Semantics/AsyncSuspensionLocator.cs']
for name in ['slg-managed-v2','slg-native']:
 proof=json.loads((b/'locator16019'/name/'result.json').read_text(encoding='utf-8-sig'));assert proof['controlMatched'] and proof['inputsStable'] and proof['processesStopped']
 for p,h in proof['inputHashes'].items():assert sha(p)==h.upper(),p
 inputs.extend(Path(p) for p in proof['inputHashes'])
inputs=list(dict.fromkeys(inputs))
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',scope='Candidate source identity branch preparation, semantic validation before provider comparison; no decision or phase closure',inputHashes=pins,cases=[],matched=0,total=len(cases),claimsGoalComplete=False,claimsDecisionComplete=False,aggregateBudgetSeconds=1200,stepBudgetSeconds=180)
 run=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None;started=time.monotonic()
 def observe(command,prefix):
  if time.monotonic()-started+180>1200:raise ValueError('LOCATOR_BRANCH_AGGREGATE_BUDGET_EXHAUSTED_BEFORE_STEP')
  return run.run(command,prefix,timeout=180)
 try:
  observed=observe([str(dotnet),str(adapter),str(compiler.with_suffix('.dll')),str(b/'locator16019/control.slg'),'probes.suspension_source_control','negative-offset'],out/'guard')
  assert observed.returncode==0 and observed.stdout.strip()=='negative-offset=rejected' and not observed.stderr,'SOURCE_POSITION_GUARD_FAILED'
  result.update(status='passed',matched=1,total=1)
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','matched','total','inputsStable','processesStopped','failure']}))

