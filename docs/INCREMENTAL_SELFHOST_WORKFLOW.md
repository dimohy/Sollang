# Incremental Self-Host Workflow

Sollang development uses a short evidence loop and keeps the expensive complete
self-bootstrap as a final gate. A small emitter or semantic change must not
wait for the complete compiler before its first useful failure.

## The loop

1. Reduce a failure to one `.slg` fixture and only its required library source.
2. Build the Stage1-hosted self-host compiler from the current `.slg` sources.
   Reuse it when the combined compiler-source fingerprint is unchanged.
3. Emit LLVM only for the focused fixture, run `llvm-as`, link it, and compare
   execution with the checked-in expected stdout.
4. If an exact-fingerprint Stage2 compiler is available, emit the same fixture
   with it and require normalized LLVM hashes to be identical.
5. After the related implementation slice is complete, perform one full
   Stage2 bootstrap and one full regression. Do not repeat either gate for a
   failure already isolated by a focused fixture.

Run the short loop with:

```powershell
pwsh -NoProfile -File scripts/verify-selfhost-incremental.ps1 `
  -Fixture examples/582-billion-sensor-alerts.slg
```

Run the expensive bootstrap gate explicitly:

```powershell
pwsh -NoProfile -File scripts/verify-selfhost-incremental.ps1 `
  -Fixture examples/582-billion-sensor-alerts.slg `
  -BootstrapStage2
```

## Cache correctness

The compiler cache key hashes every file in the self-host manifest, including
its relative path. The focused action key hashes:

```text
compiler source fingerprint + fixture fingerprint + target
```

A Stage2 executable is eligible for parity comparison only when its recorded
compiler fingerprint exactly matches the current source fingerprint. A stale
Stage2 is reported as stale; it is never accepted as evidence. Cache hits still
pass through the LLVM verifier and focused execution oracle.

This gives each layer one job:

- source/type/emitter defect: focused fixture;
- malformed LLVM: `llvm-as`;
- semantic miscompile: expected stdout;
- bootstrap divergence: exact Stage1/Stage2 LLVM hash;
- release confidence: one complete self-bootstrap and one full regression.

## Why this shape

- Rust's incremental compiler records a query dependency DAG and uses
  red/green output fingerprints so unchanged results do not invalidate their
  dependents:
  <https://rustc-dev-guide.rust-lang.org/queries/incremental-compilation.html>
- Bazel's action cache keys an action from its declared inputs, command, tools,
  and configuration. Sollang uses the same principle at compiler and fixture
  granularity:
  <https://bazel.build/reference/glossary>
- LLVM's `lit` and `FileCheck` favor small, directly selectable regression
  inputs over repeatedly running an entire suite:
  <https://llvm.org/docs/TestingGuide.html>,
  <https://llvm.org/docs/CommandGuide/FileCheck.html>
- MSBuild's incremental model compares declared inputs and outputs and skips a
  target whose outputs are already current:
  <https://learn.microsoft.com/en-us/visualstudio/msbuild/incremental-builds>
- Differential compiler testing uses an independent implementation as an
  oracle. Sollang's Stage1 and Stage2 therefore receive identical sources and
  must emit identical normalized LLVM:
  <https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf>
- A large failure should be reduced while preserving an executable
  interestingness test, following `llvm-reduce`:
  <https://llvm.org/docs/CommandGuide/llvm-reduce.html>

## Timing policy

Every command reports its elapsed time and cache hit/miss state. The intended
developer loop is seconds on a hit and at most a small Stage1-hosted rebuild on
a compiler-source miss. A multi-minute full bootstrap is allowed only at the
explicit final gate or when the focused evidence proves that the bootstrap
itself is the failing subsystem.

The first measured run of this workflow rebuilt the Stage1-hosted compiler and
verified example 582 in 44 seconds. Exact cache hits then verified 582 in 1.3
seconds, and focused 585/583 runs completed in well under one second after their
LLVM action caches were warm.
