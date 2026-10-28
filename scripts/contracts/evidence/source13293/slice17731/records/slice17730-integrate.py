from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil

r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def load(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def save(p,d):Path(p).write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
runtime=load(b/'slice17727-runtime8/result.json')
assert runtime['status']=='passed' and runtime['completed']==runtime['total']==8
assert runtime['inputsStable'] and runtime['processesStopped'] and runtime['producerBuildCount']==0
assert all(c['passed'] for c in runtime['cases'])
common=load(b/'common17726-candidate38.json')
assert common['status']=='passed' and common['completed']==common['total']==1 and common['inputsStable']
providers=load(b/'slice17716-provider-map.json')
comparison=load(b/'slice17716-comparison.json')
records=[]
for canonical,candidate in providers.items():
    p=r/canonical;q=r/candidate
    assert sha(p)==comparison['canonicalSourceHashes'][canonical]
    assert runtime['inputHashes'][str(q)]==sha(q)
    records.append(dict(path=canonical,before=sha(p),after=sha(q),qualifiedSource=candidate))
# Every candidate has completed the selected consumers and shut down. The
# failed parent is retained as historical execution evidence and never cleaned.
for row in records:
    shutil.copyfile(r/row['qualifiedSource'],r/row['path'])
    assert sha(r/row['path'])==row['after']
integration=dict(schemaVersion=1,status='canonical-slice-ABI-integrated-general-native-pending',observedAtUtc=datetime.now(timezone.utc).isoformat(),files=records,sourceComparison='slice17716-comparison.json',runtime='slice17727-runtime8/result.json',commonOriginal38='common17726-candidate38.json',claimsGoalComplete=False)
save(b/'slice17730-integration.json',integration)
archive=r/'scripts/contracts/evidence/source13293/slice17731';archive.mkdir(exist_ok=False)
items=['slice17716-prepare.py','slice17716-comparison.json','slice17716-provider-map.json','slice17716-sources.txt','slice17717-semantic','slice17719-semantic','slice17720-contract.py','slice17720-source8.json','slice17720-emitter.slg','slice17721-source8','canonical17722-stdlib','slice17724-source8/result.json','common17726-candidate38.json','slice17727-reuse.py','slice17727-runtime8','slice17730-integrate.py','slice17730-integration.json','slice17716-candidate']
for item in items:
    source=b/item
    if not source.exists():continue
    target=archive/'records'/item
    if source.is_dir():
        shutil.copytree(source,target,ignore=shutil.ignore_patterns('*.exe','*.dll','*.pdb','*.obj','*.bc','*.ll','.sollang-cache','bin','obj'))
    else:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
shutil.copyfile(b/'slice17724-source8/38-stack-promoted-dynamic-array/run.stdout',archive/'original38-actual-llvm.stdout')
qualification=dict(schemaVersion=1,status='shared-slice-source-ABI-aligned-common38-passed-general-native-pending',observedAtUtc=integration['observedAtUtc'],sourceFiles=len(records),semantic=dict(completed=4,total=4,evidence='records/slice17719-semantic/result.json'),runtime=dict(completed=8,total=8,evidence='records/slice17727-runtime8/result.json'),allocationAudits=dict(completed=4,total=4),original38CommonLlvm=dict(completed=1,total=1,evidence='records/common17726-candidate38.json'),producerBuilds=1,reusedProducerBuilds=0,failedConsumerReason='The first consumer omitted the previously approved original38 S003 diagnostic expectation. Preserve failure and exact approved diagnostic; reuse only the verified built producer and its full input closure.',canonicalIntegration='records/slice17730-integration.json',originalSourcesAndAnswersChanged=False,generalNativeCurrentSource=False,compilerClosedChanged=False,stageRun=False,claimsGoalComplete=False)
save(archive/'qualification.json',qualification)
qualification['limitations']=['Eight cases verify runtime and four allocation audits; only original38 has a new common LLVM assertion result.', 'The existing producer-specific original51 LLVM assertion still describes an anonymous slice. Its acceptance after source alignment is unresolved; keep the assertion unchanged and compare remaining function ABI/naming decisions from source.']
save(archive/'qualification.json',qualification)
goalpath=r/'scripts/contracts/active-goal-progress.json';goal=load(goalpath)
goal['currentSliceCommonAbiQualification']='scripts/contracts/evidence/source13293/slice17731/qualification.json'
goal['currentWork']['focus']='Shared slice ABI aligned with CSharp in14 source files; actual SLG runtime8/8 and allocation4/4, original38 unchanged common LLVM1/1. General Native17599 is historical. Original42 allocator/failure handling and context Error resolution remain unresolved.'
goal['currentWork']['next']='Compare and align original42 allocator/free/failure source paths. Preserve original source and expected LLVM. Original51 runtime passes but its existing producer assertion describes the old anonymous slice; acceptance remains unresolved and needs source comparison, not a new oracle. Resolve context-source name diagnostics before current general Native and final gates.'
goal['previousGoalTurnClassification']='progress: shared slice source ABI and checked planned pointer now pass original38 common assertion and eight runtime controls; no whole-goal promotion'
goal['observedAtUtc']=integration['observedAtUtc']
save(goalpath,goal)
print(json.dumps(dict(integratedFiles=len(records),runtimeCompleted=8,runtimeTotal=8,common38Completed=1,common38Total=1,claimsGoalComplete=False)))
