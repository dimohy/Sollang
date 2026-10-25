from pathlib import Path
import json,datetime,shutil
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';P=R/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505';E=P/'call-stability14067'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rel(p):return p.relative_to(R).as_posix()
now=datetime.datetime.now(datetime.timezone.utc).isoformat();q=load(B/'typed14242-source6/result.json');assert q['status']=='passed' and q['completed']==q['total']==6 and q['inputsStable'] and q['processesStopped']
dst=E/'typed14242-source6';dst.mkdir(exist_ok=True)
for f in (B/'typed14242-source6').iterdir():
    if f.is_file() and f.suffix in ['.json','.txt','.stdout','.stderr']:shutil.copyfile(f,dst/f.name)
path=E/'source100-progress14252.json';save(path,dict(schemaVersion=1,status='partial-current-source-six-passed-remainder94-running',observedAtUtc=now,completed=6,total=100,percentage=6.0,source6Evidence=rel(dst/'result.json'),remaining94=rel(B/'typed14250-source94/result.json'),sourceInputsAndOraclesUnchanged=True,caseMaximumSeconds=180,retryCount=0,claimsNativePassed=False,claimsGoalComplete=False))
running=load(B/'typed14250-source94/result.json');assert running['status'] in ['running','passed']
active=[dict(kind='unchanged-source94',result=rel(B/'typed14250-source94/result.json'),execSession=26906,status=running['status'],observedPassedCases=running['completed'],total=94)]
d=load(R/'scripts/contracts/active-goal-progress.json');c=load(P/'checkpoint14249.json')
d.update(currentSourceRefresh100=rel(path),currentActiveVerification=active,currentCheckpoint=rel(P/'checkpoint14252.json'))
d['currentCallStabilityCandidate']['source100Completed']=6;d['currentCallStabilityCandidate']['currentStage']='Canonical semantic4, stdlib144, golden6, CSharp original3, CSharp Result12, source6 and exchange1 passed; unchanged remaining94 active.'
c.update(status='source6-passed-unchanged94-active',observedAtUtc=now,previousCheckpoint=rel(P/'checkpoint14249.json'),activeExecutions=active,currentStage=d['currentCallStabilityCandidate']['currentStage'])
for key in ['sourceRefresh','currentSource100']:c[key]=dict(completed=6,total=100,percentage=6.0,evidence=rel(path))
c['nextVerification']='Wait for existing source94 session26906; do not restart. At terminal100/100 extract positive68 and exchange positive1 via existing extractor. Apply accepted retirement14248 for14010 through canonical closure and cleanup; retain12432+14112, create at most one new Native product. Reuse old managed proofs only after checking every pin; replace old semantic/golden/Result12 prerequisites with14237/14241/14246. O2/jobs4/build600, then exact1255/1264/1290 each180s and C613/native stability. Final original14/source7/runtime2708 and Stage2/3 remain pending.'
c['failureClassifications']=['historical-original1290-native180s-timeout-unresolved','historical-native-stability-compile180s-timeout','new-canonical-source94-unverified-running','retirement14247-multicase-adapter-rejected-preserved-and-authenticated-by14248-no-policy-change']
d['nextAction']=c['nextVerification'];save(P/'checkpoint14252.json',c);save(R/'scripts/contracts/active-goal-progress.json',d)
shutil.copyfile(B/'checkpoint14252.py',E/'checkpoint14252.py')
print(json.dumps(dict(checkpoint=d['currentCheckpoint'],sourceQualified='6/100',active=active)))
