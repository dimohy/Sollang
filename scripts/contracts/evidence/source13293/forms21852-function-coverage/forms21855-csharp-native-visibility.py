from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'forms21855-csharp-native-visibility';CPP=B/'managed21831/compiler/Sollang.Compiler.exe';manifest=ROOT/'scripts/probes/codegen-native-visibility/main.slg';sources=[manifest];fixtures=[];selected=[];expected=None;sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),manifest,*sources,*fixtures,*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=inputs,scope='CSharp focused compile/run: public and ordinary native zero-input declarations both resolve correct names and return identical GetVersion values.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  exe=OUT/'program.exe';done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2500:]+done.stderr
  done=ex.run([str(exe),*map(str,fixtures)],OUT/'run',timeout=budget());assert done.returncode==0 and not done.stderr,(done.stdout,done.stderr,expected)
  values=done.stdout.splitlines();assert len(values)==2 and values[0].isdigit() and values[0]==values[1],done.stdout
  result.update(status='passed',completed=1,declarations=len(selected),fieldCount=sum(len(row['fields']) for row in selected),stdout=done.stdout,cases=[dict(id='live-declaration-facts',passed=True,declarations=len(selected),fieldCount=sum(len(row['fields']) for row in selected),stdout=done.stdout)])
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
