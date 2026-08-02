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
| Windows x64 | 26,828,567 | `F81E10AF1EE1B9723B226FCE10F89956CF4067D350A1152AE9F310291225FAB6` | `2223E3878D99639363D8179C3D38757FC3F5AAE2DED6E8BF8A84C27B9C6A078B` |
| Linux x64 | 26,811,780 | `07B6619F6E9E261145FA7DEE605DD1A6BE1E329177AF82A81E27FC47C2226733` | `238121E022E34C8D4BE0BF1160BAE99B36B5F16A6332C41C7A23D7D0068EFC69` |

The complete logical catalog contains 20 user examples, 827 regression cases,
and 257 diagnostics. Windows passes 1084/1084 selected cases. Linux passes all
1083/1083 applicable cases; the Windows COM case is structurally validated on
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

- Windows x64 ZIP: `dbff5b715d235032cd5886fa17dd4f9952ebdf4df6692e4a847ff2bf45594058`
- Linux x64 tar.gz: `b45de855f01d73f81d23c7c2aadb6bbb472994946a4e2c9a76325b82a8c95146`

## Root-cause-only gate

Temporary fallback paths, defensive success defaults, swallowed errors,
diagnostic suppression, command- or test-specific hard-coded branches, and
silent feature reduction are release failures. Every defect requires a
permanent focused reproduction, owning-layer diagnosis, shared-invariant
correction, retained regression, complete cross-platform suites, and the
applicable fixed-point proofs.
