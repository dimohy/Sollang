from pathlib import Path
import sys,shutil,json,hashlib,time
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from verification_async_workers import validate_workers
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
seed=json.loads((b/'contextual15943-emitter/result.json').read_text());assert seed['runExit']==0 and seed['inputsStable'] and seed['processesStopped']
for p,h in seed['inputHashes'].items():assert sha(p)==h,('DIAGNOSTIC_EMITTER_INPUT_DRIFT',p)
compiler=b/'managed15851/compiler/Sollang.Compiler.exe';emitter=b/'contextual15943-emitter/probe.exe';bridge=b/'link15443/bin/CompilerLinkBridge/release/CompilerLinkBridge.dll';out=b/'contextual15945-slg6';contract=b/'contextual15944-positive6.json';cases=json.loads(contract.read_text(encoding='utf-8-sig'))['cases'];assert len(cases)==6
stdlib=sorted(root.glob('stdlib/**/*.slg'));inputs=[*[Path(p) for p in seed['inputHashes']],emitter,*managed_runtime_inputs(compiler),bridge,bridge.with_suffix('.deps.json'),bridge.with_suffix('.runtimeconfig.json'),contract,root/'scripts/verification_async_workers.py',*[root/c['source'] for c in cases],Path(__file__),*[root/'.tools/llvm-22.1.8/bin'/n for n in ['clang.exe','lld-link.exe','llvm-lib.exe']]]
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,scope='production-SLG-emission-path-diagnostic-not-Native-CLI-qualification',cases=[],completed=0,total=len(cases),claimsGoalComplete=False,aggregateBudgetSeconds=1200,stepBudgetSeconds=180)
 run=VerificationExecution(root,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None;started=time.monotonic()
 def bounded_run(*args,**kwargs):
  if time.monotonic()-started+180>1200:raise ValueError('DIAGNOSTIC_AGGREGATE_BUDGET_EXHAUSTED_BEFORE_STEP')
  return run.run(*args,**kwargs)
 try:
  for case in cases:
   directory=out/case['id'];directory.mkdir();ll=directory/'program.ll';work=directory/'work';work.mkdir();exe=directory/'program.exe'
   emitted=bounded_run([str(emitter),*map(str,stdlib),str(root/case['source'])],directory/'emit',timeout=180);row=dict(id=case['id'],emitExit=emitted.returncode);result['cases'].append(row)
   if case['exit']==1:
    row['passed']=emitted.returncode==1 and not emitted.stderr and emitted.stdout.strip()==case['stderr'] and 'target triple =' not in emitted.stdout
    row['rejectedBeforeLlvm']='target triple =' not in emitted.stdout
    if not row['passed']:raise ValueError('CANDIDATE_REJECTION_CHANGED:'+case['id'])
    result['completed']+=1;run.save();print('PASSED '+case['id'],flush=True);continue
   if emitted.returncode or emitted.stderr:raise ValueError('CANDIDATE_EMISSION_FAILED:'+case['id'])
   if 'nativeCoroutineWorkers' in case:row['nativeCoroutineWorkers']=validate_workers(emitted.stdout,case['nativeCoroutineWorkers'])
   shutil.copyfile(directory/'emit.stdout',ll);dll=compiler.with_suffix('.dll');command=[shutil.which('dotnet'),str(bridge),'link-slg-main',str(dll),sha(dll),str(root/'.tools/llvm-22.1.8'),str(ll),str(exe),str(work),'-O0']
   linked=bounded_run(command,directory/'link',timeout=180);row['linkExit']=linked.returncode
   if linked.returncode or linked.stderr:raise ValueError('CANDIDATE_LLVM_FAILED:'+case['id'])
   ran=bounded_run([str(exe)],directory/'run',timeout=180);row['runExit']=ran.returncode;actual=ran.stdout.replace('\r\n','\n');expected=case.get('expectedRawStdout',case['stdout']+'\n');row['passed']=ran.returncode==0 and actual==expected and not ran.stderr
   if not row['passed']:raise ValueError('CANDIDATE_OUTPUT_CHANGED:'+case['id'])
   result['completed']+=1;run.save();print('PASSED '+case['id'],flush=True)
  result['status']='passed'
 except BaseException as failure:error=failure
 finally:run.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','processesStopped','failure']}))
