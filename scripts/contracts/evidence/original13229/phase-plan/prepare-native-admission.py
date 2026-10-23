import json,pathlib,hashlib,datetime
root=pathlib.Path.cwd();base=pathlib.Path('artifacts/scratch/resume-20261006-owner-continuation22');run=base/'parsing13228'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def ref(p):return {'path':p.as_posix(),'sha256':sha(p)}
proof=run/'evidence/managed-phase-execution.json'
if not proof.exists():raise SystemExit('WAIT: actual managed22 phase execution is not complete; comparison not written')
controller=load(run/'managed-controller.execution.json');assert controller['status']=='passed' and controller['actualExit']==0 and controller['processesStopped']
batch=load(run/'managed-whole/managed-current-batch-results.json');assert batch['state']=='passed' and batch['completed']==batch['passed']==batch['total']==405 and batch['failed']==0
p=load(proof);assert p['status']=='passed' and p['completed']==p['total']==22 and p['inputStable'] and p['failureIds']==[] and p['orphanProcessIds']==[]
review=base/'parsing13016/review-current.json';r=load(review)
for path,h in r['sourceHashes'].items():assert sha(pathlib.Path(path))==h,path
inventory=load(run/'reviewed-inventory.json');contract=load(run/'execution-contract.json')
shared={path:sha(pathlib.Path(path)) for path in inventory['sharedDependencies']}
d={'schemaVersion':1,'phase':'parsing','status':'compared','observedAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Current managed original405 and22 decision witnesses passed before source-side execution. Reuse23 identical whole-file reviews and the2 recorded source deltas; all25 source hashes verified again. No source modification or new whole-file reading claimed.','sourceHashes':r['sourceHashes'],'sharedDependencyHashes':shared,'decisions':inventory['decisions'],'managedFirstRecord':ref(proof),'generationRecord':contract['generationRecord'],'sourceOrderRequalification':ref(review),'newManualWholeFileInspectionClaimed':False,'claimsFullPairedPhaseComplete':False}
out=run/'source-comparison.json';assert not out.exists();out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n');print('PASS current compared25 +shared10, decisions16; managed405/405 and22/22')
