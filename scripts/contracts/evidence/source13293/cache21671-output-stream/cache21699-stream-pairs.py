from pathlib import Path
import json,hashlib,sys,time
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21699-stream-pairs';CPP=B/'managed21688/compiler/Sollang.Compiler.exe';receipt=B/'owner21695-source-emitter/result.json';producer=json.loads(receipt.read_text());NATIVE=receipt.parent/'emitter.exe';P=ROOT/'scripts/probes/codegen-unit-stream'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'] and all(sha(p)==h for p,h in producer['inputHashes'].items())
manifest=P/'sources.txt';sources=[ROOT/s for s in manifest.read_text().splitlines() if s];expected=P/'expected.stdout.txt'
inputs=[Path(__file__),CPP,*managed_runtime_inputs(CPP),NATIVE,receipt,*map(Path,producer['inputHashes']),manifest,expected,*sources,*sorted((ROOT/'stdlib').rglob('*.slg')),B/'cache21648-source-comparison.json']
hashes={str(p):sha(p) for p in inputs};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(inputs):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=hashes,maximumCaseSeconds=180,scope='Current decoder26 source controls, compiled and run by CSharp21688 and current checked SLG source emitter21695; no full Native CLI cache or Stage claim.',claimsGoalComplete=False)
 run=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in hashes.items()),sha);error=None
 try:
  for role,compiler in [('csharp',CPP),('current-slg',NATIVE)]:
   d=OUT/role;d.mkdir();exe=d/'program.exe';start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));command=[str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0']
   if role=='current-slg':command=[str(compiler),'plain-windows',str(ROOT/'stdlib'),str(d/'unused.semantic'),str(d/'unused-stage.semantic'),*map(str,sources)]
   done=run.run(command,d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
   if role=='current-slg':
    ll=d/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n')
    done=run.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(d/'program.bc')],d/'assemble',timeout=budget());assert done.returncode==0,done.stderr
    done=run.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],d/'link',timeout=budget());assert done.returncode==0,done.stderr
   done=run.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected.read_text(encoding='utf-8-sig'),done.stdout+done.stderr
   result['cases'].append(dict(id=role,passed=True,buildExit=0,runExit=0,stdout=done.stdout,expectedRows=26));result['completed']+=1;run.save()
  result['status']='passed'
 except BaseException as e:error=e
 finally:run.finalize(error,cleanup=False)
 if error:raise error
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
