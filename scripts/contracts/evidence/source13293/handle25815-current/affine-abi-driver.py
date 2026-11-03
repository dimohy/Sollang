from pathlib import Path
import sys,json,hashlib,re
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output,cleanup_output
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();side=sys.argv[1];assert side in ['managed','native'];o=b/sys.argv[2];reuse=[b/'handle25797-native',b/'v20050/compiler-build01'];build=b/'handle25807-native'
if side=='native':reuse.append(build)
initialize_output(r,o,reusable_directories=reuse);o.mkdir();managed=b/'abi25712-managed/compiler/Sollang.Compiler.exe';native=build/'compiler.exe';paths=[Path(__file__),managed,r/'scripts/probes/native-handle-lifecycle/abi-rejection.slg',*managed_runtime_inputs(managed),*sorted((r/'stdlib').rglob('*.slg'))]
proof=None
if side=='native':
 birth=json.loads((build/'result.json').read_text());proof=json.loads((b/'handle25808-affine-managed/result.json').read_text());assert proof['status']=='passed' and proof['completed']==proof['total']==1 and proof['inputsStable'] and proof['processesStopped'];assert all(sha(p)==h for p,h in proof['inputHashes'].items());paths += [native,build/'result.json',b/'handle25808-affine-managed/result.json',*current_build_inputs(r,birth)]
pins={str(p):sha(p) for p in paths};v=dict(status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='C764 affine nominal ABI rejection uses the CSharp declaration-derived numeric identity; no fixed old number',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 expected=None if proof is None else proof['cases'][0]['stderr']
 for label,compiler in [(side,managed if side=='managed' else native)]:
  d=o/label;d.mkdir();cmd=[str(compiler),'build',str(r/'scripts/probes/native-handle-lifecycle/abi-rejection.slg'),'-o',str(d/'rejected.dll'),'--library','--target','windows-x64','--llvm',str(r/'.tools/llvm-22.1.8'),'--jobs','1','-O0']
  if label=='native':cmd+=['--stdlib',str(r/'stdlib')]
  q=x.run(cmd,d/'build',timeout=180);assert q.returncode==1 and not q.stdout,(label,q.stdout,q.stderr);m=re.fullmatch(r"sollang: type '([0-9]+)' is not a fixed-width library ABI type\n",q.stderr);assert m,(label,q.stderr)
  if expected is None:expected=q.stderr
  else:assert expected==q.stderr,(expected,q.stderr)
  v['cases'].append(dict(id=label,passed=True,diagnosticTypeId=int(m[1]),stderr=q.stderr));v['completed']+=1;x.save();print(label+': PASS '+str(m[1]),flush=True)
 v['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
if error:raise error
cleanup_output(r,o,reusable_directories=reuse)
