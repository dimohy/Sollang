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
| Windows x64 | 26,901,597 | `BADD8C5B6DEEA29EE8B616A11E8C1FA91908281683F1651273924ED5E7F0BDAF` | `BD79F71A12FBDFFD912CD1D5FE1AFBEB649FDCB1158A1E6E4C49FBA2B0BADF5F` |
| Linux x64 | 26,881,227 | `A46EFFE67E2C6E0E3A1C31DE291314857FEDA5611486F8BD16E1DC2E972017D4` | `405A468D41890C733B1D34BEBB6A98C763DACFC14AD2A70A15C60C5981ED01AA` |

The complete logical catalog contains 20 user examples, 828 regression cases,
and 257 diagnostics. Windows passes 1085/1085 selected cases. Linux passes all
1084/1084 applicable cases; the Windows COM case is structurally validated on
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

- Windows x64 ZIP: `7833cf399b85870c88ccb084d971c12c71af0a44a39015cf33b02eada17c9cfc`
- Linux x64 tar.gz: `f75b66712aac6524d593ee04a5c1423bbdb3b9f9819f4263f0ea57d225f67f8d`

## Root-cause-only gate

Temporary fallback paths, defensive success defaults, swallowed errors,
diagnostic suppression, command- or test-specific hard-coded branches, and
silent feature reduction are release failures. Every defect requires a
permanent focused reproduction, owning-layer diagnosis, shared-invariant
correction, retained regression, complete cross-platform suites, and the
applicable fixed-point proofs.
