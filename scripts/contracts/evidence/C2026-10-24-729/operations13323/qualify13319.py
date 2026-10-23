from pathlib import Path
import datetime,json
root=Path.cwd()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
e='scripts/contracts/evidence/'
units={
 'C2026-10-24-728':dict(id='readonly-array-element-value-category',total=6),
 'C2026-10-24-729':dict(id='signed-each-interpolation-type-authority',total=5)}
p=root/'scripts/contracts/compiler-defects.json'
d=read(p)
for defect in d['defects']:
    if defect['id'] not in units:continue
    uid=defect['id']
    q=e+uid+'/qualification13317.json'
    qualification=read(root/q)
    assert qualification['completed']==qualification['total']==units[uid]['total']
    assert defect['state']=='open'
    defect.update(state='candidate-fixed',focusedQualification=q,remaining='Focused implementation and actual current O2 Native qualification complete; original final source/runtime/Stage/platform closure remains pending.')
    defect['shapingEvidence'].update(tracePath=e+uid+'/as-us-001.json',candidateReceipt=e+uid+'/candidate.json')
save(p,d)
p=root/'scripts/contracts/active-goal-progress.json'
d=read(p)
for uid,unit in units.items():
    old=next(x for x in d['queuedUnits'] if x['id']==unit['id'])
    d['queuedUnits'].remove(old)
    q=e+uid+'/qualification13317.json'
    steps=[dict(id=stage,status='complete',evidence=q) for stage in ['managed-first','source-comparison','canonical-source-focused','current-native-build','current-paired-focused']]
    d['completedUnits'].append(dict(id=unit['id'],status='complete',title=old['title'],defectId=uid,focusedComplete=unit['total'],focusedTotal=unit['total'],stepsComplete=5,stepsTotal=5,steps=steps,evidence=q,completionScope='Focused implementation unit only; defect candidate-fixed and all original final acceptance remains pending.',previousQueueState=old))
for gate in d['focusedGates']:
    if gate['name'] in ['C728-canonical-original-and-reference-category6','C728-C729-canonical-original-and-guard10']:
        gate.update(status='complete',completed=gate['total'],evidence=e+'C2026-10-24-728/qualification13317.json' if gate['total']==6 else e+'C2026-10-24-729/current-source13308/native-pair10-projection13319.json',scope='Current O2 Native exact original contracts; focused implementation only, final gates pending.')
d['focusedGates'].append(dict(name='C729-general-function-integer-display1',status='complete',completed=1,total=1,evidence=e+'C2026-10-24-729/current-native13317/function1/result.json',scope='Signed Int32 minimum and UInt32 maximum through general-function console interpolation.'))
for step in d['currentWork']['steps']:
    if step['id'] in ['selfhost-build','paired-focused']:
        step.update(status='complete',evidence=e+'C2026-10-24-729/qualification13317.json')
for case in d['currentWork']['focusedCases']:
    case.update(status='complete',evidence=e+'C2026-10-24-729/current-source13308/native-pair10-projection13319.json')
d['currentWork'].update(focus='C728 CSharp6/Native6 and C729 CSharp5/Native5 passed under fresh O2 34AB. Both focused implementation units qualified; parent/final gates remain.',next='Resolve remaining phase-exhaustive source decisions/current proof references and historical evidence accounting, then fixed-source original14/source7/runtime2708, Stage2/Stage3 and stdlib/platform/performance.',activeExecutions=[],currentNativeProduct='artifacts/scratch/resume-20261006-owner-continuation22/v13312/compiler-build01/compiler.exe',currentNativeProductState='Built stable O2 and focused11 passed; final original/phase/runtime/Stage acceptance pending.',observedAtUtc=now,lastSourceFocus=dict(status='passed',completed=10,total=10,runtimeCompleted=7,runtimeTotal=7,evidence=e+'C2026-10-24-729/current-source13308/canonical-source10/result.json'))
assert len(d['completedUnits'])==137 and len(d['queuedUnits'])==3
save(p,d)
records=[]
for uid,unit in units.items():
    q=read(root/(e+uid+'/qualification13317.json'))
    records.extend(x for x in q['nativeRecords'] if not x['reference'].endswith('/function1/result.json'))
assert sum(x['completed'] for x in records)==sum(x['total'] for x in records)==10
save(root/(e+'C2026-10-24-729/current-source13308/native-pair10-projection13319.json'),dict(schemaVersion=1,status='passed',recordType='disjoint-native-proof-summary',completed=10,total=10,percentage=100.0,inputsStable=True,processesStopped=True,records=records,compilerSha256='34AB2672AF54170BB3F586835F20D4AF3E7576B4E1054F9FD797C0D59309A45E',scope='Exact selected gate10 from original separate contracts; additional general-function1 is a separate gate. No new combined run or contract substitution.',compiledAsOneRun=False,claimsGoalComplete=False))
p=root/'scripts/contracts/structural-parity-detail.json'
d=read(p)
def update(x):
    if isinstance(x,dict):
        uid=x.get('defectId')
        if uid in units and x.get('id','').endswith(('array-literal-named-read-category-admission','interpolation-committed-integer-display-type')):
            x.update(status='complete',focusedQualification=e+uid+'/qualification13317.json',currentSlgSourceRuntimeRecord=e+'C2026-10-24-729/current-source13308/canonical-source10/result.json',pairedRecord=e+uid+('/current-native13317/array4/result.json' if uid.endswith('728') else '/current-native13317/signed3/result.json'),additionalPairedRecords=[e+uid+('/current-native13317/boundary2/result.json' if uid.endswith('728') else '/current-native13317/unsigned1/result.json')],completionScope='Focused authority decision under current source/product only; phase-exhaustive source7 and original final gates remain pending.')
            if uid.endswith('729'):x['additionalPairedRecords'].append(e+uid+'/current-native13317/function1/result.json')
            x['diagnostics']='Current exact CSharp/Native pairs passed with original warning/output oracles; semantic negatives retain exact diagnostic rejection. No phase/final closure credit.'
        for v in x.values():update(v)
    elif isinstance(x,list):
        for v in x:update(v)
update(d)
save(p,d)
print('C728/C729 -> candidate-fixed; focused implementation units137/140, final acceptance unchanged.')
