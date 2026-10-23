# Compiler and standard-library completion

Requested: 2026-09-05. Status: active, not globally complete.

## Execution order

1. Windows: review already identified compiler defects first, then finish the
   standard-library contracts in `STDLIB_EVOLUTION.md`, repairing compiler
   defects exposed by the natural library implementation at their authority.
2. Finish current-source Windows Stage2 and Stage3 after the final Windows
   compiler/library changes. Only then start Linux implementation or execution.
3. Finish Linux, including current-source Stage2/Stage3, then finish WASM using
   its documented self-host and browser capability/execution contracts.

Cross-target closure requirements remain intact. A record requiring Linux or
browser proof cannot be globally closed on Windows evidence alone. Such a
record may have its Windows obligations fulfilled while its global state stays
`candidate-fixed`; it must not create a circular requirement to run Linux
before Windows completion. Review exact closure clauses, not keyword counts.

## Authorities and initial checkpoint

- `scripts/contracts/compiler-defects.json`: 93/259 closed, 166 candidate-fixed.
  Review the eight introduced regressions first, then the remaining latent
  defects and verifier records, sharing verification only when its actual
  inputs and assertions cover each record.
- `scripts/contracts/stdlib-evolution-progress.json`: frozen 22 contracts,
  4 complete, 15 in progress, 3 blocked. Preserve all required shapes and the
  acceptance gates in `STDLIB_EVOLUTION.md`; resolve recorded prerequisites
  rather than dropping blocked contracts or adding workaround APIs.
- `SESSION_HANDOFF.md` and
  `../artifacts/scratch/ownership-resume/completion-evidence.json`: the prior
  Windows snapshot passed candidate/Stage2/Stage3 native exact 123/123 each
  and the complete compiler LLVM fixed point. These are source-bound evidence,
  not a promise that future source edits are verified.

## Completion criteria

For Windows, every compiler record's applicable Windows obligations and every
stdlib contract's Windows implementation, ownership, malformed/boundary-input,
resource-limit and execution obligations must be satisfied. Keep exact evidence
and explicitly separate outstanding other-target obligations. Revalidate the
final Windows snapshot through the complete Stage2/Stage3 gates without
unexpected diagnostics before changing platform.

Optimization follows compilation speed, structural clarity, then resource
efficiency. Use retained benchmark scripts and same-workload before/after
measurements with compiler/input hashes. The previous 534683 ms native-exact
batch is a measurement, not proof of an optimization. Investigate C85's recorded
failed performance experiments before retrying changes to dispatch granularity.
Do not replace correctness gates with throughput results or claim all possible
optimization is exhausted.

Global completion requires zero unclosed compiler records under the existing
zero-known-defect verifier, all 22 stdlib contracts meeting their acceptance
criteria, and evidence for all three requested targets. For WASM, distinguish
supported portable functionality from required explicit capability diagnostics;
do not invent native OS support or reuse native Stage3 terminology where the
documented browser pipeline has a different contract.

## Reporting

Report compiler closed/total, the current bounded focused gate, source-bound
Stage2/Stage3 status, and frozen stdlib complete/22 separately. Platform-obligation
counts are additional measurements, not replacements for the global ledger.
Until all exact clauses have been reviewed, no Windows-obligation percentage is
available. Preserve failed results and historical evidence; no bulk promotion
based solely on a passing fixed point.
