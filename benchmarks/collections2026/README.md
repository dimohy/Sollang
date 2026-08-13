# Collections 2026 Benchmark Gate

This suite measures collection implementation costs without changing the
semantic workload between languages. It is intentionally separate from the
existing `perf100` workspace.

## Contract

- Run only after the host's idle-CPU gate passes.
- Build optimized native artifacts before timing; compilation is excluded.
- Warm up managed runtimes, then measure at least 10 independent process runs.
- Pin one logical CPU when the host supports it and record toolchain versions.
- Reject a run unless every implementation prints the exact checksum.
- Report median and p95 latency, operations per second, allocation count, total
  allocated bytes, and peak resident/live bytes. A metric that a runtime cannot
  expose must be reported as unavailable, never estimated as zero.
- Keep requested initial capacity and integer width equivalent. Do not replace a
  standard collection with a custom implementation in competitor baselines.

The first workload, `hash_set_mixed`, performs identical integer insertion,
positive/negative membership checks, and removal. Timed code does not print or
allocate diagnostic strings. One 10,000,000-element round is timed, and the
required checksum is `50000000000000`. Required output fields are `checksum`,
`elapsed_ms`, `len`, and `capacity` where the language exposes capacity.

No “fastest” claim is valid until all required language artifacts execute on
the same OS/kernel and hardware with the complete metric table.

The first qualified same-host measurement is recorded in
`results-2026-08-13.md`. Reproduce it with
`scripts/run-collections2026.ps1`; the runner enforces the idle-CPU gate,
processor affinity, interleaved independent runs, exact checksums, and metric
availability rules. The runner resolves Java from `JAVA_HOME` or
`P:\Utils\jdk-17`, compiles the retained Java source, and runs it in the same
interleaved affinity-pinned rounds. A missing JDK is a build failure rather than
a silently omitted baseline.
