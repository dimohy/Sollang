from pathlib import Path
from datetime import datetime, timezone
import json,shutil

r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def load(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,d):Path(p).write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
semantic=load(b/'allocation17742-semantic/result.json')
assert semantic['status']=='passed' and semantic['completed']==semantic['total']==4
assert semantic['inputsStable'] and semantic['processesStopped']
fault=load(b/'allocation17740-managed-failure/result.json')
assert fault['status']=='passed' and fault['completed']==fault['total']==1
assert fault['inputsStable'] and fault['processesStopped']
assert fault['cases'][0]['unsignedRunExit']==0xc000001d
assert (b/'allocation17740-managed-failure/run.stderr').read_text()=='main:bb_alloc_fail3'
archive=r/'scripts/contracts/evidence/source13293/allocation17745';archive.mkdir(exist_ok=False)
items=['allocation17737-failure.py','allocation17738-managed-failure','allocation17739-managed-failure','allocation17740-managed-failure','allocation17741-prepare.py','allocation17741-comparison.json','allocation17741-provider-map.json','allocation17741-sources.txt','allocation17741-candidate','allocation17742-semantic','allocation17744-archive.py']
for name in items:
    source=b/name;target=archive/'records'/name
    if source.is_dir():
        shutil.copytree(source,target,ignore=shutil.ignore_patterns('*.exe','*.dll','*.pdb','*.bc','*.ll','*.obj','.sollang-cache','bin','obj'))
    else:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
qualification=dict(schemaVersion=1,status='private-raw-memory-family-candidate-semantic-passed-runtime-pending',observedAtUtc=datetime.now(timezone.utc).isoformat(),candidateSourceFiles=28,canonicalCompilerSourcesChanged=False,sourceComparison='records/allocation17741-comparison.json',semantic=dict(completed=4,total=4,evidence='records/allocation17742-semantic/result.json'),managedFailureObservation=dict(runtimeCompleted=1,runtimeTotal=1,unsignedRunExit=3221225501,stderr='main:bb_alloc_fail3',evidence='records/allocation17740-managed-failure/result.json',lifecycleDisposition='preserved: cleanup rejected a runtime failure expectation without a pinned contract; no cleanup bypass'),scope='Raw platform allocation family and nullable allocate/copy/free resize helper, using live byte counts at three previous CRT realloc consumers. The private candidate preserves API-specific releases. No compiler product built from candidate.',remaining=['Add expression allocation null guards and the same diagnostic decision as managed before claiming original42 parity.', 'Verify emitted LLVM, normal execution, allocation/free and injected failure from the same private SLG source closure.', 'Verify original42 unchanged common LLVM; do not rename SSA only to satisfy the assertion or create another oracle.', 'Integrate canonical sources only after focused acceptance; then new general Native and final/Stage remain separate.'],compilerClosedChanged=False,claimsGoalComplete=False)
save(archive/'qualification.json',qualification)
path=r/'scripts/contracts/active-goal-progress.json';goal=load(path)
goal['currentRawMemoryFamilyCandidate']='scripts/contracts/evidence/source13293/allocation17745/qualification.json'
goal['currentWork']['focus']='Original42 allocation-family source comparison: private28-file memory primitive/resize candidate passed semantic4/4, but no emitted/runtime acceptance yet. Managed injected failure observed trap status0xc000001d and main:bb_alloc_fail3. Canonical compiler remains e9514e77 slice implementation; original42 whole parity0/1.'
goal['currentWork']['next']='Finish shared expression allocation guard and diagnostic decisions before one checked SLG producer and focused runtime/failure/common original42 tests. Keep sources/oracles and180-second case cap unchanged. Preserve lifecycle-rejected and failed outputs.'
goal['previousGoalTurnClassification']='progress: source comparison identified managed runtime trap diagnostics, raw allocator-family candidate28 files implemented privately and semantic4/4 passed; canonical integration pending acceptance'
goal['observedAtUtc']=qualification['observedAtUtc']
save(path,goal)
print(json.dumps(dict(candidateSources=28,semanticCompleted=4,semanticTotal=4,original42Completed=0,original42Total=1,canonicalCompilerChanged=False)))
