from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output
side=sys.argv[1];case=sys.argv[2];assert case in ['buffer','socket'];c=b/('platform25661-managed/compiler/Sollang.Compiler.exe' if side=='managed' else 'platform25669-native/compiler.exe');o=b/('platform25664-linux-'+case+'-'+side);reuse=[b/'io25639-native',b/'platform25669-native',b/'v20050/compiler-build01'];initialize_output(r,o,reusable_directories=reuse);o.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();compiler_inputs=managed_runtime_inputs(c) if side=='managed' else [b/'platform25669-native/result.json',*current_build_inputs(r,json.loads((b/'platform25669-native/result.json').read_text()))];paths=[Path(__file__),b/'platform25664-linux.ps1',c,*compiler_inputs,r/'scripts/verification-process.ps1',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',r/('scripts/probes/file-completion-publication/buffer-controls.slg' if case=='buffer' else 'scripts/probes/portable-memory-io/socket-completion-task-cancel-before-start.slg'),*sorted((r/'stdlib').rglob('*.slg'))];pins={str(p):sha(p) for p in paths};v=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='Actual Linux '+case+' through canonical cross-target build, WSL tool identity and supervised process captures; owned output stays in private cache.',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);err=None
try:
 d=x.run(['pwsh','-NoProfile','-File',str(b/'platform25664-linux.ps1'),'-Compiler',str(c),'-Output',str(o),'-Case',case],o/'linux',timeout=220);assert d.returncode==0 and not d.stderr and ('Platform async IO Linux '+case+': PASS') in d.stdout,(d.stdout,d.stderr);v.update(status='passed',completed=1,cases=[dict(id='actual-linux-'+case,passed=True)])
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
if err:raise err
print(json.dumps({k:v[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
