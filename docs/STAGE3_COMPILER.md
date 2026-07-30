# Sollang Stage 3 Compiler

Sollang 0.3 ships two compiler executables during the transition to a fully
self-hosted distribution:

- `sollang` is the supported command-line interface. It provides project and
  workspace builds, tests, formatting, language-server startup, dependency
  resolution, and version/help output.
- `sollangc-stage3` is the native compiler reproduced by the Sollang-written
  compiler at the verified Stage 3 fixed point. It is an advanced compiler
  driver, not yet a drop-in replacement for the supported CLI.

The Stage 3 driver accepts a target mode followed by source paths and writes
LLVM IR to standard output:

```powershell
.\sollangc-stage3.exe windows .\hello.slg > hello.ll
```

```bash
./sollangc-stage3 linux ./hello.slg > hello.ll
```

It also accepts `--jobs N` immediately after the target mode. The target modes
used for direct source compilation are `windows`, `linux`, and `wasm`.

The native driver now implements `--version`, help, explicit-source,
project-directory (including explicit `--product` selection), and
workspace-package `build`, plus `run` and literal program-argument forwarding.
Project and workspace inputs retain the public `--project`, `--product`,
`--workspace`, and `--package` spellings. Selected products now include the
transitive source closure of local path dependencies. The native path resolver
normalizes and deduplicates diamond graphs, rejects cycles, package-name drift,
and incompatible semantic versions, writes a deterministic portable
`sollang.lock`, and enforces that snapshot with `build --locked`. Explicit
`resolve --project <path>` is available for this path-only graph.

These are verified implementation slices, not the complete replacement
contract: Git and registry materialization, workspace resolution/locking,
library and Wasm output, default project output placement, `test`, `format`,
`language-server`, `bind-cpp`, and exact diagnostic-stream compatibility remain
gated. Those commands remain on `sollang` in 0.3. The C# executable can be
removed only after the complete cross-platform compatibility matrix passes.

## 0.4 Release Boundary

Version 0.4 is the hard transition boundary. Its public archives contain only
the fixed-point native compiler built from `.slg` compiler sources; the C#
bootstrap executable and its `.NET` support artifacts are not published.

The native executable keeps the final name `sollang` and must preserve the 0.3
CLI contract. Release packaging is blocked until command, diagnostic, output,
and exit-code compatibility is verified on Windows x64 and Linux x64. The C#
compiler may still build and differentially verify the native compiler inside
the development pipeline, but it is never copied into a 0.4 archive.

This boundary has an absolute root-cause-only rule, regardless of how frequently
the compiler changes or how many failures are uncovered in sequence. Temporary
fallback paths, symptom patches, defensive success defaults, swallowed errors,
diagnostic suppression, command- or test-specific hard-coded branches, and
silent feature reduction are release failures, not compatibility solutions.
Every defect must follow the same mandatory sequence:

1. reduce it to a permanent focused reproduction;
2. identify the owning compiler layer and the violated shared invariant;
3. correct that invariant in the owning layer;
4. retain the reproduction as a regression;
5. pass focused, complete, cross-platform, and fixed-point verification.

A change that cannot yet satisfy this sequence remains an unresolved defect. It
must never be described as a fix or used to unblock 0.4 packaging.

The current verified fixed points include the canonical control-result and
deterministic parent-assisted parallel-start corrections. Windows Stage 3
reproduces 19,967,212 LLVM bytes with SHA-256
`2593D82C61F36E056710262BAB80D35065BF01836FB662D288D62FA7E7A24491`;
Linux Stage 3 reproduces 19,950,197 LLVM bytes with SHA-256
`9A8461F01035385F4A1554241CA9EC7418D0122786151811EF9970B2AA11BEAB`.
The complete source suites pass 905/905 on Windows and 904/904 on Linux. The
currently implemented native CLI slices pass build/run 10/10 and format 11/11
on each fixed-point executable; these results do not waive the remaining
public-command parity gates.
