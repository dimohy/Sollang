from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,shutil

r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def load(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def save(p,d):Path(p).write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
runtime=load(b/'allocation17766-source7/result.json');loops=load(b/'allocation17775-source3/result.json');fault=load(b/'allocation17773-failure-pair/result.json')
for proof,count in [(runtime,7),(loops,3),(fault,2)]:
    assert proof['status']=='passed' and proof['completed']==proof['total']==count
    assert proof['inputsStable'] and proof['processesStopped']
assert len(fault['controls'])==14 and all(c['passed'] for c in fault['controls'])
common=load(b/'common17768-candidate42.json');assert common['status']=='passed' and common['completed']==common['total']==1 and common['inputsStable']
legacy=load(b/'allocation17771-slg-failure/result.json');assert legacy['status']=='failed' and legacy['completed']==0
prototype=load(b/'oracle17770-current51/result.json');assert prototype['status']=='failed' and prototype['completed']==4 and prototype['total']==12
providers=load(b/'allocation17761-provider-map.json');before=load(b/'allocation17748-comparison.json')['canonicalSourceHashes'];changes=[]
for canonical,candidate in providers.items():
    source=r/candidate;target=r/canonical
    assert sha(target)==before[canonical],canonical
    assert runtime['inputHashes'][str(source)]==sha(source)
    assert loops['inputHashes'][str(source)]==sha(source)
    changes.append(dict(path=canonical,before=sha(target),after=sha(source),qualifiedSource=candidate))
archive=r/'scripts/contracts/evidence/source13293/allocation17777';archive.mkdir(exist_ok=False)
items=['allocation17748-guards.py','allocation17748-comparison.json','allocation17749-semantic','allocation17750-borrow-fix.py','allocation17750-candidate','allocation17750-provider-map.json','allocation17750-sources.txt','allocation17751-semantic','canonical17752-stdlib','allocation17753-semantic','allocation17755-contracts.py','allocation17755-managed4.json','allocation17755-managed4','allocation17755-source7.json','allocation17755-emitter.slg','allocation17756-source7','common17757-candidate42.json','allocation17758-prepare-failure.py','allocation17758-failure.py','allocation17758-failure-contract.json','allocation17759-managed-failure','allocation17760-slg-failure','allocation17761-physical-pointer.py','allocation17761-comparison.json','allocation17761-candidate','allocation17761-provider-map.json','allocation17761-sources.txt','allocation17762-semantic','allocation17764-semantic','allocation17765-contract.py','allocation17765-source7.json','allocation17765-emitter.slg','allocation17766-source7','allocation17767-function-review.json','common17768-candidate42.json','oracle17770-current51','allocation17771-slg-failure','allocation17772-failure-pair.py','allocation17772-failure-contract.json','allocation17773-failure-pair','allocation17774-while-contracts.py','allocation17774-managed3.json','allocation17774-managed3','allocation17774-source3.json','allocation17774-emitter.slg','allocation17775-source3','allocation17776-integrate.py']
for name in items:
    source=b/name;target=archive/'records'/name
    if source.is_dir():
        shutil.copytree(source,target,ignore=shutil.ignore_patterns('*.exe','*.dll','*.pdb','*.bc','*.ll','*.obj','.sollang-cache','bin','obj'))
    else:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
shutil.copyfile(r/'scripts/verification_llvm_allocation.py',archive/'verification_llvm_allocation.py')
for row in changes:
    shutil.copyfile(r/row['qualifiedSource'],r/row['path']);assert sha(r/row['path'])==row['after']
integration=dict(schemaVersion=1,status='partial-canonical-memory-alignment-integrated-whole-unit-pending',observedAtUtc=datetime.now(timezone.utc).isoformat(),files=changes,originalExpectedFilesChanged=False,claimsGoalComplete=False)
save(b/'allocation17776-integration.json',integration);save(archive/'integration.json',integration)
qualification=dict(schemaVersion=1,status='canonical-memory-family-and-literal-guard-aligned-original42-common-passed-full-diagnostic-byte-equality-unresolved',observedAtUtc=integration['observedAtUtc'],canonicalSourceFiles=len(changes),currentRuntime=dict(completed=7,total=7,evidence='records/allocation17766-source7/result.json'),currentLoopRuntime=dict(completed=3,total=3,evidence='records/allocation17775-source3/result.json'),earlierRawRuntime=dict(completed=7,total=7,evidence='records/allocation17756-source7/result.json',role='previous input; do not add to current10'),original42CommonLlvm=dict(completed=1,total=1,evidence='records/common17768-candidate42.json'),sourceOwnedFailureObservation=dict(completed=2,total=2,controlsCompleted=14,controlsTotal=14,evidence='records/allocation17773-failure-pair/result.json',scope='Each diagnostic belongs to its own source function and actual failure block; both fail with0xc000001d before payload use. This does not establish byte-identical generated identifiers or replace the original common LLVM criterion.'),strictDiagnosticByteComparison=dict(completed=0,total=1,status='failed-preserved',evidence='records/allocation17771-slg-failure/result.json',managed='main:bb_alloc_fail3',slg='main:v118114_allocation_failed'),existing51ProducerPrototype=dict(completed=4,total=12,status='failed-valid-slg-assertion',evidence='records/oracle17770-current51/result.json',sourceAndExpectedFilesChanged=False),wholeOriginal42=dict(completed=0,total=1),compilerClosedChanged=False,implementationUnitsChanged=False,stageRun=False,newGeneralNativeBuilt=False,limitations=['Windows focused scope only; Linux/browser source decisions were compared but execution is unverified.', 'Reserve/materialization nullable resize callers retain earlier missing failure guards; compare and fix those decisions before closing the memory source unit.', 'The strict generated diagnostic identity comparison and original51 LLVM prototype remain unresolved.', 'General Native17599 is historical. Current-source general build, full source comparison, final2729 and Stage2/3 remain pending.'],claimsGoalComplete=False)
save(archive/'qualification.json',qualification)
path=r/'scripts/contracts/active-goal-progress.json';goal=load(path)
goal['currentCanonicalMemoryAlignmentQualification']='scripts/contracts/evidence/source13293/allocation17777/qualification.json'
goal['currentRawMemoryFamilyCandidate']='scripts/contracts/evidence/source13293/allocation17777/qualification.json'
goal['currentWork']['focus']='Canonical29-file partial memory alignment integrated after focused SLG runtime7/7, loops3/3, allocation1/1, original42 unchanged common LLVM1/1. Source-owned failure observation2/2 with14 controls does not claim identical generated diagnostic labels. Strict diagnostic bytes0/1 and original51 prototype4/12 remain unresolved. No whole-unit/closed/Stage promotion.'
goal['currentWork']['next']='Fix remaining reserve/materialization failure decisions from the CSharp source, resolve diagnostic identity scope and original51 LLVM prototype without editing original sources/answers. Context Error source resolution and current general Native/final gates remain pending.'
goal['previousGoalTurnClassification']='progress: canonical memory-family/literal failure and physical ownership pointers implemented, current focused normal10 and common42 verified; whole goal remains active'
goal['observedAtUtc']=integration['observedAtUtc'];save(path,goal)
print(json.dumps(dict(canonicalFiles=len(changes),runtime=7,loops=3,common42=1,strictDiagnosticPassed=0,wholeOriginal42Completed=0,compilerClosedChanged=False)))
