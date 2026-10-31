from pathlib import Path
import sys,json,hashlib
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22'
native=len(sys.argv)>1; OUT=B/(sys.argv[2] if native else 'place22074-csharp')
CPP=B/'managed21997/compiler/Sollang.Compiler.exe';fixture=ROOT/'scripts/probes/reference-member-loop-index/main.slg'
paths=[Path(__file__),fixture,CPP,*managed_runtime_inputs(CPP),*sorted((ROOT/'stdlib').rglob('*.slg'))]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
if native:
 EMITTER=B/sys.argv[1]/'emitter.exe';producer=EMITTER.parent/'result.json';record=json.loads(producer.read_text());assert record['status']=='passed' and record['inputsStable'] and record['processesStopped'];assert all(sha(p)==h for p,h in record['inputHashes'].items());paths += [EMITTER,producer,*map(Path,record['inputHashes'])]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=inputs,scope='Readonly owned member after nested index inside while, primary and additional arguments, exact stdout 5/8/9/12.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  exe=OUT/'program.exe'
  if native:
   done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(OUT/'unused.semantic'),str(OUT/'unused-stage.semantic'),str(fixture)],OUT/'emit',timeout=180);assert done.returncode==0 and not done.stderr,done.stdout[-1000:]+done.stderr
   ll=OUT/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n')
   done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'program.bc')],OUT/'assemble',timeout=180);assert done.returncode==0,done.stderr
   done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=180);assert done.returncode==0,done.stderr
  else:
   done=ex.run([str(CPP),'build',str(fixture),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=180);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
  done=ex.run([str(exe)],OUT/'run',timeout=10);assert done.returncode==0 and not done.stderr and done.stdout=='5\n8\n9\n12\n',(done.returncode,done.stdout,done.stderr)
  result.update(status='passed',completed=1,cases=[dict(id='nested-index-member-loop',passed=True,stdout=done.stdout)])
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
