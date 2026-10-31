from pathlib import Path
import json,hashlib,sys,time
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21708-stream-pairs';CPP=B/'managed21702/compiler/Sollang.Compiler.exe';NATIVE=B/'v21323/compiler-build01/compiler.exe';P=ROOT/'scripts/probes/codegen-unit-stream'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
manifest=P/'sources.txt';sources=[ROOT/s for s in manifest.read_text().splitlines() if s];expected=P/'expected.stdout.txt'
inputs=[Path(__file__),CPP,*managed_runtime_inputs(CPP),NATIVE,NATIVE.parent/'result.json',manifest,expected,*sources,*sorted((ROOT/'stdlib').rglob('*.slg')),B/'cache21648-source-comparison.json']
hashes={str(p):sha(p) for p in inputs};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(inputs):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=hashes,maximumCaseSeconds=180,scope='Production SLG codec source, including generated current CSharp context policy, compiled/run by current CSharp and pinned Native21323 seed; not a new self-host compiler product or full Native cache integration.',claimsGoalComplete=False)
 run=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in hashes.items()),sha);error=None
 try:
  for role,compiler in [('csharp',CPP),('native-seed',NATIVE)]:
   d=OUT/role;d.mkdir();exe=d/'program.exe';start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));command=[str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0']
   if role=='native-seed':command += ['--stdlib',str(ROOT/'stdlib')]
   done=run.run(command,d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
   done=run.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected.read_text(encoding='utf-8-sig'),done.stdout+done.stderr
   result['cases'].append(dict(id=role,passed=True,buildExit=0,runExit=0,stdout=done.stdout,expectedRows=26));result['completed']+=1;run.save()
  result['status']='passed'
 except BaseException as e:error=e
 finally:run.finalize(error,cleanup=False)
 if error:raise error
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
