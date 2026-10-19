# Sollang session handoff

## CURRENT USER STOP CHECKPOINT — 2026-10-08

Explicit user request: save a restart record for another session and stop. Observed UTC 2026-10-08T02:26:56.583061+00:00 (KST UTC+09:00). This checkpoint supersedes the historical 2026-10-05 checkpoint preserved below. The goal is paused, NOT completed. Do not start another build/test or resume until the user explicitly resumes. No subagents were used. Preserve the dirty worktree; no reset, revert, commit or push was performed for this pause.

### Stop outcome and authoritative receipts

Base `B = artifacts/scratch/resume-20261006-owner-continuation22`.

- `B/native102-original-focused312/result.json`: public native acceptance interrupted by the user's pause, completed **0/10**; inputsStable=true, processesStopped=true. Raw result remains **failed**, `ValueError: PROCESS_DESCENDANT_OUTLIVED_PARENT`, from shutdown supervision. Do not rewrite that raw failure as success or infer a compiler defect from cancellation. This run is user-cancelled, not an additional timeout.
- `B/native102-original-focused312/user-pause-audit314.json`: root PID46544 and owned child PID52212 independently rechecked; activeOwnedProcesses=[] at 2026-10-08T02:25:36.5543534Z. An initial PowerShell ID-array expression was invalid; this audit was corrected using a computed array and Get-Process. The supervisor also confirms process shutdown.
- Native102 private array acceptance has not started (**0/1**). Current native combined acceptance is **0/11 (0.00%)**, not a passing gate. Failed/cancelled output is protected.
- Durable pause snapshot: `B/user-stop-final-state315.json`. Execution ledger: `scripts/contracts/active-goal-progress.json`, `currentResume` subsection. Read actual result files before interpreting historical fields. Some older fields describe earlier source epochs.

### Actual progress at pause

| Goal axis | Completed/total | Percentage | Current evidence/limit |
|---|---:|---:|---|
| Compiler stabilization | 371/528 | 70.27% | compiler-defects.json: 156 candidate-fixed, one open C385; candidates are not closed |
| Current C#-compiled SLG focused cases | 11/11 | 100.00% | B/move-function-index-managed307/result.json; not native acceptance |
| Current Native102 focused acceptance | 0/11 | 0.00% | public312 interrupted0/10 + private array not started0/1 |
| Entire compiler source comparison | 0/7 | 0.00% | structural-parity-detail.json phaseClosure; partial reviews are not phase closure |
| Entire compiler execution comparison | 0/2708 | 0.00% | frozen whole catalog not completed at current source epoch |
| Stage2/Stage3 | 0/2 | 0.00% | Native102 is C#-compiled Stage1, not Stage2 |
| Frozen stdlib/runtime | 6/22 | 27.27% | 16 remain; full stdlib parse admission is not backlog closure |
| Performance | unknown | unknown | sampled candidates; no comparable verified speed improvement |
| Storage | unknown | unknown | exact cleanup receipts exist; total denominator not verified |
| Overall | unknown | unknown | performance/storage denominators absent; overlapping focused units cannot be summed |

Other independently scoped evidence: historical focused94/94, original related41/41, focused8/8 and required runtime3/3 remain reuse candidates only when their complete pinned input/dependency identity is unchanged. Do not blindly repeat these passed scopes. Current semantic3014/4; moving-parameter control30513/13 (C# compiles the actual old/new SLG kernel); array source controls13/13 inside307; full stdlib source3081/1 with144 sources,2076 active declarations,23 inactive,zero diagnostics. Qualified1067 current managed307 passes but native is unfinished:1/2 (50.00%). Context paired gate0/1 (0.00%); current source epoch needs fresh context proof. Native101 borrowed lookup14/14 at298 is historical because shared helper changed afterward; it is not Native102 proof.

### Current producers and canonical source changes

Managed producer31: `artifacts/scratch/resume-20261008-csharp-stream-flow-build31/bin/Sollang.Compiler/release/Sollang.Compiler.exe`; launcher SHA256 `23C686710378D0EEC91A1747D923D9F5FEDF6A98EEF7EE38D4C9E8F67F961443`. Adjacent DLL SHA256 `FB24A0E4CC019CD6597352C83BC48717FDD257B02CF97E58838218D0E16CF6FA`. Do not mix EXE and DLL identity.

Current Native102: `artifacts/scratch/resume-20261008-canonical-cli-candidate102/compiler-build01/compiler.exe`; SHA256 `169340F20CC675B0363A73E2ACBA0A5517E3911B4A88E147F650D02CA166E417`. Build receipt `B/native102-shared-function-index-build311/result.json` passed under the original180s build budget, stable inputs and stopped processes. This is C# compiling SLG compiler source once (Stage1). Native acceptance remains pending. Protect this product and its pending consumer dependencies.

Canonical changes this continuation are in `selfhost/semantic/ownership_check.slg` and `selfhost/ir/typed.slg`:

1. BorrowedText selected-function lookup now keeps private generic selection plus ascending function declaration candidates. Generic priority, duplicate same-function allowance, ambiguity/missing decisions and dynamically growing inferred contracts remain unchanged. Public generic-map API remains unchanged. Source comparison278 followed existing C# focused behavior2774/4 before SLG change; actual old/new selection kernel283/297 and Native10129814/14 passed.
2. Shared `typedIr.functionDeclarationIrs` collects kind0 functions in IR order once. `movesFrom` iterates those candidates instead of every IR node for each declared call; all existing module/symbol/parameter/flag/argument predicates, repeated matches and order remain. Ownership lookup reuses the shared helper. Existing C# behavior277 was confirmed first; actual C#/SLG comparison299 preceded the change. Current semantic3014/4, exact old/new moving-parameter kernel30513/13, full-body predicate preservation310, focused30711/11 and full stdlib source3081/1 passed. Native102 must still prove this source epoch.

Keep comparison `B/move-function-index-source-comparison299.json`, `B/move-function-index-static-preservation310.json` and backup sources `typed-before-move-function-index300.slg`, `ownership-before-shared-function-index300.slg`, `ownership-check-before-borrowed-call-index278.slg`. Do not infer parity solely from rule names or passing small fixtures. Earlier canonical wrapper binding-child index, array-layout liveness, recovery oracle and independent1067 expected output remain in place; do not undo them.

### Failures, cost and storage boundaries

Confirmed original-budget timeout history is11 (previous8 + Native100 context271 at1200s + Native100 private array274 at1200s + Native101 public1067 at180s290). Native101 array291 was agent-cancelled for cost, with raw shutdown failure and cancellation audit300. Native102312 is user-cancelled, not a timeout. Historical private array227 used the wrong180s budget: test-budget failure, not a compiler semantic result. Native98 array semantic mismatch and legacy retirement-evidence format rejection remain distinct. Fixture295 format-note failure and304 fixture parse failure were corrected and independently rerun; preserve original failed records.

Earlier native samples identified borrowedTextSelectedCallFunctionIr (275) and typed.movesFrom (296). Native102 original1067 samples313 observed sourceNode and nodeBelongsToOwnershipRegion; a third instruction sample is not attributed. Three IP observations do not prove a sole bottleneck or total speed improvement. Inspect existing313/logs first; do not repeat costly runs merely for deeper logging. Existing production diagnostic series budget is319703/360000ms,40297ms remaining, wholePreparationRepeatAdmitted=false. Original acceptance budgets are separate and must stay unchanged.

Native101 retired via existing lifecycle after all five consumers had terminal evidence (295,298,293,290,291); receipt `B/native101-consumer-retirement309.json`, reclaimed259501597 bytes. Its compiler.exe no longer exists. Keep results/hashes/source fixtures. Native92/99/100 are the explicit reusable products (maximum3); Native98 remains protected due to unresolved legitimate retirement evidence; Native102 is protected pending acceptance. Physical retained products92/98/99/100/102 are therefore not a claim that all storage work is finished. Native100 is Native102's formatter; Native99 is Native100's predecessor dependency. Do not delete an unfinished product or forge a consumer success to satisfy retention. Successful307/308 and focused301/305 output cleanup receipts are already recorded; reuse them rather than repeating cleanup/testing.

### Executable restart order

1. Read current Slogs server instructions. Search Sollang project decisions and user-wide Korean terminology/reporting preferences separately; compactly recall relevant entries. Current explicit **C# first** overrides old conflicting SLG-first memories. Read this checkpoint and `docs/AI_SLG_BEST_PRACTICES.md` before code exploration. No subagents.
2. Check live Git dirty state, canonical source and full dependency fingerprints, Native102/managed31 hashes, execution results and owned-process audit. Preserve failed/cancelled outputs and pending compiler consumers. Read actual small source/log portions when a structured query cannot identify the cause.
3. Reuse current managed proofs only if inputs are unchanged. Next native proof must include the current moving-parameter13 cases; Native101's old14 proof is insufficient. Original public195/1067 native acceptance is unfinished, not passed. Private array compiler workload113 plus13 uses the original1200s budget; context suite113/4 also uses1200s, not the earlier mistaken180s. Use existing supervised plans/commands with independent logs/results; verify source manifest, tool identity and expectations before execution. Admit another costly attempt only from concrete source/evidence change or required acceptance justification; never silently relax limits or retry budgets.
4. Every fix: focused C# compile/run -> actual C#/SLG source/branch/diagnostic comparison -> SLG implementation -> focused paired controls. If313 evidence requires another source unit, close that unit in this order before another self-host acceptance build. Do not claim measured speedup without a comparable same-condition baseline.
5. Only after all units close, run one final exhaustive C#/SLG source and execution comparison, Stage2/Stage3, then the remaining frozen16 stdlib/runtime items. Partial parsing reviews, focused passes and Stage1 builds do not close the whole goal.
6. Apply existing `scripts/ArtifactLifecycle.ps1` / artifact-lifecycle contract only after stable successful verification and process shutdown; protect pending dependencies. Preserve result JSON, diagnostics, hashes, fixtures and expected output. Do not modify the AI guide/spec with progress history.

User-facing replies start `(이해도 99%)`, include separate goal axes and overall unknown where necessary, distinguish failures/cancellations/unverified work, and name current stage/next verification. Run the Korean terminology guard and reject accidental Japanese/CJK fragments before sending; preserve literal external diagnostics/code identifiers. Slogs progress-report server validator remains unavailable/unverified; no policy-change or universal-enforcement claim. Goal pause is an explicit user request, not an external blocker.

---

## CURRENT USER STOP CHECKPOINT — 2026-10-05

The user asked to finish the already-running work, record the restart state for another session, and stop. No new exhaustive comparison, Stage2/Stage3, stdlib/runtime run or compiler build was started after this request. This checkpoint supersedes every historical checkpoint below. Do not resume until the user explicitly resumes.

### Authoritative outcome and stop state

Observed 2026-10-05T07:00:28.3000949+09:00 (UTC 2026-10-04T22:00:28.3000949Z). The already-running native original143 related41 finished passed41/41 (100.00%). Original focused8 finished passed8/8 (100.00%), including actual required runtime3/3 (100.00%). Both records confirm inputsStable=true and processesStopped=true; every recorded owned process has shutdownConfirmed=true and no activeProcess remains. Tool sessions29348 and40986 are terminal. The aggregate focused49/49 is composed from these two independent records; the related41 record alone intentionally does not certify original8 or whole49. Current verification failure: none. Earlier failed assertions/diagnostics remain preserved.

Compiler371/501 (74.05%), focused8/8 (100.00%), Stage2/Stage3 0/2 (0.00%), frozen stdlib/runtime6/22 (27.27%) remain the authoritative independent axes. The whole goal is NOT complete. Stop requested by the user; no further execution is authorized until explicit resume. Durable final snapshot: `artifacts/scratch/resume-rootfc1a-slg-scalar-rebind44-design-20261005-01/formal-array-origin56/view-element-epoch04/user-stop-final-state.json`. Performance improvement remains unknown; progress-report formal validation remains unverified.

### Goal preserved, not completed

Complete C385 semantic diagnostic ownership and exact C#/SLG source alignment; C# focused proof -> corresponding source comparison -> SLG implementation -> focused paired controls for each unit; then the final exhaustive compiler comparison, Stage2/Stage3 and frozen stdlib/runtime22. Slow-interval performance evaluation remains part of the goal. Do not redefine completion around the checks here.

Compiler registered-defect closure371/501 (74.05%);125 fixed candidates still await full promotion and five actual open entries remain (C385/C407/C503/C504/C505). These are not130 newly reproduced defects. The denominator grows with discovery and is not a time-completion percentage. Current-goal Stage2/Stage3 remains0/2. Frozen stdlib/runtime remains6/22 (27.27%),16 pending. Progress-report formal validator is unavailable/unverified; no Slogs policy-completion or universal-agent-enforcement claim.

### Resume authority and user preferences

- User forbids subagents. Work as root only unless the user changes this instruction. Old historical subagent authorizations below do not apply.
- First search Slogs project memory and separately Korean software terminology/reporting preferences, then read applicable recalls and `docs/AI_SLG_BEST_PRACTICES.md`. Current explicit C#-first workflow wins over older contrary memories.
- Every Korean status starts `(이해도 99%)` and gives independent compiler, current focused gate, Stage2/Stage3, frozen stdlib/runtime counts/percentages, failure classifications, current stage and next verification. No unknown-denominator estimates.
- Korean text guard: `P:/MyWorks/Slogs/artifacts/skill-audit-korean-software-terminology-1.0.1/scripts/terminology_guard.py`. Lint before sending. Progress-report formal validation remains unverified when its tool is absent.
- `scripts/contracts/active-goal-progress.json` is the source ledger; `scripts/show-project-progress.ps1 -AsJson` is the projection. Do not serialize its computed `progressOutcome` property back into `focusedGates`: the projection adds that property and a duplicate breaks it.
- Preserve the existing dirty worktree. No reset, clean, revert, commit, publishing or cleanup of failed/cancelled outputs was authorized.

### Current compiler and source authority

All paths are relative to `P:/MyWorks/Sollang` unless stated otherwise.

Native current product:
`artifacts/scratch/resume-rootfc1a-slg-scalar-rebind44-design-20261005-01/formal-array-origin56/view-element-epoch04/consumer13/checked-consumer.exe`
SHA256 `4A86085E8A290896F5257FB4830133619D8C4999C6587DCB0CF5E54DF79233D6`.
Its LLVM SHA256 is `C06A4E28791147D8485E8F9D1686795BAB32DB8542F0A8E310F6BEB167BBC57B`.

Use that epoch's `execution-plan.json` for the exact ordered136 compiler sources and overrides. Canonical `selfhost/semantic/ownership_check.slg` is NOT automatically the tested source. Current source is the private epoch04 `ownership_check.slg`; source comparison is the adjacent `source-comparison.md`; build4/4 proof is `admission-and-build01/result.json`. Other private driver/typed/function/grammar overrides are pinned in the execution plan. Do not rebuild from an inferred public source manifest.

Current C# actual producer:
`artifacts/scratch/resume-rootfc1a-csharp-transitive-capture-isolated-build-20261005-21-03/artifacts/bin/Sollang.Compiler/release/Sollang.Compiler.dll`
SHA256 `6A24996247EB8F022065CBC2642CF23A9083BCBEFCFED6CF9CC7E66D47C4D25F`.
The launcher EXE hash is different (`23C686710378D0EEC91A1747D923D9F5FEDF6A98EEF7EE38D4C9E8F67F961443`); never associate the DLL hash with the EXE path.
Actual C# semantic source is source21 eligible-identity epoch03; actual BorrowOrigins source is source20 binding-key epoch02, both pinned by the existing producer proofs. The canonical working-tree C# files are not inferred producer identity.

LLVM toolchain: `.tools/llvm-22.1.8`. Existing formatter is the current20 compiler pinned by the plan. No new tool installation or timeout relaxation.

### What changed and why

All changes below are private candidates pending source promotion and final global verification:

1. Source17 parameter-loan mode separates inferred formal contracts from actual local escape loans. C# original143 related41 passed; Native focused24 passed. Preserve that oracle; do not rerun it without input drift.
2. Source55 follows the owned Flow wrapper to its If control for all-continuing-arm replacement, preserving one-arm/nested/backedge negatives. This fixed the all-arm scalar false rejection.
3. Source56 resolves unmapped kind5 formal reads to exactly one kind10 formal in the actual lexical function/source/symbol chain. Root resolution, value origins, retained formals and actual continuation liveness reuse this identity. Raw operand0=-1 was valid for mut formal arrays; root-only resolution was insufficient until the liveness consumer also used it.
4. Epoch03 moves necessary kind5/source/AST predicates ahead of expensive carrier matching; formal kind/source/symbol bounds precede the exact identity resolver. It preserves the exact resolver and all lifetime/reachability rules. This is a cost candidate, not a certified global speedup.
5. Epoch04 aligns growable-array store eligibility with actual C# SemanticCompiler12101-12106 and BorrowOrigins460-462: only recursively Text/SourceText-containing element types capture stored Text origins. Native previously collected every growable push, creating false loans on byte/numeric arrays. The actual gzip declaration closure was C#-clean but native11 E21; after this change it is native-clean, while unsafe Text-array tests still reject.

Focused private native proofs: related41/41, prior controls24/24, additional gzip/numeric controls6/6;65 unique processes with six immutable duplicate observations reused. These small declaration closures are diagnostic-only and were not promoted as original143 success.

### Durable current verification references

Base `B = artifacts/scratch/resume-rootfc1a-slg-scalar-rebind44-design-20261005-01`.
Current epoch `N = B/formal-array-origin56/view-element-epoch04`.

- `N/native-related-and-controls01/result.json`: small-input41+24+6 passes, input-stable and process-shutdown verified.
- `N/original143-discriminator01/result.json`: original143 exact direct negative passed: exit1, E21 source143 byte1037 length30,42172ms, stable/stopped. This is a discriminator, not original8 or whole49 completion.
- `B/source-transfer-return15/parameter-loans-epoch04/related41-paired01/result.json`: current6A C# original143 related41/41 actual oracle. Overall record failed on an older native scalar mismatch; the C# substage is valid and input-pinned, not a whole-record success.
- `N/csharp-original8-semantic02/result.json`: current6A original143 original8 semantic8/8 passed. First four actual observations are reused from01; the negative preflight emits JSON status failed plus canonical stderr, not empty stdout. No codegen/runtime claim for this C# semantic proof.
- `N/native-original8-build-runtime01/continuation02/result.json`: original native8 builds, LLVM verification and required runtime3. First four actual observations reused from execution01. Source-owned error-stage lifecycle supplement is checked independently of the unchanged exact reference semantic line.
- `N/native-original143-related41-01/result.json`: required original143 native related41, frozen golds and input order, one run per case,60sec per case, no retries. Do not start a duplicate run.
- Frozen authoritative49-case integration input/gold plan: `B/integration-validation-preparation03-cli-source-view/integration-plan.json`, SHA256 `B48593B6E0B437636E2188C3439F175E3F5B986335E54C3E7BFCA640271970E6`. Units: scalar9 + field4 + materialize-owner2 + materialize-related3 + helper5 + array18 + original8. Original8 requires three actual runtimes, not frontend-only substitution.

### Execution and failure-record details

Use existing `VerificationExecution`, `VerificationContractLease`, `SlowStepDiagnostics` APIs. Fresh output directories, independent stdout/stderr, structured result, input fingerprints and Windows owned-process shutdown are mandatory. Do not initialize the execution API with an old process list. No fresh runner files were added for this orchestration.

Original8 negative native builds emit the exact C#-style semantic line on stderr and one source-owned lifecycle line. `claimNativeBuildStages` explicitly creates both `.l0.ll` and a ZERO-BYTE `.e0.exe` reservation before emission. On semantic failure the LLVM stage contains only the diagnostic; no target triple/definitions and no published `probe.exe`. An existing zero-byte executable reservation is not backend execution. execution01 initially failed a caller assertion that wrongly required its absence; continuation02 validated the same captured observation against the actual source contract without rerunning the compiler. Preserve both records and failed stages.

Successful original8 binaries/LLVM and current compiler products are protected by pending consumers. Use ArtifactLifecycle only after successful, input-stable verification and verified shutdown with no pending consumer. Failed/time-out/unverified output is never cleanup-as-success. Do not delete current inputs or the reusable product merely because a build passed.

### Performance evidence and limits

- Full199 diagnostic budget: three prior runs, cumulative540079ms, exhausted. A fourth diagnostic run is forbidden; required final exhaustive validation is a separate later gate after all focused/source units are resolved.
- Previous epoch02 original143 ran to60sec and was killed with all owned processes stopped. Recorded CPU60.953125sec was continuously active; sampling had no gaps/drops. A terminal zero-duration duplicate sample made the latest-interval classifier insufficient-evidence despite preserved earlier CPU samples. Do not treat it as an external idle wait or an identified hotspot.
- Epoch03 returned in43141ms but with62 false stdlib E21 diagnostics, first gzip source19 byte27156. This was failure, not acceptance.
- Epoch04 exact same original input returned the intended diagnostic in42172ms. Changed termination behavior and these single observations do not prove overall speedup. Measured global improvement percent remains unknown.
- Preserve failed products/results. Existing source and small-input proofs come before more full-input diagnostics; keep budgets and expected values unchanged.

### Next work ONLY after the user resumes

Read the current source ledger, final results and this checkpoint; confirm no live owned process before execution. Do not redo completed41/8 checks blindly. Audit their input hashes and source authority first. Full scope still requires canonical source integration of the tested private override chain, remaining compiler units/defect promotion requirements, one final exhaustive C# versus SLG comparison, current-goal Stage2/Stage3 and frozen stdlib/runtime16 remaining acceptance items. Do not mark the goal complete from49 focused checks alone. Keep independent progress axes and performance limitations.

## Historical handoffs (superseded)

Everything below is historical, including old claims of a current checkpoint, old subagent permissions, old counters and deferred performance scope. They do not override this current checkpoint.


## 2026-10-01 historical user stop checkpoint

The user explicitly requested saving for another session and stopping. This is
THE CURRENT checkpoint; all earlier stop checkpoints below are historical.
Do not continue compiler work until the user resumes. Preserve the dirty tree;
no reset, clean, revert, commit, or duplicate builds were authorized.

### Goal and workflow

Resume the existing full C385 semantic diagnostic ownership / exact source
closure goal, then focused source-aligned paired checks, final exhaustive C# vs
SLG comparison, Stage2/Stage3 and frozen stdlib/runtime acceptance. Do not shrink
success to the focused cases below. Slogs project memory AND user terminology
preferences come first, then `docs/AI_SLG_BEST_PRACTICES.md`, SPEC and this
checkpoint. C# first proof -> corresponding source comparison -> SLG alignment
-> focused paired controls. Performance evaluation is deferred.

Every Korean status starts `(이해도 99%)` and includes these separate axes:
compiler stabilization371/498 (74.50%); last completed main focused gate5/6
(83.33%); Stage2/Stage3 0/2 (0%); frozen stdlib/runtime6/22 (27.27%). Structural
phase closure remains0/7. Use the terminology guard before sending Korean text:
`P:\MyWorks\Slogs\artifacts\skill-audit-korean-software-terminology-1.0.1\scripts\terminology_guard.py`.
The user authorized active subagent use. Actual session concurrency was root+3
subagents, not five simultaneous agents. Assign disjoint file ownership.

### Stop/process state — verified, no duplicate restart

- All three subagents were interrupted or already completed on the user stop.
- Root build handle38193 is TERMINAL exit1. It was NOT canceled mid-build.
- Earlier handle6629 terminated on source format preflight; no output directory
  existed then. Required formatting was applied to both diagnostics files.
- The subsequent candidate21 build failed semantic compilation; durable result:
  `C:\Users\dimohy\AppData\Local\Sollang\c385-preir-call-and-owned-temporary-direct-20261001-21\result.json`.
- A process inventory after stop found NO candidate21 compiler/build processes.
  Old handles33410,86679,42723,30762 and numeric47619 are terminal. Agent-owned
  focused test processes are terminal. Poll or inspect before any restart.
- Never overwrite candidate21 failed result. Use a NEW directory for the next
  build (e.g. candidate22) after the source error below is fixed.

### Immediate next action: concrete build error, NOT a runtime failure

Candidate21 result: failed, inputsStable=true, 275 sources (132 compiler+143
stdlib), O1, build exit1, no LLVM assembly/V004/native binary produced.
Failure ID: `FOCUSED_SELFHOST_BUILD_EXIT_NONZERO`.

`selfhost/llvm/emitter/diagnostics.slg:3329`:
`"$targetModuleName.$declarationName" => functionName!`

C# rejects storing deferred interpolation directly: materialize into an Arena
owner. Do NOT add an unnecessary Arena merely to concatenate a diagnostic name.
The intended source-level fix is emit the canonical imported module/name as
immediate print fragments, preserving C# `std.net.loopback` rather than source
alias `net.loopback`. Keep local primary and additional diagnostic wording and
locations, generic T conflict text, and negative `-7` literal spelling intact.
This fix has NOT been performed because the user stopped.

Read `artifacts/scratch/c385-preir-call-numeric-source-comparison-20261001-01.json`
and run format/check per changed file. Refresh source-boundary proof, then build
ONCE from current managed seed with native20 formatter/cache in a fresh output.

### Last valid compilers and frozen baseline

- Managed DLL: `src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll`
  SHA256 `58A41215E03FD2500C02264DD2030B7E9D91F3A5FE4CA99FE29F13F0ADEF8922`.
  Root fixed borrowed fixed-storage field copy in C# `LlvmEmitter.Structs.cs`;
  transfer registration unchanged. Build was zero warnings/errors.
- Last valid native20: `C:\Users\dimohy\AppData\Local\Sollang\c92-fixed-array-region-abi-direct-20261001-20\compiler.exe`
  SHA256 `4BB0050BE0F6AAB8CF70E5D745EAE24B289E057C24F4CF643C4F1C0189C949A8`.
- Native19: `C:\Users\dimohy\AppData\Local\Sollang\c92-fixed-struct-runtime-direct-20261001-19\compiler.exe`
  SHA256 `A1ADCEF8D053EABAD7DB8125F5E7D337D4BDC385139E71C47257E7DCCE55B0B5`.
- Managed production proof6/6:
  `artifacts/scratch/c92-managed-retained-after-ref-copy-20261001-01/result.json`.
  P1206 allocations/releases169877/169877, invalid0. DO NOT lower169877.
- Native20 production5/6:
  `artifacts/scratch/c92-additional-move-direct20-20261001-01/result.json`.
  Functional `quic-multi-stream=true`, allocations169872/releases169870,
  invalid0/live2. Native18 was169666/169252/live414. These are historical
  binary observations, NOT proof of current unbuilt sources.

### Completed focused evidence in this continuation

- Native19 structure copy/cleanup paired14/14 (move4,mixed3,region4,consumers3)
  and enumforwarding3/3 passed. Related controls14/14 also passed.
- Native20 region scalar fixed-array ABI fix: paired2192 plus region4+move4,
  9/9 passed. Source comparison:
  `artifacts/scratch/c92-control-region-fixed-array-field-source-comparison-20261001-01.json`.
- Current managed numeric ranges10/10, ordinary S0015/5, call argument4/4:
  `artifacts/scratch/c385-{range,ordinary,argument}-managed-fixed-struct-20261001-01/result.json`.
- Native19 numeric range paired10/10, inputsStable true:
  `artifacts/scratch/c385-range-retained-direct19-20261001-01/result.json`.
- New C385 direct/imported/generic/negative/contextual-if and invalid diagnostics
  C#8/8 through reproducible runner:
  `artifacts/scratch/c385-preir-call-numeric-managed-runner-20261001-04/result.json`.
- Generic literal range C#2/2:
  `artifacts/scratch/c385-generic-range-managed-runner-20261001-02/result.json`.
  Contracts `c385-preir-call-numeric-coverage.json` and
  `c385-preir-generic-call-numeric-range.json`, fixtures2193–2197,2207/probe2208.

### Current source edits awaiting a SUCCESSFUL integrated build

1. C385 semantic call argument contract:
   `selfhost/semantic/context.slg`, `expression_type_ids.slg` now commit canonical
   direct/flow/imported/generic identities and expected/actual type facts.
   `ExpressionTypeIdSet.callArguments` holds `ResolvedCallArgument`: sourceModule,
   callAst, argumentAst, targetSourceModule, functionSymbol, parameterSymbol,
   parameterOrdinal, expectedTypeId, actualTypeId, status,
   suppressNumericWarning,genericParameterSymbol,genericFirstActualTypeId.
   Status0 resolved,1 unresolved,2 conflicting generic inference. Primary flow
   warning suppressed (C# behavior), direct primary warns. Generic flow and
   direct inference order remain distinct. No T/Int fallback. Composite/multiple
   generic conflict identity is STILL known incomplete status1; do not claim
   complete generic coverage or whole semantic phase closure.
2. `selfhost/semantic/diagnostics.slg`: call range/warning/mismatch decisions now
   consume semantic facts, not TypedIR edges; negative conversion literal can
   be unary minus; generic numeric range uses specialized expected type.
3. `llvm/text/context_prepare.slg`: numeric call decisions precede lowerPreparedIr.
   `llvm/emitter/diagnostics.slg`: semantic symbol rendering, direct/imported
   canonical names, additional parameter wording and generic conflict text.
   Immediate build error above remains here.
4. Source-boundary checker (ONLY structural boundary, not behavior):
   `scripts/verify-c385-preir-call-diagnostic-ownership.py`; last passed proof
   `artifacts/scratch/c385-preir-call-diagnostic-source-boundary-20261001-05.json`.
   `scripts/verify-c385-preir-call-numeric.py` provides pinned managed/paired
   contract execution, durable running/result state, stdout/stderr and timeout.
5. Scheduling fix `selfhost/llvm/text/function_scheduling.slg` carries observable
   producer ordering through ancestor bindings, preserving earlier guard/try
   barriers. C#6/6 counts0/1/0/1/0/1; native20 propagation and mutable-field guard
   reproduced allocation1/release0. Source comparison:
   `artifacts/scratch/c92-fixed-struct-producer-control-source-comparison-20261001-01.json`.
   Contract `fixed-struct-producer-control-order.json`, fixtures2198–2203.
6. Empty borrowed call-argument temporary allocation AND cleanup aligned with
   C#: shared `freshEmptyArrayCallParameter` in `call_arguments.slg`, applied to
   `function_expressions.slg`,`control_region_expressions.slg`,
   `entry_expressions.slg`,`container_control.slg` while emission.
   Fresh [] readonly slice call argument allocates at least element ABI stride,
   logical length0, then frees after call with dedup and proper while SSA.
   Unowned null views and typed empty growable/bounded are excluded.
   C#4/4 cases2204–2206,2209 each allocation/release1; native20 empty3cases
   reproduced0/0 and nonempty control1/1 passed. While cases2210/2211 C#2/2
   counts3/1 include final false condition. Source comparison:
   `artifacts/scratch/c92-empty-array-call-temporary-source-comparison-20261001-01.json`.
   Contracts `empty-array-call-temporary-ownership.json` and
   `while-empty-array-call-temporary-ownership.json`.
7. `verify-fixed-storage-ownership.py` now accepts exact nonnegative integer
   counts:0 allowed, bool/float/negative rejected; five boundary values checked.
   Previous positive ownership proofs predate this runner hash change; retain
   them as historical evidence, do not silently rewrite hashes.
8. SPEC/guide updated ONLY normative storage/borrowed copy rules, not progress.

### Residual production count difference fully attributed

Two extra64-byte allocations were hoisted before completeServer's false early
return (native LL25147 create before guard25159; C# guard first and create after
try success). Seven missing allocations are empty argument temporaries:
ed25519.sign3; quic.acceptImpl1; initial_engine encodeClientInitial2 and
encodeServerInitial1. Fixed-copy allocations are797 BOTH compilers, so do not
invent a struct copy count patch. Diagnostic (observed only) traces:
`artifacts/scratch/c92-p1206-direct20-allocation-trace-20261001-01/result.json`
and `artifacts/scratch/c92-p1206-managed-allocation-sites-review-20261001-01/result.json`.
After scheduler and empty temporary changes, runtime equivalence must still be
measured; expected169877 is NOT already proven for current sources.

### Resume commands after fixing immediate semantic build error

```powershell
python scripts/verify-c385-preir-call-diagnostic-ownership.py --output artifacts/scratch/c385-preir-call-diagnostic-source-boundary-20261001-06.json
& scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe -OutputDirectory 'C:\Users\dimohy\AppData\Local\Sollang\c385-preir-call-and-owned-temporary-direct-20261001-22' -Optimization O1 -FormatCompiler 'C:\Users\dimohy\AppData\Local\Sollang\c92-fixed-array-region-abi-direct-20261001-20\compiler.exe' -CacheSeedDirectory 'C:\Users\dimohy\AppData\Local\Sollang\c92-fixed-array-region-abi-direct-20261001-20\.sollang-cache'
```

After successful build, use UNIQUE output folders and actual resulting binary
hash for focused paired C3858 +generic range2, original ordinary5/argument4/
range10 controls, producer-order6, empty-call4 +while2 and related ownership
controls. The numeric paired runner pins ALL selfhost sources: no SLG source
edits during it. Root serializes build/cache and ledger promotion. Then run the
main6 production gate, retaining frozen169877 and functionaltrue/invalid0.
No exhaustive or Stage builds until every known source unit closes.

### Structural evidence honesty

`artifacts/scratch/structural-evidence-current-20261001-01.json` measured4/9
current matching source claims (0/5 compiler,4/4fixtures), not old declared5/9.
All11 historical verifier claims and5 current checks are stale; this is
fingerprint drift, not proof every semantic behavior is wrong. All7 phase rows
remain partial; control-flow evidence inventory is empty. The current detail
validator FORCES partial statuses and is not yet a real phase-promotion gate.
Need required per-phase decision inventory, current source/compiled proofs and
fail-closed promotion validator; do not flip labels or count narrow cases as a
whole-phase proof. Keep final exhaustive comparison0/1 and Stage2/Stage3 0/2
independent. No policy or memory capture was substituted for source execution.

---

## Historical checkpoints (superseded)

Updated: 2026-09-29 16:15 (Asia/Seoul)

## 2026-09-29 16:15 STOP CHECKPOINT — READ THIS FIRST

The user stopped work to continue at home. Do not resume compiler work in this
session. The 06:12 checkpoint and older sections below are historical. Preserve
the dirty worktree, existing results, and separate C# and SLG implementations.
At the next session, follow the current Slogs LLM Wiki policy and terminology
preference before local exploration, then read `docs/AI_SLG_BEST_PRACTICES.md`
and the live progress ledger.

### Measured status at stop

- Compiler stabilization: **371/498 (74.50%)**; 126 candidate-fixed items are
  not promoted to complete.
- Current focused gate, C527 missing nominal member diagnostic SLG
  implementation: **0/1 (0%)**. Its build was canceled before validation.
- Current-goal Stage2/Stage3: **0/2 (0%)**.
- Frozen stdlib/runtime: **6/22 (27.27%)**.
- Structural phase closure: **0/7 (0%)**. The global interpolation proof and
  exhaustive current-source comparison are stale or pending.
- The live ledger is `scripts/contracts/active-goal-progress.json`. Do not use
  historical Stage2/Stage3 totals from an aggregate report for this goal.

### Completed focused work in this continuation

- C527 direct, nested, computed-initializer, and imported nominal struct
  literal receiver work before this continuation is detailed in the ledger and
  `artifacts/scratch/c527-struct-literal-expression-controls-20260929-01.json`.
- The C# parser now passes surrounding namespace and imports into a parsed
  interpolation fragment. `dotnet build src/Sollang.Compiler/Sollang.Compiler.csproj
  -c Release --no-restore -v:q` passed with zero warnings and errors. The SLG
  compiler carries the full nominal type path, resolves import aliases and
  exact module paths, and omits AST path wrappers from member-access IR.
- Imported alias positive, field-type error, and local namespace cases passed
  C# versus SLG **3/3** in
  `artifacts/scratch/c527-imported-struct-paired-20260929-01.json`. Full module
  path positive and unknown-type cases plus three retained controls passed
  **5/5** in `artifacts/scratch/c527-fullpath-paired-20260929-01.json` on the
  compiler at `C:\Users\dimohy\AppData\Local\Sollang\c527-fully-qualified-compiler-o1-20260929-02\compiler.exe`
  (SHA-256 `4AF80B4C65A2D17BC8BC6D2B4CEA3FBCD9DDD8F92A584D7EA2D87C894B90C693`).
  These proofs predate the final missing-member diagnostic edit.
- Retained fixtures 2112–2116 were added, with 2113 and 2116 as diagnostic
  fixtures. The root fixture-name check passed **1879/1879**; it does not count
  diagnostic fixtures. `docs/SPEC.md` and `docs/AI_SLG_BEST_PRACTICES.md`
  describe alias and complete-path constructor behavior.
- Source comparisons are
  `artifacts/scratch/c527-imported-struct-source-comparison-20260929-01.json`,
  `artifacts/scratch/c527-fully-qualified-source-comparison-20260929-01.json`,
  and `artifacts/scratch/c527-missing-member-source-comparison-20260929-01.json`.

### Open edit and canceled build

- C# first proved that `$((c527.shapes.Point { x: 5 }).missing)` reports
  `sollang: semantic error at 1:29: [module '<main>'] struct 'c527.shapes.Point' has no field or readonly computed member 'missing'`.
  The previous SLG compiler reported position `1:1` and member `.missing`.
- The current unbuilt source edits in `selfhost/semantic/diagnostics.slg` and
  `selfhost/llvm/emitter/diagnostics.slg` locate the actual member dot and name
  within the interpolation fragment. A malformed span has explicit S062 output.
  No current-source paired validation exists for this edit.
- The focused O1 build in
  `C:\Users\dimohy\AppData\Local\Sollang\c527-missing-member-compiler-o1-20260929-01`
  was interrupted with Ctrl-C at the user's stop request. Its runner exited 1;
  there is no build result or compiler executable, and the process check found
  no related child. The cancellation record is
  `artifacts/scratch/c527-missing-member-build-cancelled-20260929-01.json`.
  This attempt is **canceled and unverified**; use a new output directory.

### Next-session order

1. Inspect the live worktree, process list, ledger, cancellation record, and
   current source. Keep the previous 3/3 and 5/5 proofs scoped to their pinned
   source; do not count the canceled build.
2. Build the current SLG compiler in a new output directory with
   `scripts/build-focused-selfhost-compiler.ps1`, using the current Release C#
   compiler as seed and the pinned full-path O1 compiler above as formatter and
   cache seed. Keep independent build logs and result files.
3. Pair the missing-member probe
   `scripts/probes/interpolation/c527-fully-qualified-struct-missing-member.slg`
   against its C# first proof at
   `artifacts/scratch/c527-fullpath-missing-member-managed-20260929-01/result.json`.
   Require the exact position and member name above. Then rerun only affected
   alias, complete-path, local, and initializer controls on the new compiler.
4. If the focused unit passes, add a retained missing-member diagnostic fixture,
   update the relevant specification/guide text, and advance the ledger.
   Continue C# first source/behavior comparisons for remaining C527 units.
   Run the one exhaustive comparison and Stage2/Stage3 only after all units
   and structural phases close.

## 2026-09-29 STOP CHECKPOINT — READ THIS FIRST

The user explicitly requested a stop and a handoff to another session. Do not resume work in this session. The older checkpoints below are historical. Preserve the dirty worktree and all receipts; do not clean or reuse an output directory.

### Measured status at stop

- Compiler stabilization: **371/498 (74.50%)**. This is the current ledger's stabilized count, not the count of source comparison units.
- Current focused C613 gate: **4/4 (100%)**. Explicitly enumerated implementation units: **92/93 (98.92%)**; the remaining queued unit and final global closure are not complete.
- Stage2/Stage3: **0/2 (0%)**.
- Frozen stdlib/runtime backlog: **6/22 (27.27%)**.
- Structural phase closure: **0/7 (0%)**; historical source-hash closure: **0/9 (0%)**. The exhaustive current-source comparison has not run.
- The progress ledger is `scripts/contracts/active-goal-progress.json`; detailed parity is `scripts/contracts/structural-parity-detail.json`. Read these live files before changing counts.

### Proven C613 work

- The focused unit receipt is `artifacts/scratch/c613-result-propagation-semantic-owner-unit-20260929-01.json` (4/4). The managed-first gate was 5/5; v103 positive C#↔SLG controls 2/2; exact negative diagnostics 4/4. Read the receipt and `artifacts/scratch/c613-result-propagation-source-comparison-20260929-01.json` for evidence paths.
- Pinned v103 compiler: `C:\Users\dimohy\AppData\Local\Sollang\c613-result-propagation-managed-v103-20260929-01\compiler.exe`, SHA-256 `C467A93359E182780C255FEFF189A503BECD2C230E3E834FC5B5718E76BB201F`. Build receipt is in the same directory. The focused verifier is `scripts/verify-c613-result-propagation-semantic-owner.ps1`.
- C613 semantic ownership is implemented through `selfhost/semantic/interpolation_inference.slg`, `selfhost/llvm/text/context_prepare.slg`, `selfhost/llvm/emitter/context.slg`, `selfhost/llvm/emitter/diagnostics.slg`, `selfhost/llvm/text/foundation.slg`, and `selfhost/ir/interpolation.slg`. Numbered cases 2081–2085 cover positive and negative behavior. Do not reintroduce emitter-owned C613 decisions.

### Open gate and interrupted run

- `scripts/verify-interpolation-semantic-parity.ps1` still fails at line 457 because it expects an obsolete emitter-owned `intrinsicFlowResultBuiltinByNode[globalNodeIndex!]` source expression. Current ownership uses `interpolationFlowTypeByNode`; review and update the verifier from actual C# and SLG source decisions before claiming the global gate.
- `scripts/verify-structural-parity-detail.py` reaches `verify-context-fixture-source-closure.py --static-only`, which uses an old C583 receipt with 72 context fields. Current `EmitContext` has 89. Four direct fixtures (1000, 1100, 1126, 1290) now each initialize 89 fields; `python scripts/sync-emit-context-fixtures.py` reports zero missing. `scripts/refresh-context-fixture-source-closure.py` exists but has not generated a new proof because paired native fixture proof is incomplete.
- The first paired fixture 1000 attempt at `C:\Users\dimohy\AppData\Local\Sollang\c613-v103-context-fixture-1000-pair-20260929-02` hit its three-minute timeout; managed passed. The second serial attempt at `...\c613-v103-context-fixture-1000-pair-20260929-03` was interrupted on the user's stop request after about 13 minutes. Its managed artifacts exist, but no `result.json` or selfhost result exists. The runner exited code 1 after Ctrl-C. A process check at 06:12 KST found no related compiler/dotnet/clang/lld process. Treat the second run as **canceled and unverified**, not failed or passed; see `cancellation.json` in that directory. Do not resume that output directory.
- Historical source-hash claims for nine files do not match current sources. The inventory is `artifacts/scratch/c613-interpolation-source-hash-drift-audit-20260929-01.json`; source-hash closure is 0/9 until fresh current-source proofs are collected.

### Next-session order

1. Read this checkpoint and `docs/AI_SLG_BEST_PRACTICES.md` first. Inspect the live process list, dirty worktree, progress ledger, C613 receipts, and cancellation receipt. Keep completed focused proof separate from open global gates.
2. Diagnose fixture 1000's long selfhost compile from read-only logs/process evidence and current source before another costly run. If needed, use a new output directory with a supervised timeout and durable result; do not reinterpret canceled artifacts as proof.
3. Finish fresh paired proof for the 89-field EmitContext fixtures, then generate and verify current context fixture source closure. Repair the stale interpolation verifier to check the actual semantic decision path. Refresh all nine current source-hash proofs, then rerun structural parity detail.
4. Resolve the one explicitly queued implementation unit and each structural phase using C# implementation and focused C# proof first, C#↔SLG source comparison second, focused paired compile/run third. Only then run one exhaustive comparison, Stage2/Stage3, and frozen stdlib/runtime gates. Report each axis separately with completed/total and percentages.

## 2026-09-26 STOP CHECKPOINT — READ THIS FIRST

The user explicitly stopped this session and requested a handoff to another session. Do not resume compiler work in this session. Preserve all existing changes and result files. The 2026-09-24 checkpoint below is historical; this section is the latest state.

### Measured status at stop

- Compiler stabilization: **497/498 (99.80%)**; umbrella C385 remains open.
- Current focused C385 unit: **6/7 steps (85.71%)**; focused cases **4/5 (80.00%)**. The remaining step is semantic-phase diagnostic ownership. Identified units are 24/25; that count does not include unenumerated future work.
- Stage2/Stage3: **0/2 (0%)**.
- Frozen stdlib/runtime: **6/22 (27.27%)**.
- Structural C#↔SLG parity: **0/7 (0%)**. The final same-source-revision exhaustive comparison has not run.
- `scripts/contracts/active-goal-progress.json` is the progress ledger; `artifacts/scratch/compiler-implementation-parity-current-20260926-68.json` is the latest parity snapshot. Keep passing, failing, running, and unverified results separate.

### Worktree and processes

- At the stop check, `git status --short` showed **780 entries**. These preexisting and current changes are intentional work in progress; do not reset, clean, overwrite, or discard them.
- No active Sollang-related `sollang`, `dotnet`, `clang`, or `lld` process was found at the stop check. Recheck processes and result files before starting work in the next session.
- The project policy is **implement and verify C# first; compare C# and SLG source structure and logic; then implement and verify SLG in focused units**. Do one exhaustive C#↔SLG comparison only after all focused units finish.

### Evidence and exact limits

- The latest completed SLG candidate before the unfinished semantic edit is `artifacts/scratch/c385-and-logical-diagnostic-managed-seed-v68-20260926-02/compiler.exe`, SHA-256 `DACD1ED4AA7934F3CE5AEC889D200C9113CDEA589A09C320CF30460AB485C332`.
- The v68 focused pair result `artifacts/scratch/c385-logical-diagnostic-pair-v68-20260926-03/result.json` passed **3/3** C#↔SLG cases. Its positive native fixture 1562 passed **1/1** in `artifacts/scratch/expression-lowering-c385-and-selfhost-v68-20260926-01`; And AST→TypedIR coverage passed **1/1** in `artifacts/scratch/c385-and-expression-coverage-v68-20260926-01/result.json`. These are valid scoped v68 results, **not proof for the source edited after v68**.
- The C# semantic implementation and focused managed/native check were completed first. The source comparison receipt is `artifacts/scratch/c385-and-expression-source-comparison-20260926-03.json`; it records the remaining semantic-phase ownership difference.
- `scripts/verify-selfhost-compiler-contracts.ps1` **failed**: exact source closure fixture `1000-selfhost-partition-route-type-invariant` omits `sollang.compiler.syntax.source_decoding` and `sollang.compiler.syntax.unicode_identifier`. See `artifacts/scratch/c385-formal-exact-source-closure-20260926-01.json`. Do not report this static gate as passed.

### Unfinished edit at stop

- `selfhost/semantic/diagnostics.slg` contains a newly added `LogicalOperandDiagnostic` collector and `firstLogicalOperandDiagnostic`. It is **not wired into the compiler execution path** and has not been selfhost-built. Do not count it as an implemented parity fix.
- The scratch observation source `artifacts/scratch/c385-semantic-logical-inspect-20260926-02.slg` and native executable `...-02.exe` observed `failure=2,0,10,12,-25,56` for the right-invalid flow-result case. This proves only that the semantic type table can identify that operand and source offset 56 (2:23); other cases and integration are unverified.
- The scratch managed compile emitted **S001** in `selfhost/semantic/diagnostics.slg` near line 347: replace `UIntSize(0)` with `0`. Fix and review this partial source before a strict selfhost build. The current v68 executable predates this edit.

### Next-session order

1. Read this checkpoint and `docs/AI_SLG_BEST_PRACTICES.md`; recheck worktree, live processes, result files, and the progress ledger. Preserve all existing artifacts.
2. Keep the already verified C# behavior as the reference. Source-review the unfinished SLG semantic collector, fix its S001 warning, and run small semantic observations for both-invalid And/Or and the positive case before compiler integration.
3. Move the logical-operand diagnostic decision to the semantic phase before Typed IR lowering (`selfhost/llvm/text/context_prepare.slg` and the necessary emit context), then remove redundant emitter-phase decision code in `selfhost/llvm/emitter/diagnostics.slg`. Follow C# structure and first-invalid-operand behavior. Review source before each focused compile.
4. Build one new candidate in a unique artifact directory and run only the focused C385 pair cases, positive fixture 1562, and AST→TypedIR check. Record exact passing, failing, and unverified counts; then close the exact source-closure fixture failure.
5. Only after the focused compiler and structural work is complete, perform the one exhaustive C#↔SLG comparison, then Stage2/Stage3 and frozen stdlib/runtime verification according to the goal.

## 2026-09-24 STOP CHECKPOINT — READ THIS FIRST

The user explicitly requested a stop and a durable restart record. Do not
resume work automatically in this session. All running subagents were
interrupted. The candidate28 output-transaction process subsequently finished
with a structured focused result; a targeted process check found no remaining
candidate28/output-transaction process. Preserve the large dirty worktree and
all scratch results; do not reset, clean, or rerun an existing output directory.
The older checkpoints below are historical, not the current status.

### Current measured axes and exact boundary

- Compiler stabilization: **472/477 (98.95%)**, **5 open**. C476 is
  `candidate-fixed`, not closed; C477 remains open. Verify live counts with
  `scripts/show-project-progress.ps1` after any later ledger change.
- Current focused C477 proof under candidate27: **12/12 (100%)** = mutable
  binding 5/5, canonical rebind 6/6, same-scope regression 1267 1/1. These
  results do **not** prove candidate28/current source; C477 promotion was
  deliberately withheld after the Windows path changes.
- Current-change Stage2/Stage3: **0/2 (0%)**. Frozen stdlib/runtime backlog:
  **6/22 (27.27%)**. Do not promote either from compiler-focused results.
- The overall compiler-defect evidence validator is **not green**. A new
  read-only inventory examined **265/265** candidate/closed entries and found
  **18 affected defect IDs / 66 contract issues**, stable input fingerprints:
  `scripts/audit-compiler-defect-evidence.ps1` and
  `artifacts/scratch/compiler-defect-evidence-audit-20260924-02/result.json`.
  C424 is the first failure, not the only one; do not rewrite historical
  baselines to manufacture a pass.

### Verified candidate builds and focused results

- Candidate24 selfhost SHA
  `D50514A4DA8D34A8019F8F3E5CDA7DE38BDB75224D760ED622D02B6B971A5E13`
  established C476 strict negatives 10/10, positives 10/10, bounded ABI
  18/18, bounded parity 8/8, retained native controls 22/22 plus C471 trap
  1/1. Its C476 candidate evidence is in
  `scripts/contracts/evidence/C2026-09-24-476/candidate.json`; the old AS-US
  fingerprint there is a historical signal identity, not the candidate source
  fingerprint. C476 ledger is `candidate-fixed`. It does not claim the output
  alias, Stage2/Stage3, or global evidence validator gates.
- Candidate27 selfhost SHA
  `8EE65254010B70DBC2E387521A3CCB0213ED4308869222D52D5573047BDB30F0`
  passed current-source C476 strict 10/10 at
  `artifacts/scratch/c476-strict-negatives-candidate27-20260924-01/result.json`,
  C477 5/5 and 6/6 at the corresponding
  `c477-mutable-binding-candidate27-20260924-01` and
  `c477-canonical-rebind-candidate27-20260924-01` directories, and 1267
  1/1 at `c477-same-base-batch27-20260924-01`. Each focused result used stable
  inputs. The C477 mutable runner's PowerShell one-element-array argument
  collapse was fixed in `scripts/verify-c477-mutable-binding-parity.ps1`.
- Candidate28 combines output-parent safety and Windows W-path changes:
  `artifacts/scratch/c476-output-path-integrated-candidate28-20260924-01/compiler.exe`,
  SHA `331BB86E1DD8A6BA9DA160DDCE3ABC2AE5F4278ACD9D589A03E51ADB982C0C6F`.
  Its build result in the same directory reports stable input, warning/note 0,
  llvm-as 0, V004 0, no cache seed. Managed W build DLL SHA
  `F370942F6EDD3C42ED0568825F21A57E6A7793E9EE85DD0B4FF9E07C5D7E83E1`
  was copied to `artifacts/scratch/managed-output-path-w-candidate28-20260924-01`.
  Candidate28 output-parent gate **3/3** passed; output-alias deterministic
  cases **5/5** passed with the 8.3 alias **1/1 unverified** because the volume
  did not create a short name. Output transaction is `focused-passed` **4/13**:
  4 implemented focused cases passed, 9 contract cases were not run, and
  supplemental alias was not requested. Results are respectively
  `artifacts/scratch/c476-output-parent-candidate28-20260924-01/result.json`,
  `artifacts/scratch/c476-output-alias-candidate28-20260924-01/result.json`, and
  `artifacts/scratch/c476-output-transaction-candidate28-20260924-01/result.json`.
  Input start/end fingerprints match. No candidate28 C476 strict or C477 12-case
  rerun was performed before the stop.

### Active failure and remaining path boundaries

- The old candidate27 demonstrably mispublished `-o é.exe`: it exited 0 and
  printed `é.exe`, but created only `챕.exe` and `챕.exe.ll` under
  `artifacts/scratch/c476-output-alias-unicode-candidate27-20260924-01`.
  The host ACP is 949. The managed and selfhost owned-file/directory emitters
  were changed from A calls to checked UTF-8-to-UTF-16 W calls; the managed
  Unicode fixture and existing directory/atomic controls passed local native
  runs. `docs/SPEC.md` and `docs/AI_SLG_BEST_PRACTICES.md` now describe this
  bounded file/directory contract, not all Windows path consumers.
- The **integrated candidate28 Unicode paired gate is failed, not passed**:
  `artifacts/scratch/windows-wide-integrated28-20260924-01/result.json`
  records managed 1/1, selfhost not completed, `UNICODE_BUILD_EXIT`, stable
  inputs. Its selfhost stderr reports LLVM line 2705 `use of undefined value
  '@sollang_m64_s2'` followed by native linker exit 1. Diagnose the missing
  direct-call closure in this fixture before attributing it to W path behavior;
  do not treat the successful managed case as selfhost proof.
- Independent review found another actual path-identity gap outside the
  owned-file W migration: Windows `process.runToFile` uses CRT `_open` on raw
  UTF-8 bytes, configured process redirection uses `CreateFileA`, and the
  `file.mapText` diagnostic path also uses `CreateFileA`. A Unicode **parent
  directory** can therefore make stage claim (W) and emitter redirection (A)
  refer to different paths even if a Unicode basename test eventually passes.
  Add an isolated Unicode-parent output fixture and repair these process and
  mapped-text boundaries by one coherent path-encoding contract; do not claim
  full Windows path coverage from the owned-file fixture alone.
- Further observed limits, not current PASS claims: managed owned open/replace
  caps UTF-8 paths at 259 bytes while selfhost uses a 4096-byte buffer;
  directory enumeration `FindClose` return is unchecked in both emitters;
  `createExclusive` can leave a file after a successful create but failed
  close (already described in SPEC). Preserve these as separate contracts.

### Resume order

1. Confirm no active verifier processes, read this checkpoint and the actual
   candidate28 result files, then inspect the dirty worktree. Read
   `docs/AI_SLG_BEST_PRACTICES.md` before code. Do not resume an incomplete
   scratch directory as if it passed.
2. Root-cause the candidate28 selfhost Unicode fixture's missing
   `@sollang_m64_s2` definition. Keep the managed 1/1 and selfhost failure
   distinct. Make the focused Unicode gate pass with stable inputs and exact
   output/inventory; rerun the old RED comparison only if needed.
3. Cover Unicode-parent `runToFile` and related Windows process/file-map A
   paths as separate, explicit scopes. Validate original ASCII controls and
   Windows managed/selfhost parity. Resolve or explicitly retain the 259/4096
   and `FindClose` boundaries rather than hiding them in broad success.
4. Build a fresh integrated current-source compiler with a pinned managed DLL
   and zero warnings; rerun candidate28's parent/alias/transaction gates and
   C476 strict 10/10, C477 5/5 + 6/6 + 1267 1/1 under that **same** SHA.
   Only then consider C477 candidate promotion. Keep 8.3 unverified unless a
   real short-name fixture can be created.
5. Work through the 18-ID evidence-contract inventory without overwriting
   historical failed baselines. Complete the remaining compiler/frozen-runtime
   gates before supervised Stage2/Stage3 fixed-point verification.

Historical update: 2026-09-13 21:47 (Asia/Seoul)

## 2026-09-13 STOP CHECKPOINT — READ THIS BEFORE OLDER SECTIONS

The user requested a clean stop after the current focused work so another
session can resume it. The authoritative branch is `v0.5`; do not create a tag.
The lower historical sections remain useful provenance but are not the current
status.

### Current measured axes

- Compiler stabilization: **424/436 (97.25%)**, open **12**. The 08:28 KST
  baseline was 405/418 with 13 open, so the current delta is +19 stabilized,
  +18 registered denominator, and -1 open.
- Current focused Stage2/Stage3: **0/2**. Do not start the accumulated stages
  until focused source defects and planned source changes are complete.
- Frozen stdlib/runtime: **5/22 (22.73%) fully accepted**, **17/22 in
  progress**, **0 blocked**, **22/22 started**. Intermediate progress is tracked
  separately in `scripts/contracts/active-goal-progress.json`.

### Completed focused work in this checkpoint

- Instance-first migration advanced from 34/97 to **40/97**, leaving 57 debt
  entries. Concrete array owners such as `impl [UInt8]` are supported without a
  marker wrapper, allocation, copy, or name allowlist. HKDF five methods and
  SHA-512 digest migrated to natural array receivers. Managed/module-qualified
  receiver checks pass 6/6; migration contract passes 44/44; stdlib inventory
  passes 261 globals = 204 exceptions + 57 debt.
- Self-host array-owner support now shares `implOwnerTypeAst/implOwnerTypeId`
  across expression typing and ordinary-function lowering, and structural
  receiver lookup uses the canonical receiver type ID. Static self-host contract
  passes 11/11. The actual focused self-host gate remains **7/8**; fixture 1759
  must be rerun after disk space is recovered.
- QUIC QS6 natural direction/Result cleanup passes 5/5, natural Result contract
  18/18, and stream contract 20/20 fixtures. Actual current-source 1291/1297 is
  still 0/2 until a stable current compiler is available. A stale UInt16
  `encodeCertificateVerify` call was migrated to the instance form.
- ZIP `Decoder.deflate` now moves through one `takeDeflate` helper that repairs
  the field to `None` before transfer. ZIP analysis passed that old ownership
  failure; method-8 remains **5/8** until current-source semantic/O0 execution.
  No golden was fabricated.
- Child processes gained typed `SignalStatus`,
  `TerminationStatus.Exited/Signaled`, and
  `Child.tryWaitTermination(mut)`. The existing `tryWait` is a projection over
  the same single poll/reap authority. Focused Child gate passes 6/6, contract
  37/37, extracted kill/runtime gates 24/24 and 12/12, Windows tryWait runtime
  10/10, and Linux runtime 16/16. Remaining capability gaps are wait/I/O
  timeout, forced-request attribution, and public pipe handles.
- Async task observability gained a 13-case managed matrix, result schema, and
  corrected bounded/capacity/Busy-close/session-reuse/use-after-close fixtures.
  Input/schema validation passes 13/13 with positive 1/1 and mutation controls
  7/7. Official current-source single-run progress remains **4/13**; distributed
  current-source evidence is 9/13 and isolated behavior is 13/13. Do not raise
  the official numerator until one stable-input run completes all 13 cases.

### Fail-closed execution records and exact resume order

1. Recover disk space first. P: had only about **108 MiB free** at stop. Large
   disposable failed-run work directories include
   `artifacts/scratch/selfhost-array-inherent-1260ab692362452187281123ec06809a`
   and `artifacts/scratch/selfhost-array-inherent-00e2b6ba98cc469dab2792ba476d4bae`.
   Preserve their sibling durable `.log`, `.log.stderr`, `.result.json`, and
   `.launch.json` files before deleting only the verified scratch directories.
2. Run exactly one new-ID focused array gate for fixture 1759 through
   `scripts/invoke-detached-selfhost-verification.ps1 -Verification ArrayInherent`.
   The latest v8 supervisor ended without publishing its required result JSON;
   its durable log/stderr/launch files make that run invalid, not passed.
3. Independently repair the pre-existing portable-memory focused defect
   `binding 'available' has inconsistent ownership across async branch paths in
   'std.io.async.readMemoryInto'`. Do not rerun broad Incremental verification
   until its narrow probe passes.
4. With one stable current managed compiler/input fingerprint, complete the
   async observability 13-case matrix in one structured run.
5. Reuse that stable compiler for ZIP semantic/O0 and QUIC 1291/1297 focused
   actual gates. Only then continue the remaining stdlib/runtime capabilities.
6. Final accumulated Stage2/Stage3 remains the last promotion step, after all
   focused defects and source changes are complete.

### Last integrated lightweight verification

- PASS: self-host array contract 11/11; module-qualified receiver 6/6;
  instance migration 44/44; stdlib instance policy 261/261 with stale 0;
  QUIC natural Result 18/18; QUIC stream contract 20/20 fixtures; Child
  termination/tryWait contract 37/37; Child kill contract 24/24; async static
  contract 14/14; async managed matrix inputs/schema 13/13; project-progress
  contract; `git diff --check`.
- No full Stage2/Stage3 was run. No tag was created.

## LATEST CHECKPOINT — READ THIS FIRST


### Current integration checkpoint

- Active compiler/stdlib goal: finish Windows through final Stage3, then Linux,
  then WASM. Ledger **107/286 (37.4%) closed, 179 candidate-fixed, 0 open**.
  Current-change Stage2/Stage3 **0/2**; frozen stdlib/runtime **4/22 (18.2%)**.
- C275 fixes enum payload block-result ownership and named subject invalidation.
  Managed focused4/4 + subject-reuse negative1/1; native1422 1/1.
- C276 distinguishes direct owned field paths in one aggregate and returns
  distinct root owners for consumption. Managed6/6, native1423 1/1. Separate
  mutation calls retain root exclusion. Nested projection admission is unchanged.
- C277 fixes all three region lexical-root interpolation branches to use the
  existing direct-each role writer before parameter/local resolution. Native
  1424 + original1404 **2/2**. Focused actual same-input baseline/candidate receipts
  recorded; prior combined baseline retained under combined-*.
- C278 preserves completed control prefixes feeding later flow targets and
  restricts postfix-arm repair to regions containing an actual Try IR node24.
  Without that witness, repair replaced a real Result constructor with a nested
  match. Native1425/1413/1419 **3/3**, combined frozen1424/1425 candidate **2/2**.
  Speculative terminal-token/span guards were removed after they did not fix the
  cause. C275–C278 are candidate-fixed with promoted traces; not closed.
- C263 normalization is integrated into SourceAnalysis/PackageAnalysis/EmitContext.
  Source-ranged sparse Long literals feed emission. Failure captures byte spans
  before consuming AST owners and emits S055. Prepared resolution/type-term/
  canonicalization APIs borrow tables directly; five whole-table copies removed
  from analyzeSource. ResolutionRequest/TypeTermRequest removed, SubstitutionRequest
  retained. 461 affected current source closures received four constant modules.
- Expanded numeric siblings must follow normalized AST order. Reused selector
  source offsets first lost duplicate elements, then grouped dictionary keys
  before values. The current patch in both main/function sibling linking orders
  numeric literal siblings of IR array14/dictionary16 by AST identity. The newest
  build c263-pair-order-driver.exe passes native75/1419/1426 **3/3**.
- Fixed-array interpolation now distinguishes local pointer/length carriers from
  inline field/call results and value parameters. 439 and projected1186 PASS.
  The remaining75 failure moved from array ABI to missing dictionary interpolation.
- Dictionary interpolation is implemented in foundation.slg using existing Set
  hash/equality emitters, canonical layouts, a bounded scalar probe, empty guard,
  and missing-key trap. Native/managed1426 **1/1 each** covers mutable integer
  entries, explicit borrowed parameters, and Text keys. The c263-dictionary driver
  assembled75 but trapped because expansion sibling order was still keys-first;
  c263-pair-order fixes that separate ordering defect and passes all three controls.
- C263 is candidate-fixed with fresh original1404 baseline/candidate receipts.
  The historical baseline input incorrectly mixed grammar implementation hashes
  with fixture inputs; legacy receipts are preserved. The corrected immutable
  source/stdout contract has fingerprint ED072103F7BB1E83C7B4FE03E62FFFBECED3F2A8755F624073F0FD0C707A2E39.
  Actual native nonconstant compilation exits1 with source-located S055.
- Most recent fully built driver:
  artifacts/scratch/windows-completion/c263-pair-order-driver.exe (7,318,016 bytes).
  C278 proof binary: c278-postfix-driver.exe (7,266,304 bytes). All are managed-built
  SLG, not Stage3 seeds. Managed builds have0 warnings/errors. Shared contracts PASS
  compiler-contracts-c278.log; ledger PASS ledger-c278-candidate.log. Default source
  preflight now passes146/146 including1426 (c263-final-preflight.log).
- Full managed regression finished with eight jobs: **1348/1703 PASS (79.2%),
  355 failures** before C279/C280. Log:
  artifacts/scratch/windows-completion/windows-managed-full-c263.log. Use
  scripts/summarize-example-test-log.ps1 for a fresh bounded report; snapshot
  counts in messages are not final results. It opens the active log with shared
  read/write access and records a hash of the observed UTF-8 text.
  Failures include LLVM stdout differences, warning-zero violations, missing
  source closure inputs and real compiler errors. Do not bulk accept snapshots.
  Failure groups: stdout mismatch216, warnings/notes105, compiler exit14,
  executable exit1 nine, missing expected diagnostics5, expected-failure mismatch3,
  abnormal executable exit2, LLVM contract1. No bulk snapshot acceptance.
- C279 fixes readonly enum payload address forwarding: writeReferenceRootAddress
  now uses existing referenceRootValueIndex instead of operand0. Native1427 1/1,
  managed1427 1/1; original537/550 extracted inner programs compile and run with
  output40/observed=40. Same-input real baseline/candidate receipts preserved.
- C280 fixes managed readonly reference arguments to mutable scalars: borrow the
  existing scalar slot instead of materializing the stale initial RuntimeValue.
  Original repro assigned39->40 but read39. Managed1428 1/1 and existing reference
  controls plus1427 4/4 pass; native1428 1/1. Release build0 warnings/errors.
  Both C279/C280 are candidate-fixed with promoted evidence, not closed.
- Latest native proof driver is c279-reference-driver.exe (7,318,528 bytes),
  built before the separate managed C280 repair. It is not a verified Stage3 seed.
  Default native/Stage2/Stage3 selectors now include1427 and1428; rerun preflight
  for148. Full managed suite must be rechecked after remaining failure causes are
  fixed; the previous355 failures must not be reported as currently all resolved.
- C263 synthetic invariant contexts now initialize the new literal/failure tables
  and source range spans. Original1000/1100/1126/1290 managed controls pass4/4.
  Missing source manifests for1237/1238/1260 were restored from existing smallest
  matching closures; all3 pass. Fragment inventory updated for these three new
  manifests and passes29 fragments/605 manifests.
- Source closure now reads only the SourceFile module preamble using
  scripts/source-module-header.ps1. Embedded raw-string sample imports were false
  dependencies and embedded namespaces could satisfy real imports. New positive
  and negative controls cover both, plus library strings/comments; contract PASS.
  The two module-read loops avoid the typed SourcePath parameter name collision.
  Last default preflight148/148 PASS before1429/1430; now recheck150.
- C281 tap side-call linkage is candidate-fixed. Baseline1429 fails V001 (one expected
  argument, two linked: source14.nextOperand points to tap15). Managed1429/1430
  both pass. A candidate shares bindTapStageInput between ordinary/main lowering,
  prepends the input to explicit arguments and makes the final side stage the
  tap dependency instead of using nextOperand as stage sequencing. Candidate
  c281-tap-driver.exe failed2/2 because later sibling linking overwrote the new
  edges. The corrected c281-tap-links-driver.exe preserves exact side-call input
  edges and passes1429/1430 native2/2. Frozen1429 candidate receipt and promoted
  trace are retained. Additional controls75/1419/1427/1428 pass4/4;1288 fails with
  array-vs-pointer capture store LLVM. The preceding c279-reference-driver fails
  identically at LLVM line64645, so this is a separate existing compiler-as-input
  defect. Preserve c281-controls-native and c281-1288-before-native artifacts.
- C282 managed dyn reachability is candidate-fixed: conversion methods become
  reachable through the existing function scanner, and unused conversion tables
  are omitted.1431/1432 managed2/2 pass, including dead implementation exclusion.
- C283 is candidate-fixed. Native1431/1432 both pass direct closure, LLVM
  contracts, assembly, and execution using c283-target-path-driver.exe (7,301,120
  bytes,3509 functions). Its build log is c283-target-path-build.log; native proof
  is c283-target-path-native.log. The earlier c283-path-driver.exe was built before
  the AST patch (a Python syntax error prevented that edit); do not use it as proof.
  Candidate1431 receipt and promoted trace are recorded. No final Stage2/Stage3.
- S047 was a trait classifier scope defect: whole-expression identifier scanning
  interpreted quic's nested frames.Value.HandshakeDone as dispatch to user trait
  Value. directFlowTargetPath in typed.slg now supplies the exact direct Path token
  range to ordinary and entry dispatch lowering. Native1432 passes unchanged with
  full stdlib. Native source39 is quic.slg under source_root's UTF8-sorted BFS;
  c283-native-source-order.txt records that derived order. A sorted-source IR dump
  independently shows the contaminated quic node opcode-226 at AST7461.
- C284 is candidate-fixed. repairNamedFlowReceiverCallPlans now gives an
  existing exact role receiver the canonical source element type, guarded by
  resolved name AST and symbol identity. This fixes argument ordinal shifting
  without weakening parallelRoleMatchesSourceType. Fixture1433 is the frozen
  15-reference reproducer; managed1/1 and native1433/1320 2/2 pass. Original1288
  compiler-as-input also passes closure, assembly and execution (58 sources).
  Driver:c284-role-driver.exe,7,302,656 bytes. Evidence:c284-role-build.log,
  c284-role-native.log,c284-managed.log,c284-original-native.log. Baseline/candidate
  receipts and promoted trace are in evidence/C2026-09-05-284. Ledger validator
  passes; native/Stage2/Stage3 selectors include1433; input preflight153/153 passes.
  Common compiler contracts pass in c284-compiler-contracts.log.
- C283 controls1429/1430 pass2/2. Its earlier1320 failure was resolved by C284;
  retain both old failure and current execution proof.
- C285 is candidate-fixed. LlvmEmitter.Flow.cs uses the same exact standard
  library printer-wrapper resolver in the multistage loop and direct fast path.
  Effective printer kind preserves terminal-position and zero-argument checks.
  Managed1434/1435/1436 pass3/3; native1434 and1436 pass2/2 using c284-role-driver.
  User Printer.print instance method returns17, proving it was not intercepted.
  Nonterminal println and extra-argument println are rejected; global print is
  a reserved name and is not a valid user-shadowing positive control.
  Receipts, promoted trace and candidate ledger entry exist for C285; ledger
  validator passes. c285-baseline-compiler is an isolated baseline build of the
  exact pre-fix Flow.cs, with candidate source restored in finally. Main/test
  binaries retain candidate behavior. Managed build warnings/errors0/0.
- C286 is candidate-fixed. Native1435's missing dyn dispatch was caused by
  assuming AST children follow their parents. Synthetic multistage prefix63 owns
  earlier Path61. SemanticSnapshot.directFlowTargetPathByAst now indexes parent
  identity once for all sources; four snapshot producers initialize it and both
  ordinary/entry lowering query it in constant time. The old per-expression
  ordering-based helper was removed. No wall-clock speedup claim yet.
  Driver:c286-index-driver.exe (7,371,264 bytes); build:c286-index-build.log.
  Native1431/1432/1435/1436 pass4/4 in the FIRST candidate receipt execution.
  Native1288 also passes under the new shared context layout: c286-context-native.log.
  Candidate1435 IR23 is nowkind9/opcode-225 (c286-fixed-ir.log).
  Baseline receipt preserves the previously executed c285-native failure; see
  baseline-provenance.md for its session69887 origin, not a new baseline rerun.
  Trace promoted, ledger validator passes, input preflight156/156 passes.
- Existing managed full-suite failure261 was migrated from removed global
  milliseconds to std.time.milliseconds(1), matching the Result<Duration,Error>
  and instance sleep/await contract. Error construction remains observable.
  Managed261/1066 pass2/2 in c286-time-api-controls.log. Async scheduler proof is
  managed only; do not use blocking native sleep as a replacement.
- Trait scan guard optimization was MEASURED AND REVERTED. Plan/results live
  in artifacts/scratch/windows-completion/trait-scan-measurement.130 frozen sources,
  identical full Typed IR SHA256, one IR warmup per binary then3 alternating
  timing pairs. Baseline median16.0623446s, candidate16.1202266s (-0.3604% gain),
  below the predeclared1% improvement threshold. Both added module-loop guards
  and their new guide requirement were removed. Keep the proven C286 parent
  index; c286-index-driver.exe remains the verified implementation. Do not claim
  speedup or use trait-scan-guard-driver.exe as the accepted compiler.
- Generic inherent methods are IN PROGRESS; no ledger closure or stdlib unblock.
  Managed fixtures1437/1438/1439/1440 pass individually: explicit Int, inferred
  Int/explicit Long and Text, trait constraints, two-owner scope isolation.
  Negative scratch inputs reject explicit Int vs Long and missing Measure trait.
  Existing managed1436/663/67 controls pass. The attempted diagnostic --exact
  names did not select diagnostic fixtures (denominator2); do not claim4 controls.
- Changes: ParserSourceGenerator removes the explicit generic impl rejection;
  MethodDeclaration grammar includes GenericParameterClause and GenericWhereClause.
  StructLiteralExpression permits an empty field list (managed already did).
  Generated grammar was regenerated with the managed grammar build command.
  SemanticCompiler validates generic parameters appearing in additional inputs;
  ResolveGenericFlowSpecialization infers from receiver AND additional arguments,
  respects explicit types, contextualizes resolved parameter types and preserves
  the concrete receiver type. LlvmEmitter.Flow prioritizes resolved specializations
  before looking up the unspecialized instance method.
- Native ast.slg stops method-name extraction at Less as well as Colon; type_ids.slg
  admits kind31 methods as generic type-parameter owners. Latest driver:
  generic-method-owner-driver.exe (7,371,776 bytes). Native1437 originally passed with42;1438/1440
  attempt to pass Text aggregates as i8;1439 emits undefined %v99517 in the
  constrained method body. All failures are in generic-method-owner-native.log
  and its output directory. Investigate native per-type method specialization
  and trait-bound body lowering next, preserving the meaningful failing fixtures.
  Earlier generic-method-driver/empty-driver failures and logs are retained.
- Managed build latest generic-method-context-build2.log has0 warnings/errors.
  Native driver predates that final managed literal-context adjustment but its
  SLG source includes the native method-name/owner fixes. No Stage2/Stage3 proof.
  Fixtures1437-1441 are now in focused native/platform inventories while failing.
  Last completed global preflight remains156 inputs; current default list has161.
- Stronger ABI baseline:1437 now uses300 and native returns44 (i8 truncation).
  New1441 instantiates ordinary identity<T> with Int300 and Text in one program;
  native emits one Text signature but an Int call with `%sollang.text 300` and
  fails LLVM assembly. Typed IR subsequently disproved shared-template mutation:
  `generic-function-abi-ir.log` nodes99508-99511 retain canonical type918,
  kind1/origin3/module129/symbol1; calls99515/99517 correctly have Int2/Text1.
  `ownership.slg:writeSemanticTypeId` sends every non-nominal kind1 through its
  builtin-symbol branch, so generic symbol1 becomes Text and symbol3 becomesi8.
  No call-order conclusion is justified by these outputs. Native per-instantiation
  signature/body/call identity is still missing.
  `generic-concrete-abi-managed.log` passes2/2 (changed1437,new1441); together with
  unchanged1438-1440, managed focused coverage is5/5. Native current coverage is
  0/5, not1/4. First native executions and retained LLVM are under
  `artifacts/scratch/windows-completion/generic-concrete-abi-native`; batch log
  has fixture failure summaries, final process output reports expected300/actual44.
  No compiler rebuild was needed for this baseline. This is root-cause evidence,
  not a compiler fix, ledger closure, measured speedup or stdlib completion.
- Generic scalar ABI fail-fast is implemented separately from specialization:
  `unresolvedGenericAbiNode` in llvm/text/invariants.slg uses actual reachable
  functions, excludes intrinsic and dedicated stream/block templates, and checks
  canonical kind1/origin3 on emitted function returns and parameters. Both the
  diagnostic count and diagnostic output invoke that same predicate before LLVM
  headers/emission. Native1437 and1441 now exit1 with S047 and create no executable;
  their retained `.exe.ll` files contain the diagnostic, not LLVM definitions.
  Native1436-user-printer-method-flow still passes closure/assembly/execution.
  Evidence: generic-abi-invariant-native.log and its same-named output directory.
  These are2/2 expected diagnostic controls plus1/1 positive control, not generic
  feature passes. Compiler ledger and stdlib completion counts are unchanged.
  Candidate build initially emitted N001 for the guard's long while condition.
  Only its line wrapping was corrected; generic-abi-invariant-build-clean.log
  finishes exit0 with no warnings/notes/errors, reusing78/81 codegen units and
  3021/3510 semantic functions. Latest driver is7,227,904 bytes. Native controls
  above preceded that formatting-only rebuild; no runtime logic changed and the
  passing controls were not rerun solely for new receipts.
- Native specialization integration points established from source/IR evidence:
  context_prepare.slg:prepareSnapshot resolves recursiveTypes then calls
  lowerPreparedIr before stream/ownership/layout preparation. Typed IR retains
  the template correctly. core_calls.slg:targetFunctionIndex and
  invariants.slg:concreteFunctionsBySymbol currently choose a single IR function
  per original module/symbol; text.slg:emitCore emits each reachable kind0 once.
  Merely changing writeSemanticTypeId or a call result type cannot specialize
  signatures, bodies, reachability and callees. Preserve origin identity and
  introduce explicit per-instantiation identity through those consumers.
- User explicitly reported slow progress. Apply the guide's first-run receipt
  rule now: one execution is both focused proof and receipt, never an extra
  passing rerun for bookkeeping. Batch ledger/handoff updates after results;
  retain focused root-cause work and useful companion work during builds.
  Do not claim a measured speedup before observing it.
- During C284 builds the portable I/O backlog was audited against readInto:
  a partial-read loop cannot guarantee transactional exact reads for streams.
  STDLIB_EVOLUTION.md and AI_AGENT_GUIDE.md now require checkpoint capability or
  explicitly bounded replay staging, preserving caller bytes and logical reader
  position without claiming physical stream rollback. Adapter implementation
  and short/error/retry/pre-read-limit fixtures remain pending; stdlib stays4/22.
- Defaults include1431/1432/1433 (153 inputs). Final Windows Stage2/Stage3 remain0/2;
  Linux/WASM have not started. Continue Windows implementation first.
- Historical C273 receipts predate1419's Failure API change. Do not claim current
  source matches that old13-input snapshot. Audit lower's error-propagation owned
  input cleanup: an earlier omission was suspected, not minimized/proven as a leak.
- Full native775 compiler-as-input remains unverified from the prior interrupted
  attempt. No Linux/WASM work has started. All active goal axes remain incomplete.

### Historical C274 snapshot

The broader compiler/stdlib completion goal is now active. Follow
`COMPLETION_PLAN.md`: finish Windows implementation and final Stage3 before
starting Linux, then WASM. The prior ownership slice below remains complete.

Current ledger: **107/274 (39.1%) closed, 166 candidate-fixed, 1 open (C263)**.
Current-change Windows Stage2/Stage3 is **0/2 pending**; frozen stdlib/runtime
is **4/22 (18.2%)**. The full goal remains active; Linux/WASM has not started.

Latest continuation: C272/C273/C274 are candidate-fixed, not closed.

- C272 fixes managed flow ownership accounting and LLVM cleanup: only the
  first target receives the initial source place. Later move targets consume
  the preceding result. Fixture 1420 covers local and parameter reuse; managed
  ownership controls and negative diagnostics pass 6/6. Same-input real
  baseline/candidate receipts and promoted trace are retained.
- C273 restricts interpolation binding lookup to lexical names with a resolved
  nonnegative symbol. A projected array's absent symbol no longer matches an
  unnamed scalar temporary. C274 then fixed the separately exposed double-free
  in 1419's no-expansion early-return branch.
- C274 makes early whole-parameter cleanup observe the existing path ownership
  bit. ASAN first proved a 224-byte AST array was freed in `lower` after transfer
  and freed again by its receiver. Original 1419 now passes exact native output
  and ASAN exit 0. Fixture 1421 requires guarded-drop LLVM and executes both
  transfer/retention branches. 1354/1340/1410/1411 ownership controls pass 4/4.
- `selfhost/semantic/constant_collection_lowering.slg` is a proven C263
  prerequisite, not yet integrated into SourceAnalysis. It preserves element
  order, removes expanded subtrees through an indexed child graph, relocates
  parent identities, and stores computed Long literals separately from source
  tokens. Fixture 1419 proves mixed arrays/dictionaries, empty/plain cases,
  spans and typed failures. Its current Error still carries original AST
  indices; integrate source-located errors before consuming the AST owner.
- Latest binary: `artifacts/scratch/windows-completion/c274-candidate-driver.exe`
  (7,125,504 bytes), managed-built SLG, not a Stage3 seed. Keep C273 for baseline
  comparison. Shared contracts PASS `compiler-contracts-c274.log`; ledger PASS.
  Default native input preflight passes **141/141** after adding 1419–1421 to
  both formal stage selectors and the default native plan. Execution remains
  focused only. There are no live build/test sessions at this checkpoint.
- Evidence: `scripts/contracts/evidence/C2026-09-05-{272,273,274}/`.
  C273's failed first candidate is retained as `candidate-before-c274.*`;
  its final candidate passed the unchanged 13/13 frozen inputs. C274 matched
  3/3 frozen inputs. C272's comparison script restored exact current source
  bytes after rebuilding the baseline; no worktree reset was used.

Earlier C269/C270/C271 checkpoint (retained as historical evidence):

- C269: preserved module-local Range identity, retained and sealed exact each
  role reads, removed nearest-arm member rebinding without matching symbols,
  shared direct-each emission across main/functions/control arms, ordered body
  statements, and made postfix propagation consume the merged Result.
  Unchanged 1413 input bytes matched the frozen 12/12 hashes at candidate
  recording. Its real candidate receipt passes. The C269 snapshot passed
  managed/native 1413/1414/1415/1417/1366 **5/5 each**.
- C270: BlockFunctionCallStatement now uses RangeExpression instead of an
  inline range production which erased the AST range node. Original 847
  passes natively; 670, 1413 and 1415 controls pass. The broader 4/5 run retains
  the known C263 failure in 1404 (collection expansion is still unwired).
- C271: an exactly resolved function returning Result/Option can no longer be
  reclassified from an earlier enum-constructor token. Main and ordinary
  function controls 1416/1418 pass managed **2/2**; native
  1416/1418/1417/1415/847 pass **5/5**.
- Baseline/candidate receipts and shaping traces are under
  `scripts/contracts/evidence/C2026-09-05-{269,270,271}/`.
  C269 inputs use raw-byte hashes; C270/C271 explicitly use canonical UTF-8/LF.
  Do not replace or reinterpret historical fingerprints. The later C270 grammar
  change naturally changes 1413's generated-grammar input; the C269 receipt
  remains proof of its recorded earlier snapshot.
- Earlier focused binary: `artifacts/scratch/windows-completion/c271-candidate-driver.exe`.
  Preserve C268, C269-role and C270 binaries for reproducible comparisons.
  These are managed-built SLG candidates, not published Stage3 seeds.
- Shared contracts PASS: `compiler-contracts-c271.log` in the completion
  scratch directory. Ledger validation passes. Stage2/Stage3/default native
  selections include fixtures 1413 through 1418; preflight must be rerun for
  the expanded selection. No full native-suite pass is claimed.
- The native 775 compiler-as-input build was deliberately stopped after more
  than six minutes so known small failures could be fixed first. It has no
  completed result and must be rerun; do not count its interrupted exit -1 as
  a language defect or a passing reference-array gate.
- Use existing driver `ast-nodes`, `typed-ir-nodes`, `typed-ir-calls`, and
  `qualified-resolutions` with ordered source paths before building new
  embedded-source probes. This removed repeated diagnostic rebuilds during
  C270/C271 analysis. `AI_AGENT_GUIDE.md` documents this inspection route.

Next: integrate C263's proven constant-collection product into SourceAnalysis,
canonical collection types and literal emission, retaining source locations
and explicit computed values. Fixture 1404 still reports S007 on the
comprehension result. Do not rewrite user sources or encode values as token
indexes. Then continue the complete frozen stdlib/runtime scope and perform
final Windows Stage2/Stage3 before Linux and WASM.

Previous checkpoint (historical, before C269 repairs):
Current ledger then: **107/269 (39.8%) closed, 160 candidate-fixed, 2 open**.
Windows current-change Stage2/Stage3 remains **0/2 pending**; the preceding
2/2 fixed point is historical evidence. Frozen stdlib/runtime **4/22 (18.2%)**.
The broader goal is active. Linux/WASM execution has not started.

Latest continuation: C263/C269 are OPEN; C267/C268 remain candidate-fixed.

- Added AST kind 83 for the existing `CompileTimeEachExpression` grammar rule.
  A live shape probe confirms distinct range and selector children beneath it.
- `selfhost/semantic/constant_collections.slg` now expands one range/each element
  into Long constants carrying original AST node identities. It covers array
  values and dictionary key/value pairs, named/implicit items, inclusive and
  half-open ranges, and source-located expression failures. Ascending bounds
  and the 100000-element limit are checked before allocating expansion values.
  Empty ranges do not evaluate selectors, matching the managed parser.
- Fixture 1413 passes managed exact output, including both 100000-element
  boundaries, maximum Long, overflowing range distance, descending bounds,
  nonconstant expressions and selector arithmetic overflow. Current managed
  controls 1413/1410/1405/1404/75 pass **5/5**.
- Native 1413 fails **0/1** with S017/S031; do not claim native expansion parity.
  C269 freezes the exact 10-source input manifest plus expected output, the
  actual native baseline command, and diagnostics under
  `scripts/contracts/evidence/C2026-09-05-269/`. Do not rename the local Range
  or flatten the Constant record merely to evade the failure.
- The first diagnosed issue is a local `constant_collections.Range` returned
  through Result being typed as builtin Range (type 25). Review builtin-first
  annotation resolution in `semantic/type_ids.slg` around 440 and the older
  projection in `semantic/nominal_types.slg` around 91. The managed parser's
  reserved builtin list excludes Range; its std.sequence.Range alias is an
  explicit runtime identity. Preserve actual builtin range behavior while
  fixing declared local type identity. S031 on `value.sourceNode` may require
  a separate element/projection fix after the Range identity is corrected.
- Current shared contracts PASS:
  `artifacts/scratch/windows-completion/compiler-contracts-c263-collections.log`.
  The ledger validator passes. Native default input preflight passes **133/133**,
  not execution. Stage2/Stage3 and default native selections now include 1413.
- The expansion product is NOT yet wired into SourceAnalysis, collection type
  inference or LLVM literal emission. C263 stays open. Preserve original
  source spans and source-local indexes when integrating computed constants;
  do not encode numeric values into token indexes or rewrite source text.

Next: repair C269 with focused nominal/projection controls, prove native 1413,
then integrate C263's computed values into canonical collection typing and
literal emission. Current focused compiler binary remains the C268 candidate
listed below; rebuild from current SLG sources after the semantic fix. All
runs from this continuation are terminal; no live wait handle remains.

Previous checkpoint: C267/C268 are candidate-fixed; C263 remains OPEN.

- `semantic/constant_expressions.slg` now compiles a real AST subtree into
  checked Long instructions and reusable value slots. Reverse dependency order
  handles appended synthetic binary nodes; one-child precedence shells remain
  transparent. Fixture 1410 covers arithmetic, repeated item evaluation, exact
  source spans and repeated evaluation after overflow/division failure. The
  managed fixture passes. Actual collection AST expansion is still unwired.
- Native 1410 initially exited with heap corruption (-1073740940). Retained
  LLVM explicitly freed both arrays of a borrowed `mut self` receiver on its
  error return. `llvm/text/control_regions.slg` now requires move ownership
  before partial-parameter cleanup, consistently with complete cleanup.
  Same-input native 1410 and bound receiver control 1411 pass **2/2**; existing
  ownership/nested-Result controls 1399, 1400 and 1384 pass **3/3**.
- Native 1412 initially failed: direct
  `if { Result.Err } else { Result.Ok } -> when` emits the real if result but
  refers to an undefined SSA subject. Its bound-subject control 1411 passes.
  This separate issue is C268. The final control-shell pass now reseals only
  the exact linked following match to its validated direct control producer.
  The actual IR probe changed match node 27's subject from wrapper 39 to
  concrete control 20; no caller rewrite or LLVM-only repair is used.
- Final current-candidate managed and native suites both pass **7/7**:
  1410/1411/1412/1384/1399/1400/1397. Shared compiler contracts PASS in
  `artifacts/scratch/windows-completion/compiler-contracts-c268-final.log`.
  The ledger validator also passes after recording both candidate receipts.
- C267/C268 baselines, exact inputs, LLVM and execution/assembly receipts are
  under `scripts/contracts/evidence/C2026-09-05-267/` and `...-268/`.
  Scratch guard/trace LLVM was diagnostic only; never promote it as a compiler
  fix. C267's uninstrumented candidate is the passing native execution proof.
- Current focused candidate: `artifacts/scratch/windows-completion/c268-candidate-driver.exe`.
  It was built from SLG sources using the managed bootstrap, with no warnings;
  it is neither a Stage3 seed nor final self-host proof. Keep the earlier driver
  and published Stage3 intact. Current formal Stage2/Stage3 remains **0/2**.
- Stage2/Stage3 selections and the default native plan include 1410-1412.
  The default plan input preflight passes **132/132**; that is not full native
  execution. `verify-struct-field-migration.ps1` reviews the plan's two private
  fields, which protect instruction topology and scratch-slot invariants.
- Earlier contract failures are retained: the new plan's private fields needed
  explicit inventory review, and the partial-cleanup assertion needed the new
  move-ownership guard. Both contracts were updated without weakening the
  behavior checks; the final shared contract run passes.
- All runs from this continuation are terminal. No active compiler or wait
  session needs polling. Do not restart an already completed candidate build.

Next: continue C263's expanded constant representation,
source-located diagnostics and array/dictionary lowering. The relevant final
control-wrapper normalization is in `ir/typed/resolved_context_seal.slg` near
1902; the C268 same-input before/after IR evidence is retained. Continue stdlib's frozen
22 contracts only within the Windows-first completion order. Linux/WASM remain
unstarted. No global completion or measured speedup has been established.

Previous continuation: C265/C266 are candidate-fixed, not closed. Its focused
managed examples pass **8/8**, native 1406/1407/1408 pass **3/3** and native 1409
passes **1/1**. Shared compiler contracts pass (`compiler-contracts-c266-final.log`).
The default native plan now contains **129 fixtures**; input-only validation
passes 129/129, which is not a full native batch result. Stage2 and Stage3 exact
selections include fixtures 1404 through 1409. All runs from this continuation
are terminal; there is no pending wait handle to restart or poll.

- `selfhost/semantic/constant_integer.slg` now provides explicit checked signed
  64-bit arithmetic (Long). Fixture 1406 covers 20 exact boundary, sign, overflow
  and zero-divisor cases; both managed and native execution pass. This kernel
  is not yet connected to the collection expansion consumer. C263 is still OPEN.
- C265: managed enum constructors, patterns and ownership classification now
  use shared `TypeDefinitionTable.TryResolveInModule`, also used by LLVM enum
  emission. Local bindings retain precedence. Fixture 1407 tests a module-local
  Error enum against an unrelated root Error, payload and payloadless creation,
  explicit enum patterns, and a local value named Error.
- The original native 1407 failed with `getelementptr inbounds i32` in the shadow
  function. SLG `semantic/qualified.slg` now indexes exact resolved reference
  tokens once per source and excludes lexical value roots before enum/native/
  import lookup. It does not repair the wrong type at LLVM emission. Direct
  semantic fixture 1408 keeps an actual enum path (1) and excludes a shadowing
  value projection (0); current-source native 1407/1408 pass.
- C266: generated managed enum-pattern parsing now consumes all owner segments
  before the final variant and applies canonical imported type resolution.
  Fixture 1409 covers `scope.Error.Failed` and `scope.Error.Present(value)`;
  managed and SLG native execution pass. Existing Result propagation/imported
  method fixtures 1028/1029 and 1404-1409 pass together (8/8).
- Evidence: `scripts/contracts/evidence/C2026-09-05-265/` and `...-266/`, including
  preserved baselines, candidate receipts, hashes and focused native evidence.
  The C265 baseline was re-frozen after removing two redundant Long casts; a
  retained pre-fix compiler actually reproduces the same Error lookup failure
  on the final warning-free source. Original baseline files remain preserved.

Current tested SLG candidate: `artifacts/example-tests/selfhost-sollangc-driver.exe`,
built from current SLG sources by the managed bootstrap. Its build and inner 775
managed/native differential passed (`c265-driver-bootstrap.log`). It is not a
Stage3 seed or release proof. Its runner fingerprint may need regeneration after
C266 changed the managed compiler; do not manually forge or update that receipt.
Published Stage3 still predates the grammar and qualified-resolution changes.
Next resume should continue C263's AST constant representation, range/selector
expression evaluation and canonical expanded collection typing, using the tested
arithmetic kernel. Preserve source locations and report nonconstant/overflow/
expansion-limit errors before LLVM. Use Long for constant values, not 32-bit Int.
Inventory AST construction, copying and artifact serialization before extending
its record; do not store computed numbers in source-token indexes. Keep the
original 1404 failing native collection-return control until real expansion works.

The initial closure audit closed eleven old records. This continuation also
closed C260 (single/batch native manifest fail-fast), C261 (reviewed 775 LLVM
snapshot) and C264 (stale syntax diagnostic keyword indexes).
Fresh outer 775 native verification (session 28868) FINISHED PASS after about
10 minutes: direct-call closure, LLVM contracts, assembly and exact execution.
The log is `artifacts/scratch/windows-completion/c223-native-775-reviewed.log`;
artifact hashes are `scripts/contracts/evidence/windows-closure-2026-09-05/775-closure.json`.
That run predates the following C263 grammar changes. C223 remains pending the
final current-source Stage2/Stage3 promotion. Do not repeat 775 on an unchanged
snapshot merely to recover this result.

C262 remains candidate-fixed: the managed generated parser routes bare tail
`each` through runtime statement parsing. Fixture 1404 retains collection-return
and primary/additional readonly-reference and branch-tail controls. Its managed
baseline/candidate receipts are preserved. Native 1404 exposed C263.

C263 remains OPEN, with a partially implemented grammar repair:
- Canonical grammar now has `CollectionElement` and `CompileTimeEachExpression`.
  This accepts named/unnamed array and dictionary comprehensions, including
  non-first array elements; bare runtime each parsing remains unchanged.
- Regenerated `syntax/generated/sollang_grammar.slg`; grammar determinism passes.
  Reviewed grammar inventory contains 122 rules. Guide was updated in the same
  change. Fixture 1405 exercises 9 generated-VM syntax cases (7 valid, 2 malformed)
  and passes. It is added to Stage2 and Stage3 exact selections.
- Current focused examples 75, 96, 1404, 1405 pass **4/4**. Shared compiler
  contracts pass (`compiler-contracts-grammar-reviewed.log`, session 98073
  FINISHED). C264 now asserts resolved diagnostic names/order instead of stale
  numeric keyword allocation indexes; previous/current grammar outputs were
  independently executed and found identical before that fixture update.
- **Semantic expansion is still wrong.** A cheap C#-compiled SLG semantic probe
  resolves `[1..2 -> each { it * 10 }]` as `array-length=1 first=25`, with all
  reported expression statuses zero, instead of two Int constants. Probe source,
  binary and build/output logs are `artifacts/scratch/windows-completion/c263-semantic-probe.*`.
  Do not claim C263 fixed because syntax tests pass; do not remove the original
  1404 collection-return control. The originally published Stage3 still embeds
  the old grammar and is not a test of the new grammar implementation.

Next implementation must represent and evaluate collection expansion with
preserved source locations, checked arithmetic and the documented 100000-element
limit, produce canonical expanded array/dictionary types, and feed ordinary IR
operands/storage rather than textual source substitution. Review managed
`ParserSourceGenerator.cs` helpers `ExpandCompileTimeRange` and
`TryEvaluateCompileTimeInt` for exact semantics. Current SLG AST has no
comprehension kind or expansion pass; `AstNode` is flat/source-token addressed.
Type construction is in `selfhost/semantic/expression_type_ids_resolution_phases.slg`
(around 1359), array emission in `selfhost/llvm/text/function_expressions.slg`
(around 903) and entry counterpart. Integer IR currently reads source tokens in
`core_calls.slg:writeIntegerLiteral`; plan an explicit constant representation
instead of overloading source token indexes with computed values.

No long-running compiler processes remain from this continuation. Session 72032
(native 1404) failed with C263, 28868 (775) passed, and 98073 (contracts) passed.
Compiler/stdlib completion is not achieved. Continue known defect audits and
stdlib contracts per `COMPLETION_PLAN.md`; preserve the dirty worktree.
Audit inventories under `artifacts/scratch/windows-completion/` are indexes,
not closure approval. No commit or push was made.

## Completed ownership slice — preceding checkpoint

The resumed Windows ownership goal is complete. Preserve the dirty worktree.
C250–C259 are closed with baseline/candidate receipts and full current-source
Windows verification. This is not completion of the entire compiler or stdlib.

| Axis | Verified current state |
| --- | --- |
| Compiler stabilization | 93/259 (35.9%) closed; 166 candidate-fixed remain |
| Ownership/payload focused gate | 5/5 (100%) native; new 1403 managed 1/1 |
| Existing frozen focused manifest | 33/33 (100%) |
| Full Windows native exact | candidate 123/123; Stage2 123/123; Stage3 123/123 |
| Current Windows Stage2/Stage3 | 2/2 (100%), complete compiler LLVM fixed point |
| Frozen stdlib/runtime | 4/22 (18.2%); 15 in progress; 3 blocked |

Verified reusable SLG seed: `artifacts/incremental-selfhost/selfhost-slg-seed.exe`
SHA256: `5279D0B3830E2F22F36FBF13CA001467AFE3222C7A28C2B7F1C1B2F38834EC38`.
Stage2/Stage3 complete LLVM SHA256:
`34A28BAD6049EA705176DBEC1A279E2630FCF5D7FD91F62B79679B1C8326B7F9`.
Both artifact receipt validation and the newly published seed provenance were
independently re-read and passed. The native build emitted no compiler warnings.

Completion evidence and exact artifact/log hashes:
`artifacts/scratch/ownership-resume/completion-evidence.json`.
Final logs: `stage2-259-recovery.log`, `stage3-259.log` in that directory.
Full zero-cache profile: `windows-payload-trait-profile.json`, 123/123, 534683 ms
wall, 8182040 ms observed CPU, 2367.4 MiB peak. One unavailable exit-race CPU
sample was explicitly excluded; the profiler completed and retained valid hashes.

The late Stage3 diff exposed C259: a fresh directory enum payload lost its drop.
Fixture 1403 now requires one drop after readonly copying; 1398 protects borrowed
payloads. Both are Stage2 seed canaries with 1201. The receipt-bound Stage2Bridge
failed 1403 before heavy compilation; explicit ManagedRecovery then passed all
gates, and Stage3 republished the current SLG seed. Return to default Slg mode.

The next work slice starts from the 166 remaining candidate-fixed compiler
records and frozen stdlib/runtime contract. Linux was not run in this slice;
its prior receipts are not current-source proof. No commit or push was made.

## Detailed run evidence (historical checkpoints)

Continuation on 2026-09-05 is active. Preserve the dirty worktree. The prior
generation passed full Windows 122/122 and formal Stage2. Stage3 then rejected a
7-line LLVM difference: six redundant path drops plus one required directory
payload drop. C259 repairs the latter; current source verification restarted.
Linux must not start before full Windows and current Stage2/Stage3 pass.

| Axis | Current measured state |
| --- | --- |
| Compiler stabilization | 83/259 (32.0%) closed; 176 candidate-fixed await formal promotion |
| Current focused gate | 5/5 (100%) native plus 1/1 managed fixture 1403 |
| Prior ownership/Brotli focus | 16/16 (100%) with the preceding driver; latest full rerun pending |
| First full Windows run | 120/122 (98.4%) pass; both failures fixed in focused checks |
| Prior full Windows run | 122/122 (100%) pass; 24 verified cache hits |
| Current full Windows run | 123/123 (100%) pass, cache 0, windows-payload-trait-profile.json |
| Current Windows Stage2/Stage3 | 1/2 (50.0%); current Stage2 passed, Stage3 running |
| Frozen stdlib/runtime | 4/22 (18.2%) complete; 15 in progress; 3 blocked |

Current driver: `artifacts/scratch/ownership-resume/candidate-driver.exe`
SHA256: `E0E48E444C9BF34B2317CB2BE9CC08AAF12F0F16A735677A1B60B7A1D8C1C162`.
Prior driver CD664DD4 is retained at `pre-259-driver.exe` in the same directory.

C259: fresh enum cleanup uses the selected payload's ownership trait, not the
container enum's trait. Reference-result producers remain borrowed. Fixture
1403 rejects missing directory Raw cleanup after readonly copying; 1398, 1399,
1400, and 1306 controls pass. Baseline/candidate receipts and shaping trace are
under `scripts/contracts/evidence/C2026-09-05-259`. Compiler contracts passed
before the seed-canary expansion; recheck them with Stage2 after the current run.
The Stage2 seed canary now includes 1201, 1398 and 1403, so incompatible historical
cleanup semantics fail before the heavy partition and full compiler generation.

Completed profile: `artifacts/scratch/ownership-resume/windows-payload-trait-profile.json`.
Its live stdout appends `.stdout.log` to that filename. Label/output directory:
`windows-payload-trait`; Jobs 16. Passed 123/123 with zero cache hits, 534683 ms
wall, 8182040 ms observed CPU, peak 2367.4 MiB, 45 processes. One unavailable
CPU sample was explicitly excluded; profiling completed with valid log hashes.
Default SLG Stage2 stopped at provenance: its old Stage3 provenance binds a prior
Stage2 artifact, replaced by the newly verified Stage2. The explicit Stage2Bridge
run then passed private-field 3/3 but failed expanded canary 1403 (2/3 passed):
the receipt-bound Stage2 omits the required raw-payload drop. This is the actual
seed capability failure authorizing explicit ManagedRecovery; no gate was bypassed.
Evidence logs: `stage2-259-slg.log`, `stage2-259-bridge.log`.
The recovery Stage2 command passed: canary 3/3, heavy 3/3, light 29/29, QUIC
ownership 5/5, native exact 123/123, and final differential 134/134. All seven
stages passed and current Stage2 artifacts were promoted with receipts.
Log: `artifacts/scratch/ownership-resume/stage2-259-recovery.log`.
Active command: `scripts/verify-selfhost-stage3.ps1 -Jobs 16`.
Log: `artifacts/scratch/ownership-resume/stage3-259.log`.
Complete current Stage2/Stage3 and publish the verified SLG seed through the
canonical Stage3 script before claiming recovery complete.

The remainder of this checkpoint records the prior generation's evidence and
commands; do not treat its Stage2 result as current-source verification.
The formal Stage2 differential runner rebuilt the managed oracle at
`artifacts/example-tests/selfhost-sollangc-driver.exe`; its SHA256 is
`5EA1CFDE0DB48032FA23BC33E9A5A081883247A7D1D9262AFC9F204DF5A65674`.
Baseline driver before the full-run fixes: `pre-full-fix-driver.exe` in the same
scratch directory, SHA256 `50F3FF812D2D36ECCAF42811D4679855A0D959564E61874CA6298D1360097AD1`.

Candidate fixes (not formally closed):

- C2026-09-05-250 / 1398: borrowed enum payload retains original owner cleanup.
- 251 / 1399: exact parameter symbol identity; one flag clear after member store.
- 252 / 1400: ownership joins use the emitted enum-arm body; terminating arms
  do not impose ownership obligations on a continuing merge.
- 253 / 1401: function scheduling's shared mutation catalog includes reserve (-271).
- 254 / 1272: entry control barriers include enum/when roots, so final output
  follows the last nested match. Exact output is block-switch=true:true:true.
  Fixture 1402 is a compatibility control, not a failing baseline witness.
- 255 / 1184: Windows thread creation is selected for capture separately from
  ordinary process wait; parallel/mouse/join users retain their declarations.
- 256 / 1306, introduced regression: `nearestCompletedTransferOwner` gives
  generic and aggregate-specific ownership marking disjoint completion sites.
  One Huffman-table transfer again emits one clear rather than three.
- 257 / 1132, verifier: module-independent observer signature and pre-wait
  projection contracts replace hardcoded module/type IDs. A synthetic nominal
  wrapper is rejected while legitimate later exit-status formatting is allowed.
- 258 / profiler: an exited process can expose null CPU time; report unavailable
  samples explicitly. Sampler failure now stops the entire batch process tree,
  preserves live logs, and writes a failure checkpoint. Fault-injection coverage
  verifies root and descendant termination; normal failure log hashes remain valid.

Latest focused checks: 1184, 1306, 1399, 1389, 1340, 1326, 1400, 1132, 1133,
1182, 1183, 1198 — all pass in `artifacts/scratch/ownership-resume/full-fixes-focused`.
Compiler contracts pass in `compiler-contracts-full-fixes.log`. C250–258 baseline,
candidate, and shaping receipts are present under `scripts/contracts/evidence`.
No current-source fixed point or performance improvement is claimed by those receipts.

First full profile (`windows-full-profile.json`): 536331 ms wall, 8135770 ms
observed CPU, 2550439936 bytes peak aggregate working set, 45 maximum observed
processes, Jobs 16, no cache hits. It finished 120/122; 1184 and 1306 failed.
The second run stopped after 9/122 reported passes because of C258; it produced no
valid profile. Its verified orphan batch tree was stopped before resuming.
The resumed run uses `windows-full-resumed-profile.json`, label
`windows-ownership-fixed`, output directory `windows-full-fixed`, Jobs 16, with
fingerprint-verified cache reuse. Live logs append `.stdout.log` / `.stderr.log`
to the full JSON filename. Root profiler PID at launch: 72724.
Keep both profiles and do not edit the active compiler, stdlib, fixtures, or
verifier inputs while profiling. The default plan contains 122 existing fixtures.

Resumed profile passed with exit 0: 476298 ms wall, 7473446 ms observed CPU,
4069482496 bytes peak aggregate working set, 42 observed processes, and zero
unavailable CPU samples. Cache reuse means this is not a like-for-like speedup.

Current command: `scripts/verify-selfhost-stage2.ps1 -Stage2BuildJobs 16`.
Log: `artifacts/scratch/ownership-resume/stage2-slg-retry.log`.
The initial `stage2-slg.log` run stopped before compilation: the compiler contract
looked for obsolete profiler-test output wording. It now checks the executable
failure-progress, log-hash, and descendant-cleanup assertions; compiler contracts
pass in `compiler-contracts-profiler-recovery.log`. This belongs to C258.
Next: finish current Windows Stage2
(default Slg seed first, Jobs 16) then Stage3. Historical Stage3 seed provenance
and artifact receipts pass, but that is not current-source compatibility proof.
Use explicit ManagedRecovery only if the verified seed fails the narrow current
capability gate; retain that failure as evidence and return to Slg after promotion.
Do not reuse old fixed-point evidence or start Linux early.

Stage2 live checkpoint: the default SLG seed passed private-field 3/3, canary
1/1, heavy regressions 3/3, and remaining seed regressions 29/29. No
ManagedRecovery was needed. Stage2 emitted 39,552,244 bytes of LLVM in about
461 seconds. Candidate checks include QUIC ownership 5/5 and matching Stage1 /
Stage2 source and stream LLVM. Internal stages 1 through 4 are complete; stage 5
is running the separate 122-fixture batch against `selfhost-stage2.candidate.exe`.
Stage2 subsequently passed the full 122/122 batch, remaining build/diagnostic
checks, and final 134/134 differential examples. The script exited 0 and promoted
the current Stage2 artifacts with receipts. Current Stage2/Stage3 is now 1/2.
Active command: `scripts/verify-selfhost-stage3.ps1 -Jobs 16`.
Log: `artifacts/scratch/ownership-resume/stage3-slg.log`.
Verified current Stage2 executable SHA256:
`0A5641C96E438E873C472AD49C810114EA7A48F6DE4C64A74F105BB8D926AC6A`.
Stage2 LLVM SHA256: `22DDBE871B317CB08E605A6123E9045C354C3DAC274FA4ABD8DF58F25CCF6974`.

```powershell
# Rebuild only after source changes; the runner's current Release net11 DLL is available.
$driverSources = @(Get-Content tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt | Where-Object {$_.Trim()} | ForEach-Object {$_.Trim()})
& dotnet src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll build @driverSources -o artifacts/scratch/ownership-resume/candidate-driver.exe --target windows-x64 --llvm .tools/llvm-22.1.8 -O1 --keep-temps

# This second profile is already running: check process/output before restarting.
& scripts/measure-native-exact-batch-profile.ps1 -Compiler artifacts/scratch/ownership-resume/candidate-driver.exe -Output artifacts/scratch/ownership-resume/windows-full-fixed-profile.json -Label windows-ownership-fixed -LlvmRoot .tools/llvm-22.1.8 -StdlibRoot stdlib -RepositoryRoot . -OutputDirectory artifacts/scratch/ownership-resume/windows-full-fixed -Jobs 16

& scripts/verify-selfhost-stage2.ps1 -Stage2BuildJobs 16
& scripts/verify-selfhost-stage3.ps1 -Jobs 16
```

The default native plan includes 1398–1402. Fixture 1393 remains the managed
integrated regression; formal candidates use the three direct private-field
manifests. The QUIC contract checks this routing. Batch preflight now rejects
missing fixture files before worker/artifact creation (negative control passed).
The original focused invocation mistyped 1397; the correct real fixture passed
separately. That harness-input error was not counted as a compiler failure.
Exploratory 1401/1402 interpolation reductions are scratch evidence, not claims.
## Previous checkpoint — before ownership continuation

This section supersedes the older continuation and restart text below. The
historical Windows Stage2/Stage3 fixed point was valid for its earlier source
snapshot, but the current compiler changes have not yet been promoted. For the
current source, Stage2/Stage3 is therefore **0/2**, and Linux must not start.

The user's required order is:

1. fix and measure Windows first;
2. pass the complete Windows native-exact set;
3. rebuild and pass the current Windows Stage2/Stage3 fixed point;
4. only then begin Linux.

Do not wait idly during a long run. Keep a non-conflicting Windows task queue,
and report compiler stabilization, the current focused verification,
Stage2/Stage3, and frozen stdlib/runtime as separate measured axes.

### Current measured state

| Axis | Current state |
| --- | --- |
| Compiler stabilization | 83/249 (33.3%) verified closed; 166/249 (66.7%) candidate-fixed and still awaiting current-source promotion |
| Current focused verification | 4/4 (100%): 1397, 1263, 1273, and compiler contracts pass |
| Downstream Windows exact impact | 1/6 (16.7%) passes: 1279 passes; 1266, 1268, 1269, 1272, and 1274 fail |
| Stage2 / Stage3 | 0/2 (0%) for the current source |
| Frozen stdlib / runtime | 4/22 (18.2%) accepted; 15 in progress; 3 blocked |
| Linux | 0 current actions; explicitly deferred |

### Last completed compiler fix

- Fixture 1263's stack overflow was not a stack-size problem. The second
  chained `when` used the terminal value of the first `when`'s last arm instead
  of the first control result, so its region was never emitted and the loop ran
  forever.
- `selfhost/ir/typed/resolved_context_seal.slg` now restores the exact
  `producer.nextOperand -> consumer` subject only when the provisional subject
  is a descendant of that producer. Complexity is one IR pass plus parent-chain
  walks, `O(n * depth)`; no repeated LLVM consumer scan was added.
- New fixture 1397 and its expected output freeze a nine-arm
  `State -> Result -> Advance` chain inside one `while`.
- The rebuilt Windows driver hash is
  `6CF0D2F25FDDFCFC93ECEA3BDA66CCC5B6C70FD5DB8ABF2D10FACCC1E790119A`.
- Windows exact 1397, production 1263, independent control 1273, and
  `scripts/verify-selfhost-compiler-contracts.ps1` all pass.

### Active Windows blocker — resume here

The next change is not implemented yet. Two independent self-host LLVM
ownership defects are fully diagnosed:

1. Borrowed enum payload cleanup (`selfhost/llvm/text/control.slg`)
   - A `when` over an owned field such as `self.table` borrows its payload, but
     the arm cleanup currently treats that binding as a new owner and drops it.
   - 1266 then frees a 128-byte prefix-table buffer twice. 1269 first produces
     `InvalidTreeIndex(6), offset=698` and prints `context-map-stream=false`.
   - Removing only the erroneous payload drop from a copy of 1269 LLVM changes
     the result to `context-map-stream=true`; `llvm-as` and Windows linking pass.
   - Fixture 1398 is the minimal regression. Managed output is
     `borrowed-enum=3:3`; the current self-host executable exits with Windows
     `0xC0000374` and no stdout.

2. Move parameter transferred through an enum constructor
   (`selfhost/llvm/text/container_control.slg`)
   - `BlockStreamReader.installPrefix(mut self, table: move Table)` stores
     `Present(table)` in a field but leaves `%arg*_owned=true`; function cleanup
     drops the table although the field now owns it, and a later read drops it
     again.
   - In generated 1274 LLVM this is visible in `sollang_m60_s523`: the payload
     is stored in the member at lines 2897-2931, while lines 2966-2970 still
     branch to `drop_arg1_path`.
   - Fixture 1399 freezes the transfer shape. It currently passes by output, so
     the compiler contract must additionally require the exact owned-flag clear
     and absence of source cleanup; output alone is insufficient.

Windows AddressSanitizer independently confirmed double-free for 1266 and 1274.
The four no-output failures 1266, 1268, 1272, and 1274 exit with decimal
`-1073740940` (`0xC0000374`). 1269 exits zero but returns the wrong Boolean.

### Exact next implementation and verification

1. Read `docs/AI_AGENT_GUIDE.md` completely and preserve the dirty worktree.
2. Validate the two minimal fixtures before editing:
   - 1398: managed `borrowed-enum=3:3`, current self-host `0xC0000374`;
   - 1399: output passes, so retain an LLVM structure assertion as the failing
     pre-fix signal.
3. In `control.slg`, emit arm-payload cleanup only when the match subject is an
   actually owned temporary producer. A name/member/projected subject borrowed
   from an existing owner must not be dropped. Preserve cleanup for genuine
   owned Result/enum temporaries as a negative control.
4. In `container_control.slg`, after the successful member store, route the
   exact assignment through `emitCompletedPatternBindingTransferMarks` so a
   move parameter transferred through an enum constructor clears its path
   ownership flag. Do not broadly suppress parameter cleanup.
5. Rebuild `artifacts/example-tests/selfhost-sollangc-driver.exe` with the
   Release net11 managed compiler and the complete
   `selfhost-sollangc-driver.sources.txt` manifest.
6. Run Windows exact in this order:

   ```powershell
   # minimal ownership regressions
   .\scripts\verify-native-exact-fixture-batch.ps1 `
     -Compiler .\artifacts\example-tests\selfhost-sollangc-driver.exe `
     -Label windows-ownership-focused -Platform windows `
     -Fixture @('1398-selfhost-borrowed-enum-payload-lifetime','1399-selfhost-move-parameter-enum-field-transfer') `
     -LlvmRoot .\.tools\llvm-22.1.8 -StdlibRoot .\stdlib `
     -RepositoryRoot . -OutputDirectory .\artifacts\example-tests\windows-ownership-focused -Jobs 16

   # affected production cluster
   .\scripts\verify-native-exact-fixture-batch.ps1 `
     -Compiler .\artifacts\example-tests\selfhost-sollangc-driver.exe `
     -Label windows-brotli-downstream -Platform windows `
     -Fixture @('1266-brotli-complex-prefix-description-stream','1268-brotli-complex-prefix-repeat-stream','1269-brotli-context-map-stream','1272-brotli-command-block-switch-stream','1274-brotli-block-stream-reader','1279-brotli-decoder-compressed-stream') `
     -LlvmRoot .\.tools\llvm-22.1.8 -StdlibRoot .\stdlib `
     -RepositoryRoot . -OutputDirectory .\artifacts\example-tests\windows-brotli-downstream-fixed -Jobs 16
   ```

7. Add 1398 and 1399 to the authoritative native-exact list only after focused
   success; 1397 is already in that list. Re-run the allocation contract,
   profile contract, and compiler contracts.
8. Run the complete Windows native-exact plan under
   `scripts/measure-native-exact-batch-profile.ps1`. The profiler now streams
   each `completed/total` event live and preserves wall time, host-visible CPU,
   peak aggregate memory, process count, cache hits, fingerprints, logs, and
   long no-completion intervals. Do not call measurement-tool existence a
   performance improvement.
9. Only after the complete Windows set passes and has measured performance,
   run the current Windows Stage2 and Stage3 to a new fixed point. Do not reuse
   the historical fixed point below as current proof.
10. Do not run Linux until all preceding Windows steps pass.

### Windows optimization already verified

- The deterministic source-count/source-byte LPT allocator passes 6 named and
  5,120 exhaustive shapes plus fail-fast controls.
- On the same four-fixture sample, `Jobs=1` took 96.127 seconds and `Jobs=4`
  took 35.125 seconds: 2.74x throughput and 63.5% shorter wall time, with 4/4
  identical LLVM hashes and 20/20 non-empty outputs.
- The heavy-fixture allocation and complete 118-fixture Windows result are not
  yet measured. After adding 1398/1399, the authoritative total will become
  120; calculate it from the script rather than hard-coding progress elsewhere.
- `scripts/verify-native-exact-batch-profile-contract.ps1` passes both success
  and preserved-failure cases after live progress streaming was added.

### Files created or changed in this checkpoint

- `selfhost/ir/typed/resolved_context_seal.slg`
- `examples/regression/1397-selfhost-while-chained-wide-match-result.slg`
- `examples/regression/1398-selfhost-borrowed-enum-payload-lifetime.slg`
- `examples/regression/1399-selfhost-move-parameter-enum-field-transfer.slg`
- matching expected stdout files under `examples/regression/expected/`
- `docs/AI_AGENT_GUIDE.md`
- `scripts/native-exact-batch-allocation.ps1`
- `scripts/verify-native-exact-batch-allocation.ps1`
- `scripts/measure-native-exact-batch-profile.ps1`
- `scripts/show-native-exact-batch-profile.ps1`
- `scripts/contracts/native-exact-batch-profile.schema.json`
- `scripts/verify-native-exact-batch-profile-contract.ps1`
- `scripts/verify-native-exact-fixture-batch.ps1`
- `scripts/verify-selfhost-compiler-contracts.ps1`

All of these coexist with a large pre-existing dirty worktree. Do not reset,
clean, or discard unrelated files.

## Continuation state

- Windows optimization and the complete Windows fixed point are accepted before
  any Linux action. The clean Stage2 run completed in about 42 minutes and its
  full compiler LLVM emission fell from 3,546 seconds to 408 seconds, about
  8.7x faster. Stage2 passed its 50-fixture native batch and final 134/134
  managed/native differential with zero timeout.
- Windows Stage3 then completed in about 48 minutes. It regenerated the same
  39,423,046-byte LLVM, passed Stage2 and Stage3 51/51 native fixture batches,
  and published fixed point
  `A0AEB80BB444FF944EDB05CFA00BAE462B2E5D0917F15C42483563BD85AC3A27`.
  The verified SLG feedback seed is
  `262BEFC1BEA7B7154C7B83E38BCD646981BCBCA315E86922A7B2BEE935C57356`.
- The function-owner-bounded direct-child index remains covered by independent
  fixture 1395. A rejected global `V012` and an incomplete 121-source
  measurement are preserved only as failed evidence; the accepted controlled
  run used all 133 sources, finished in 507.354 seconds, emitted zero
  diagnostics, and retained identical start/end input fingerprints.
- The first Stage3 attempt exposed one preflight self-match: the time contract's
  negative-test message itself contained forbidden namespace `sys.time`. The
  diagnostic now avoids that obsolete active token while the exact legacy file
  existence check remains. Time API 14/10/6/3 and module layout 34/0 checks pass.
- Preserve the current dirty worktree. It contains the user's ongoing compiler,
  runtime, stdlib, regression, documentation, and collaboration work; do not
  reset or discard unrelated changes.

## Measured progress

| Axis | Completed | Additional state |
| --- | ---: | --- |
| Compiler stabilization | 83/249 (33.3%) verified closed | 166/249 (66.7%) candidate-fixed; 0/249 (0.0%) open; 166/249 release-unclosed |
| Current focused verification | 33/33 (100.0%) | formal timeout 0/33 |
| Stage2 / Stage3 | 2/2 (100.0%) | Windows fixed point complete; Linux refresh next |
| stdlib / runtime | 4/22 (18.2%) fully accepted | 15 in progress, 3 blocked, 19/22 (86.4%) started |
| Agentic Shaping / Slogs collaboration | 2/3 (66.7%) | 1 pending |

These values were read from `scripts/show-project-progress.ps1` immediately
before this handoff was written.

## Last verified work

- Replaced the repeated whole-function `valueHasDirectBinding` scan with an
  immutable, function-owner-bounded lookup prepared once for parallel emitters.
  The current compiler IR removes 35,775,116 guaranteed repeated visits while
  retaining all 29,982 observed same-owner bindings.
- The rebuilt Windows native compiler passed both smoke cases, the compiler
  contracts, source formatting, source-structure/module checks, 1394 direct
  binding, 1129 control topology, 377 integration, and the positive/negative
  if-value comparisons against Stage1.
- The candidate function profile passed function 3811 (788 nodes), where the
  baseline profile had stopped, and completed 85 profiled functions before the
  bounded measurement ended.
- The stopped clean Stage2 run completed heavy fixture 787 in 27 minutes 48
  seconds. Its 13,310,801-byte LLVM output passed direct-call closure, LLVM
  contracts, assembly, and native execution. Heavy fixtures 1217 and 1383 then
  passed the same checks in about 3 minutes 48 seconds and 2 minutes 6 seconds;
  the 29-fixture light batch passed across 16 outer workers under a shared
  16-job budget. Stage2 phase 1 completed and phase 2 LLVM generation reached
  5.4% (351/1,869 definitions) with rising CPU before the earlier timeout.
  LLVM stdout is buffered in 1 MiB chunks, so the byte/definition percentage
  can remain unchanged while one large definition is being computed; process
  CPU and responsiveness are the current liveness evidence. Historical
  `final2-windows-stage3.stdout.log` recorded 63 unchanged 5.2% heartbeats and
  then one jump to 100%, so a flat byte percentage alone is not a hang signal.
  At about 31 minutes the process had 4 running and 13 waiting threads, then
  dropped to 3 running and 14 waiting threads, with zero error bytes. This is a
  parallel long-tail of large function tasks rather than an idle compiler; map
  those tasks before any further split.
  The prior complete Stage2 LLVM's two largest definitions map to module 22
  `selfhost/llvm/text.slg` (35,446 LLVM lines) and module 44
  `selfhost/llvm/text/container_control.slg` (23,973 lines). They are profiling
  candidates, not yet proven identities for the two current remaining workers.
- The Slogs MCP server reports policy `2026.09.04.2`. The project repository's
  `AGENTS.md` contains only Sollang instructions; the older versioned policy
  block visible to this session is environment-injected and cannot be updated
  through the repository. Do not claim repository synchronization from the
  server version alone.
- Slogs Skills now has validated `korean-software-terminology` 1.0.1 with
  precise English/Korean search aliases. Live search passed 4/4 positive and
  6/6 negative queries with no early body disclosure; first-use scope remains
  undecided. Agentic Shaping 0.3.1 was pushed at `1235711`, restoring every
  public v0.3 verifier asset and adding staged-snapshot release closure checks.
- Added `scripts/verify-selfhost-private-field-diagnostics.ps1`.
  - Directly checks the opaque-struct construction, private-field read, and
    private-field write diagnostic manifests.
  - Requires exit code 1, one exact actionable diagnostic, no V006 diagnostic,
    and no LLVM target output.
  - Current Windows Stage1 passed 3/3 in about 0.3 seconds.
  - Linux-target diagnostics through the Windows Stage1 compiler passed 3/3.
- Removed regression 1393 from the expensive native Stage2 seed and Stage3
  exact arrays. Its managed `--exact 1393` regression remains integrated, while
  the direct 3-case gate now protects the native diagnostic contract.
- Integrated the direct private-field gate into Windows and Linux Stage2/Stage3
  verification paths.
- Updated `scripts/verify-selfhost-compiler-contracts.ps1` to lock routing,
  invocation counts, and cases. The full compiler-contract verifier passed.
- Updated `docs/AI_AGENT_GUIDE.md` and recorded decision D634 in
  `docs/DECISIONS.md`.
- `git diff --check` passed; only existing line-ending warnings were reported.

## Active verification

The corrected clean Windows phase measurement completed:

```powershell
.\scripts\measure-selfhost-control-allocas.ps1
```

It preserves command, compiler hash, source-manifest hash, elapsed time, output,
and completion state under `artifacts/profiles/windows-control-allocas`. The
accepted 133-source run completed in 507.354 seconds with zero diagnostics and
identical starting/ending source fingerprints. Its
first 492.237-second run correctly failed the zero-diagnostic criterion with 621
diagnostics: its source plan omitted the 12-file runtime manifest (617), while
the rejected global `V012` added four. It is not a candidate performance result.
The previous candidate timing and incomplete baseline were not a controlled pair
because a diagnostic process shared CPU near the end of the baseline; the
earlier 66% figure remains preliminary rather than a release number. The clean
Windows Stage2 and Stage3 fixed point now provide the accepted end-to-end
correctness and performance evidence. Linux artifacts remain stale and are the
next platform task.

## Completed formal Windows commands

The accepted commands were:

```powershell
.\scripts\verify-selfhost-stage2.ps1 -Rebuild -SeedMode ManagedRecovery -Stage2BuildJobs 16
.\scripts\verify-selfhost-stage3.ps1 -Jobs 16
```

Both commands completed. Stage2 and Stage3 receipts bind the current inputs,
LLVM, bitcode, executables, fixed-point hash, and published SLG seed provenance.

## Exact restart sequence

1. Read `docs/AI_AGENT_GUIDE.md` completely before changing code.
2. Recall the Sollang project decisions and current goal from Slogs LLM Wiki.
3. Confirm the progress table with:

   ```powershell
   .\scripts\show-project-progress.ps1
   ```

4. Windows performance and Stage2/Stage3 are complete. Remove only the redundant whole-condition parentheses
   around the two-line `node.sourceModule ... node.nextOperand` condition at
   line 41 of fixture 617. Keep the precedence parentheses inside its embedded
   source text, then run fixture 617 exactly.
5. Rebuild stale Linux artifacts from the verified Windows SLG seed and run the
   Linux Stage2/Stage3 proof. Do not treat old Linux binaries as current proof.
6. Once the compiler problem is closed, return immediately to the frozen
   stdlib/runtime backlog instead of starting an unrelated full compiler audit.

## Important provenance boundary

- The old verified SLG seed under `artifacts/incremental-selfhost` predates the
  new public-field syntax and fails fast with `expected Colon`; it cannot serve
  as a Stage2 bridge for this change.
- The required recovery is exactly one managed generation, followed by the
  Stage2-to-Stage3 fixed-point comparison and restoration of the SLG seed path.
- The direct diagnostic gate replaces a disproportionate native timeout; it
  does not waive the managed integrated regression or the formal fixed-point
  gates.
