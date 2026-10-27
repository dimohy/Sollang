from pathlib import Path
import json,hashlib,shutil,datetime
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22'
load=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def save(p,r):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(r,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
q=load(root/'scripts/contracts/evidence/source13293/duplicate16770/qualification.json')
proofs=[(b/'duplicate16751-reference10/result.json',10),(b/'duplicate16762-source10/result.json',10),(b/'duplicate16792-cache10/result.json',10),(b/'duplicate16791-semantic/result.json',2)]
for p,n in proofs:
 r=load(p);assert r['status']=='passed' and r['completed']==r['total']==n and r['inputsStable'] and r['processesStopped'],str(p)
 for name,h in r['inputHashes'].items():assert sha(name)==h.upper(),name
cache=load(b/'duplicate16792-cache10/result.json');warm=[c for c in cache['cases'] if 'warmExit' in c];assert len(warm)==3 and all(c['warmExit']==0 and c['warmLlvmExact'] and c['warmFrameLoadStatus']==0 and c['warmFrameReused']>0 for c in warm)
dest=root/'scripts/contracts/evidence/source13293/integration16797';assert not dest.exists()
copies=[]
for row in q['sourceCopies']:
 candidate=root/'scripts/contracts/evidence/source13293/duplicate16770'/row['candidate'];target=root/row['target'];assert sha(target)==row['beforeSha256'] and sha(candidate)==row['afterSha256'];copies.append(dict(target=row['target'],qualifiedCandidate=str(candidate.relative_to(root)).replace('\\','/'),beforeSha256=sha(target),afterSha256=sha(candidate)))
for row in copies:
 target=root/row['target'];before=dest/'before'/row['target'];before.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(target,before);shutil.copyfile(root/row['qualifiedCandidate'],target);assert sha(target)==row['afterSha256'];after=dest/'after'/row['target'];after.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(target,after)
p=root/'scripts/contracts/active-goal-progress.json';g=load(p);save(dest/'previous-current-epoch.json',dict(currentSourceEpoch16714=g['currentSourceEpoch16714'],currentFocusedGate=g['currentFocusedGate'],currentBuildResult=g.get('currentBuildResult'),currentBuildSha256=g.get('currentBuildSha256')))
counts=dict(currentFocus=dict(completed=0,total=66),currentSource=dict(completed=0,total=111),independentNative100=dict(completed=0,total=100),finalOriginal=dict(completed=0,total=14),finalSource=dict(completed=0,total=7))
g.update(currentBuildSourceMatchesWorktree=False,currentBuildSourcesCurrent=False,currentSourceProofsValidForWorktree=False,currentNativeSourceInvalidation='Four qualified declaration-diagnostic providers integrated. Prior16730 source111/native100/integration66 remain preserved; final gates require this new epoch.')
g['currentSourceEpoch16714']['supersededBy']='canonical-declaration-source16797';g['currentSourceEpoch16797']=dict(status='integrated-awaiting-current-native',sources=copies,authoritativeCurrentCounts=counts,priorEvidencePreserved=True,cachedProof='artifacts/scratch/resume-20261006-owner-continuation22/duplicate16792-cache10/result.json')
g['currentFocusedGate']='current-input-integration66-epoch16797';g['focusedGates'].append(dict(name=g['currentFocusedGate'],status='active',completed=0,total=66,evidence='scripts/contracts/evidence/source13293/integration16797/focused-gate.json'))
g['currentWork'].update(title='Canonical declaration diagnostic requalification',focus='CSharp10, actual SLG10, cache-enabled10 including three actual warm restoration controls passed. Four providers integrated; fresh canonical preflights and Native pending.',checkpoint='scripts/contracts/evidence/source13293/integration16797/qualification.json',next='Fresh canonical semantic preflight and source8 emission proof; retire superseded16730 through the existing qualified plan, then new Native build and relevant paired cases. Final14/source7/runtime2708/Stage remain pending.',activeExecutions=[])
for step in g['currentWork']['steps']+g['currentWork']['focusedCases']:step.update(status='pending');step.pop('evidence',None)
g['next']=g['currentWork']['next'];save(p,g)
gate=load(root/'scripts/contracts/evidence/source13293/integration16714/focused-gate.json');gate.update(status='pending-current-source-native-requalification',completed=0,total=66,scope='Same66 after four declaration-provider source changes; previous qualified66/111/100 proofs preserved, not rerun without this input change',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
for step in gate['steps']:step.update(status='pending',managedPassed=False,nativePassed=False)
save(dest/'focused-gate.json',gate)
save(dest/'qualification.json',dict(schemaVersion=1,status='qualified-private-declaration-providers-integrated;native-pending',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),sourceCopies=copies,proofs=[dict(path=str(p),sha256=sha(p),completed=n,total=n) for p,n in proofs],warmControls=3,authoritativeCurrentCounts=counts,currentNativeProductsQualified=0,stageCredit=0,claimsGoalComplete=False))
print('Integrated exactly four qualified declaration sources; current SLG111/Native100/integration66 reset for explicit source epoch change; prior evidence preserved')
