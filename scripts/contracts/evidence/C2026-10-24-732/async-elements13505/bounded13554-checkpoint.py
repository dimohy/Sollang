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
            q=dst/p.relative_to(src); q.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(p,q)

source=read(b/'bounded13553-source/result.json')
assert source['status'] in ['passed','failed'] and source['inputsStable'] and source['processesStopped']
assert source['total']==5
for folder,n in [('bounded13550-trace',1),('bounded13551-semantic',4),('bounded13552-stdlib',1)]:
    d=read(b/folder/'result.json')
    assert d['status']=='passed' and d['completed']==d['total']==n and d['inputsStable'] and d['processesStopped']
for folder in ['bounded13547-trace','bounded13548-trace','bounded13550-trace','bounded13551-semantic','bounded13552-stdlib','bounded13553-source']:
    archive(b/folder,out/folder)
for name in ['bounded13547-run.py','bounded13547-trace.slg','bounded13548-fullcontext.py','bounded13548-run.py','bounded13548-template.slg','bounded13548-trace.slg','bounded13550-ir-validation.py','bounded13550-run.py','bounded13550-template.slg','bounded13550-trace.slg','bounded13553-contract.json','bounded13554-checkpoint.py']:
    shutil.copyfile(b/name,out/name)
paths=[row['path'] for row in read(out/'checkpoint13545.json')['files']]
path='selfhost/ir/typed/resolved_context_normalize_phases.slg'; paths.append(path)
assert len(paths)==10
managedBuild=read(b/'managed13519/result.json')
for name in paths:
    pins=source['inputHashes'] if name.endswith('.slg') else managedBuild['inputHashes']
    assert pins[str(r/name)]==sha(r/name),name
passed={c['id'] for c in source['cases'] if c.get('passed')}
assert len(passed)==source['completed']
focus=out/'focused-field-context13554.json'
full=out/'focused-current-source13554.json'
for target,total,contract in [(focus,5,b/'bounded13553-contract.json'),(full,44,b/'bounded13520-contract.json')]:
    write(target,dict(completed=len(passed),total=total,steps=[dict(id=c['id'],status='complete' if c['id'] in passed else 'pending') for c in read(contract)['cases']],evidence=rel(out/'bounded13553-source/result.json'),executionState=source['status'],observedAtUtc=now,claimsGoalComplete=False))
nextStep='Repair the now-observed cleanup ABI mismatch first: container_control local binding cleanup and function_returns temporary/binding cleanup still send runtime bounded descriptors to canonical inline drop helpers (mutable slots are also loaded with the wrong inline type). CSharp44 already proves the exact indexed-copy case. Compare those consumers and materialize canonical bounded values before drop, preserving ownership and cleanup. Then complete interpolation and enum/dictionary/capture boundaries, current source44, C731 strict23 and fresh Native focused validation before original14/source7/runtime2708, Stage2/3, frozen22 and platform/performance acceptance.'
checkpoint=out/'checkpoint13554.json'
record=read(out/'checkpoint13545.json')
record.update(observedAtUtc=now,status='typed-ir-bounded-context-field5-'+source['status'],semantic=dict(completed=4,total=4,evidence=rel(out/'bounded13551-semantic/result.json')),stdlibSource=dict(completed=1,total=1,evidence=rel(out/'bounded13552-stdlib/result.json')),sourceFieldContext=dict(completed=len(passed),total=5,status=source['status'],evidence=rel(out/'bounded13553-source/result.json')),sourceMatrix=dict(completed=len(passed),total=44,evidence=rel(full)),files=[dict(path=p,sha256=sha(r/p)) for p in paths],next=nextStep,claimsCandidateFixed=False,claimsGoalComplete=False)
record['canonicalContextValidation']=dict(completed=1,total=1,evidence=rel(out/'bounded13550-trace/result.json'),scope='Actual stdlib144+main1 preparation and Typed IR lowering preserve both inner bounded type identities; not general Native/final acceptance.')
record['failures'][0].update(state='field5-fixed-runtime-passed' if source['status']=='passed' else 'current-field5-still-failed',currentEvidence=rel(out/'bounded13553-source/result.json'))
if source['status']=='failed':
    record['failures'].append(dict(id='bounded-local-cleanup-canonical-drop-abi',state='observed-llvm-assembly-failure',evidence=rel(out/'bounded13553-source/bounded-index-copy-isolation/assemble.stderr'),reason='Prior semantic rejection fixed; actual LLVM now exposes runtime handle passed to inline bounded drop helper and mutable descriptor slot loaded as inline storage.'))
write(checkpoint,record)
patch=subprocess.run(['git','diff','--',path],capture_output=True,check=True).stdout
assert patch; (out/'ir-context13554.patch').write_bytes(patch)
previous=out/'physical-source-review13545.json'; physical=read(previous)
changed={p:sha(r/p) for p,row in physical['sources'].items() if sha(r/p)!=row['sha256']}
assert set(changed)=={path},changed
old=physical['sources'][path]['sha256']
physical['sources'][path].update(sha256=sha(r/path),inspectionState='current-complete',review=dict(sha256=sha(r/path),evidence=rel(out/'ir-source-comparison13549.json'),method='CSharp44 first, full-package semantic/Typed IR comparison; preserve contextual bounded identity while retaining operand repair and element diagnostics.'))
physical['authoredDeltaReviews'][path]=dict(source=path,preimageSha256=old,currentSha256=sha(r/path),evidence=rel(checkpoint),scope='Authored normalization delta only; no new whole-file credit.',wholeFileCreditAdded=False)
physical.update(observedAtUtc=now,previousIndex=rel(previous),requalificationCounts=dict(unchangedCurrentReviewReuse=210,currentAuthoredDeltaReview=1),currentCanonicalDeltaRequalification=dict(reference=rel(checkpoint),count=1,scope='Typed IR contextual bounded identity delta; terminal focused runtime result recorded separately.'))
write(out/'physical-source-review13554.json',physical)
root=r/'scripts/contracts/active-goal-progress.json'; d=read(root)
for g in d['focusedGates']:
    if g['name']=='C732-current-field-context5': g.update(completed=len(passed),total=5,status='complete' if source['status']=='passed' else 'failed',evidence=rel(focus))
    if g['name']=='C732-current-source44': g.update(completed=len(passed),total=44,status='active',evidence=rel(full))
d['currentFocusedGate']='C732-current-source44'; d['observedAtUtc']=now
d['next']=nextStep
d['currentSourceProofsValidForWorktree']=False
d['currentNativeSlgSourcesMatchWorktree']=False
d['currentPhysicalSourceReview'].update(reference=rel(out/'physical-source-review13554.json'),counts=physical['requalificationCounts'])
d['currentC732SourceCandidate'].update(evidence=rel(checkpoint),sourceResult=rel(out/'bounded13553-source/result.json'),sourcePassed=len(passed),sourceTotal=5,sourceFailed=sum(c.get('status')=='failed' for c in source['cases']),sourceUnexecuted=5-len(source['cases']),sourceEpoch='current-typed-ir-contextual-bounded-identity',currentSourceStatus=source['status'],currentSourcePassed=len(passed),currentSourceTotal=44,currentSemanticEvidence=rel(out/'bounded13551-semantic/result.json'),currentStdlibSourceEvidence=rel(out/'bounded13552-stdlib/result.json'),claimsCandidateQualified=False)
d['currentWork'].update(focus=f'Current CSharp44 passed. Typed IR was erasing nonempty contextual bounded identities; guarded canonical normalization and actual package IR validation passed. Current field-context runtime {len(passed)}/5, status {source["status"]}. Remaining interpolation/enum/dictionary/capture consumers, full source44 and fresh Native remain pending.',next=nextStep,observedAtUtc=now,snapshot=rel(checkpoint),activeExecutions=[])
d['currentBoundedContext13554']=record; write(root,d)
ledger=r/'scripts/contracts/compiler-defects.json'; d=read(ledger)
for row in d['defects']:
    if row['id']=='C2026-10-24-732':
        row.update(currentArrayAsyncEvidence=rel(checkpoint),remaining=nextStep)
        cause='Typed IR nonempty array normalization discarded canonical contextual bounded identity and re-inferred fixed literal storage.'
        if cause not in row['additionalRootCauses']: row['additionalRootCauses'].append(cause)
    if row['id'] in ['C2026-10-24-733','C2026-10-24-734']:
        row['remaining']=f'Current CSharp44 passed; current source field-context matrix {len(passed)}/5 ({source["status"]}), including projected mut and indexed copy. Fresh Native and final closure remain pending.'
write(ledger,d)
print(json.dumps(dict(sourceCompleted=len(passed),sourceTotal=5,status=source['status'],checkpoint=rel(checkpoint))))
