from pathlib import Path
import sys,json,hashlib,shutil,time,re
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21667-stream-equivalence';P=ROOT/'scripts/probes/codegen-function-order';producerPath=B/'cache21666-stream-emitter/result.json';producer=json.loads(producerPath.read_text());EMITTER=producerPath.parent/'emitter.exe'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped']
assert all(sha(p)==h for p,h in producer['inputHashes'].items())
paths=[Path(__file__),producerPath,EMITTER,*map(Path,producer['inputHashes']),*P.iterdir(),*[B/'order21638-slg-order'/name/'emit.stdout' for name in ['before','after','source-order']]]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir();project=OUT/'project';project.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=4,cases=[],inputHashes=inputs,maximumCaseSeconds=180,claimsGoalComplete=False,scope='Current SLG production emitter: framed output stripped to original bytes equals plain output and previous qualified output; Windows link/run and Linux assembly. No actual codegen cache reuse claim.')
 run=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  shutil.copyfile(P/'main.slg',project/'main.slg');shutil.copyfile(P/'alpha.slg',project/'alpha.slg')
  for name,variant,order,target in [('before','before.slg',['main.slg','alpha.slg','beta.slg'],'windows'),('after','after.slg',['main.slg','alpha.slg','beta.slg'],'windows'),('source-order','after.slg',['main.slg','beta.slg','alpha.slg'],'windows'),('linux','before.slg',['main.slg','alpha.slg','beta.slg'],'linux')]:
   shutil.copyfile(P/variant,project/'beta.slg');sources=[project/n for n in order];live={str(p):sha(p) for p in sources};d=OUT/name;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));outputs={}
   for mode in ['plain','framed']:
    done=run.run([str(EMITTER),mode+'-'+target,str(ROOT/'stdlib'),str(d/'cache.semantic'),str(d/(mode+'.semantic')),*map(str,sources)],d/mode,timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1500:]+done.stderr;outputs[mode]=done.stdout
   lines=outputs['framed'].splitlines(keepends=True);markers=[line.rstrip('\r\n') for line in lines if line.startswith('; sollang.codegen.')]
   headers=[line[len('; sollang.codegen.unit '):] for line in markers if line.startswith('; sollang.codegen.unit ')];assert headers[0]=='0:' and headers[-1]=='2:' and len(headers)==4 and markers[-1]=='; sollang.codegen.end',markers
   assert sorted(headers[1:-1])==['1:cache.alpha','1:cache.beta'],headers
   stripped=''.join(line for line in lines if not line.startswith('; sollang.codegen.'));assert stripped==outputs['plain'],'framing changed LLVM bytes'
   if target=='windows':assert outputs['plain']==(B/'order21638-slg-order'/name/'emit.stdout').read_text(encoding='utf-8-sig'),'module worker changed previous qualified LLVM bytes'
   ll=d/'program.ll';ll.write_text(outputs['framed'],encoding='utf-8');done=run.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(d/'program.bc')],d/'assemble',timeout=budget());assert done.returncode==0,done.stderr
   stdout=None
   if target=='windows':
    exe=d/'program.exe';done=run.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],d/'link',timeout=budget());assert done.returncode==0,done.stderr
    done=run.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==(P/'expected.stdout.txt').read_text(encoding='utf-8-sig'),done.stdout+done.stderr;stdout=done.stdout
   assert all(sha(p)==h for p,h in live.items());result['cases'].append(dict(id=name,passed=True,units=4,framedEqualsPlain=True,equalsPreviousQualified=target=='windows',target=target,linkedAndRun=target=='windows',stdout=stdout,sourceHashes=live,llvmSha256=sha(ll)));result['completed']+=1;run.save()
  result['status']='passed'
 except BaseException as error:err=error
 finally:run.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
