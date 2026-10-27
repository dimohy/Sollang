# Sollang 세션 재시작 체크포인트 — 2026-10-27

실제 작업 폴더: `W:\MyWorks\Sollang`, 브랜치 `v0.5`.
이 문서와 `scripts/contracts/evidence/source13293/restart16770/summary.json`부터 읽는다. 과거 `SESSION_HANDOFF.md` 11488을 다시 처음부터 실행하지 않는다.
사용자가 느려진 채팅을 재시작하기 위해 저장과 일시 중지를 요청했다. 진행 중이던 검증은 모두 자연 종료했고 입력 안정성·프로세스 종료를 확인했다. 장기 목표를 완료로 처리하지 않는다.

## 전체 목표와 검증된 현재 상태

checkpoint11488에서 이어진 전체 목표: 모든 수정 단위와 C385 해결, 소스 검토와 과거 shaping 근거 정리, 고정 소스의 원본14·소스7·실행2708 비교, Stage2/3, stdlib/runtime22, 요구 플랫폼 및 성능 평가. 후보 수정을 최종 완료로 올리지 않는다.

- 컴파일러: closed363/737(49.25%), candidate-fixed372, open C385와 C741.
- 현재 C#·Native 통합66/66, 실제 SLG 소스111/111, C# 참조111/111, 독립 Native100/100: 모두 통과, 입력 안정성·프로세스 종료 확인.
- 최종 원본0/14, 소스 단계0/7, 전체 실행0/2708, Stage2/3 0/2, stdlib/runtime 로드맵6/22. 전체 소스·플랫폼·성능의 분모가 없어 총 진행률은 미확인.
- `source111-16770/qualification.json`, `native16763/qualification.json`, `focus16745/qualification.json`, `current16739/qualification.json`이 현재 근거다. 모두 `scripts/contracts/evidence/source13293/` 아래에 있다.
- 이전 동결 원본 catalog는1057 passed/181 failed/1150 unrun이었다. 현재 전체2708 통과로 바꾸지 않는다.

## 제품과 산출물 한도

아래 `B`는 `artifacts/scratch/resume-20261006-owner-continuation22`이다.

- C# `B/managed16362/compiler/Sollang.Compiler.exe`, DLL SHA `375D9B7D7448758904AFE49F1F8DDD9136E218EFFCC75A221E63C395B501DDB1`.
- 현재 Native `B/v16730/compiler-build01/compiler.exe`, SHA `5184988C734374FC01D6E5078F1A90B54EF88018B0EE42D54E6E6EFB84DC35B1`.
- 유지 중인 일반 Native는12432(포매터),16382(과거 제품),16730의3개다. 네 번째를 만들기 전에 기존 수명·소비 종료 계약을 충족해 하나를 정리해야 한다. 포매터12432는 빌드 근거가 참조하므로 임의로 제거하지 않는다.
- 16673은 두 소비66/28의 종료를 확인하고 정상 소비 종료 계약으로 정리했다. `retire16728/qualification.json` 참조. 실패한 소비 산출물은 보존했다.
- 16382 정리 시도는 과거 집계 형식 등으로 차단된 상태다. `interpolation16429-replay-controls` 아래는 의도적으로 변조한 테스트용 기록 복사본이며 실제 추가 실행으로 세지 않는다. 정리 검사를 완화하거나 원본 result.json을 고치지 않는다.

## 정식 소스에 들어간 내용

기존 여섯 SLG 수정과 C741 독립 파일 모듈 탐색이 통합되어 있다. `selfhost/cli_sources.slg`는 프로젝트와 독립 파일의 공통 순회 경로를 사용하며 기존 `Path.absolute`로 상대·구분자·상위 폴더 별칭을 정규화한다. 드라이버는 발견한 모듈까지 전달한다. 모듈 탐색13개 조건과 기존 프로젝트3개 조건의 전후 실행이 통과했다.
현재111/100/66은 이 정식 소스16714 기준이다. 아래 별도 후보 네 파일은 아직 정식 소스에 들어가지 않았다.

## 별도 후보: 선언 중복과 오류 우선순위

`duplicate16770/qualification.json`과 그 `sourceCopies`를 읽는다. 최종 후보는 `B/duplicate16760-candidate/`의 네 파일이며 보존된 소스 사본도 근거 폴더에 있다.

- 대상: `selfhost/semantic/diagnostics.slg`, `selfhost/llvm/emitter/diagnostics.slg`, `selfhost/llvm/text/context_prepare.slg`, `selfhost/llvm/text/entrypoints.slg`.
- 선언 이름을 네임스페이스/점/공백 규칙에 맞게 비교하고, 기존 서명 거부보다 먼저 발생해야 하는 중복 선언을 명시적인 `DeclarationRejected`로 전달한다. 캐시/일반 준비 경로와 기존7개 소비 분기를 함께 갱신했다.
- C# 기준10/10, 후보의 실제 SLG10/10, 의미 분석4/4 통과. 로컬 범위, 다른 네임스페이스, 다른 인자 수, 네임스페이스 공백, 먼저 잘못된 서명, 중복 선언의 잘못된 서명, 본문 오류보다 먼저인 중복 선언을 포함한다.
- 초기 후보는8/10 뒤 아홉 번째의 서명 우선순위가 달라 실패했다. 이후 준비 단계 거부를 보완했고, 누락 import도 사전 검사에서 고쳤다. 모든 실패는 보존했다.
- 아직 일반 Native 제품으로 빌드/검증하지 않았고 캐시 경로의 실제 행동 검증은 별도 필요하다. 기존 현재 제품5184988의 문제를 해결했다고 승격하지 않는다.
- 실행한 마지막 스크립트: `B/duplicate16762-source10.py`, 결과 `B/duplicate16762-source10/result.json`.

## 이어서 할 첫 작업: LLVM52 생성기별 검사 시제품

현재 정식 Native로 실행한 원본9건은7 통과/2 실패였다. 52번은 컴파일·별도 실행 결과가 원본 정답과 같으나 C# 방식의 LLVM 이름/인자 검사가 실패했다. 중복 함수 사례는 중복 대신 접근성 오류를 냈다. 이 기록은 `cli16742/qualification.json`에 그대로 남아 있다.

기존 `LlvmAssertions.SelectPaths`가 이미 `csharp`/`slg`별 검사 파일을 지원한다. 실제 C# 함수는 사용하지 않는 I/O 인자를 받고 `i32 * 2`를 반환하며 Native 함수도 같은 곱셈을 반환하지만 이름/서명이 다르다. 기존 `compare-selfhost-llvm-functions.ps1` 결과는 `B/cli16755-llvm-comparison.json`에 있다. 전체 함수/오류 경로 동치로 확대하지 않는다.

다음 세 파일은 저장을 위한 미완료 시제품이며 아직 적용 완료/검증 완료로 보지 않는다.

1. `examples/regression/expected/52-multi-file-modules.slg.llvm.regex-counts.txt`: 호출 인수21·동일 호출 대상·곱셈2·같은 SSA 반환을 함께 확인하는 SLG 전용 검사. 기존 C# `.llvm.contains.txt`는 바꾸지 않았다.
2. `tests/Sollang.ExampleTests/LlvmAssertionTests.cs`: 기존 검사 도구에52번 정상/잘못된 곱셈·인수·반환·함수 누락 대조를 추가.
3. `tests/Sollang.ExampleTests/Program.cs`: 기존 `--llvm-assertion-tests`에 선택적인 fixture 이름 인자를 지원.

테스트 전용 빌드 `B/runner16766-build/result.json`은1/1 통과했고 C#375 DLL은 그대로다. 새 실행기 `B/runner16766-build/bin/Sollang.ExampleTests.dll`을 쓸 수 있다. **52번9개 검사 제어·기존51번12개 제어·새 생성기별 검사로 실제 C#/Native52 실행은 아직 하지 않았다.** 먼저 이 검증을 마치고 성공/실패를 보존한다. 기존 원본52의 실패를 새 검증 없이 통과로 바꾸지 않는다.

검사 제어 명령 형태:
`dotnet <새 실행기> --llvm-assertion-tests <실제 Native52 LLVM> <새 결과 경로> 52-multi-file-modules`
기존51번은 마지막 이름 인자 없이 기존 호출을 유지한다.52번 실제 LLVM 경로는 `B/cli16755-llvm-inputs.json`의 candidate에 있다. 검증기 제어는 단순 소스 실행/전체 목표 완료의 대체물이 아니다.

## 이후 진행 원칙

- 진행 중인 검증은 없다. 재시작할 때 모든 결과 상태와 git/원격을 읽고 불필요하게111/100/66을 다시 실행하지 않는다.
- 별도 네 파일의 통합은 전후 해시를 확인하고 해야 한다. 통합 시 새 소스 기준의 Native/집중/소스 검증 상태를 정확히 갱신하고 이전 근거는 보존한다.
- 원본 소스·정답·사례당180초를 유지한다. 전체 실행 예산만 실측에 맞춰 조정하는 것은 이미 사용자가 승인했다. 내부 진단 구조48바이트 채택과 입력 없는 generic async의 C#/Native 일치도 이미 승인된 범위다.
- 형식 경고·오류를 숨기거나 검사 강도를 낮추지 않는다. 플랫폼 보안 알림을 우회하거나 사라짐을 보장하지 않는다. 정상적인 컴파일러 소스 수정과 검증을 계속한다.
- Stage2/3은 아직0/2다. 선택한 최종 seed의 컴파일러 소스 ABI1196/1201을 전체 방출 전에 확인한다. 실제 파일은 `1196-selfhost-cross-fragment-ref-dynamic-array.slg`와 `1201-parallel-move-parameter.slg`다. 이번 재시작 저장 전에 이 둘을 새로 실행하지 않았다.
- 전체 형식의 Slogs 진행 보고를 계속한다. 수치와 관측 시점을 보존하고 보이는 문자열을 검증된 `renderedReportText` 그대로 사용한다. 허용되는 `evidenceState`는 임의의 `partial`이 아니다. 개별 통과 관측을 스냅샷 해시/행 수로 확인한 뒤 `confirmed`로 수치를 보고하되 전체 실행 미확정을 명시한다. 보고 검증 실패는 `B/report16763-rejected.json`에 보존했고 수정 보고는 통과했다. repair 도구는 이 세션에 노출되지 않았다.
- 한국어로 `(이해도 99%)` 형식을 사용하고 실제 보고에 오타/다른 언어가 끼지 않게 한다. 서브 에이전트는 명시 허가 없이는 만들지 않는다.
- 마무리한 작업은 계속 커밋·푸시한다. `B/commit13564.py`가 근거 manifest/원시 바이트/진행 CLI를 검사하고 커밋·푸시한다. 소유 목록에 없는 새 파일은 명시적으로 git add한다.
- 이 체크포인트는 `SESSION_HANDOFF.md`를 덮어쓰지 않았다. 로컬 메모리 파일도 변경하지 않았다.
