from pathlib import Path
import json,sys,hashlib,re,shutil,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
fixture=b/'locator16024/extended';cases=[b/'locator16055/local_sync.slg'];out=b/'locator16056-local-sync'
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
  for source in cases:
   folder=out/source.stem;folder.mkdir();text=source.read_text(encoding='utf-8-sig');headers=list(re.finditer(r'^(\w+)[^\n]*-> async\b',text,re.M));expected=[];states={}
   for site in re.finditer(r'\b(yield|await)\b',text):
    fn=[h.group(1) for h in headers if h.start()<site.start()][-1];states[fn]=states.get(fn,0)+1;prefix=text[:site.start()]
    expected.append(f"point|{fn}|{states[fn]}|{1 if site.group(1)=='yield' else 0}|{len(prefix.encode())}|{prefix.count(chr(10))+1}|{len(prefix.rsplit(chr(10),1)[-1])+1}")
   expected.sort();(folder/'expected.stdout').write_bytes(('\n'.join(expected)+'\n').encode());row=dict(id=source.stem,source=str(source),sourceSha256=sha(source),expectedPoints=len(expected));result['cases'].append(row)
   command=[str(dotnet),str(adapter),str(compiler.with_suffix('.dll')),str(source),'probes.suspension_source_control']
   managed=observe(command,folder/'managed');row['managedExit']=managed.returncode
   if managed.returncode:
    row.update(status='candidate-source-rejected',diagnostic=managed.stderr.splitlines()[0] if managed.stderr else 'empty diagnostic');run.save();print(source.stem+': source rejected',flush=True);continue
   row['managedMatched']=sorted(managed.stdout.splitlines())==expected and not managed.stderr
   row['providerMatched']=[]
   for index,probe in enumerate(probes):
    observed=observe([str(probe),str(source)],folder/('slg'+str(index)));row['providerMatched'].append(observed.returncode==0 and not observed.stderr and sorted(observed.stdout.splitlines())==expected)
   covered=observe([*command,'coverage'],folder/'coverage');row['coveredTypes']=sorted({line.rsplit('|',1)[-1] for line in covered.stdout.splitlines() if line.startswith('visit|')});row['coverageExit']=covered.returncode
   matched=row['managedMatched'] and all(row['providerMatched']) and covered.returncode==0 and not covered.stderr
   row['status']='matched' if matched else 'provider-difference';result['matched']+=int(matched);run.save();print(source.stem+': '+row['status'],flush=True)
  result['status']='observed-not-qualified'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','matched','total','inputsStable','processesStopped','failure']}))

