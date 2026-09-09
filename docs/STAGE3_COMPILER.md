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
stdout/stderr, and exit-code behavior is checked against the C# bootstrap after
the `.slg` candidate passes its focused proof. The C# compiler is a recovery
bootstrap and independent oracle, not the design authority or a release asset.

## Development authority order

Normal compiler work follows this order:

1. implement the contract in the `.slg` self-host compiler;
2. compile it with the newest compatible verified SLG executable and run the
   focused Typed IR, LLVM, and execution fixture; prefer fixed-point Stage 3,
   while a receipt-bound Stage 2 may bridge one generation when the older Stage
   3 cannot represent current source;
3. implement the same contract in C# and run the managed differential oracle;
4. require Stage 2/Stage 3 fixed-point convergence before release or global
   installation.

If no verified SLG seed can parse or represent the new compiler source, a
minimal C# bootstrap bridge may precede step 1. That exception must be explicit
and cannot become a second semantic authority.

## Bootstrap and fixed-point proof

The cold trust-bootstrap release chain, used only when a verified SLG seed is
unavailable or when rebuilding the complete trust proof, is:

1. the C# bootstrap compiles the complete `.slg` compiler into Stage 2;
2. Stage 2 compiles the same ordered source manifest into Stage 3;
3. normalized Stage 2 and Stage 3 LLVM must have the same SHA-256;
4. Stage 3 LLVM must assemble and link into the native compiler;
5. the immutable native executable must pass the complete public CLI matrix;
6. the packaged executable hash must equal that verified Stage 3 executable.

After the fixed-point and artifact gates pass, the Stage 3 verifier publishes a
schema-bound `.stage3-seed.json` beside the copied feedback seed. Formal SLG
Stage 2 accepts that seed only after rehashing the retained Stage 2 and Stage 3
executables, LLVM, bitcode, completion receipts, and Stage 3 input receipt. The
receipt also fixes the target, Stage 3 gate producer, O1 optimization profile,
and normalized fixed-point LLVM hash. A sibling executable SHA-256 or a Stage 1
generation receipt alone does not authorize formal fixed-point seeding.

Current fixed-point evidence for the 2026-08-25 source tree:

| Target | LLVM bytes | Normalized LLVM SHA-256 | Native executable SHA-256 |
| --- | ---: | --- | --- |
| Windows x64 | 30,318,335 | `E46E5C75F457F738B09EEF86DF8380124BD0F953BEC19684F129F02561DC98FC` | `C9ED64FB9E1F33FB3F078D50DD1B6D2E20975FC0C79C3082F75159B9494A0585` |
| Linux x64 | 30,297,787 | `DAD5300890F22B96A05EADA3FA84CF03CE6606679E7BFA79B89804558096F4CE` | `AD21BC826C944A270716AA57A12E137E7AEDAAB56579FED2771554D8BDB62CE1` |

The complete logical catalog contains 20 user examples, 995 regression cases,
and 274 diagnostics. Windows passes 1269/1269 selected cases. Linux passes all
1268/1268 applicable cases; the Windows COM case is structurally validated on
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

`publish-release.ps1` accepts only a complete receipt-bound fixed-point artifact
set. A custom `WindowsStage3Path` or `LinuxStage3Path` must retain its sibling
Stage 2 compiler, Stage 3 LLVM/bitcode, Linux object, and published input/output
receipts; packaging recomputes the current ordered-source input fingerprint
and rechecks Stage2/Stage3 normalized LLVM equality before copying the
executable. For
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
