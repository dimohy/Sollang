from pathlib import Path
import datetime, hashlib, json, shutil, subprocess
r=Path.cwd(); b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
out=r/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,x): p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def rel(p): return p.relative_to(r).as_posix()
def archive(src,dst):
    for p in src.rglob('*'):
        if p.is_file() and p.suffix in ['.json','.stdout','.stderr','.log','.txt']:
            q=dst/p.relative_to(src);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
source=read(b/'bounded13562-source/result.json')
assert source['status'] in ['passed','failed'] and source['total']==4 and source['inputsStable'] and source['processesStopped']
for folder,n in [('bounded13557-semantic',4),('bounded13558-stdlib',1),('bounded13561-managed',1)]:
    d=read(b/folder/'result.json');assert d['status']=='passed' and d['completed']==d['total']==n and d['inputsStable'] and d['processesStopped']
for folder in ['bounded13557-semantic','bounded13558-stdlib','bounded13559-managed','bounded13560-managed','bounded13561-managed','bounded13562-source']:
    archive(b/folder,out/folder)
for name in ['bounded13559-managed-contract.json','bounded13560-managed-contract.json','bounded13561-managed-contract.json','bounded13561-full45.json','bounded13562-contract.json','bounded13562-emitter.slg','bounded13563-checkpoint.py']:
    shutil.copyfile(b/name,out/name)
cpp=read(b/'bounded13521-managed/result.json');extra=read(b/'bounded13561-managed/result.json')
assert cpp['status']=='passed' and cpp['inputsStable'] and cpp['processesStopped']
fullContract=read(b/'bounded13561-full45.json');assert len(fullContract['cases'])==45
for c in fullContract['cases']:
    proof=extra if c['id']=='bounded-function-cleanup' else cpp
    assert proof['inputHashes'][str(r/c['source'])]==sha(r/c['source']),c['id']
cppFocus=out/'focused-csharp45.json'
write(cppFocus,dict(completed=45,total=45,steps=[dict(id=c['id'],status='complete') for c in fullContract['cases']],evidence=[rel(out/'bounded13521-managed/result.json'),rel(out/'bounded13561-managed/result.json')],scope='Reuse unchanged CSharp44 exact input/producer proofs and supplement1; not one new whole45 execution.',claimsGoalComplete=False))
passed={c['id'] for c in source['cases'] if c.get('passed')};assert len(passed)==source['completed']
focus=out/'focused-cleanup13563.json';full=out/'focused-current-source13563.json'
for target,total,contract in [(focus,4,read(b/'bounded13562-contract.json')),(full,45,fullContract)]:
    write(target,dict(completed=len(passed),total=total,steps=[dict(id=c['id'],status='complete' if c['id'] in passed else 'pending') for c in contract['cases']],evidence=rel(out/'bounded13562-source/result.json'),executionState=source['status'],observedAtUtc=now,claimsGoalComplete=False))
paths=[row['path'] for row in read(out/'checkpoint13554.json')['files']]
delta=['selfhost/llvm/text/container_control.slg','selfhost/llvm/text/function_returns.slg']
paths+=delta;assert len(paths)==12
build=read(b/'managed13519/result.json')
for name in paths:
    pins=source['inputHashes'] if name.endswith('.slg') else build['inputHashes']
    assert pins[str(r/name)]==sha(r/name),name
nextStep='Inspect current cleanup focused4 result and actual function cleanup emission; finish interpolation and remaining enum/dictionary/capture boundaries against CSharp reference, then full current source45, C731 strict23 and fresh Native focused verification. Resolve implementation prerequisites and freeze inputs for original14/source7/runtime2708, Stage2/3, frozen stdlib/runtime22 and required platform/performance acceptance.'
checkpoint=out/'checkpoint13563.json'
record=dict(schemaVersion=1,observedAtUtc=now,status='bounded-cleanup-source4-'+source['status'],compiler=dict(closed=363,candidateFixed=363,open=4,total=730),implementation=dict(completed=139,total=145),managed=dict(completed=45,total=45,evidence=rel(cppFocus),reuseScope='Unchanged44 plus supplemental1 on same8AB compiler'),semantic=dict(completed=4,total=4,evidence=rel(out/'bounded13557-semantic/result.json')),stdlibSource=dict(completed=1,total=1,evidence=rel(out/'bounded13558-stdlib/result.json')),sourceCleanup=dict(completed=len(passed),total=4,status=source['status'],evidence=rel(out/'bounded13562-source/result.json')),sourceMatrix=dict(completed=len(passed),total=45,evidence=rel(full)),files=[dict(path=p,sha256=sha(r/p)) for p in paths],stage=dict(completed=0,total=2),stdlib=dict(completed=6,total=22),failures=[dict(id='prior-indexed-copy-drop-abi',state='focused-fixed' if source['status']=='passed' else 'current-cleanup-focus-failed',priorEvidence=rel(out/'bounded13553-source/result.json'),currentEvidence=rel(out/'bounded13562-source/result.json')),dict(id='invalid-supplementary-test-expression-statements',state='input-corrected-csharp-passed',evidence=rel(out/'input-corrections13562.json')),dict(id='historical-progress-checker-retired-inputs',state='unresolved',evidence='scripts/contracts/evidence/C2026-10-24-732/field-value13489/progress-check-observation13502.json')],next=nextStep,claimsCandidateFixed=False,claimsGoalComplete=False)
write(checkpoint,record)
coverage=read(out/'cleanup-emission13563.json')
record['actualCleanupEmissionCoverage']=dict(evidence=rel(out/'cleanup-emission13563.json'),ordinaryLocal=coverage['ordinaryLocal'],regionEarly=coverage['regionEarly'],temporary=coverage['temporary'],scope='Observed after function regression runtime passed. Temporary-specific prefix absent; do not claim direct coverage of that branch from this case.')
write(checkpoint,record)
patch=subprocess.run(['git','diff','--',*delta],capture_output=True,check=True).stdout;assert patch
(out/'cleanup13563.patch').write_bytes(patch)
previous=out/'physical-source-review13554.json';physical=read(previous)
changed={p:sha(r/p) for p,row in physical['sources'].items() if sha(r/p)!=row['sha256']};assert set(changed)==set(delta),changed
for p,h in changed.items():
    old=physical['sources'][p]['sha256'];physical['sources'][p].update(sha256=h,inspectionState='current-complete',review=dict(sha256=h,evidence=rel(out/'cleanup-source-comparison13556.json'),method='CSharp44 pre-edit cleanup authority; runtime-handle local slots and canonical inline drop boundary; supplemental function regression CSharp1 verified separately.'))
    physical['authoredDeltaReviews'][p]=dict(source=p,preimageSha256=old,currentSha256=h,evidence=rel(checkpoint),scope='Two authored cleanup deltas only.',wholeFileCreditAdded=False)
physical.update(observedAtUtc=now,previousIndex=rel(previous),requalificationCounts=dict(unchangedCurrentReviewReuse=209,currentAuthoredDeltaReview=2),currentCanonicalDeltaRequalification=dict(reference=rel(checkpoint),count=2,scope='Entry/region and ordinary function cleanup ABI source review; no whole-phase or general Native closure.'))
write(out/'physical-source-review13563.json',physical)
root=r/'scripts/contracts/active-goal-progress.json';d=read(root)
for g in d['focusedGates']:
    if g['name'] in ['C732-current-source44','C732-current-field-context5']:
        g['status']='stale-failed';g['scope']='Prior Typed IR epoch; terminal4/5 followed by LLVM cleanup ABI failure. Not current cleanup epoch acceptance.'
names=['C732-current-csharp45','C732-current-cleanup4','C732-current-source45']
d['focusedGates']=[g for g in d['focusedGates'] if g['name'] not in names]
d['focusedGates'] += [dict(name=names[0],status='complete',completed=45,total=45,evidence=rel(cppFocus)),dict(name=names[1],status='complete' if source['status']=='passed' else 'failed',completed=len(passed),total=4,evidence=rel(focus)),dict(name=names[2],status='active',completed=len(passed),total=45,evidence=rel(full))]
d.update(currentFocusedGate=names[2],observedAtUtc=now,next=nextStep,currentSourceProofsValidForWorktree=False,currentNativeSlgSourcesMatchWorktree=False)
d['currentPhysicalSourceReview'].update(reference=rel(out/'physical-source-review13563.json'),counts=physical['requalificationCounts'])
d['currentC732SourceCandidate'].update(evidence=rel(checkpoint),sourceResult=rel(out/'bounded13562-source/result.json'),sourcePassed=len(passed),sourceTotal=4,sourceFailed=sum(c.get('status')=='failed' for c in source['cases']),sourceUnexecuted=4-len(source['cases']),sourceEpoch='bounded-cleanup-value-abi',currentSourceStatus=source['status'],currentSourcePassed=len(passed),currentSourceTotal=45,currentSemanticEvidence=rel(out/'bounded13557-semantic/result.json'),currentStdlibSourceEvidence=rel(out/'bounded13558-stdlib/result.json'),claimsCandidateQualified=False)
d['currentWork'].update(focus=f'Canonical inline materialization at entry/region and function cleanup boundaries authored. CSharp44 unchanged proofs plus supplemental function1 passed; semantic4/std source1 passed. Current cleanup4 runtime {len(passed)}/4, {source["status"]}; full source45 and fresh Native pending.',next=nextStep,observedAtUtc=now,snapshot=rel(checkpoint),activeExecutions=[])
for step in d['currentWork']['steps']:
    if step['id']=='managed-first':step['evidence']=rel(cppFocus)
    if step['id']=='source-comparison':step['evidence']=rel(out/'cleanup-source-comparison13556.json')
d['currentBoundedCleanup13563']=record;write(root,d)
ledger=r/'scripts/contracts/compiler-defects.json';d=read(ledger)
for row in d['defects']:
    if row['id']=='C2026-10-24-732':
        row.update(currentArrayAsyncEvidence=rel(checkpoint),remaining=nextStep)
        cause='Entry/region and ordinary function cleanup passed bounded runtime descriptors directly to canonical inline drop helpers and misloaded mutable descriptor slots as inline values.'
        if cause not in row['additionalRootCauses']:row['additionalRootCauses'].append(cause)
    if row['id'] in ['C2026-10-24-733','C2026-10-24-734']:
        row['remaining']=f'Current CSharp45 proof scope; cleanup focused4 {len(passed)}/4 ({source["status"]}). Fresh Native and final closure pending.'
write(ledger,d)
print(json.dumps(dict(sourceCompleted=len(passed),sourceTotal=4,status=source['status'],checkpoint=rel(checkpoint))))
