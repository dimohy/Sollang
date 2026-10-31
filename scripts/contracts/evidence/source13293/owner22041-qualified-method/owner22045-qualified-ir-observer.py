from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'owner22045-qualified-ir-observer';CPP=B/'managed21997/compiler/Sollang.Compiler.exe';manifest=ROOT/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';observer=ROOT/'scripts/probes/typed-pattern-scope/call-qualification-ir-observer.slg';sources=[observer]+[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s and not s.endswith('selfhost-sollangc-driver.slg')];fixture=ROOT/'scripts/probes/inherent-block-method-parity/negative-wrong-owner.slg';proof=ROOT/'scripts/contracts/evidence/source13293/block21994-value-contract/records/block21998-csharp-c426/result.json';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();managed=json.loads(proof.read_text(encoding='utf-8-sig'));assert managed['status']=='passed' and managed['completed']==managed['total']==4 and managed['inputsStable'] and managed['processesStopped'];assert all(sha(p)==h for p,h in managed['inputHashes'].items());paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),manifest,*sources,fixture,proof,*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=inputs,scope='Diagnostic only: inspect exact original N1 qualified path, symbols and final call rows. No Native acceptance or full-stdlib claim.',claimsAcceptancePassed=False,claimsGoalComplete=False,budget=dict(observerBuilds=1,buildSeconds=180,observationSeconds=60))
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  exe=OUT/'observer.exe';done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O0'],OUT/'build',timeout=180);assert done.returncode==0 and not done.stderr,done.stdout[-2000:]+done.stderr
  done=ex.run([str(exe),str(fixture)],OUT/'observe',timeout=60);assert done.returncode==0 and not done.stderr and done.stdout.rstrip().endswith('observed-qualification=1'),(done.returncode,done.stdout[-2000:],done.stderr)
  result.update(status='passed',completed=1,cases=[dict(id='c426-n1-qualification-observation',passed=True,observationOnly=True,stdout=done.stdout)])
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
