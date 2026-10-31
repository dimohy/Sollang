from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'yield22025-native-controls';producerPath=B/'yield22023-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';producer=json.loads(producerPath.read_text(encoding='utf-8-sig'));assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'];contractPath=ROOT/'scripts/contracts/evidence/source13293/yield22019-input-contract/controls.json';contract=json.loads(contractPath.read_text(encoding='utf-8-sig'));cases=[contract['positive'],*contract['negative']];paths=[Path(__file__),producerPath,EMITTER,*map(Path,producer['inputHashes']),contractPath,*[ROOT/c[k] for c in cases for k in ['source','expected']]];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert all(sha(p)==h for p,h in producer['inputHashes'].items());inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,observations=[],inputHashes=inputs,maximumCaseSeconds=60,scope='Bounded Native observation of scalar and transformed input and later producer yield error. Capture exact current diagnostics before choosing explicit equivalent semantic oracles. Observation collection is not acceptance qualification.',claimsAcceptancePassed=False,claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,60-(time.monotonic()-start))
 try:
  for case in cases:
   label=case['id'];done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(OUT/'unused.semantic'),str(OUT/'unused-stage.semantic'),str(ROOT/case['source'])],OUT/(label+'-emit'),timeout=budget());result['observations'].append(dict(id=label,exit=done.returncode,stdout=done.stdout,stderr=done.stderr,hasTargetHeader='target triple =' in done.stdout));result['completed']+=1
   if label=='P1':
    assert done.returncode==0 and not done.stderr,done.stdout[-2000:]+done.stderr
    ll=OUT/'P1.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n');exe=OUT/'P1.exe';done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'P1.bc')],OUT/'assemble',timeout=budget());assert done.returncode==0,done.stderr
    done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=budget());assert done.returncode==0,done.stderr
    done=ex.run([str(exe)],OUT/'P1-run',timeout=budget());expected=(ROOT/case['expected']).read_text(encoding='utf-8-sig');assert done.returncode==0 and not done.stderr and done.stdout==expected,(done.returncode,done.stdout,done.stderr,expected);result['positiveRuntime']=dict(passed=True,stdout=done.stdout)
  result['status']='passed';result['cases']=[dict(id=o['id'],passed=True,observationOnly=True) for o in result['observations']]
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
