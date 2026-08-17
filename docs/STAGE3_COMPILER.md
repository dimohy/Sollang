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
| Windows x64 | 28,317,932 | `E97879C3C968DDB0751425A0109621522AE26F77675E2981856966FC7A63E527` | `971BEDAD6D8842890EAEACA62477C4359E56369495F08CCA1C1B5B8132E4C4BD` |
| Linux x64 | 28,297,562 | `7D80DCE6C5C6AC4094E5E85AC0FCB1552D16DA233A151277782BC66562B73AAF` | `885E5B869628169A8623A3C15597BC5FE1A0E94A375FEB2968297C8AE7FBE1C1` |

The complete logical catalog contains 20 user examples, 985 regression cases,
and 274 diagnostics. Windows passes 1259/1259 selected cases. Linux passes all
1258/1258 applicable cases; the Windows COM case is structurally validated on
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

The `0.4.260817` packages contain only the native compiler, `stdlib`, `README`,
and `LICENSE`. Their archive SHA-256 values are:

- Windows x64 ZIP: `55e0c55d9687d04b788f94584e3f634c894d8c6427bef5b7b6563eef8973c400`
- Linux x64 tar.gz: `042f0df38e28d4e0ce332fab76ffe1d0dae45bc347f79ca01d3f2ab7d7c5d82c`

## Root-cause-only gate

Temporary fallback paths, defensive success defaults, swallowed errors,
diagnostic suppression, command- or test-specific hard-coded branches, and
silent feature reduction are release failures. Every defect requires a
permanent focused reproduction, owning-layer diagnosis, shared-invariant
correction, retained regression, complete cross-platform suites, and the
applicable fixed-point proofs.
