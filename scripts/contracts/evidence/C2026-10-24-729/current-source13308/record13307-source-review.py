from pathlib import Path
import copy, datetime, hashlib, json
root=Path.cwd()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(p,d):
    assert not p.exists()
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
prior_path=root/'scripts/contracts/evidence/source13293/current-physical-source-review13293.json'
prior=read(prior_path)
comparison=root/'scripts/contracts/evidence/C2026-10-24-729/type-provenance13300/source-comparison.json'
before=read(comparison)['sourceHashes']
out=root/'scripts/contracts/evidence/source13293'
delta=[]
current=copy.deepcopy(prior)
for name,row in current['sources'].items():
    actual=sha(root/name)
    if name not in before:
        assert row['sha256']==actual,name
        continue
    assert before[name]==row['sha256'],name
    assert sha(comparison.parent/(Path(name).stem+'.before.slg'))==row['sha256']
    change=dict(path=name,beforeSha256=row['sha256'],afterSha256=actual,
                before=str((comparison.parent/(Path(name).stem+'.before.slg')).relative_to(root)).replace('\\','/'),
                review='Full authored delta reviewed against preserved complete-file preimage, actual CSharp RuntimeInt.Type and terminal control-region type-provenance observation. Shared helper retains only committed concrete builtin integer symbols; all3 output paths consume it.',
                claimsCompiledParity=False)
    delta.append(change)
    row.update(sha256=actual,previousReviewedSha256=row['sha256'])
    row['review']=dict(sha256=actual,evidence='scripts/contracts/evidence/source13293/authored-delta13307.json',method=change['review'])
assert len(delta)==4 and len(current['sources'])==211
write(out/'authored-delta13307.json',dict(schemaVersion=1,status='source-delta-reviewed-focused-proof-pending',changes=delta,unchangedFiles=207,changedReviewedFiles=4,physicalFiles=[211,211],claimsCompiledParity=False,claimsGoalComplete=False))
current.update(observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),previousIndex=str(prior_path.relative_to(root)).replace('\\','/'),scope='Current physical inspection only:207 identical previous reviewed files plus4 fully reviewed authored deltas. Behavioral parity and phase closure remain separate.',requalificationCounts=dict(unchangedCompleteReviewReuse=207,currentAuthoredDeltaReview=4),currentCanonicalDeltaRequalification=dict(unchanged=207,deltaReviewed=4,evidence='scripts/contracts/evidence/source13293/authored-delta13307.json'))
write(out/'current-physical-source-review13307.json',current)
p=root/'scripts/contracts/active-goal-progress.json'
d=read(p)
d['currentPhysicalSourceReview'].update(reference='scripts/contracts/evidence/source13293/current-physical-source-review13307.json',counts=dict(unchangedCurrentReviewReuse=207,currentAuthoredDeltaReview=4))
d['currentWork'].update(focus='Committed integer helper now shared by entry/function/control-region interpolation; current semantic4 passed, std144 prerequisite running before source controls10.',next='Finish current std144, run unchanged original/guard10 against actual canonical SLG emitter, then fresh O2 Native product and focused pair.')
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=root/'scripts/contracts/compiler-defects.json'
d=read(p)
unit=next(x for x in d['defects'] if x['id']=='C2026-10-24-729')
assert unit['state']=='open'
unit.update(rootCause='Actual control-region console interpolation resolves semantic Int type2 but uses legacy symbol -1 or13 for output signedness. Entry-only repair missed general-function/control-region consumers. All3 console paths now restore concrete builtin integer identity through a shared helper before choosing width and signedness.',sourceComparisonEvidence='scripts/contracts/evidence/C2026-10-24-729/type-provenance13300/source-comparison.json',remaining='Shared canonical source fix applied. Fresh semantic4 passed; current std144 and source-focused10 pending, then new Native product/focused pair and final closure requirements.')
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Current physical review211/211 requalified against4 authored deltas; C729 remains open.')
