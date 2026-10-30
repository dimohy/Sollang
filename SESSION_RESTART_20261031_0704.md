# 2026-10-31 07:04 KST 사용자 요청 중지 및 다른 세션 재개

사용자가 “다른 세션에서 다시 시자가도록 중지!”라고 요청했다. 개발과 검증 실행은 중지했다. 아래는 전체 장기 목표의 재개 지점이며 완료 선언이 아니다.

## 첫 지시와 장기 목표

- 작업 폴더: `W:\MyWorks\Sollang`, 브랜치 `v0.5`.
- 원래 저장 기준: `a1e47bd6`. `SESSION_RESTART_20261027_1755.md`와 연결 근거, checkpoint11488 이후 전체 목표를 유지한다.
- C# 컴파일러 구조·분기·논리·진단 결정을 먼저 확인하고 SLG에 대응시킨다. C# 우선 집중 검증, 소스 비교, SLG 수정과 집중 대조를 거쳐 모든 단위 해결 후 전체 비교와 Stage2/Stage3를 수행한다.
- 원본 소스·정답과 기존 승인 범위를 유지한다. 관련 정답 표기 유지보수에 대한 재질문을 하지 말라는 포괄 승인은 유효하다. 진단 정답을 바꾸어 실제 C#/SLG 차이를 숨기지 않는다.
- 사례당180초, 산출물 수명 계약, 실행 소유권과 실패·취소·입력 변경 산출물 보호를 유지한다.
- 완료한 통합66·SLG111·Native100을 변경 입력이나 구체적 이유 없이 반복하지 않는다.
- 후보 통과를 전체 완료나 closed로 올리지 않는다. Slogs 조회·한국어 용어 검사·정형 진행 보고 검증을 유지하고 완료한 묶음을 커밋·푸시한다. 태그는 만들지 않는다.

## 마지막 저장 상태

- 저장 수정과 현재 Native 검증: `7df25da2d246fb886380d4c7686043effc5236a2`.
- 박싱 타입 시제품과 대조 근거: `f178b881f5e4ebd27da78ec3f829d4082920bb62`.
- 이 문서와 마지막 관측 근거를 포함하는 중지 커밋이 위 두 커밋 다음에 생성된다. 재개 시 `git status`, `git log -3`, 원격 `origin/v0.5`를 확인한다.
- `docs/SESSION_HANDOFF.md`는 수정하지 않았다.

## 권위 있는 진행 수치

| 축 | 완료/전체 | 백분율 |
| --- | ---: | ---: |
| 컴파일러 안정화 | 363/763 | 47.58% |
| C767 조건식 이후 저장 집중 대조 | 2/2 | 100.00% |
| C764 읽기 전용 ABI 진단 집중 대조 | 1/2 | 50.00% |
| 공유 모드 초기 계약 | 10/10 | 100.00% |
| C543 숫자 재대입 집중 대조 | 8/8 | 100.00% |
| 남은 단계 소스 연결 점검 | 2/6 | 33.33% |
| 현재 소스 단계 | 0/7 | 0.00% |
| 현재 런타임 전체 비교 | 0/2708 | 0.00% |
| Stage2/Stage3 | 0/2 | 0.00% |
| 동결 stdlib/runtime | 6/22 | 27.27% |

후보397건·미해결3건(C385·C742·C764). 전체 소스 분기·플랫폼·성능의 분모와 전체 진행률은 미확정이다. LLVM 이름 연결은84/106이다. 원장은 `scripts/contracts/compiler-defects.json`, `active-goal-progress.json`, `stdlib-evolution-progress.json`이다.

## 이번 재개에서 완료한 범위

1. C767: 조건식 RHS 안의 내부 `=>`를 바깥 배열·필드 대입 대상으로 잘못 고르는 SLG AST 결함을 수정했다. `selfhost/syntax/ast.slg`의 공유 `outerBindingNameToken`을 일반 바인딩·배열·필드 대입에 적용했다. C# ParseStatement의 완전한 RHS 뒤 대상 선택에 대응한다.
2. `selfhost/llvm/text/container_control.slg`의 S032 불변식 실패가 성공으로 저장을 생략하지 않도록 `process.exit(1)`을 추가했다. 유효 사례에서 S032가 사라짐은 검증했다. 잘못된 내부 상태를 주입하는 전용 실패 경로 실행은 아직 하지 않았다.
3. 현재 소스 실행4/4, 의미 검사4/4, stdlib1/1, LLVM 조립2/2, 새 일반 Native의 실제 배열·필드 저장2/2가 통과했다. 기존 C# 실행 정답을 그대로 사용했다. C767은 candidate-fixed만 부여했다.
4. 이름 타입 ID 시제품은 새 Native3/3에서577·578·577개가 C#과 일치했다.
5. 박싱 타입 ID 시제품은 C# 실행3/3·Native3/3에서566·567·566개 이름과 ID가 모두 일치했다. 다음 ID는2150·2152·2150이다. 별칭 Int/Int32는 서로 다른 이름 항목이고 Duration은 BoxDuration28을 유지하며 나머지 내장 핸들은 C# 제외 결정을 따른다.
6. 완료·안정·종료된 산출물은 기존 수명 도구로 정리했다. 결과·진단·소스·해시는 보존했다. 실패·변경된 산출물은 완료로 간주해 삭제하지 않았다.

주요 근거:

- `scripts/contracts/evidence/source13293/store21267-qualified/qualification.json`
- `scripts/contracts/evidence/source13293/typeid21274-boxes/qualification.json`
- `scripts/contracts/evidence/source13293/typeid21286-paused/state.json`

## 현재 컴파일러 제품

공통 scratch 접두사는 `artifacts/scratch/resume-20261006-owner-continuation22`이다.

- C# seed: `managed21139/compiler/Sollang.Compiler.exe`, DLL SHA256 `B838CF7C48EF32FFA96ACA2D6B8197645AF8C070D30C48C233DDE65A94FA991E`.
- 현재 일반 Native: `v21262/compiler-build01/compiler.exe`, SHA256 `C1CA82328D0912F0181B6CCB8B893632727D8A2A9B946B09ADFCCFF080775D52`.
- Native 입력 지문: `813160CEF2B1DB98F1D9301501699F278572E57ECB61F81962466E89B40885A5`.
- 재사용 제품은 위 Native와 `v18915/compiler-build01` 포매터, `v20050/compiler-build01` 파서 대체 제품의3개이다.
- 빌드 성공은 소비자 검사 전체 완료가 아니다. 현 제품은 C767 및 이름·박싱 시제품 집중 검사만 통과했다. C764 실제 진단·전체 소스·전체 런타임·Stage 검증은 남아 있다.
- 소스 실행/의미/LLVM 증거의 생성 파일은 소비 후 정리되었으므로 기록 JSON만 보고 그 파일이 현재 존재하거나 즉시 재사용 가능하다고 주장하지 않는다.

## 지금 이어갈 실제 미완료 단위

C764의 실제 읽기 전용 ABI 진단은 C#이 `type '2651' is not a fixed-width library ABI type`를 출력하고, SLG는 아직 CSharp TypeId mapping unresolved 검증 실패를 출력한다. 이 C# 진단을 바꾸거나2651을 상수로 넣어 우회하지 않는다.

`scripts/probes/codegen-identity/reference-type-ids-prototype.slg`는 이름·박싱 등록 연구용이며 프로덕션 ABI 경로가 아니다. `type-registration-nominal-contract.slg`, `type-registration-box-contract.slg`가 소비한다. 합성 타입과 실제 진단 소비 경로가 맞기 전에 프로덕션으로 승격하지 않는다.

마지막으로 `type-registration-definition-observer.slg`를 추가해 현재 SLG 의미 표의 이름·필드/열거형 페이로드 참조·타입 세부 정보를 추출했다.

- `typeid21277-definition-observer/result.json`: SourceText 직접 보간이라는 관측 검사 자체 오류로 실패0/4. 보존.
- `typeid21278-definition-observer/result.json`: 빌드 종료0이지만 긴 조건식 형식 진단2건 때문에 검사 실패0/4. 보존. 경고/진단을 무시해 통과로 바꾸지 않았다.
- 기존 포매터로 수정 후 `typeid21280-definition-observer/result.json`: 통과4/4. 각 사례 이름577·578·577개, 정의 참조1745·1746·1745개, 타입 세부1213개. 데이터는 stdout과 중지 증거 zip에 보존했다.
- `typeid21281-shape-trace/result.json`: C# 실제 TypeDefinitionTable 메타데이터를 읽는 reflection 관측4/4 통과. 프로덕션 소스는 바꾸지 않았다. TypeTrace.cs와 프로젝트 파일도 증거 zip에 보존했다.
- `typeid21284-definition-model.py` 및 JSON: 관측 데이터에 대한 Python 연구 모형이다. SLG 구현이나 프로덕션 검증이 아니다. 정의 합성 타입36개를 생성했고 다음 ID가2186·2188·2186인데 C# 생성자 직후는2188·2190·2188이다. 이름 ID 범위 비교도 false이다. 원인 확정·통과로 올리지 않는다.
- C# 생성자는 BuildTypeDefinitions 뒤 BindTraits도 실행한다. `std.log.Sink.write`의 `[Field]` 같은 트레이트 매개변수가 추가 타입을 만들 수 있다. 이는 다음 분석 후보이며 남은 차이2개의 원인이 확정된 것은 아니다.
- C# 순서는 이름 타입 → 박싱 → 런타임 Result 별칭 예약 → 구조체 필드 → 열거형 페이로드 → 선언 레이아웃 → 트레이트 → 비공개 서명 추론 → 함수 선언이다. 이전 관측에서는 비공개 추론이 새 ID를 만들지 않았지만 함수 선언이 읽기 전용 입력2651을 만들었다. 일반 규칙으로 확대하지 않는다.

다음 세션은 이 모형의 누락/순서 차이부터 좁혀 확인한다. 필드 수집과 이름·박싱 성공을 전체 합성 타입 대응 성공으로 보고하지 않는다. 현 일반 Native를 불필요하게 다시 빌드하지 않는다. 프로덕션 구현 변경이 생기면 C# 결정 비교와 현재 입력에 맞는 집중 의미/실행 근거를 먼저 확보한다.

## 보고·기억·도구

Slogs 정책2026.10.30.1을 사용했다. 프로젝트 기억과 사용자 전체 용어 선호를 별도 조회하고 적용했다. `korean-software-terminology`는 모든 프로젝트 적용 승인이 이미 있어 재질문하지 않는다. 검사 명령은 scratch의 `terminology16813-package/scripts/terminology_guard.py lint <보고파일>`이다. 보고는 Slogs prepare/validate를 거쳐 반환된 renderedReportText를 그대로 표시한다.

장기 목표는 이 중지 저장이 끝난 뒤 도구 상태를 paused로 바꾼다. 다음 세션에서는 사용자 재개 지시에 따라 전체 목표로 다시 잡는다. 중지 저장 후 개발이나 검증을 계속하지 않는다.
