from pathlib import Path
import sys,json,hashlib
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'places21738-source-emitter';CPP=B/'managed21731/compiler/Sollang.Compiler.exe'
manifest=ROOT/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s and not s.endswith('selfhost-sollangc-driver.slg')];probe=ROOT/'scripts/probes/codegen-unit-stream/emitter.slg';semantic=B/'places21737-current-semantic/result.json'
sem=json.loads(semantic.read_text());assert sem['status']=='passed' and sem['completed']==sem['total']==4 and sem['inputsStable'] and sem['processesStopped']
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),manifest,probe,semantic,*sources,*sorted((ROOT/'stdlib').rglob('*.slg')),ROOT/'scripts/contracts/evidence/source13293/cache21658-production-flow/source-comparison.json',ROOT/'scripts/contracts/evidence/source13293/places21735-indexed-ref/source-comparison.json']
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(paths):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=inputs,scope='Build current SLG production stream emitter for pending output equivalence consumers. No Native cache reuse or Stage claim.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  done=ex.run([str(CPP),'build',str(probe),*map(str,sources),'-o',str(OUT/'emitter.exe'),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=180);assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
  result['completed']=1;result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
