from pathlib import Path
import json,datetime,shutil
R=Path.cwd(); B=R/'artifacts/scratch/resume-20261006-owner-continuation22';P=R/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505';E=P/'call-stability14067'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rel(p):return p.relative_to(R).as_posix()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
detail=load(R/'scripts/contracts/structural-parity-detail.json');gap=load(R/'scripts/contracts/evidence/source13293/decision-source-gaps14142.json')
for row,phase in zip(gap['phaseRows'],detail['phaseProgress']):
    assert row['phase']==phase['phase'];decisions=phase['decisionInventory']['decisions']
    row.update(qualifiedDecisions=sum(x['status']=='complete' for x in decisions),pendingDecisionIds=[x['id'] for x in decisions if x['status']!='complete'])
gap['observedAtUtc']=now;save(R/'scripts/contracts/evidence/source13293/decision-source-gaps14239.json',gap)
root=R/'scripts/contracts/active-goal-progress.json';d=load(root)
d['currentSourceDecisionRequalification']['evidence']='scripts/contracts/evidence/source13293/decision-source-gaps14239.json'
active=[]
for name,session,kind in [('call14237-semantic',56129,'canonical-semantic4'),('call14238-stdlib',73005,'canonical-stdlib144')]:
    p=B/name/'result.json';q=load(p) if p.exists() else {}
    active.append(dict(kind=kind,result=rel(p),execSession=session,status=q.get('status','running')))
d['currentActiveVerification']=active;d['currentCheckpoint']=rel(P/'checkpoint14239.json')
c=load(P/'checkpoint14236.json');c.update(observedAtUtc=now,previousCheckpoint=rel(P/'checkpoint14236.json'),activeExecutions=active)
save(P/'checkpoint14239.json',c);save(root,d)
for name in ['promote14236.py','checkpoint14239.py']:shutil.copyfile(B/name,E/name)
print(json.dumps(dict(checkpoint=d['currentCheckpoint'],registeredQualified=43,active=active)))
