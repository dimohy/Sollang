# Sollang restart — 2026-11-05 / Unit input ABI

작업 경로: `W:\MyWorks\Sollang`, 브랜치 `v0.5`.
사용자 요청으로 다른 세션용 인계를 준비했다. 목표는 **paused**, 미완료이다.
이 문서는 2026-10-21 및 그 이전 중단 기록보다 우선한다.
새 세션에서 사용자가 재개를 요청할 때까지 구현·빌드·테스트를 시작하지 않는다.

## 처음 읽을 자료

1. `AGENTS.md`, `docs/AI_SLG_BEST_PRACTICES.md`.
2. Slogs 프로젝트 기억과 사용자 전체 용어 선호를 별도로 조회하고 선택한 항목을 읽는다.
   - managed-first: `12f31659-1386-4771-be53-34394fdefc6d`
   - 전체 목표/경로/검증된 묶음 커밋·푸시, 태그 금지: `b3b3ab7b-b6f6-457e-bd1d-14ada4b1943c`
   - 한국어 보고: `87ca1dfa-82ea-40f6-8f63-154c2cdd7b54`
3. 이 문서, `scripts/contracts/active-goal-progress.json`의
   `currentUnitValueInputUnit`, `currentFileReviewReconciliation`.
4. `B/session-handoff28387.json`과 거기 연결된 실제 결과를 확인한다.

아래에서 `B = artifacts/scratch/resume-20261006-owner-continuation22`이다.
HEAD는 `8701b76b7957ae7b0a8f110755ba3164a8eed2df`.
현재 Unit 변경은 **미커밋**, 인계 작업 중 커밋·푸시는 하지 않았다.
파일이 더 바뀌었을 수 있으므로 새 세션에서 현재 Git·해시·프로세스를 다시 확인한다.

## 계속 유지할 전체 목표

C764 TypeId 합성 등록·읽기 전용 ABI 진단, C385/C742와 남은 소스 결정을 해결한다.
각 단위마다 C# 구현 및 집중 컴파일·실행 → C#/SLG 소스 구조·분기·진단 결정 비교
→ SLG 대응 구현 → 집중 대조 순서를 지킨다.
C#이 바뀌면 SLG에도 같은 결정을 쉽게 반영할 수 있는 구조가 사용자 요구이다.
공통 정책은 기존 compiled-policy 생성 경로를 재사용한다.
개별 단위가 모두 해결되고 입력이 고정된 뒤 원본14, 소스7, 런타임2708,
Stage2/Stage3, 동결 stdlib/runtime22 및 요구 플랫폼·성능 검증을 수행한다.
기존 기대값·시간 제한·산출물 수명 계약을 유지한다.
검증된 묶음만 커밋·origin/v0.5 푸시하며 태그는 만들지 않는다.
질문으로 작업을 미루지 말고 자료에서 판단 가능한 사항은 직접 확인한다.
하위 에이전트를 만들지 않는다.

## 현재 수치와 범위

| 축 | 완료/전체 | 진행률 |
|---|---:|---:|
| 컴파일러 안정화 | 363/839 | 43.27% |
| 현재 Unit 집중 검증 | 7/14 | 50.00% |
| 소스 결정 연결 | 729/729 | 100.00% |
| 파일 전체 검토 | 70/116 | 60.34% |
| 원본 검증 | 0/14 | 0.00% |
| 소스 단계 완료 | 0/7 | 0.00% |
| 런타임 전체 대조 | 0/2708 | 0.00% |
| Stage2/Stage3 | 0/2 | 0.00% |
| 동결 stdlib/runtime | 6/22 | 27.27% |

총 진행률은 플랫폼·성능 검증의 전체 건수 미확정으로 미확인이다.
안정화 후보474, 미해결2이며 후보를 완료로 올리지 않는다.
Unit 집중 검증은 C# 일반6 + C# 라이브러리 양성1이 완료, SLG7이 미완료이다.
라이브러리 음성7건은 별도 통제 검사이다. 중복으로 합산하지 않는다.
파일 범위는 기존114에 새 공통 정책/생성 파일2를 추가해116으로 늘었다.
현재70개 전체 검토, 나머지46개. 부분 수정은 파일 전체 검토로 세지 않는다.
`B/unit28383-source-review-reconciliation.json`에 현재 해시와 범위가 있다.
보고 자동 검증은 `progress.counts.missing`으로 실패했다. 수치를 만들거나
정책을 수정하지 말고 미검증임을 밝힌다.

## Unit 구현과 실제 검증

Unit은 원래 허용된 core/library 타입이다. 미지원으로 돌리지 않는다.
C#은 Unit 값·인자 저장을 `i8`, source-produced literal을 `0`으로 구현했다.
Unit 함수 반환형은 `void`를 유지하고 producer 효과는 한 번만 실행한다.
공통 `FunctionValueAbiPolicy.cs`에서 생성한
`selfhost/llvm/generated/function_value_abi_policy.slg`를 manifest에 추가했다.
`selfhost-sync --check`는13개 모듈 통과.
C#은 기본/추가 인자, forwarding, Unit 반환, generic Unit, async 입력을 수정했다.
Native는 `writeMaterializedValueAbiType`/`isMaterializedUnit`과 관련 인자·저장 경로를
연결했다. **아직 대조 실패가 있어 구현 완료가 아니다.**

| 실행 | 실제 상태 |
|---|---|
| unit28374-managed | C# build 1/1 통과 |
| unit28375-csharp | 일반/async/generic 6/6 통과, async 할당·해제2/2 |
| unit28376-csharp-library | 음성7+양성1 = 8/8 통과, 실제 ABI 호출6개 |
| unit28381-semantic | 의미 분석 사전 검사4/4 통과 |
| unit28379-stdlib | stdlib144개 포함 사전 검사1/1 통과 |
| unit28380-cli | 수정 SLG CLI 빌드1/1 통과, **Stage2 아님** |
| unit28382-csharp-library-controls | 기존 원본 계약8/8 통과 |
| unit28384-paired | 첫 primary 빌드 실패, 완료0/6 |
| unit28385-native-library | 사용자 중지로 취소, 최종 기록2/8; 전체 통과 아님 |

각 결과는 `B/<실행>/result.json`. 성공 결과는 입력 안정·프로세스 종료 확인.
취소 기록은 inputsStable=null이므로 성공으로 재사용하지 않는다.
초기 중지 보고에는 라이브러리1/8이라고 썼지만 종료 직전 두 번째 검사가 끝나
최종 실제 기록은2/8이다. `session-handoff28387.json`에 정정 근거를 기록했다.
오래된 pause JSON의1/8보다 실제 result.json을 우선한다.

## 바로 다음에 할 일

1. `unit28384-paired/result.json`의 primary 실패와 보존된 LLVM을 직접 읽는다.
   재현된 오류:
   ```llvm
   %v3 = call i32 @sollang_fn_unitvalue_take(..., i8 %v2)
   ```
   clang: `use of undefined value '%v2'`.
   파일: `B/unit28384-paired/primary/.l0.ll`, 약1662행.
   인자형은 i8로 바뀌었지만 Unit producer의 존재하지 않는 SSA 이름을 참조한다.
   어느 value writer가 우회되는지는 아직 진단하지 않았다. **원인 확정 아님**.
2. C# 실제 인자 materialization과 대응 SLG 호출/flow 값 writer를 비교해
   단일 값 경로의 원인을 확인한다. fixture 이름, LLVM 사후 교체, 기본값 fallback으로
   숨기지 않는다. 일반 `writeValue`에 Unit literal 분기가 있어도 이 호출 경로가
   이를 소비하는지 직접 확인해야 한다.
3. C#의 의미가 더 바뀌면 C#을 먼저 집중 검증한다. 원인 수정 후 바뀐 SLG만
   format 검사하고 필요한 사전 검사부터 실행한다. `unit28378-semantic`은
   형식 위반 실패 기록이며 수정 후 `unit28381-semantic`이 통과한 기록이다.
4. `B/unit28377-source-comparison.json`은 **첫 빌드 예산1회를 이미 사용**했다.
   output을 덮어쓰거나 예산을 늘려 반복하지 않는다. 현재 실패 원인·수정·예상 관측을
   근거로 기존 도구를 이용해 별도 다음 실행을 정당화한다.
5. 일반6건과 Native 라이브러리7음성+1양성 대조를 완료한다. 정상 Unit 외부 인자는
   0/255 둘 다 같은 결과, Unit 반환은 void여야 한다.
6. 증거·원장·기존 소스 결정에 연결하고 산출물 수명 정리 후 검증된 묶음만 커밋한다.
   단위 완료로 전체 목표를 종료하지 않는다.

## 도구와 소스 위치

- C# 재사용: `B/unit28374-managed/compiler/Sollang.Compiler.exe`
- 현재 SLG CLI: `B/unit28380-cli/compiler.exe` (Unit 실패 분석/후속 검사 소비자 보호)
- C# 일반 계약: `scripts/contracts/codegen-unit-value-input.json`
- 라이브러리 계약: `scripts/contracts/library-unit-value-abi.json`
- 입력: `scripts/probes/unit-value-input/*.slg`
- 실행 도구: `scripts/verify-c385-preir-call-numeric.py`,
  `scripts/verify-library-abi-parity.py`,
  `scripts/verify-focused-selfhost-semantic-preflight.py`,
  `scripts/verify-owned-index-full-stdlib-source-preflight.py`,
  `scripts/build-focused-source-emitter.py`, `scripts/build-managed-reference.py`.
- Native reusable directories (명시적으로 전달):
  `B/v20050/compiler-build01`, `B/order26416-native`, `B/deque27418-native`.
- Managed reusable directories:
  `B/source26309-managed`, `B/dyn26504-managed`, `B/llvm26620-managed`.
- LLVM: `.tools/llvm-22.1.8`. 새 Native CLI 빌드는 jobs24/O2, 예산180초.
- paired 실행은 `--mode paired --build B/unit28380-cli`,
  `--managed-proof B/unit28375-csharp/result.json`,
  `--managed-compiler B/unit28374-managed/compiler/Sollang.Compiler.exe`,
  `--contract scripts/contracts/codegen-unit-value-input.json`,
  `--source-comparison B/unit28377-source-comparison.json`, 새 `--output`을 사용했다.
  변경 후에는 현재 입력 해시/빌드와 일치하는 근거만 사용한다.

## 변경 보호와 수명

미커밋 전체 작업을 유지한다. `git reset`, 일괄 revert/clean/stage 금지.
현재 Unit 소스 목록과 해시는 `session-handoff28387.json`의 ownedSourceHashes에 있다.
관련 SPEC/가이드 변경도 현재는 미완료 Unit 동작을 설명하는 초안이다.
기존 외부 변경: regression1000/1100/1126/1290/1999와 expected1100/1290/1999,
`scripts/completed_artifact_plan.py`, `scripts/test_completed_artifacts.py`,
active-goal/structural-parity JSON의 타 작업 필드, `.vscode`,
context23315/diagnostic23351, runtime-context 및 다른 미추적 probes를 보존한다.
보호8개 원본 해시: `B/block24016-protected-inputs.json`; 인계 직전8/8 일치.
혼합 원장 staging은 HEAD+이번 소유 필드만 재구성하여 타 작업 변경을 제외한다.
인계 전 원장 사본: `B/unit28383-active-goal-before.json`.

실패·취소28373/28378/28384/28385와 그 중간 산출물을 보존한다.
현재 C#74와 CLI80은 후속 소비자가 있어 삭제하지 않는다.
성공한 library76/stdlib79/library-controls82는 기존 수명 도구로 이미 정리했다.
정리할 때는 ArtifactLifecycle 계약/기존 도구를 쓰며 원본·기대값·결과·로그·해시를 유지한다.
재사용 가능한 컴파일러는 종류별 최대3개, 활성 소비자는 보호한다.
최종 인계 시 compiler/LLVM 실행 프로세스는 관측되지 않았다.
현재 목표는 paused이며, 이 인계 작업은 테스트 재개나 목표 완료가 아니다.
