# Incremental Self-Host Workflow

Sollang development uses a short evidence loop and keeps the expensive complete
self-bootstrap as a final gate. A small emitter or semantic change must not
wait for the complete compiler before its first useful failure.

## The loop

1. Reduce a failure to one `.slg` fixture and only its required library source.
2. Use the newest compatible verified SLG executable to build a candidate
   compiler from the current `.slg` sources. Prefer fixed-point Stage 3; a
   receipt-bound Stage 2 may bridge one source generation when the older Stage 3
   cannot represent current source. Reuse it only when the seed-executable and
   compiler-source fingerprints are unchanged.
3. Emit LLVM only for the focused fixture, run `llvm-as`, link it, and compare
   execution with the checked-in expected stdout.
4. After the focused SLG proof passes, build/run the same fixture with the C#
   bootstrap as a differential oracle and bring its implementation into parity.
   If an exact-fingerprint Stage2 compiler is available, reuse or emit the same
   exact-action fixture LLVM and require normalized Stage1/Stage2 hashes to be
   identical. Reused LLVM still passes through `llvm-as`.
5. After both implementations agree, perform one full
   Stage2 bootstrap and one full regression. Do not repeat either gate for a
   failure already isolated by a focused fixture.

The successful Windows Stage 3 fixed-point gate publishes its exact native
executable and SHA-256 receipt as the next incremental SLG seed. The incremental
gate rejects a missing or mismatched receipt. `-SeedMode ManagedRecovery` is an
explicit bootstrap bridge only; it prints a warning and never silently replaces
the SLG-first default. A seed supplied with `-SlgSeedCompiler` must carry a
same-basename `.sha256` receipt beside it; an unreceipted custom executable is
not a verified seed.

Run the short loop with:

```powershell
pwsh -NoProfile -File scripts/verify-selfhost-incremental.ps1 `
  -Fixture examples/regression/582-billion-sensor-alerts.slg
```

Run the expensive bootstrap gate explicitly:

```powershell
pwsh -NoProfile -File scripts/verify-selfhost-incremental.ps1 `
  -Fixture examples/regression/582-billion-sensor-alerts.slg `
  -BootstrapStage2
```

## Full managed reference verification

Integrate the intended compiler and regression changes before starting the
full suite, and keep those inputs fixed until it ends:

```powershell
pwsh -NoProfile -File scripts/verify-managed-reference.ps1 `
  -OutputDirectory artifacts/scratch/managed-reference-run -Jobs 8
```

Use a new, empty output directory for each run. The wrapper executes the existing
ExampleTests reference suite for Windows, streams stdout and stderr to files,
and records the process identity. It requires a successful terminal summary
and unchanged input membership and hashes before writing `success.json`.
`-ValidateInputsOnly` checks and returns the input inventory without starting
the suite. Interrupted or changed-input runs retain evidence but do not establish
full-suite success.

## Cache correctness

The compiler cache key hashes the verified SLG seed executable and every
file in the self-host manifest, including each relative path. Managed inputs
have a separate differential-oracle key and cannot invalidate or become the
authority for the SLG candidate. The focused action key hashes:

```text
verified SLG seed + compiler source fingerprint + fixture fingerprint + target
```

Stage1 compiler LLVM is independent of the native link optimization profile,
so it has one content-addressed cache entry keyed by the bootstrap inputs.
The O0 and O1 host executables have separate profile keys and filenames. A
profile switch therefore relinks the shared verified LLVM instead of spending
minutes asking the seed compiler to emit identical LLVM again.

Each host profile keeps two distinct hashes. The `.inputs.sha256` file is only
the cache key for the seed, compiler sources, target, and optimization profile.
The same-basename `.sha256` file is the executable verification receipt and
contains the executable's actual SHA-256. It is published only after focused
LLVM verification and native expected-output execution pass. These files must
never share a pathname or be interpreted interchangeably.

A Stage2 executable is eligible for parity comparison only when its recorded
compiler fingerprint exactly matches the current source fingerprint. A stale
Stage2 is reported as stale; it is never accepted as evidence. Cache hits still
pass through the LLVM verifier and focused execution oracle.

The full Stage2 differential runner owns its historical managed-oracle path,
`selfhost-sollangc-driver.exe`. The Stage2/Stage3 gate owns the distinct
`selfhost-stage1-verification.exe` path. This prevents a differential run or
ordinary fixture bootstrap from changing the seed bound by the Stage2 receipt.
Only explicit managed-recovery mode copies a successfully built oracle into the
verification path.

When a fixture's expected contract itself is under diagnosis, use
`-ManagedOracleOnly` to check the C# differential oracle without paying for a
self-host fixture emission first. The command labels itself diagnostic-only and
is never accepted as SLG completion evidence; the normal SLG-first gate still
has to pass afterward.

This gives each layer one job:

- source/type/emitter defect: focused fixture;
- malformed LLVM: `llvm-as`;
- semantic miscompile: expected stdout;
- SLG/C# semantic drift: post-SLG managed differential execution;
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
  oracle. Sollang runs the C# implementation after the SLG candidate, while
  Stage1 and Stage2 receive identical sources and must emit identical normalized
  LLVM:
  <https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf>
- A large failure should be reduced while preserving an executable
  interestingness test, following `llvm-reduce`:
  <https://llvm.org/docs/CommandGuide/llvm-reduce.html>

## Timing policy

Every command reports its elapsed time and cache hit/miss state. Focused
feedback separates Stage1 compiler construction, Stage1/Stage2 LLVM emission,
LLVM verification, and native link plus execution. The intended developer loop
is seconds on a hit and at most a small Stage1-hosted rebuild on a compiler-
source miss. A multi-minute full bootstrap is allowed only at the explicit
final gate or when the focused evidence proves that the bootstrap itself is the
failing subsystem.
Any redirected compiler process that exceeds two minutes reports elapsed wall
time, consumed CPU time, and working-set memory every two minutes while keeping
its stdout/stderr artifacts private until atomic promotion. This heartbeat is
observability, not a reason for an Agent to poll idly: independent review,
regression, documentation, and implementation work continues between those
meaningful progress boundaries.
Before starting a multi-minute gate, the Agent records at least one concrete
non-overlapping task from the active goal (for example API inventory, fixture
design, deterministic diagnostic improvement, documentation parity, or a
different module). The gate runs as a hidden background process with separate
logs. The Agent works that queue and inspects the gate only at heartbeat or
phase boundaries; it does not turn a 30-second process wait into the active
task while useful independent work remains. Compiler-source edits remain
frozen for that generation, but scripts, contracts, documentation, research,
and genuinely independent modules may advance. If a known defect is found,
stop before paying for later gates and preserve receipt-bound candidates for
diagnosis or resume.

When Stage2 and Stage3 normalized hashes differ, summarize the semantic surface
before choosing a bridge:

```powershell
pwsh -NoProfile -File scripts/compare-selfhost-llvm-functions.ps1 `
  -Baseline artifacts/example-tests/selfhost-stage2.ll `
  -Candidate artifacts/example-tests/selfhost-stage3.candidate.ll
```

The schema-v1 JSON binds both complete-file SHA-256 values and reports
function-body SHA-256 additions, removals, and changes by LLVM symbol. It is a
triage index, not proof that a difference is correct; inspect the named bodies
and runtime/fixture evidence before using `Stage2Bridge`.

To locate semantic cost without paying for LLVM emission, record the
prepare-only and expression-type boundaries as validated structured evidence:

```powershell
pwsh -NoProfile -File scripts/verify-selfhost-incremental.ps1 `
  -ProfileExpressionTypesOnly `
  -Fixture examples/regression/1043-selfhost-imported-instance-bool-call-ir.slg `
  -ProfileOutput artifacts/profiles/1043-expression-types.json
```

The record uses schema version 3, binds the compiler and expanded fixture
fingerprints, labels its semantic baseline `prepare-only`, and records wall
time, CPU time, and peak working set for each independently launched phase. A single
sample is diagnostic evidence, not a speedup claim; compare repeated
samples under the same fingerprints and environment before selecting an
optimization.

The formal exact-fixture suite has a separate nested-concurrency experiment.
Its runner currently bounds outer fixture concurrency, but every native
self-host compiler child independently defaults to all logical processors.
Raising only the outer `--jobs` value can therefore oversubscribe source-local
parallel lowering while still leaving too few independent fixtures during each
compiler's serial tail. Before changing that gate, expose an explicit internal
compiler-job budget and compare equal total budgets such as two outer workers
times twelve inner workers versus four times six. Keep the exact fixture set,
compiler/source fingerprints, LLVM and runtime outputs, warning-zero gate, and
machine environment fixed; record suite wall time plus aggregate CPU and peak
memory. Do not interpret a faster unbounded oversubscribed run as a compiler
speedup.

Stage2's current native stdlib gates also repeat the larger input boundary.
Result propagation, socket endpoint observation, no-delay, timeout, three
checked-index controls, interpolation references, and projected references each
launch a separate `build --stdlib <root>` process. Preserve isolated LLVM-shape
checks where a fixture genuinely needs its own small module, but merge compatible
execution-only checks into one deterministic native harness or reuse one
fingerprint-bound prepared/module-artifact product. The optimized path must
retain each named assertion, exact output, `llvm-as`, direct-call closure, target
runtime, and warning-zero evidence. Measure full-root analysis count and formal
wall time before and after; fewer checks is not an optimization.
For compiler-only LLVM-shape fixtures, prefer the existing exact-suite route:
emit the explicit minimal source closure through the direct `windows`/`linux`
target and apply the shared runtime-link contract. Keep at least one independent
`build --stdlib` gate to prove the public build surface itself; merely deleting
`--stdlib` from `build` is invalid because that command requires a readable
stdlib source root.

The previous C#-seeded O0 feedback path rebuilt the Stage1-hosted compiler in
about 15.2 seconds after a self-host source change. That number is retained as a
historical baseline, not the authority order. With that compiler cached, example 582
emitted LLVM in 48 ms, verified it in 11 ms, linked and executed it in 109 ms,
and completed in 267 ms. DNS example 1042 completed an exact warm action in 272
ms while still rerunning `llvm-as` and the native execution oracle. These are
focused development timings, not substitutes for the optimized Stage2/Stage3
release gate.

Formal Stage2/Stage3 runs use
`scripts/invoke-detached-selfhost-verification.ps1`. The launcher reserves a
durable log and a distinct structured completion record, starts a hidden
supervisor whose lifetime is independent of the observing shell, and records
the supervised process exit code plus exact diagnostic or fixture identifiers
when the process terminates. A successful exit has no failure identifiers;
failed exits derive identifiers only from failure-context lines so passing
negative diagnostics cannot be mislabeled. Read measured stage progress with
`scripts/read-detached-selfhost-progress.ps1`; a missing completion record is
`running` only while the recorded supervisor PID exists, otherwise it is
`interrupted-without-result`. Never infer success from the final visible log
line. Validate observer separation, passing and failing termination, path
boundaries, and missing-result classification with
`scripts/verify-detached-selfhost-verification.ps1` before relying on this path.
