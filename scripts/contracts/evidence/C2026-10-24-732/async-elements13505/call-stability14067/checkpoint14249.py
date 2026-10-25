from pathlib import Path
import json,datetime,shutil
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';P=R/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505';E=P/'call-stability14067'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rel(p):return p.relative_to(R).as_posix()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
for name in ['call14237-semantic','call14238-stdlib','call14241-managed1','call14243-preflight3','call14244-managed3','exchange14245-source1','result14246-managed12','retirement14247-proposal','retirement14248-observation']:
    src=B/name;dst=E/name;dst.mkdir(exist_ok=True)
    for f in src.iterdir():
        if f.is_file() and f.suffix in ['.json','.txt','.stdout','.stderr','.log']:shutil.copyfile(f,dst/f.name)
for name in ['contracts14240.py','retirement14247-propose.py','retirement14248-observe.py','checkpoint14249.py']:shutil.copyfile(B/name,E/name)
d=load(R/'scripts/contracts/active-goal-progress.json');c=load(P/'checkpoint14239.json')
active=[]
for name,session,kind in [('typed14242-source6',76704,'unchanged-source6')]:
    q=load(B/name/'result.json');active.append(dict(kind=kind,result=rel(B/name/'result.json'),execSession=session,status=q['status'],observedPassedCases=q['completed'],total=q['total']))
for key,name,n in [('currentCSharpSemantic','call14237-semantic',4),('currentStdlibSource','call14238-stdlib',1),('currentCallStability','call14241-managed1',1)]:
    q=load(B/name/'result.json');assert q['status']=='passed' and q['completed']==q['total']==n and q['inputsStable'] and q['processesStopped']
    c[key]=dict(completed=n,total=n,evidence=rel(E/name/'result.json'))
q=load(B/'exchange14245-source1/result.json');assert q['status']=='passed' and q['completed']==q['total']==1
path=E/'exchange1-qualification14249.json';save(path,dict(schemaVersion=1,status='passed',observedAtUtc=now,completed=1,total=1,evidence=rel(E/'exchange14245-source1/result.json'),inputsStable=True,processesStopped=True,claimsGoalComplete=False))
d['currentExchangeSourceRefresh']=rel(path);c['sourceExchange']=dict(completed=1,total=1,evidence=rel(path))
d['currentCallStabilityCandidate'].update(sourceComparison=rel(E/'recovery-source-comparison14236.json'),managedSemanticProof=rel(E/'call14237-semantic/result.json'),managedSemanticCompleted=4,managedSemanticTotal=4,focusedProofStatus='passed-current-recovery-csharp-golden',managedFocusedCompleted=1,managedFocusedTotal=1,stdlibSourceCompleted=1,stdlibSourceTotal=1,exchangeSourceCompleted=1,managedC613Proof=rel(E/'result14246-managed12/result.json'),managedC613Completed=12,managedOriginal3Qualification=rel(E/'call14244-managed3/result.json'),managedOriginal3Completed=3,source100Completed=0,nativeOriginal3Completed=0,original1290Status='pending-current-source-native-rebuild',nativeFocusedStabilityStatus='pending-current-source-native-rebuild',registeredDecisionsQualified=43,currentStage='Recovery source epoch: semantic4+stdlib144+golden6+CSharp original3+Result12+exchange1 passed; original source100 active before fresh Native.')
for k in ['qualification','nativeBuildQualification','nativeOriginal3Qualification','nativeFocusedStabilityQualification','nativeC613Qualification','source100Qualification']:d['currentCallStabilityCandidate'].pop(k,None)
d['currentReceiverFieldIndexCandidate'].update(status='scratch-equivalent-held-not-promoted-extra-cost-reduction-too-small',comparisonEvidence=rel(E/'call14225-paired-source/result.json'),productionChanged=False)
d['currentReceiverRecoveryCandidate'].update(status='promoted-canonical-semantic-stdlib-golden-passed-source100-running',semanticEvidence=rel(E/'call14237-semantic/result.json'),stdlibEvidence=rel(E/'call14238-stdlib/result.json'),goldenEvidence=rel(E/'call14241-managed1/result.json'))
d['currentNativeRetirementProposal']=rel(E/'retirement14248-observation/proposed-consumer-closure.json')
d['currentActiveVerification']=active;d['currentCheckpoint']=rel(P/'checkpoint14249.json')
c.update(status='recovery-prerequisites-passed-original-source100-requalification-active',observedAtUtc=now,previousCheckpoint=rel(P/'checkpoint14239.json'),activeExecutions=active,currentStage=d['currentCallStabilityCandidate']['currentStage'],nextVerification=d['nextAction'])
c['currentManagedOriginal3']=dict(completed=3,total=3,evidence=rel(E/'call14244-managed3/result.json'));c['currentManagedC613']=dict(completed=12,total=12,evidence=rel(E/'result14246-managed12/result.json'))
c['nativeRetirementProposal']=dict(validated=True,executed=False,consumers=4,evidence=d['currentNativeRetirementProposal'],originalTestsAdded=0)
save(P/'checkpoint14249.json',c);save(R/'scripts/contracts/active-goal-progress.json',d)
print(json.dumps(dict(checkpoint=d['currentCheckpoint'],active=active)))
