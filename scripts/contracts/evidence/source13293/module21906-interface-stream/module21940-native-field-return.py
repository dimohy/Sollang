from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'module21940-native-field-return';producerPath=B/'module21938-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';referencePath=B/'module21935-fixed-field-return/result.json';producer=json.loads(producerPath.read_text(encoding='utf-8-sig'));reference=json.loads(referencePath.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
for r in [producer,reference]:assert r['status']=='passed' and r['inputsStable'] and r['processesStopped'] and all(sha(p)==h for p,h in r['inputHashes'].items())
manifest=ROOT/'scripts/probes/codegen-function-owner/conditional-field-return.slg';sources=[manifest];fixtures=[];expected='n\n';assert reference['status']=='passed' and reference['completed']==reference['total']==3
paths=[Path(__file__),producerPath,EMITTER,referencePath,*map(Path,producer['inputHashes']),*map(Path,reference['inputHashes']),manifest,*sources,*fixtures];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=3,cases=[],inputHashes=inputs,scope='Current Native matched-payload field projection: implicit return, borrow and explicit early return against fixed CSharp controls. No full cache admission claim.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(OUT/'unused.semantic'),str(OUT/'unused-stage.semantic'),*map(str,sources)],OUT/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2000:]+done.stderr
  ll=OUT/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n');exe=OUT/'program.exe'
  done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'program.bc')],OUT/'assemble',timeout=budget());assert done.returncode==0,done.stderr
  done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=budget());assert done.returncode==0,done.stderr
  for mode in ['tail','borrow','early']:
   done=ex.run([str(exe),mode],OUT/mode,timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,(done.returncode,done.stdout,done.stderr,expected)
   result['cases'].append(dict(id=mode,passed=True,stdout=done.stdout));result['completed']+=1
  result.update(status='passed',ownershipProbe=True)
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
