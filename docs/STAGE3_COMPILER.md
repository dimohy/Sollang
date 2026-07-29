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

Stage 3 does not yet implement the supported CLI commands such as `build`,
`test`, `format`, `language-server`, `resolve`, `--help`, or `--version`.
Those commands remain on `sollang` in 0.3. The next transition step is to move
that complete CLI contract into Sollang and remove the C# executable only after
cross-platform behavior is verified.

## 0.4 Release Boundary

Version 0.4 is the hard transition boundary. Its public archives contain only
the fixed-point native compiler built from `.slg` compiler sources; the C#
bootstrap executable and its `.NET` support artifacts are not published.

The native executable keeps the final name `sollang` and must preserve the 0.3
CLI contract. Release packaging is blocked until command, diagnostic, output,
and exit-code compatibility is verified on Windows x64 and Linux x64. The C#
compiler may still build and differentially verify the native compiler inside
the development pipeline, but it is never copied into a 0.4 archive.
