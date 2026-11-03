from pathlib import Path
import sys,json,hashlib,re
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output,cleanup_output
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();side=sys.argv[1];assert side in ['managed','native'];o=b/('join25825-event-managed' if side=='managed' else 'join25833-event-native');managed=b/'join25821-managed/compiler/Sollang.Compiler.exe';native=b/'join25830-native/compiler.exe';compiler=managed if side=='managed' else native;reuse=[b/'handle25807-native',b/'v20050/compiler-build01']
if side=='native':reuse.append(b/'join25830-native')
initialize_output(r,o,reusable_directories=reuse);o.mkdir();cases=['809-event-stream-merge-bounded-runtime','810-event-stream-latest-bounded-runtime'];paths=[Path(__file__),compiler,*managed_runtime_inputs(managed),*[r/'examples/regression'/(n+'.slg') for n in cases],*sorted((r/'stdlib').rglob('*.slg'))];proof=None
if side=='native':
 birth=json.loads((b/'join25830-native/result.json').read_text());proof=json.loads((b/'join25825-event-managed/result.json').read_text());assert proof['status']=='passed' and proof['completed']==proof['total']==2 and proof['inputsStable'] and proof['processesStopped'];assert all(sha(p)==h for p,h in proof['inputHashes'].items());paths += [*current_build_inputs(r,birth),b/'join25830-native/result.json',b/'join25825-event-managed/result.json']
pins={str(p):sha(p) for p in paths};v=dict(status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='EventStream worker-backed merge/latest compilation and emitted call proof only; physical mouse events are not executed',runtimeExecuted=False,claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for n in cases:
  d=o/n;d.mkdir();exe=d/'probe.exe';cmd=[str(compiler),'build',str(r/'examples/regression'/(n+'.slg')),'-o',str(exe),'--llvm',str(r/'.tools/llvm-22.1.8'),'--jobs','4','-O1','--keep-temps']
  if side=='native':cmd+=['--stdlib',str(r/'stdlib')]
  q=x.run(cmd,d/'build',timeout=180);assert q.returncode==0 and not q.stderr,(n,q.stdout,q.stderr);ll=Path(str(exe)+'.ll');text=ll.read_text(encoding='utf-8-sig');matches=re.findall(r'^.*call ptr @sollang_stream_join_runtime_create.*$',text,re.M);assert matches,n;v['cases'].append(dict(id=n,passed=True,compilationPassed=True,runtimeExecuted=False,llvmSha256=sha(ll),workerCalls=matches));v['completed']+=1;x.save();print(n+': COMPILE PASS',flush=True)
 v['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
if error:raise error
cleanup_output(r,o,reusable_directories=reuse)
