from pathlib import Path
import json,sys,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
config_path=Path(__file__).with_suffix('.json');config=read(config_path);pins=config['inputHashes'];pins[str(config_path.resolve())]=sha(config_path);pins[str(Path(__file__).resolve())]=sha(Path(__file__))
stable=lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
assert stable(),'INPUT_DRIFT_BEFORE_REPRESENTATION14'
out=Path(config['output']);initialize_output(root,out,reusable_directories=list(map(Path,config['reusableDirectories'])));out.mkdir(exist_ok=False)
r=dict(schemaVersion=1,status='running',completed=0,total=1,scope='Current independent Native14, exact original4+10 source/oracles, validated currentCSharp14 and explicit retained formatter;180s commands unchanged.',inputHashes=pins,maximumSeconds=config['maximumSeconds'],caseSeconds=180,retryCount=0,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,sha);error=None
try:
 done=x.run(config['command'],out/'native100',timeout=config['maximumSeconds']);assert done.returncode==0,done.stderr
 leaf=read(config['leaf']);assert leaf['status']=='passed' and leaf['completed']==leaf['total']==config['expectedCases'] and leaf['inputsStable'] and leaf['processesStopped'];r.update(status='passed',completed=1)
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
