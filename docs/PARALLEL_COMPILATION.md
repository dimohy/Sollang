# Deterministic Parallel Compilation

Status: runtime implemented; C82 native Typed IR closure in progress (27/28)
Updated: 2026-08-27

This document defines Sollang's CPU-parallel execution model and the concrete
self-host compiler migration. A worker-count message is not implementation
evidence. A checkbox is complete only when the corresponding runtime behavior,
compiler path, and regression evidence exist.

## Decision

`async` remains the structured latency/concurrency abstraction. CPU-bound data
parallelism uses an ordinary typed role named `parallel`:

```sollang
sources -> parallel source {
    source -> analysis.analyzeSource
} => analyses!
```

`parallel` is not a keyword. It is a standard-library role built on a native
structured task group. This preserves the role-block invariants in
[`ROLE_BLOCKS.md`](ROLE_BLOCKS.md): normal name resolution, normal imports, and
no private subgrammar.

The callback-result extension has the type:

```text
Role<Source, Item, Result, Output>
Source -> Output block Item -> Result
```

The task group executes callback indices in an unspecified order but writes
each result into the slot for that index. It joins every child before returning
and exposes results in canonical input order. Scheduling therefore cannot alter
source indices, symbol IDs, type IDs, diagnostic order, or emitted bytes.

## Why This Fits Sollang

- Swift task groups provide structured child lifetime and require the parent to
  await its children. Swift's `Sendable` model also rejects unsafe values that
  cross concurrency domains.
- Mojo's CPU `parallelize` executes indexed work items in parallel and returns
  only after all items complete. This is the right minimal runtime shape for a
  compiler's module and function arrays.
- Sollang already has affine ownership and compile-time sendability checks for
  async inputs/results. The parallel role reuses those checks instead of adding
  shared mutable collections or implicit reference counting.

Primary references:

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Mojo CPU parallelize](https://docs.modular.com/mojo/std/algorithm/backend/cpu/parallelize/)
- [Mojo ownership](https://docs.modular.com/mojo/manual/)

## Runtime Algorithm

1. Start a bounded native pool lazily, with a default worker count equal to the
   available logical processors and an explicit positive override for builds.
2. Publish a task-group record containing immutable input storage, an atomic
   next-index counter, disjoint result slots, cancellation state, and remaining
   work count.
3. Each worker claims an index atomically and invokes the outlined callback.
4. A worker owns only its callback input and result slot. Captured values must
   be immutable and sendable; mutable borrows and non-sendable owners are
   compile-time errors.
5. The parent participates in work while waiting, then joins the group.
6. Package and LLVM products are merged in canonical source/function order.
7. Failure cancels unclaimed work, joins started work, and destroys every
   initialized result exactly once.

The pool is bounded; Sollang must not create one OS thread per item. File I/O
continues to use its separate operation worker and does not consume compute-pool
capacity while blocked.

## Self-Host Decomposition

The first safe parallel boundary is source-local analysis:

```text
SourceText view
  -> AST + tokens + symbols + resolved names + type terms + type uses
  -> SourceAnalysis result slot
  -> canonical PackageAnalysis merge
```

Global module/import/symbol/type facts remain sequential until frozen. After
that barrier, function-local typed IR and LLVM bodies can use the same indexed
task-group primitive and ordered merge.

## Completion Checklist

### A. Source-local product boundary (4/4)

- [x] `SourceAnalysis` owns every source-local output array.
- [x] `analyzeSource(Text)` borrows immutable source text only.
- [x] `analyzeSources` consumes source-local products in source order.
- [x] Flat package/context and LLVM module-call regressions pass.

Evidence: `selfhost/semantic/analysis.slg`; examples 182, 293, and 294.

### B. Typed role surface (5/5)

- [x] Block callbacks can return a typed result.
- [x] `parallel` is implemented as an imported standard-library role.
- [x] Input/item/result types are inferred through ordinary generics.
- [x] Non-sendable captures and mutable borrows are rejected.
- [x] Owned callback results transfer exactly once.

### C. Native compute task group (7/7)

- [x] Windows pool uses bounded reusable native workers.
- [x] Linux pool uses bounded reusable native workers.
- [x] The available processor count and explicit build override are supported.
- [x] Workers claim indices atomically without a global result lock.
- [x] Parent-assisted waiting and structured join are implemented.
- [x] Cancellation and partial-result destruction are exactly once.
- [x] File-operation waiting remains outside the compute pool.

### D. Self-host compiler integration (5/6 verified)

- [x] Nested imported calls cannot overwrite the enclosing runtime call target.
- [x] Source-local analysis uses `parallel` and ordered package assembly.
- [x] Global semantic facts form an explicit read-only barrier.
- [ ] Function-local typed IR uses indexed parallel work with current performance, memory, browser, and fixed-point evidence.
- [x] LLVM function bodies use per-function buffers and ordered emission.
- [x] The self-host driver accepts and reports the effective worker count.

Evidence for the completed call-identity fix: example 322. Example 323 proves a
literal-returning function in the second module still emits `ret i32 42`.
Example 378 proves the self-host worker-limit intrinsic together with native
parallel execution. The C82 source path now routes compute-pool targets through
`lowerResolvedContextParallel`, browser targets through the sequential
`lowerResolvedContext`, and both through one ordered readonly result merge with
prompt whole-element owner replacement after each merged range.
Function requests are collected once across all sources in canonical
source/symbol order. Native lowering publishes exactly one compute group;
browser lowering traverses that same request array once sequentially. Recorded
per-source start/count ranges restore source-local assembly order. A `parallel`
group inside the per-source loop is forbidden because pool publication, worker
wake-up, TLS output-sink setup, and the barrier join are fixed costs that dwarf
small or empty source-local request batches.
Merged `SourceTypedIr` owners are replaced with empty instances in O(1) as
source assembly advances, so already-copied nodes do not remain live until the
final source. Indexed `take` extraction and indexed-member assignment are not
part of this path.
The target choice returns one owned Typed IR array through `lowerPreparedIr`;
`prepareSnapshot` binds that result once as `ir!`. It must not create an empty
owned array and rebind the whole container in each branch: managed semantics
and self-host E28 reject that lost-drop shape. The helper is one direct call and
introduces no array copy, heap wrapper, or virtual dispatch.
The self-host callback eligibility contract applies recursive worker-transfer
classification to nominal input and output records. It must not restrict native
workers to scalar or `SourceText` inputs and silently serialize a transferable
record. Example 1198 guards the nominal request/result boundary; example 1199
independently guards callback discovery for a reachable local function. The
semantic ownership pass is the only capture-safety authority: E18 rejects
mutable captures and E19 rejects structurally non-shareable captures before
LLVM emission. Code generation always validates worker input/output ABI, then
copies approved scalar captures and borrows approved owned/readonly captures
until the structured join. Example 1200 combines those captures with nominal
input and output so neither an ownership-policy duplicate nor a capture-based
ABI bypass can silently select the serial loop.
Current-source performance and fixed-point evidence must pass before this item
is checked again. `SemanticSnapshot`
is the named ownership barrier consumed read-only by semantic, typed-IR,
ownership, effect, and LLVM passes; example 379 proves the frozen package,
module, import, and resolved-import views.
The reference compiler rejects direct and transitive mutable captures and
structurally non-sendable values. The self-host ownership pass now follows the
local-function call graph and reports direct or transitively hidden mutable
captures as production diagnostic E18; code 19 continues to classify direct
structurally non-sendable captures. Examples 380 and 497 prove mutable,
non-sendable, immutable, and transitive cases, while example 498 proves that
the checked compiler stops before LLVM emission. Before parallel typed-IR and
LLVM work begins, construction-time tables move into immutable owners without
copying, so worker callbacks never capture mutable builders.

### E. Verification (6/6)

- [x] A 24-processor machine shows more than two active frontend workers.
- [x] Frontend CPU-time/wall-time ratio materially exceeds 2.0.
- [x] Full self-host frontend wall time improves from the recorded baseline.
- [x] Three repeated LLVM outputs are byte-for-byte identical.
- [x] Peak runtime memory stays within the documented budget.
- [x] Windows and Linux full suites pass with zero warnings and errors.

Evidence: example 324 executes `block item: Int -> Int`; example 325 proves the
self-host grammar/parser accepts the same declaration and call form. The two
`block-callback-result-*` diagnostics cover missing and mismatched results.

Parallel-compilation progress is **27/28 checks** while C82 closure is active. This is a feature-local
metric. The canonical self-host roadmap subsequently completed at
**60/60 equivalent gates (100%)**.

## Definition of Done

The feature is complete only when all 28 checks are proven. In particular,
`--jobs 24`, LLVM's 24 native partitions, the test runner's workers, or visible
`n/total` output do not prove frontend parallelism. Completion requires active
compute workers inside the long-running self-host frontend plus deterministic
output and measured wall-time improvement.

## Current Evidence

The 2026-08-27 C82 diagnostic baseline freezes three schema-v3 runs of the 36-source 1043
compiler fixture under compiler fingerprint
`78CC7ECD05E59D0D4BF32FAA16645C12EE54A83E1D7CA612C03384E4BB6E3BC3`.
The post-expression Typed IR wall median is 133,568 ms, its CPU median is
132,843 ms, and peak working-set median is 167,559,168 bytes. Every run spent
approximately one CPU second per wall second in that phase. The full 112-source
pre-change Stage3 analysis likewise accumulated only 354 CPU seconds from 180
through 540 wall seconds. The diagnostic `typed-ir` command uses the standalone
sequential compatibility wrapper, so those three records prove the serial
bottleneck but are not the native C82 acceptance comparison. The original C82
callback gate uses `measure-selfhost-compiler-emission.ps1` to run the actual
native target command over the same ordered compiler/runtime manifests for
adjacent fixed-source bootstrap generations. Stage1 contains the corrected
callback classifier but its own C82 region was emitted sequentially by the
older seed; Stage2 is emitted by Stage1 and contains the nominal-record worker
callback. After C85 changed the dispatch implementation itself, its
authoritative performance comparison used two O1 compilers generated by one
receipt-bound C86 seed: deterministic per-source dispatch and compiler-wide
dispatch. Both exposed at least four parallel callbacks and one nominal-transfer
callback, so generation topology did not masquerade as the implementation
effect. The frozen comparison rejected the compiler-wide implementation;
production now uses the measured per-source path.
Both compilers use O1; the O0 feedback Stage1 is correctness evidence only and
cannot be used as the performance baseline.
Three samples per side must have identical input and LLVM
output fingerprints; the candidate must improve wall median by at least one
percent, avoid CPU regression, keep peak memory within two percent, preserve
browser sequential capability, and reach Stage3 fixed point before the final
checklist item closes.

The first post-change SLG-seed candidate completed on 2026-08-27 with executable
SHA-256 `E83FE691CFEE65EF5FAFFBF0239094C54AB8014D9788FFBEBAE809ABFEEB4EB3`.
Its LLVM emission passed the direct-call closure gate and the complete feedback
build took 903,873 ms. A focused one-sample sequential diagnostic recorded
137,955 ms after expression-type resolution; it is retained only as a negative
control because that driver does not traverse the native production entry. The
six-sample alternating full compiler-emission comparison remains the acceptance
gate, so no native speedup is claimed from this number.
`run-selfhost-compiler-emission-benchmark.ps1` owns that six-sample sequence. It
uses the balanced `B,C,C,B,B,C` order, reports completed samples out of six, and
authenticates every resumed profile before reuse rather than silently
overwriting or mixing a stale compiler, target, or worker count.

```powershell
./scripts/new-c85-implementation-performance-pair.ps1 `
  -BaselineReceipt ./artifacts/c85-per-source-control/receipt.json `
  -CandidateReceipt ./artifacts/incremental-selfhost/selfhost-stage1-host-o1.generation.json `
  -SeedCompiler ./artifacts/incremental-selfhost/selfhost-c86-managed-bridge-seed.exe `
  -OutputPath ./artifacts/c85-implementation-performance-pair.json

./scripts/run-selfhost-compiler-emission-benchmark.ps1 `
  -BaselineCompiler ./artifacts/c85-per-source-control/selfhost-c85-per-source-control.exe `
  -CandidateCompiler ./artifacts/incremental-selfhost/selfhost-stage1-host-o1.exe `
  -ImplementationPairReceipt ./artifacts/c85-implementation-performance-pair.json `
  -OutputDirectory ./artifacts/profiles/c85-global-function-group-20260828 `
  -Name c85-global-function-group -Target windows -Jobs 24 -Resume -KeepFirstLlvm
```

The current-source refresh completed all six samples with identical input
`C94CD7340AD2EBB0CE93FD8F465393C953477E0ABAA9C78CD6574C1FDDFC877D`
and identical 34,642,698-byte LLVM
`87D00789C4015000DA74F9B34B82CE7D6A5CE5609939DBEBD76A3EEFCEC65158`,
but correctly failed the frozen performance thresholds. Candidate wall median
regressed from 844,999 ms to 963,492 ms and CPU median from 4,706,938 ms to
5,121,500 ms; peak memory rose only 0.4717 percent. Function-level LLVM
comparison isolated the difference to one new callback and its caller. Route
inspection then showed that the caller created a compute group once for each of
113 sources. That experiment moved to a single compiler-wide request group and
passed structural correctness, warning-free rebuild, fixture 377, and native
1198--1200 closure/assembly/execution. It was not promoted because the two
subsequent frozen comparisons below rejected its production performance.

The first fresh Stage1 attempt after that repair emitted its complete compiler
LLVM in 900,429 ms and passed direct-call closure, but `llvm-as` rejected an
undefined array value in `lowerFunctionRequests`. The parallel expression lived
inside an `if` and read an explicit `move` array parameter. Ordinary function
and `tryParallel` emitters resolved that source as `%arg`; the control-region
plain-`parallel` path printed the operand node's nonexistent `%vN` instead.
Fixture 1201 reproduces the defect with a small move-parameter mapper. Managed
execution passes, the preceding self-host fails on the undefined SSA value, and
the repaired self-host passes closure, LLVM contracts, assembly, link, and
execution. The failed Stage1 artifact is compiler-defect evidence, not a
performance sample. The coherent C86 seed has now generated the current O1
candidate and passed fixture 1201 plus the managed differential. The controlled
per-source baseline also passed closure, callback topology, LLVM assembly, and
O1 link. Their implementation-pair receipt binds both compilers to seed
`1A74485383076D1E20D7FAEF9BBAF9842F6E42901044C13B1700F5F7B673D61A`,
current input `0B22E8D43D2EA670A4D90427354C0C04ACA804F632B10EC2EB3628AF18B4F529`,
and the same four-callback/one-nominal-transfer topology. Six alternating
samples now own output-equality and frozen-threshold acceptance; pair creation
alone is not speed evidence.

The first compiler-wide six samples completed with one identical input and one identical
34,662,072-byte LLVM output. The compiler-wide group reduced CPU median by
7.1758 percent, but wall median regressed 3.1683 percent and peak memory median
grew 14.5201 percent, so the 1/0/2 gate failed. The retained baseline and
candidate LLVM both pass direct-call closure and assembly. The cause is the
global result owner's lifetime: all per-function node arrays survived the later
ordered assembly of every source. The follow-up keeps one compute group but
replaces each merged `SourceTypedIr` array element with an empty owner
immediately. This is an O(1) instance replacement, not `take(0)` or a relaxed
memory threshold. A fresh same-seed pair and six samples were required before
selecting the production path.

That prompt-release comparison completed 6/6 over source fingerprint
`000FDB1DDB9816DA10DAADACDD3148A902E3158342D914FEEC3AFD8BF752B977`.
Every sample emitted the identical 34,666,085-byte LLVM output
`42805557F8B18D66B792332219BB380B9AE60E1E851DDF8B9D539412B72CF14C`.
Per-source baseline medians were 851,702 ms wall, 4,947,094 ms CPU, and
3,441,139,712 bytes peak. Compiler-wide candidate medians were 855,000 ms wall,
4,981,906 ms CPU, and 3,436,277,760 bytes peak: wall regressed 0.3872 percent,
CPU regressed 0.7037 percent, and peak memory improved 0.1413 percent. The
frozen 1/0/2 gate therefore rejected the candidate. Production restores the
per-source batch, merges and releases it before the next source, and retains
both failed global reports as evidence; thresholds were not relaxed.

This project failure also produced the cross-project Agentic Shaping
`AS-PR-001` route-evidence contract. The current Sollang profile producer
already supplies actual command execution, compiler/input/output fingerprints,
and repeated samples, while source contracts prove the intended target branch.
It does **not** yet emit non-forgeable internal driver/API/capability events into
the generic contract. Until that benchmark-harness integration exists, the
Sollang comparison and structural compiler gates remain the project authority;
do not describe `AS-PR-001` as product-integrated merely because a manually
constructed JSON record can pass its schema.

The 2026-08-25 Windows ManagedRecovery-to-Stage2 measurement at the current compiler scale
(103 ordered sources, 95,755 lines, about 30.3 MB of LLVM) separated the
remaining bottleneck instead of treating the build as one opaque wait. The
front end produced no LLVM for about 300 seconds and accumulated roughly the
same amount of CPU time, with one running thread during representative samples.
Once function/codegen work began, a 61-second sample accumulated about 527 CPU
seconds (roughly 8.6 active cores), and complete LLVM emission reached 533
seconds with about 1,636 CPU seconds. This is not proof that the semantic phase
is inherently serial: the immediately following SLG Stage2-to-Stage3 generation
reported 436 CPU seconds in its first 60 wall seconds of analysis, or about 7.3
active cores. The next performance slice therefore targets generation parity:
identify why the ManagedRecovery-produced Stage1 loses frontend parallelism
that the SLG-produced Stage2 retains, then add per-phase instrumentation before
changing semantic/package assembly. It must preserve deterministic ordered
merge and avoid re-parallelizing a path already proven to scale. Candidate receipts and
`-ResumeCandidate` remain the verification-time optimization: post-generation
script or fixture repairs reused the authenticated compiler candidate instead
of repeating the nine-minute emission.

The subsequent SLG-seed Stage2 rebuild narrowed that disparity with live
thread evidence. During the first 60 seconds of its 103-source analysis it
accumulated 472 CPU seconds (about 7.9 active cores). By 121 seconds it had
accumulated 694 CPU seconds, after which CPU increased almost exactly with wall
time: 754 seconds at 181 seconds, 812 at 240, 872 at 300, 932 at 361, and 992
at 421. A thread snapshot in that tail showed eight compute workers waiting
after accumulating 69.1-76.8 CPU seconds each while one thread remained active.
LLVM output began at 449 seconds with 1,019 total CPU seconds. This rules out a
blanket claim that SLG frontend analysis is serial and localizes the next
instrumentation boundary: measure `prepareAnalyzed`, recursive expression-type
resolution, `typedIr.lowerResolvedContext`, and final context construction
separately after the per-source parallel burst. Do not add more source workers
until one of those post-burst phases is proven parallel-safe and dominant.

On the 24-logical-processor Windows development machine, example 329 created
24 bounded compute workers and observed 12 callbacks executing concurrently.
Examples 328, 329, and 294 pass together: ordered `Int -> Int` mapping, active
worker instrumentation, and the self-host `SourceAnalysis` boundary.

Example 377 proves 100 generations of borrowed `SourceText` input and owned
struct/array output through native workers. Example 378 proves an explicit
positive worker limit, while the driver reports the effective count as a valid
LLVM comment. Example 381 limits the pool to one native worker and observes a
peak of two active callbacks, proving that the submitting parent claims work
instead of idling. The parent exhausts the same atomic index queue, waits for
all native workers, and only then flushes ordered sinks and destroys the group.
The submitter reserves source index zero before waking workers, so this
observable parent-help property remains deterministic even for short queues;
30 repeated Windows executions all reported `parent-helped=true`.
This follows the helping-wait pattern documented by Java `ForkJoinPool` and
oneTBB task groups.

The Linux x86-64 backend now uses a bounded reusable pthread pool, `eventfd`
work/completion signals, and a futex generation barrier. Example 383 reuses the
same pool for 100 generations, and `scripts/verify-linux-parallel.ps1` executes
six focused WSL checks covering ordered output, parent help, reuse, LLVM emitted
by the native self-host compiler, and AddressSanitizer ownership cleanup.
Memory-output ownership is shared by
one runtime abstraction: platforms provide only the final writer adapter while
the common sink owns grow, append, canonical flush, and destruction.

The reference runtime and scalar self-host LLVM paths now implement the
fallible `tryParallel<T, R, E>` role.
It keeps the earliest failing source index, stops new claims at that boundary,
joins already-started callbacks, flushes only the successful output-sink prefix,
and moves or destroys every initialized `Result` payload exactly once. The
self-host emitter executes the same ABI from entry, ordinary-function, and
nested-region positions (examples 392-394). Example 395 proves deterministic
earliest-error selection and prefix-only output over competing failures.
Example 396 returns owned dynamic arrays from callbacks and verifies the error
path under Linux AddressSanitizer with leak detection enabled. This closed C.6
at that checkpoint; the later full Windows/Linux suite run closed the remaining
verification item.

- [POSIX `pthread_create`](https://pubs.opengroup.org/onlinepubs/000095399/functions/pthread_create.html)
- [POSIX `pthread_join`](https://pubs.opengroup.org/onlinepubs/009695399/functions/pthread_join.html)
- [Linux `eventfd`](https://man7.org/linux/man-pages/man2/eventfd.2.html)

- [Java `ForkJoinPool.awaitQuiescence`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/ForkJoinPool.html#awaitQuiescence(long,java.util.concurrent.TimeUnit))
- [oneTBB `task_group`](https://uxlfoundation.github.io/oneTBB/main/specification/source/task_scheduler/task_group/task_group_cls.html)

The complete 28-source self-host compiler reached an exact
stage-2/stage-3 fixed point of 7,217,656 bytes with SHA-256
`1C026529C832C88AA54ACCC55B05FE0A7358BBFA4F2A31F6F6F1F1ECEF0FD0DD`;
the stage-3 output also assembles with `llvm-as`. The preceding source-worker
measurement used 377.77 CPU-seconds over 34.81 seconds wall time (10.85
effective cores). The parent-help fixed-point run used 376.91 CPU-seconds over
34.56 seconds wall time (10.91 effective cores). The Linux-pool and common-sink
run used 407.42 CPU-seconds over 36.86 seconds wall time (11.05 effective cores)
and peaked at 100.7 MiB. The earlier capture-safety run peaked at 77.5 MiB.
The complete Linux x64 suite now passes all 523 cases through WSL.

The `tryParallel` reference-runtime checkpoint passes the complete 516-case
Windows suite and its three runtime cases on Linux x86-64. The updated compiler
reaches an exact 7,247,585-byte stage-2/stage-3 fixed point with SHA-256
`C1D43534CFC873CC3BB18BA9DDE3CAF1F515FB8D9FEBA57ABDFE063F648F0723`;
stage 3 assembles with `llvm-as` and took 35.19 seconds to emit. This evidence
predates executable self-host owned-`Result` cleanup. That cleanup is now
covered by example 396; the complete Linux suite now covers the same 523-case
inventory as Windows.

The post-owned-cleanup Windows gate passes all 523 examples in a read-only
run with a zero-warning, zero-error Release build. That run also repaired a
self-host aggregate-flow defect exposed by slice and nested-region output: only
opcode `-1` kind-9 nodes are transparent wrappers, and two-operand calls select
the later resolved IR value. The six-step Linux verifier remains green, but it
remains the fast platform gate. The new `--target linux-x64` runner path also
compiles and executes all ordinary examples and diagnostics under WSL, emits
Linux LLVM for every reusable self-host case, assembles all of those modules,
and links/executes every case with a runtime expectation. The resulting Linux
gate passes 523/523, closing the final checklist item.

The current repository completion baseline is D254: the feature remains 28/28,
the full self-host inventory passes 357/357 on both Windows and Linux, and the
solution builds with zero warnings and zero errors. Earlier 516/523 counts and
fixed-point hashes above are retained as dated checkpoint evidence.
