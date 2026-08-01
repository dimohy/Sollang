# Sollang 0.4 Fixed-Point Compiler

Sollang 0.4 publishes one compiler executable per platform: `sollang.exe` on
Windows x64 and `sollang` on Linux x64. Each executable is compiled from the
`.slg` self-host compiler sources and reproduces itself at the verified Stage 3
fixed point. The public archives do not contain the C# bootstrap compiler,
`sollangc-stage3`, or `.NET` support artifacts.

The native executable preserves the public CLI used by earlier releases:

```text
sollang --version
sollang build <source-or-project> [options]
sollang run <source-or-project> [options] [-- program-arguments]
sollang test <project> [options]
sollang format <source> [options]
sollang resolve --project <project>
sollang grammar build <grammar> [options]
sollang language-server
sollang bind-cpp <source-or-project> [options]
```

Project, product, package, workspace, dependency, lock-file, diagnostic,
stdout/stderr, and exit-code behavior is checked against the C# reference
compiler during development. The C# compiler is an oracle and bootstrap input,
not a release asset.

## Bootstrap and fixed-point proof

The release chain is:

1. the C# bootstrap compiles the complete `.slg` compiler into Stage 2;
2. Stage 2 compiles the same ordered source manifest into Stage 3;
3. normalized Stage 2 and Stage 3 LLVM must have the same SHA-256;
4. Stage 3 LLVM must assemble and link into the native compiler;
5. the immutable native executable must pass the complete public CLI matrix;
6. the packaged executable hash must equal that verified Stage 3 executable.

Current fixed-point evidence:

| Target | LLVM bytes | Normalized LLVM SHA-256 | Native executable SHA-256 |
| --- | ---: | --- | --- |
| Windows x64 | 24,934,632 | `BDECDDCCAA23A3C8DBEE135FF525550EAD47C77D4A6CB5ED909EEE1290290434` | `5E81D0ECBFD65687A42FB17668D5DB4818967D7D0534FC13F3D4C3056AF44617` |
| Linux x64 | 24,917,845 | `417AC4E06F2D99C0419DF8EA386C672426D0EB0339FA9F1C8B6518E5A31E1CEC` | `0F63C12FF0E3422EEC7D543888102B1AE186E28356E7597631E30FCE01764098` |

The complete logical catalog contains 10 user examples, 770 regression cases,
and 231 diagnostics. Windows passes 1001/1001 selected cases. Linux passes all
1000/1000 applicable cases; the Windows COM case is structurally validated on
Linux but is not executed there.

Each fixed-point executable passes 16 exact top-level command contracts plus
the following retained matrices:

- native source/project/dependency/workspace/lock build and run;
- grammar build 4/4;
- native test 10/10;
- format 11/11;
- streaming language server 4/4;
- bind-cpp generation, compilation, and execution 6/6.

## Native-only release boundary

`publish-release.ps1` accepts only the hash-bound fixed-point executables. For
0.4 it rejects `.dll`, `.deps.json`, `.runtimeconfig.json`, `.pdb`, and Stage
driver files, verifies `sollang --version`, and uses the compiler and bundled
standard library to build and run a smoke program before archiving.

The `0.4.260801` packages contain only the native compiler, `stdlib`, `README`,
and `LICENSE`. Their archive SHA-256 values are:

- Windows x64 ZIP: `ac7b268b88ce817754c3e453be54dbf5efd4987d892da5151949345e844db9f8`
- Linux x64 tar.gz: `f661f88a51d2330de7a41b8ddee7a817d076d5c542467d74aadfc7e2b365d38f`

## Root-cause-only gate

Temporary fallback paths, defensive success defaults, swallowed errors,
diagnostic suppression, command- or test-specific hard-coded branches, and
silent feature reduction are release failures. Every defect requires a
permanent focused reproduction, owning-layer diagnosis, shared-invariant
correction, retained regression, complete cross-platform suites, and the
applicable fixed-point proofs.
