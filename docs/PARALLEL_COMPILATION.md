# Deterministic Parallel Compilation

Status: accepted direction, implementation in progress  
Updated: 2026-07-17

This document defines SmallLang's CPU-parallel execution model and the concrete
self-host compiler migration. A worker-count message is not implementation
evidence. A checkbox is complete only when the corresponding runtime behavior,
compiler path, and regression evidence exist.

## Decision

`async` remains the structured latency/concurrency abstraction. CPU-bound data
parallelism uses an ordinary typed role named `parallel`:

```smalllang
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

## Why This Fits SmallLang

- Swift task groups provide structured child lifetime and require the parent to
  await its children. Swift's `Sendable` model also rejects unsafe values that
  cross concurrency domains.
- Mojo's CPU `parallelize` executes indexed work items in parallel and returns
  only after all items complete. This is the right minimal runtime shape for a
  compiler's module and function arrays.
- SmallLang already has affine ownership and compile-time sendability checks for
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

The pool is bounded; SmallLang must not create one OS thread per item. File I/O
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

Evidence: `selfhost/semantic/analysis.sl`; examples 182, 293, and 294.

### B. Typed role surface (3/5)

- [x] Block callbacks can return a typed result.
- [x] `parallel` is implemented as an imported standard-library role.
- [x] Input/item/result types are inferred through ordinary generics.
- [ ] Non-sendable captures and mutable borrows are rejected.
- [ ] Owned callback results transfer exactly once.

### C. Native compute task group (3/7)

- [x] Windows pool uses bounded reusable native workers.
- [ ] Linux pool uses bounded reusable native workers.
- [ ] The available processor count and explicit build override are supported.
- [x] Workers claim indices atomically without a global result lock.
- [ ] Parent-assisted waiting and structured join are implemented.
- [ ] Cancellation and partial-result destruction are exactly once.
- [x] File-operation waiting remains outside the compute pool.

### D. Self-host compiler integration (2/6)

- [x] Nested imported calls cannot overwrite the enclosing runtime call target.
- [x] Source-local analysis uses `parallel` and ordered package assembly.
- [ ] Global semantic facts form an explicit read-only barrier.
- [ ] Function-local typed IR uses indexed parallel work.
- [ ] LLVM function bodies use per-function buffers and ordered emission.
- [ ] The self-host driver accepts and reports the effective worker count.

Evidence for the completed call-identity fix: example 322. Example 323 proves a
literal-returning function in the second module still emits `ret i32 42`.

### E. Verification (2/6)

- [x] A 24-processor machine shows more than two active frontend workers.
- [ ] Frontend CPU-time/wall-time ratio materially exceeds 2.0.
- [ ] Full self-host frontend wall time improves from the recorded baseline.
- [x] Three repeated LLVM outputs are byte-for-byte identical.
- [ ] Peak runtime memory stays within the documented budget.
- [ ] Windows and Linux full suites pass with zero warnings and errors.

Evidence: example 324 executes `block item: Int -> Int`; example 325 proves the
self-host grammar/parser accepts the same declaration and call form. The two
`block-callback-result-*` diagnostics cover missing and mismatched results.

Parallel-compilation progress is **14/28 checks (50.0%)**. This is a feature-local
metric and does not promote the canonical self-host roadmap, which remains
**48.5/60 equivalent gates (80.8%)** until a full checklist audit proves a gate.

## Definition of Done

The feature is complete only when all 28 checks are proven. In particular,
`--jobs 24`, LLVM's 24 native partitions, the test runner's workers, or visible
`n/total` output do not prove frontend parallelism. Completion requires active
compute workers inside the long-running self-host frontend plus deterministic
output and measured wall-time improvement.

## Current Evidence

On the 24-logical-processor Windows development machine, example 329 created
24 bounded compute workers and observed 12 callbacks executing concurrently.
Examples 328, 329, and 294 pass together: ordered `Int -> Int` mapping, active
worker instrumentation, and the self-host `SourceAnalysis` boundary.

The reusable native self-host driver compiled example 323 three times to the
same 242-byte LLVM output with SHA-256
`C1B1607773224F83B30F5AEC060B65E8A8C48C076C42DE882C8C0B857C74B670`.
A full 29-source self-host attempt reached 28 OS threads, 98.5 MiB peak working
set, and 184.3 seconds wall time, but then hit the pre-existing stage-2 trap
after producing 172,417 output bytes. Its whole-run CPU/wall ratio was 0.99,
so the global semantic, typed-IR, and LLVM-body stages remain sequential and
the wall-time/CPU-ratio verification boxes deliberately remain open.
