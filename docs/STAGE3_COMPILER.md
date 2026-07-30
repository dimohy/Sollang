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

This boundary has a permanent no-fallback rule. Temporary fallback paths,
defensive success defaults, diagnostic suppression, command-specific hard-coded
bypasses, and silent feature reduction are release failures, not compatibility
solutions. Every discovered parity gap must be corrected at its root and pass
focused reproduction, the complete regression suite, and the cross-platform
fixed-point gates before 0.4 can be published.
