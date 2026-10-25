from pathlib import Path
import json, hashlib, shutil, datetime
R=Path.cwd(); B=R/'artifacts/scratch/resume-20261006-owner-continuation22'
P=R/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505'; E=P/'call-stability14067'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):
    p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rel(p): return p.relative_to(R).as_posix()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
source=R/'selfhost/semantic/call_resolution_sources.slg'; candidate=B/'receiver-recovery14230/candidate.slg'
assert sha(source)=='27B66B758454BA28B23B3785013F146C4B633ED40CC5308EB71946415C1018ED'
for name in ['call14225-paired-source','call14232-semantic','call14233-reference-semantic','call14234-managed1','call14235-paired-source']:
    q=read(B/name/'result.json'); assert q['status']=='passed' and q['completed']==q['total'],name
    out=E/name; out.mkdir(exist_ok=True)
    for p in (B/name).iterdir():
        if p.is_file() and p.suffix in ['.json','.txt','.stdout','.stderr']: shutil.copyfile(p,out/p.name)
out=E/'receiver-recovery14230'; shutil.copytree(B/'receiver-recovery14230',out,dirs_exist_ok=True)
comparison=read(out/'source-comparison.json')
assert comparison['csharpSha256']==sha(R/comparison['csharpSource'])
comparison.update(status='compared-before-slg-edit',observedAtUtc=now,productionChanged=False,
                  chosenRoute='reuse-existing-preparation-and-source-local-immutable-index',
                  pairedEvidence=rel(E/'call14235-paired-source/result.json'))
save(E/'recovery-source-comparison14236.json',comparison)
pre=E/'before-recovery14236'; pre.mkdir(exist_ok=False)
shutil.copyfile(source,pre/'call_resolution_sources.slg')
probe=R/'scripts/probes/module-identity/method-reference-index.slg'; shutil.copyfile(probe,pre/'method-reference-index.slg')
root=R/'scripts/contracts/active-goal-progress.json'; d=read(root); save(pre/'active-goal-progress.json',d)
parity=R/'scripts/contracts/structural-parity-detail.json'; detail=read(parity); save(pre/'structural-parity-detail.json',detail)
invalid=[]
def visit(x):
    if isinstance(x,dict):
        if x.get('status')=='complete' and rel(source) in x.get('selfhostSources',[]):
            invalid.append(x['id']); x['previousQualificationBefore14236']={k:x[k] for k in ['status','currentFocusedQualification'] if k in x}
            x.update(status='pending',currentSourceEpochInvalidation=rel(E/'epoch-invalidation14236.json'))
        for v in list(x.values()): visit(v)
    elif isinstance(x,list):
        for v in x: visit(v)
visit(detail)
assert invalid==['semantic-analysis.prepared-method-candidate-row-index'],invalid
shutil.copyfile(candidate,source); shutil.copyfile(B/'receiver-recovery14230/method-reference-index.slg',probe)
save(parity,detail)
save(E/'epoch-invalidation14236.json',dict(schemaVersion=1,observedAtUtc=now,source=rel(source),beforeSha256=comparison['slgBeforeSha256'],afterSha256=sha(source),decisionsInvalidated=invalid,registeredComplete=43,registeredTotal=91,previousEvidencePreserved=True,source100CurrentCompleted=0,source100Total=100,claimsGoalComplete=False))
keys=['currentSourceRefresh100','currentExchangeSourceRefresh','currentReturnedMatchNative3','currentCandidateC613NativeProgress','currentResultPropagationOwnerEvidence','currentNativeCandidateBuild','currentNativeBuildQualification','currentSourceDecisionRequalification','currentCallStabilityCandidate']
d['previousSourceEpochBeforeRecovery14236']={k:d[k] for k in keys if k in d}
for key,total,name in [('currentSourceRefresh100',100,'source100'),('currentExchangeSourceRefresh',1,'exchange1')]:
    path=E/f'{name}-pending14236.json';save(path,dict(schemaVersion=1,status='pending-current-source-revalidation',completed=0,total=total,observedAtUtc=now,sourceSha256=sha(source),previousEvidence=d.get(key),claimsGoalComplete=False));d[key]=rel(path)
d['currentSourceDecisionRequalification'].update(registeredQualified=43,status='recovery-source-epoch-refresh-pending',sourceEpochInvalidation=rel(E/'epoch-invalidation14236.json'))
d['currentNativeCandidateBuild'].update(sourceInputsCurrent=False,nativeRegressionQualified=False)
d['currentNativeCandidateSourceDrift']=dict(source=rel(source),beforeSha256=comparison['slgBeforeSha256'],afterSha256=sha(source),nativeRebuildRequired=True,currentNativeSourceQualified=False)
d['currentCandidateC613NativeProgress']=dict(completed=0,total=12,evidenceState='pending-current-source',previousEvidence=d.get('currentResultPropagationOwnerEvidence'))
d['currentActiveVerification']=[]
d['currentReceiverRecoveryCandidate']=dict(status='promoted-focused-prototype-passed-canonical-revalidation-pending',sourceComparison=rel(E/'recovery-source-comparison14236.json'),sourceSha256=sha(source),prototypeSemanticCompleted=4,prototypeSemanticTotal=4,prototypeGoldenCompleted=1,prototypeGoldenTotal=1,comparisonCalls=39521,comparisonFields=276647,comparisonEvidence=rel(E/'call14235-paired-source/result.json'),baselineMilliseconds=22149,candidateMilliseconds=15195,productionChanged=True,claimsOriginal1290Passed=False,claimsGoalComplete=False)
d['nextAction']='Revalidate canonical semantic4 and stdlib144, frozen call-context golden6, unchanged source100/exchange1; retire a Native product through complete consumer closure; build current Native and run exact original3 with each case180s. Stage2/3 remain pending.'
d['currentCheckpoint']=rel(P/'checkpoint14236.json')
c=read(P/'checkpoint14224.json');c.update(status='receiver-recovery-promoted-canonical-revalidation-pending',observedAtUtc=now,previousCheckpoint=rel(P/'checkpoint14224.json'),activeExecutions=[])
for k,t in [('sourceRefresh',100),('currentSource100',100),('sourceExchange',1),('currentCSharpSemantic',4),('currentStdlibSource',1),('currentCallStability',1),('candidateNative3',3),('candidateC613NativeProgress',12)]:
    c[k]=dict(completed=0,total=t,status='pending-current-source-revalidation')
c['previousNativeOriginal3']=read(E/'original-native3-qualification14135.json')
c['registeredDecisionQualification']=dict(completed=43,total=91)
c['currentNamedDecisionQualification']=dict(completed=43,total=91,evidence=rel(E/'epoch-invalidation14236.json'))
c['currentReceiverRecoveryCandidate']=d['currentReceiverRecoveryCandidate']
c['currentStage']='Canonical current-source semantic and stdlib preflight before original source100 and Native rebuild'
c['nextVerification']=d['nextAction']
save(P/'checkpoint14236.json',c);save(root,d)
print(json.dumps(dict(sourceSha256=sha(source),invalidated=invalid,checkpoint=d['currentCheckpoint'])))
