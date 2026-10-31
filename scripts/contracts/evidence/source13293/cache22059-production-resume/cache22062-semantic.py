from pathlib import Path
import sys,json,hashlib
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache22062-semantic';CPP=B/'managed21997/compiler/Sollang.Compiler.exe'
manifests=[ROOT/p for p in ['scripts/probes/codegen-compilation-modules/sources.txt','selfhost/browser_driver.sources.txt','tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt','tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt']]
sourceSets=[[ROOT/s for s in m.read_text(encoding='utf-8-sig').splitlines() if s] for m in manifests]
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),*manifests,*[p for group in sourceSets for p in group],*sorted((ROOT/'stdlib').rglob('*.slg'))]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=4,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Current probe and all canonical source manifests: CSharp semantic preflight before SLG producer build.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  for index,sources in enumerate(sourceSets):
   done=ex.run([str(CPP),'check',*map(str,sources)],OUT/str(index),timeout=180);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
   result['cases'].append(dict(id=str(manifests[index].relative_to(ROOT)),passed=True));result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
