from pathlib import Path
import hashlib,json,sys
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import assert_output_shutdown,consumer_closure_record
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
old=base/'v13312/compiler-build01'
replacement=base/'v13347/compiler-build01'
out=base/'retirement13393-audit'
out.mkdir(exist_ok=False)
names=['native13313-array4','native13313-boundary2','native13313-signed3','native13313-unsigned1','native13313-function1','type-cache13326-native','type-runtime13333-native','character13337-native','retirement13345-audit']
consumers=[base/n/'result.json' for n in names]
observations=[]
for path in consumers:
    record=read(path)
    assert record['status'] in ['passed','failed'] and record['inputsStable'] and record['processesStopped'],path
    assert_output_shutdown(root,path.parent)
    observations.append(dict(path=str(path),status=record['status'],completed=record.get('completed'),total=record.get('total'),failedEvidencePreserved=record['status']=='failed'))
pins={str(p):sha(p) for p in consumers+[old/'compiler.exe',old/'result.json',replacement/'compiler.exe',replacement/'result.json',Path(__file__),root/'scripts/completed_artifact_plan.py',root/'scripts/verification_execution.py']}
result=dict(schemaVersion=1,status='running',scope='34AB product retirement observation only: all18 passing direct cases and failed C730 case are terminal and preserved. Replacement EB14 has known C731 failure and is an identity replacement only. No current compiler acceptance claim.',inputHashes=pins,consumerObservations=observations,claimsGoalComplete=False,claimsCompilerTestsPassed=False)
execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
error=None
try:
    version=execution.run([str(old/'compiler.exe'),'--version'],out/'old-product-probe',timeout=30)
    assert version.returncode==0 and not version.stderr,version.stderr
    result.update(status='passed',observedVersion=version.stdout.strip())
except BaseException as caught:error=caught
finally:execution.finalize(error,cleanup=False)
assert result['status']=='passed',result.get('failure')
proposal=consumer_closure_record(root,old,consumers+[out/'result.json'],replacement,legacy_terminal=True)
(out/'proposed-consumer-closure.json').write_text(json.dumps(proposal,indent=2)+'\n',encoding='utf-8')
print('34AB consumer closure proposal validated; product not retired. Current source23 must finish before applying lifecycle cleanup.')
