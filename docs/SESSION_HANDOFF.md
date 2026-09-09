# Sollang session handoff

Updated: 2026-09-05 (Asia/Seoul)

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
