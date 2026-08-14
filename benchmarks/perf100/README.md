# Sollang Perf100

Perf100 is the cross-language performance gate for Sollang. It contains 20
algorithm families and five workload profiles per family, for exactly 100
measured cases. Every case is implemented in Sollang, C++, Rust, C# NativeAOT,
Go, and Java.

## Completion contract

- All six implementations consume the same runtime input and print the exact
  same checksum before a case may be timed.
- Each release build uses the implementation's speed-oriented production mode.
- Measurements run on the same WSL2 kernel and CPU, one process at a time.
- A run starts only after `/proc/stat` reports at most 10% aggregate CPU use
  over a ten-second window. Every case repeats a two-second idle check and the
  harness aborts instead of publishing measurements when another workload
  makes the machine busy. The limit and every observed value are stored in the
  raw report.
- The harness records toolchain identity, source hash, raw samples, median,
  median absolute deviation, range, peak RSS, executable size, build time, and
  rank. Every timing sample launches one fresh process; warmups prime host and
  filesystem caches but deliberately do not preserve a language runtime or JIT
  between samples.
- A case is green only when Sollang ranks first, second, or third among all six
  implementations. The suite is complete only when all 100 cases are green.
- An interrupted run resumes only when its build report, executable identities,
  measurement settings, and completed case prefix still match exactly. Set
  `PERF100_RESUME=0` only when deliberately starting a fresh baseline.
- Benchmark-specific compiler branches, precomputed answers, hidden fallback,
  reduced work, unchecked wrong output, and source rewriting are forbidden.
  Optimizations must improve a shared compiler, runtime, or standard-library
  invariant and must pass the ordinary regression and self-host gates.

The 100 cases cover integer arithmetic, branches, calls, loop structure,
floating-point work, arrays, sorting, sieves, matrix work, and searching. The
canonical list is generated from `cases.mjs`; changing an input or algorithm
creates a new benchmark contract and requires a fresh baseline.

`scripts/perf100-build.sh` builds all six runners. Before any timed run,
`scripts/perf100-check.sh` checks one representative input from every algorithm
family across all six implementations. `scripts/perf100-run.mjs` then verifies
the exact output again for every measured case before collecting samples.
`scripts/perf100-report.mjs` validates the completed 100-case JSON and produces
checked-in English and Korean Markdown summaries bound to the same raw report
by SHA-256.

## External methodology

The comparison set is C++, Rust, C# NativeAOT, Go, and Java. It deliberately
combines ahead-of-time native toolchains with the widely deployed Go runtime
and Java JIT instead of selecting only the first five entries of one summary
chart. Perf100 does not copy scores from another machine because they cannot
prove Sollang performance on this computer.

The harness adopts the LLVM Test Suite rules that benchmark programs must also
be correctness tests, should record runtime, compilation time, and code size,
and must use repeated samples. It also keeps Benchmarks Game's warning that
source and implementation choices matter: the checked-in sources and exact
compiler flags are part of every result.

Measurements collected while another application was consuming substantial
CPU on 2026-08-02 are exploratory only. They are not a Perf100 baseline and
must not be cited as evidence that the ranking gate passed or failed.

Primary references:

- https://benchmarksgame-team.pages.debian.net/benchmarksgame/
- https://benchmarksgame-team.pages.debian.net/benchmarksgame/box-plot-summary-charts.html
- https://benchmarksgame-team.pages.debian.net/benchmarksgame/how-programs-are-measured.html
- https://llvm.org/docs/TestSuiteGuide.html
- https://llvm.org/docs/lnt/tests.html
