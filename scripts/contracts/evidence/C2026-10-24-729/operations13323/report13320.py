from pathlib import Path
from collections import Counter
import copy,datetime,hashlib,json
root=Path.cwd()
e=root/'scripts/contracts/evidence/C2026-10-24-729'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report=copy.deepcopy(read(root/'scripts/contracts/evidence/C2026-10-24-728/progress-report13281.json')['report'])
states=dict(Counter(x['state'] for x in read(root/'scripts/contracts/compiler-defects.json')['defects']))
assert states=={'closed':363,'candidate-fixed':361,'open':1},states
axes={x['id']:x for x in report['axes']}
def set_axis(id,done,total,evidence,reason=None):
    a=axes.get(id,dict(id=id))
    a.update(completed=done,total=total,percentage=round(done/total*100,2) if total else None,evidenceReference=evidence,evidenceState='confirmed' if total else 'unverified',authoritativeCompleted=done,authoritativeTotal=total)
    if reason:a['evidenceReason']=reason
    axes[id]=a
set_axis('compiler',363,725,'scripts/contracts/compiler-defects.json','363 closed;361 candidate-fixed;1 open parent C385. Focused candidates are not final closure.')
set_axis('sourceReview',211,211,'scripts/contracts/evidence/source13293/current-physical-source-review13307.json','207 unchanged previously reviewed files plus4 complete authored delta reviews; not source7 phase closure.')
set_axis('nativeWhole',402,405,'scripts/contracts/evidence/progress13282/terminal-native405/native-current-batch-results.json','Terminal prior source epoch:402 passed,3 failed. Not current edited-source/final whole acceptance; parent whole gate failed.')
set_axis('nativeWitness',0,22,'scripts/contracts/evidence/progress13282/terminal-native405/native-controller.execution.json','Not executed because prior Native whole405 failed; no witness credit.')
set_axis('arrayReadNative',4,4,'scripts/contracts/evidence/C2026-10-24-728/current-native13317/array4/result.json')
set_axis('arrayReadBoundaryNative',2,2,'scripts/contracts/evidence/C2026-10-24-728/current-native13317/boundary2/result.json')
for id,done,total,path in [
 ('c434Managed',6,6,'scripts/contracts/evidence/c434-original13286/qualification13286.json'),
 ('c434Native',6,6,'scripts/contracts/evidence/c434-original13286/qualification13286.json'),
 ('integerManaged',5,5,'scripts/contracts/evidence/C2026-10-24-729/qualification13317.json'),
 ('integerNative',5,5,'scripts/contracts/evidence/C2026-10-24-729/qualification13317.json'),
 ('canonicalSource',10,10,'scripts/contracts/evidence/C2026-10-24-729/current-source13308/canonical-source10/result.json'),
 ('canonicalRuntime',7,7,'scripts/contracts/evidence/C2026-10-24-729/current-source13308/canonical-source10/result.json')]:set_axis(id,done,total,path)
report['axes']=list(axes.values())
report['declaredAxes']=[x['id'] for x in report['axes']]
groups=report['presentationGroups']
groups[0].update(completed=363,total=725,percentage=round(363/725*100,2),remainingWork='candidate361; open1 parent C385; focused implementation units137/140. Final closure pending.')
groups[1].update(completed=None,total=None,percentage=None,remainingWork='Physical review211/211 and historical evidence26/28 are separate units; no combined rate. Phase source final0/7.')
groups[2].update(completed=None,total=None,percentage=None,remainingWork='Retained units59/59 and dynamic families42/42 are separate historical proof scopes; no current-product or whole-goal credit.')
groups[3]['axisIds']+=['c434Managed','c434Native','integerManaged','integerNative','canonicalSource','canonicalRuntime']
pool=[axes[id] for id in groups[3]['axisIds']]
done=sum(x['completed'] for x in pool)
total=sum(x['total'] for x in pool)
assert (done,total)==(1026,1051),(done,total)
groups[3].update(completed=done,total=total,percentage=round(done/total*100,2),remainingWork='Case-execution evidence across explicitly different epochs, not fixed-source final acceptance. Current CSharp11/Native11, canonical source10/runtime7 passed. Prior whole402/405 failed3; Native witness22 not run.')
report.update(event='progress',failureClassifications=[
 'Current focused11: no failures; both actual original1471/1712/1713 defects repaired in focused current product34AB.',
 'Historical failed Native whole405 retained:402 passed,3 failed; no Native witness22 execution. Focused repair does not promote it to a current whole pass.',
 'Resolved adapter failures retained: first canonical source attempt used entry-only consumer; diagnostic instrument yielded no entry comments; shared helper source initially needed canonical formatting.',
 'Unresolved: C385 phase-exhaustive/final closure, C588/C591 historical evidence and stale retired6808 references in current full project verifier.',
 'Unverified: C434 current memory audit, final original14/source7/runtime2708/Stage2/Stage3/stdlib22/platform/performance.',
 'Slogs grouped-policy versus evaluator contract mismatch remains; no policy change or validation-success claim.'
],currentStage='Current canonical source10/runtime7 and fresh O2 Native focused11 qualified; C728/C729 candidate-fixed. Remaining phase source/history accounting and fixed-source final acceptance.',nextVerification='Verify remaining phase-exhaustive source decisions/current proof references, then fixed-source original14/source7/runtime2708 and Windows Stage2/Stage3; retain all original limits and oracles.',claimsGoalComplete=False,requestedScope='long-goal-report',actualPolicyAuthority='slogs-llm-wiki',claimsPolicyChangeComplete=False,policyEvidenceReference='scripts/contracts/evidence/progress13282/slogs-contract-observation13287.json')
text='''(이해도 99%) 배열 값 읽기와 정수 보간 수정을 새 O2 컴파일러에서 검증했습니다. C#/Native 각각 11/11, 실제 SLG 소스 검사10/10·실행7/7이 통과했습니다. 원래 출력과 경고를 유지했으며 두 결함은 후보 수정 상태입니다.

| 목표축 | 확인한 진행률 | 남은 범위 |
|---|---|---|
| 컴파일러 | 최종 종료363/725 · 50.07%; 집중 구현137/140 · 97.86% | 후보361건, 열림1건(C385); 후보는 최종 종료가 아님 |
| 소스·이력 | 물리적 검토211/211 · 100.00%; 과거 근거26/28 · 92.86% | 단계별 소스 최종 검증0/7 |
| 보존 근거 | 수정 단위59/59 · 100.00%; 대표군42/42 · 100.00% | 과거 제품·입력별 근거이며 최신 전체 통과를 뜻하지 않음 |
| 실행 검증 근거 | 시점별 사례1026/1051 · 97.62% | 현재 Native11/11 통과; 이전 전체405는402 통과·3 실패, Native 추가22건은 미실행 |
| 최종 검증 | 원본0/14·소스0/7·실행0/2708·Stage0/2 각각0.00%; stdlib/runtime6/22 · 27.27% | 플랫폼·성능과 목표 전체 진행률은 분모 미확인 |

현재 집중 검증의 실패는 없습니다. 이전 전체 실패 기록은 보존했고, C385 단계별 소스 검증·과거 근거2건·전체 검증기의 오래된 제품 참조는 미해결입니다. 현재 단계는 두 수정의 집중 검증 완료이며, 다음은 남은 소스·근거 정리와 고정 소스 전체 검증을 거쳐 Stage2/3에 진입하는 것입니다. Slogs 보고 자동 검증은 계약 불일치로 아직 통과하지 못했습니다.'''
report['renderedReportText']=text
snapshot=dict(schemaVersion=1,observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),goalStatus='active',goalComplete=False,compilerStates=states,implementationUnits=dict(completed=137,total=140,percentage=round(137/140*100,2),scope='Focused implementation units;3 remaining current-cohort/final requalification units.'),axes=copy.deepcopy(report['axes']),caseExecutionEvidence=dict(completed=done,total=total,percentage=round(done/total*100,2),scope='Different recorded execution epochs; not overall goal or current final acceptance.'),currentCompilerSha256='34AB2672AF54170BB3F586835F20D4AF3E7576B4E1054F9FD797C0D59309A45E',finalOriginal=[0,14,0.0],finalSource=[0,7,0.0],finalRuntime=[0,2708,0.0],stage=[0,2,0.0],stdlibRuntime=[6,22,27.27],overall=None,failures=report['failureClassifications'],currentStage=report['currentStage'],nextVerification=report['nextVerification'],reportValidation=dict(accepted=False,reason='Pending current tool invocation; prior contract mismatch retained.'))
save(e/'checkpoint13320.json',snapshot)
assert len(report['axes'])==43
for a in report['axes']:
    if a['total'] is not None:assert a['percentage']==round(a['completed']/a['total']*100,2)
save(e/'progress-report13320.json',dict(report=report,localContractArithmetic='passed43 axes; does not imply Slogs validator acceptance'))
(e/'progress-report13320.txt').write_text(text+'\n',encoding='utf-8')
print(json.dumps(dict(axes=len(report['axes']),compilerStates=states,caseEvidence=[done,total,round(done/total*100,2)],goalComplete=False)))
