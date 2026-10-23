from pathlib import Path
import hashlib,json,sys
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import assert_output_shutdown,consumer_closure_record
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
old=base/'v13220/compiler-build01'
replacement=base/'v13262/compiler-build01'
out=base/'retirement13310-audit'
out.mkdir(exist_ok=False)
intake=root/'scripts/contracts/evidence/progress13282/native99-consumer-intake13296.json'
rows=[x for x in read(intake)['rows'] if x['productPinned']]
pins={}
observations=[]
for row in rows:
    p=root/row['path']
    record=read(p)
    assert record['status'] in ['passed','failed'] and record['processesStopped'] and record['inputsStable'],str(p)
    assert_output_shutdown(root,p.parent)
    pins[str(p)]=sha(p)
    observations.append(dict(path=str(p),sha256=sha(p),status=record['status'],inputsStable=True,processesStopped=True,claimsAcceptance=False))
controller=base/'parsing13228/native-controller.execution.json'
batch=base/'parsing13228/native-whole/native-current-batch-results.json'
c=read(controller)
b=read(batch)
assert c['status']=='failed' and c['inputsStable'] and c['processesStopped']
assert b['state']=='failed' and (b['completed'],b['passed'],b['failed'],b['total'])==(405,402,3,405)
assert_output_shutdown(root,controller.parent)
for p in [intake,controller,batch,old/'compiler.exe',old/'result.json',replacement/'compiler.exe',replacement/'result.json',Path(__file__),root/'scripts/completed_artifact_plan.py',root/'scripts/verification_execution.py']:
    pins[str(p)]=sha(p)
result=dict(schemaVersion=1,status='running',scope='Native99 compiler retirement audit only: terminal consumers and unchanged products; original405 has402 passed and3 failed in prior source epoch, no witness22 execution or current-source acceptance.',inputHashes=pins,retiredConsumerObservations=observations,wholeObservation=dict(controller=str(controller),batch=str(batch),passed=402,failed=3,total=405,sourceEpoch='pre-C728-C729'),claimsGoalComplete=False,claimsCompilerTestsPassed=False)
execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
error=None
try:
    probe=execution.run([str(old/'compiler.exe'),'--version'],out/'old-product-probe',timeout=30)
    assert probe.returncode==0 and not probe.stderr,probe.stderr
    result.update(status='passed',observedVersion=probe.stdout.strip())
except BaseException as caught:error=caught
finally:execution.finalize(error,cleanup=False)
assert result['status']=='passed'
direct=[root/row['path'] for row in rows if row['executesProduct'] and '/original13227-native/' not in row['path']]
assert len(direct)==5
consumers=direct+[out/'result.json']
proposal=consumer_closure_record(root,old,consumers,replacement,legacy_terminal=True)
(out/'proposed-consumer-closure.json').write_text(json.dumps(proposal,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(status='retirement-proposal-validated-not-applied',directConsumers=len(direct),terminalObservedConsumers=len(rows),originalWholeFailedPreserved=True,productDeleted=False)))
