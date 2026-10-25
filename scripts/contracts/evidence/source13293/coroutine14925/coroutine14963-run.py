from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cp=Path(__file__).with_suffix('.json');c=R(cp);pins=c['inputHashes'];pins[str(cp.resolve())]=H(cp);pins[str(Path(__file__).resolve())]=H(Path(__file__))
stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
assert stable(),'CURRENT48_CANDIDATE_INPUT_DRIFT'
out=Path(c['output']);initialize_output(root,out,reusable_directories=list(map(Path,c['reusableDirectories'])));out.mkdir(exist_ok=False)
r=dict(schemaVersion=1,status='running',scope='Candidate current48 private ABI, original nine semantic boundary groups plus null untracked-head assertions; original40 probe remains unchanged and failed.',completed=0,total=9,inputHashes=pins,cases=[],pendingBaselineDecision=True,claimsOriginal40ProbePassed=False,compilerSourceModified=False,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,H);error=None
try:
 link=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),c['llvm'],c['candidate'],'-O0','-Wno-override-module','-o',str(out/'runtime.exe')],out/'link',timeout=180);assert link.returncode==0 and not link.stderr,'CURRENT48_CANDIDATE_LINK_FAILED'
 run=x.run([str(out/'runtime.exe')],out/'run',timeout=180);norm=lambda p:Path(p).read_bytes().replace(bytes((13,10)),bytes((10,)));assert run.returncode==0 and not run.stderr and norm(out/'run.stdout')==norm(c['expectedStdout']),'CURRENT48_CANDIDATE_BOUNDARY_FAILED'
 r.update(status='passed',completed=9,cases=[dict(id='current48-start-boundaries',status='passed',passed=True,controlsCompleted=9,controlsTotal=9,untrackedHeadNullRequired=True)])
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
