from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parent
root=r.parents[3]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
d=read(r/'records/parsing13013-producers/result.json');assert d['status']=='passed' and d['completed']==d['total']==3 and d['inputsStable'] and d['processesStopped']
for c in d['cases']:
 p=r/'records/parsing13013-producers'/c['id'];assert hashlib.sha256(p.read_bytes()).hexdigest().upper()==c['actualSha256']
pdb=read(r/'parsing13015-pdb.json');assert pdb['status']=='passed' and pdb['completed']==pdb['total']==2
old=read(r/'original-execution-contract9740.json');new=read(r/'execution-contract.json')
assert new['wholeFixturePlan']==old['wholeFixturePlan'] and len(new['wholeFixturePlan'])==405
assert new['cases'][:20]==old['cases'] and len(new['cases'])==22
assert new['decisionIds'][:15]==old['decisionIds'] and len(new['decisionIds'])==16
snap=read(r/'checkpoint13019.json');assert snap['goalComplete']==False and snap['finalSource']==[0,7,0.0]
assert snap['liveExecution']['restartAllowed']==False
print('PASS fresh generation3, actual compiled generated documents2, unchanged original405/20, additive subject-range2/decision1; execution still in progress, no phase completion claim')
