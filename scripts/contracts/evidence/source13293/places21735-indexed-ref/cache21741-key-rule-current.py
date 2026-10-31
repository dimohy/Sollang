from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21741-key-rule-current';producerPath=B/'places21738-source-emitter/result.json';producer=json.loads(producerPath.read_text());EMITTER=producerPath.parent/'emitter.exe';referencePath=B/'cache21733-key-rule-pairs/result.json';reference=json.loads(referencePath.read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'] and all(sha(p)==h for p,h in producer['inputHashes'].items());assert reference['status']=='failed' and reference['completed']==1 and reference['cases'][0]['id']=='csharp' and reference['cases'][0]['passed'] and reference['inputsStable'] and reference['processesStopped'];assert all(sha(p)==h for p,h in reference['inputHashes'].items());assert all(sha(p)==h for p,h in reference['generatedInputHashes'].items())
P=ROOT/'scripts/probes/codegen-cache-key-rules';sources=[ROOT/p for p in (P/'sources.txt').read_text().splitlines() if p];smoke=referencePath.parent/'vectors/key-rule-smoke.slg';expectedPath=referencePath.parent/'expected.stdout.txt';paths=[Path(__file__),producerPath,EMITTER,*map(Path,producer['inputHashes']),referencePath,*map(Path,reference['inputHashes']),*sources,smoke,expectedPath];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=inputs,maximumCaseSeconds=180,claimsGoalComplete=False,scope='Current compiled SLG production checked emitter consumes generated CSharp key plans and matches the prior independently passed CSharp13 hash results plus two negative controls. The prior combined result remains failed because its Native21323 side failed. No full Native CLI cache/Stage qualification.')
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(OUT/'unused.semantic'),str(OUT/'unused-stage.semantic'),*map(str,sources),str(smoke)],OUT/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
  ll=OUT/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n');exe=OUT/'program.exe'
  done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'program.bc')],OUT/'assemble',timeout=budget());assert done.returncode==0,done.stderr
  done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=budget());assert done.returncode==0,done.stderr
  done=ex.run([str(exe)],OUT/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expectedPath.read_text(encoding='utf-8'),done.stdout+done.stderr
  result.update(status='passed',completed=1,keyHashes=13,negativeControls=2,stdout=done.stdout,referenceCppSubcase='cache21733-key-rule-pairs:cases[0]')
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
