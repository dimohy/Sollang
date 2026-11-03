from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output
side=sys.argv[1];c=b/('io25614-managed/compiler/Sollang.Compiler.exe' if side=='managed' else 'io25639-native/compiler.exe');o=b/('io25640-buffer-linux-'+side);reuse=[b/'io25626-native',b/'io25639-native',b/'v20050/compiler-build01'];initialize_output(r,o,reusable_directories=reuse);o.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();compiler_inputs=managed_runtime_inputs(c) if side=='managed' else [b/'io25639-native/result.json',*current_build_inputs(r,json.loads((b/'io25639-native/result.json').read_text()))];paths=[Path(__file__),b/'io25640-buffer-linux.ps1',c,*compiler_inputs,r/'scripts/verification-process.ps1',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',r/'scripts/probes/file-completion-publication/buffer-controls.slg',*sorted((r/'stdlib').rglob('*.slg'))];pins={str(p):sha(p) for p in paths};v=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='Actual Linux file buffer eight-operation ownership program through canonical compiler cross-target build and supervised WSL output capture; owned output stays in private cache.',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);err=None
try:
 d=x.run(['pwsh','-NoProfile','-File',str(b/'io25640-buffer-linux.ps1'),'-Compiler',str(c),'-Output',str(o)],o/'linux',timeout=220);assert d.returncode==0 and not d.stderr and 'Shared file buffer Linux build and eight actual operations: PASS' in d.stdout,(d.stdout,d.stderr);v.update(status='passed',completed=1,cases=[dict(id='actual-linux-file-buffer-eight',passed=True)])
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
if err:raise err
print(json.dumps({k:v[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
