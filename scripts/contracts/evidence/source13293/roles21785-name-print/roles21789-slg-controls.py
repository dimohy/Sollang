from pathlib import Path
import sys,json,hashlib,time,re
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'roles21789-slg-controls';P=ROOT/'scripts/probes/each-role-display';producerPath=B/'roles21787-source-emitter/result.json';producer=json.loads(producerPath.read_text(encoding='utf-8-sig'));EMITTER=producerPath.parent/'emitter.exe'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'];assert all(sha(p)==h for p,h in producer['inputHashes'].items())
referencePath=B/'roles21784-csharp/result.json';reference=json.loads(referencePath.read_text(encoding='utf-8-sig'));assert reference['status']=='passed' and reference['completed']==reference['total']==6 and reference['inputsStable'] and reference['processesStopped'];assert all(sha(p)==h for p,h in reference['inputHashes'].items())
cases=[(row['id'],row['expectedRuntimeTrap'],row.get('stdout')) for row in reference['cases']];providers=[]
paths=[Path(__file__),producerPath,EMITTER,*map(Path,producer['inputHashes']),referencePath,*map(Path,reference['inputHashes']),*[(P/(n+'.slg') if n!='stream' else ROOT/'scripts/probes/source-review-boundaries/scratch-integer-stream.slg') for n,_,_ in cases],*providers]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=len(cases),cases=[],inputHashes=inputs,maximumCaseSeconds=180,claimsGoalComplete=False,scope='Current SLG actual control/entry/function each-role Text/Bool/Int/member interpolation and unchanged stream terminal control against CSharp6. No whole Native CLI, codegen cache or Stage promotion.')
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  for name,rejected,expected in cases:
   d=OUT/name;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
   done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(d/'unused.semantic'),str(d/'unused-stage.semantic'),str(P/(name+'.slg') if name!='stream' else ROOT/'scripts/probes/source-review-boundaries/scratch-integer-stream.slg'),*map(str,providers)],d/'emit',timeout=budget());diagnostic=done.stdout if rejected else None
   assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
   ll=d/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n');exe=d/'program.exe'
   done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(d/'program.bc')],d/'assemble',timeout=budget());assert done.returncode==0,done.stderr
   done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],d/'link',timeout=budget());assert done.returncode==0,done.stderr
   done=ex.run([str(exe)],d/'run',timeout=budget())
   if rejected:assert done.returncode!=0 and not done.stdout,done.stdout+done.stderr
   else:assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout+done.stderr
   stdout=done.stdout
   result['cases'].append(dict(id=name,passed=True,expectedRuntimeTrap=rejected,diagnostic=diagnostic,stdout=stdout));result['completed']+=1;ex.save()
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
