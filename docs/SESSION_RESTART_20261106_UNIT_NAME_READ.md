# Sollang 재시작 안내 — 2026-11-06 / Unit 이름 읽기 수정 이후

작업 경로는 `W:\MyWorks\Sollang`, 브랜치는 `v0.5`이다.
사용자가 다른 세션에서 재개하기 위해 기록 후 중지를 요청했다. 목표는 **paused**, 미완료이다.
이 문서가 `SESSION_RESTART_20261105_UNIT_INPUT.md`와 이전 인계 항목보다 우선한다.
사용자가 재개를 요청할 때까지 구현·빌드·테스트를 시작하지 않는다.
인계 문서는 로컬에 저장했으며 미커밋 상태이다.

## 재개 순서

1. Slogs `llm_wiki_instructions`를 확인하고 프로젝트 결정과 사용자 전체 한국어 용어·보고 선호를 별도로 검색한 뒤 적용할 항목을 읽는다.
2. `AGENTS.md`, `docs/AI_SLG_BEST_PRACTICES.md`, 이 문서와 `docs/SESSION_HANDOFF.md`의 최신 항목을 읽는다.
3. `B/session-handoff28886.json`, 현재 Git·프로세스·소스 해시와 실제 결과를 확인한다. 아래 기록은 새 세션의 현재 상태를 대신하지 않는다.
4. 기존 전체 목표를 새 세션의 목표로 등록하고 이어간다. 개별 수정이나 정책 개선을 전체 완료로 처리하지 않는다.

`B = artifacts/scratch/resume-20261006-owner-continuation22`이다.
마지막 로컬·원격 HEAD는 `f2d02a01a4bef0d98ec0341917def56333821dac`로 일치했다.

## 현재 수치

| 작업 | 완료/전체 | 진행률 |
| --- | ---: | ---: |
| 컴파일러 안정화 | 363/854 | 42.51% |
| Unit 이름 읽기 집중 대조 | 14/14 | 100.00% |
| Task<Unit> 별도 검사 | 2/2 | 100.00% |
| 병렬 인자 Wasm 대조 | 12/12 | 100.00% |
| 브라우저 쓰기 반환 대조 | 8/8 | 100.00% |
| 정적 계약 오류 정리 | 45/45 | 100.00% |
| 파일 전체 검토 | 100/116 | 86.21% |
| 소스 결정 연결 | 734/734 | 100.00% |
| 원본 검증 | 0/14 | 0.00% |
| 소스 단계 검증 | 0/7 | 0.00% |
| 런타임 전체 대조 | 0/2708 | 0.00% |
| Stage2/Stage3 | 0/2 | 0.00% |
| 동결 stdlib/runtime | 6/22 | 27.27% |
| Slogs 정책·MCP 개선 | 4/4 | 100.00% |

안정화 수정 후보는 489건, 미해결은 2건이다. 후보를 완료로 올리지 않는다.
플랫폼·성능 검증은 전체 건수가 정해지지 않아 진행률과 총 진행률을 계산하지 않는다.
파일 전체를 읽은 수치와 소스 단계 검증은 별개이다. 단계별 전체 검증은 아직 0/7이다.

## 완료한 수정과 근거

- 초기 Unit 인자의 미정의 `%v2` 문제는 `ffc636575`에서 해결했다. 이전 중단 문서의 실패를 현재 미해결 문제로 다시 시작하지 않는다.
- 사용자 승인에 따른 EmitContext 필드 보완과 C853/C854는 `d41d833`에서 반영했다. 보호 대상 원본과 기존 기대값은 보존했다.
- 병렬 추가 인자 준비 C855와 Wasm 쓰기 상태 C856은 `6bf5cab19`에서 반영했다. Windows 16건, 병렬 Wasm 12건, 쓰기 상태 8건을 확인했다. 근거는 `scripts/contracts/evidence/source13293/parallel28788-current`이다.
- 정적 계약의 기존 45건을 모두 해결했다. 현재 실패 0건이며 검사 장치의 정상·실패 통제 사례 124건을 확인했다. AES 실행은 C#·Native 기본 및 강제 portable/AES-NI 경로 6/6이다. `static28832-current`에 공용 실행기, 생산용 링크 경로, Stage 사전 검사, 집중 벤치마크 근거가 있다. 플랫폼·성능 전체 완료를 뜻하지 않는다.
- 비동기 시작 실패의 소유 입력 정리는 이미 12/12건 확인된 수정이다. 오래된 미해결 표시를 현재 원장으로 연결한 커밋은 `74b72752e`이다. 같은 시작 실패 진단을 반복하지 않는다.
- 빈 상한 배열·사전에서 원소 해제 함수가 빠진 C857은 `406fc338e`에서 해결했다. 기존 소유 타입 의존 탐색에 타입 종류 12/13을 포함했다. C# 3건·Native 3건, 의미 분석 4건, stdlib 144개 소스 사전 검사와 정적 계약을 확인했다. 근거는 `bounded28860-current`이다.
- Unit 추가 인자를 함수 안에서 다시 읽어 전달할 때 `freeze void %arg1`을 만든 C858은 `b3255969e`에서 해결했다. C#의 RuntimeUnit 이름 읽기와 대조한 뒤 공통 `emitNamedPlaceRead`에서 물리 값이 필요 없는 Unit 읽기를 생략했다. 값 전달은 기존 공용 0을 사용하며 호출 효과와 Task 핸들은 유지한다.
- C858은 새 재전달 사례와 기존 6개 사례를 양쪽에서 확인해 14/14이다. Task<Unit>는 별도 2/2, 비동기 할당·해제는 각 컴파일러에서 각각 2회이다. 의미 분석 4/4, stdlib 144개 소스, 정적 계약 실패 0도 확인했다. 근거는 `unitname28881-current`이다.
- Unit 커밋 푸시는 GitHub의 `commit_refs_rules` 오류로 두 번 실패했지만 세 번째 일반 푸시에서 성공했다. 보호 규칙이나 인증 설정을 변경하지 않았다. 이후 검토 기록 `f2d02a01a`도 푸시했고 원격 SHA를 확인했다.

위 근거 경로의 공통 접두사는 `scripts/contracts/evidence/source13293/`이다.
실패·중단·취소·소스 변경 후 산출물은 보존했다. 현재 Unit 수정의 검사 실패는 없다.
이전 작은 checked 관측의 `valueLayoutCycles` 중단은 현재 소스로 재확인하지 않았다.
첫 Unit 이름 읽기 사전 검사 2건은 서식 오류로 중단했다. 정식 포매터 적용 후 새 경로의 필수 검사가 통과했다. 최초 실패 기록은 남아 있다.

## 재사용할 컴파일러

- C#: `B/library28485-managed/compiler/Sollang.Compiler.exe`.
  DLL SHA256: `148482484ACF07C0BD1FEDED4AB42DF7C980EC7FF8C7EA52ACFE5BEDF282AB47`.
- Native CLI: `B/context28871-unit-name-cli/compiler.exe`.
  SHA256: `3D2D9C871E3D6BCB8FF24F415B560B1491C76B44DD4AA68864993A6A189293CB`.
  빌드 기록은 같은 폴더의 `result.json`이다.
- 재사용 제품은 `context28871-unit-name-cli`, `library28485-managed`, `v20050/compiler-build01`의 세 경로를 명시한다.
- 예전 Native CLI 28780/28855는 현재 소스 이전 제품이다. 변경·실패 기록을 보존하며 현재 제품으로 간주하지 않는다.

## 바로 이어갈 일

현재 검토 근거는 `review28885-current/source-review.json`이며 100개 파일의 현재 해시를 모두 확인했다.
마지막으로 `selfhost/ir/typed/resolved_context_finalize.slg` 2490줄 전체를 읽었다.
새로운 재현 결함이나 소스 수정은 없다. 상한 사전 인덱스의 늦은 타입 복원은 종류 5만 다루는 부분이 있으나, 앞선 의미 분석 경로는 종류 13을 지원하고 원본 848/2544가 양쪽에서 통과했다. 이름이나 조건만 보고 수정하거나 전체 빌드를 시작하지 않는다.

남은 16개 파일은 `B/session-handoff28886.json`의 `remainingPhysicalSources`에 고정했다.
다음은 작은 순서대로 `selfhost/ir/typed.slg`, `selfhost/llvm/text/control_region_expressions.slg`, `selfhost/semantic/type_ids.slg`부터 전체 검토한다.
부분 읽기는 전체 검토로 세지 않고 범위와 현재 해시를 기록한다.
C764의 합성 TypeId 등록·읽기 전용 ABI 진단, C385/C742와 남은 소스 결정을 전체 목표 안에서 마무리한다.
모든 단위를 해결하고 입력을 고정한 뒤 원본 14·소스 7·런타임 2708·Stage2/Stage3·동결 stdlib/runtime 22 및 요구 플랫폼·성능 검증을 진행한다.

## 실행 계약과 보존

C# 구현·집중 검증 → 실제 C#/SLG 구조·분기·논리·진단 결정 비교 → SLG 구현 → 집중 대조 순서를 지킨다.
C#이 이미 올바른 경우에는 그 동작을 먼저 확인하고 해당 소스 결정을 대조한다.
새 Native 전체 빌드는 실제 소스 수정과 비교 기록, 의미 분석 4/4 및 stdlib 144개 소스 사전 검사를 갖춘 뒤 한 번만 시작한다. 기본 집중 빌드 예산은 180초이다.
통과한 검사를 반복할 때는 바뀐 의존성이나 새 미해결 우려를 먼저 밝힌다.

현재 세션이 실행한 검증은 모두 종료됐다. 중지 시점에 작업 경로 아래의 compiler/probe/LLVM 실행 파일은 관측되지 않았다.
다른 도구·사용자 프로세스는 종료하지 않는다.
기존 `docs/SESSION_HANDOFF.md` 변경 13줄, `completed_artifact_plan.py`, `test_completed_artifacts.py`, 두 원장의 기존 변경과 미추적 자료를 보존한다.
두 원장은 기존 변경이 섞여 있으므로 자신의 키·결정 행만 Git index에 반영한다. 전체 파일을 무조건 stage하지 않는다.
산출물 정리는 기존 ArtifactLifecycle을 사용한다. 실패·취소·변경된 산출물과 활성 소비자는 정리하지 않는다.
검증한 묶음만 `origin/v0.5`에 커밋·푸시한다. 태그와 하위 에이전트는 만들지 않는다.

## Slogs 정책·MCP와 보고

이번 요청의 Slogs 정책·MCP 개선은 별도로 완료했다. 정책 버전은 `2026.11.05.1`, 운영 반영은 `20261105153610`이다.
`W:/MyWorks/Slogs/artifacts/progress-report-20261105/`와 `.agent-docs/IMPLEMENTATION_CHECKLIST.md`에 근거가 있다.
오류 보고 거부·수정 보고 수용, 자연스러운 한국어 진단, 회상 적용을 실제 운영 도구에서 확인했다. 모든 후속 Agent 문장을 자동으로 인증한다는 뜻은 아니다.
다른 저장소의 기존 변경이 많으므로 Slogs 전체를 stage하거나 같은 정책 개선을 다시 시작하지 않는다.

장기 목표 보고는 매번 독립 목표축, 완료/전체와 정확한 백분율, 실패·미해결·미검증, 현재 단계·다음 검증을 포함한다.
`llm_wiki_prepare_progress_report`에는 `draftJson` 문자열로 권위 있는 근거와 그룹을 전달한다.
반환된 `report.renderedReportText`를 한국어 용어 검사 후 그대로 표시한다. 수치를 JSON에만 넣거나 표시 문장을 따로 다시 쓰지 않는다.
직접 `llm_wiki_validate_progress_report` 응답은 Markdown일 수 있으므로 무조건 JSON으로 파싱하지 않는다.
표시 문구 불일치를 수정한 운영 도구 근거는 `artifacts/scratch/session-20261105/visible-copy-repair.json`이다.
보고에는 결과와 남은 검증을 자연스러운 한국어로 쓴다. 실패를 통과로, 집중 검증을 전체 완료로 올리지 않는다.
Slogs 토큰이나 키를 응답·문서·로그·기억에 기록하지 않는다.
