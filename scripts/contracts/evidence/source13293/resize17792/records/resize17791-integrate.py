from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,shutil
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def load(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def save(p,d):Path(p).write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
runtime=load(b/'resize17786-source4/result.json');fault=load(b/'resize17790-failure-pair/result.json')
for proof in (runtime,fault):
    assert proof['status']=='passed' and proof['completed']==proof['total']==4
    assert proof['inputsStable'] and proof['processesStopped']
assert len(fault['controls'])==35 and all(x['passed'] for x in fault['controls'])
common=load(b/'common17789-resize42.json');assert common['status']=='passed' and common['completed']==common['total']==1
providers=load(b/'resize17781-provider-map.json');before=load(b/'resize17781-comparison.json')['canonicalSourceHashes'];changes=[]
for canonical,candidate in providers.items():
    assert sha(r/canonical)==before[canonical]
    assert runtime['inputHashes'][str(r/candidate)]==sha(r/candidate)
    changes.append(dict(path=canonical,before=sha(r/canonical),after=sha(r/candidate),qualifiedSource=candidate))
archive=r/'scripts/contracts/evidence/source13293/resize17792';archive.mkdir(exist_ok=False)
items=['resize17780-loop-control.slg','resize17780-managed1.json','resize17780-managed1','resize17781-prepare.py','resize17781-comparison.json','resize17781-candidate','resize17781-provider-map.json','resize17781-sources.txt','resize17782-semantic','canonical17783-stdlib','resize17785-contracts.py','resize17785-managed-materialize1.json','resize17785-managed-materialize1','resize17785-source4.json','resize17785-emitter.slg','resize17786-source4','resize17787-freeze.py','resize17787-failure-contract.json','resize17787-failure-pair.py','resize17787-failure-pair.before17790.py','verification_llvm_allocation.before17790.py','resize17788-failure-pair','common17789-resize42.json','resize17790-failure-pair','resize17791-integrate.py']
for name in items:
    source=b/name;target=archive/'records'/name
    if source.is_dir():
        shutil.copytree(source,target,ignore=shutil.ignore_patterns('*.exe','*.dll','*.pdb','*.bc','*.ll','*.obj','.sollang-cache','bin','obj'))
    else:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
shutil.copyfile(r/'scripts/verification_llvm_allocation.py',archive/'verification_llvm_allocation.py')
for row in changes:
    shutil.copyfile(r/row['qualifiedSource'],r/row['path']);assert sha(r/row['path'])==row['after']
observed=datetime.now(timezone.utc).isoformat()
integration=dict(schemaVersion=1,status='canonical-reserve-materialize-failure-guards-integrated',observedAtUtc=observed,files=changes,phiPredecessorsUpdated=4,originalSourcesAndAnswersChanged=False,claimsGoalComplete=False)
save(b/'resize17791-integration.json',integration);save(archive/'integration.json',integration)
qualification=dict(schemaVersion=1,status='focused-resize-failure-decisions-verified-general-native-pending',observedAtUtc=observed,decisionUnits=dict(completed=2,total=2,units=['reserve','materialize']),sourceFiles=2,runtime=dict(completed=4,total=4,evidence='records/resize17786-source4/result.json'),allocationAudits=dict(completed=2,total=2,allocationsAndReleases=[2,1]),failureInjection=dict(completed=4,total=4,evidence='records/resize17790-failure-pair/result.json',scope='Managed and SLG grow paths trap before publication. Each diagnostic is bound to its actual source-function/failure block; generated identifier byte equality is not claimed.'),controls=dict(completed=35,total=35,previousMissingGuardRejectedBeforeLink=True,unrelatedFunctionCannotSupplyFailureBlock=True),constantApiCompatibility=2,original42CommonLlvm=dict(completed=1,total=1,evidence='records/common17789-resize42.json'),priorMemoryQualification='scripts/contracts/evidence/source13293/allocation17777/qualification.json',specification='docs/SPEC.md',compilerClosedChanged=False,implementationUnitsChanged=False,generalNativeBuilt=False,stageRun=False,original42WholeScope=dict(completed=0,total=1,reason='Previously recorded exact generated diagnostic identifier mismatch remains separate.'),remaining=['Original51 existing Native LLVM assertion is preserved and still requires source investigation.', 'Context-source Error binding failure, current general Native, full source/final comparison and Stage remain pending.', 'Linux/browser runtime execution is unverified; focused checks here are Windows.'],claimsGoalComplete=False)
save(archive/'qualification.json',qualification)
path=r/'scripts/contracts/active-goal-progress.json';goal=load(path)
ref='scripts/contracts/evidence/source13293/resize17792/qualification.json'
goal['currentResizeAllocationGuardQualification']=ref;goal['currentCanonicalMemoryAlignmentQualification']=ref;goal['currentRawMemoryFamilyCandidate']=ref
goal['currentWork']['focus']='Shared literal/reserve/materialize null guard integrated with four corrected phi predecessors. Decision units2/2, actual SLG runtime4/4, audits2/2, paired fault injection4/4 and controls35/35. Original42 unchanged common LLVM1/1; exact generated diagnostic identity remains separately unresolved. No compiler/Stage promotion.'
goal['currentWork']['next']='Inspect original51 fixed-value versus readonly-view ABI boundaries and the e951 source regression while preserving the pre-baseline Native assertions. Keep source/answers unchanged. Context Error binding and general Native/final gates remain pending.'
goal['previousGoalTurnClassification']='progress: canonical reserve/materialize guards implemented and verified with real null-result injection; verifier function-local block binding corrected with a negative control'
goal['observedAtUtc']=observed;save(path,goal)
print(json.dumps(dict(decisionsCompleted=2,decisionsTotal=2,runtime=4,faults=4,controls=35,canonicalFiles=2,claimsGoalComplete=False)))
