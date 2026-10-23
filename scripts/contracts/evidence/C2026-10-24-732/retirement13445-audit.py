from pathlib import Path
import hashlib,json,sys
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import assert_output_shutdown,consumer_closure_record
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
old=base/'v13347/compiler-build01'
replacement=base/'v13395/compiler-build01'
out=base/'retirement13445-audit'
out.mkdir(exist_ok=False)
names=['arraylayout13377-baseline','character13350-native','numeric13361-helper-supervised','numeric13360-native','numeric13365-helper-supervised','numeric13363-helper-supervised','retirement13393-audit','paired-retirement13444','substitution13374-guards-native','type-array13351-native']
consumers=[base/n/'result.json' for n in names]
observations=[]
for path in consumers:
    record=read(path)
    assert record['status'] in ['passed','failed'] and record['inputsStable'] and record['processesStopped'],path
    assert_output_shutdown(root,path.parent)
    observations.append(dict(path=str(path),status=record['status'],completed=record.get('completed'),total=record.get('total'),failedEvidencePreserved=record['status']=='failed'))
projection=read(base/'paired-retirement13444/result.json')
assert projection['claimsCompilerTestsPassed'] is False and projection['observedPairs']==5
assert all(Path(p).is_file() and sha(p)==h for p,h in projection['inputHashes'].items())
pins={str(p):sha(p) for p in consumers+[old/'compiler.exe',old/'result.json',replacement/'compiler.exe',replacement/'result.json',Path(__file__),root/'scripts/completed_artifact_plan.py',root/'scripts/verification_execution.py']}
result=dict(schemaVersion=1,status='running',scope='EB14 retirement observation only: ten direct consumers are terminal with current immutable results; failed language and helper observations remain preserved. Replacement B060 is a live identity product with known C732 failure, not current candidate acceptance.',inputHashes=pins,consumerObservations=observations,claimsGoalComplete=False,claimsCompilerTestsPassed=False)
pins.update(projection['inputHashes'])
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
print('EB14 consumer closure proposal validated; product not retired. Current source20 must finish before applying lifecycle cleanup.')
