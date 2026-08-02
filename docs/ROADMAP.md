# Sollang Implementation Roadmap

Status: core implementation and 0.4 native distribution verified
Updated: 2026-08-02

Every completed slice must add cumulative `.slg` examples, keep safe-code leak
freedom statically provable, build with zero warnings, and pass the complete
example suite. LLVM allocation assertions are required when placement or
ownership behavior is part of the feature.

## Memory Placement

- [x] Deterministic drop for owned dynamic arrays and dictionaries
- [x] Readonly, `mut`, and `move` container parameter modes
- [x] Lazy allocation for empty dynamic containers
- [x] Top-level readonly array and dictionary stack promotion
- [x] Function-entry stack-frame allocation plan
- [x] Binding lifetime intervals and non-overlapping slot reuse
- [x] Peak concurrent stack budget instead of cumulative candidate bytes
- [x] `llvm.lifetime.start/end` emission
- [x] Nested `if`, `when`, block, and loop stack promotion
- [x] Stack planning for local/standard-library inline function bodies
- [x] Function-entry placement for mutable container handles
- [x] Function-entry placement for small fixed arrays
- [x] Large fixed-array automatic heap placement

## User Types

- [x] Fixed-width `Int8/16/32/64`, `UInt8/16/32/64`, and `Float32/64` primitives
- [x] Embedded-friendly `Int = Int32`, `Long = Int64`, `Float = Float32`, and
  `Double = Float64` source aliases
- [x] Target-pointer-width `Size` and `UIntSize` ABI types
- [x] Explicit checked numeric conversions and same-type arithmetic
- [x] Nominal `struct` value types with exact field layout
- [x] Complete field initialization and direct field access
- [x] Recursive move/drop generation for owned fields
- [x] `impl` blocks and associated constructors
- [x] Readonly `self`, `mut self`, and `move self` method receivers
- [x] Object-oriented dot-call syntax without class inheritance
- [x] Payload `enum` values and exhaustive `when`
- [x] Standard `Option<T>` and `Result<T, E>` foundations
- [x] Move-aware postfix `?` propagation for owned `Result<T, E>` payloads

## Traits And Generics

- [x] Nominal `trait` declarations and explicit `impl`
- [x] Static trait dispatch as the default
- [x] Checked type generics with trait bounds
- [x] Two-parameter generics with associated-type inference
- [x] Fixed arrays with distinct `Int` and `Text` element layouts
- [x] Parametric fixed arrays for copyable user `struct` and `enum` values
- [x] Element-wise recursive drop for owned fixed-array elements
- [x] Parametric growable arrays with typed push/grow/index/drop
- [x] Parametric dictionaries with typed hash/equality, put/grow/index/drop
- [x] Readonly, `mut`, and `move` function ABI for parametric dictionaries
- [x] Readonly, `mut`, and `move` function ABI for parametric dynamic arrays
- [x] Type-preserving `each` for fixed and dynamic parametric arrays
- [x] Type-preserving `eachKey` and `eachValue` for parametric dictionaries
- [x] Static `Hash`/`Eq` trait dispatch for local/imported nominal dictionary
  keys, including recursively owned keys
- [x] Contextual struct-key literals in dictionary indexing
- [x] Compile-time `Int` value generics, `[Int; N]` parameters, and specialization
- [x] Monomorphization with deterministic ownership/drop behavior for inline values
- [x] Associated types and equality constraints for container and iterator contracts
- [x] Explicit heap-only `box T` for stable identity or recursive-size breaks
- [x] Explicit owned `dyn<Trait>` and vtables for runtime polymorphism

## Compiler Primitives

- [x] UTF-8 `Text` iteration as validated Unicode `CodePoint` values
- [x] Owned byte `Arena` with aligned bump allocation, stable offsets, growth,
  reset, checked byte access, move/mut ABI, and one-shot drop
- [x] Reusable byte-offset source spans and diagnostics
- [x] Command-line argument and environment access
- [x] Shell-free argv-based child-process execution with typed status/errors
- [x] Deterministic lexer-descriptor/parser-bytecode generation into `.slg`
- [x] Deterministic source-root discovery with sorted owned `.slg` paths
- [x] Sollang lexer/parser VM, lossless CST, AST lowering, semantics, typed IR,
  ownership analysis, and LLVM emission over generated grammar tables

## Standard Library And Tooling

- [x] Canonical scalar file I/O plus affine random-access and async file owners
- [x] Explicit user-value serialization through `BinarySerializable`
- [x] Deterministic projects, products, packages, workspaces, and lock files
- [x] Confined path/Git/registry dependency resolution
- [x] Parser-backed formatter, language server, and VS Code formatting
- [x] Native `sollang test` discovery, generated harness, filtering, and status
- [x] Windows/Linux Stage 2 differential and full self-host suite verification

The auditable self-hosting roadmap is **60/60 (100%)**. Publishing, registry
authentication, signing, broader codecs, and richer editor features are
follow-on product work rather than incomplete self-hosting gates. See
[`SELF_HOSTING_ROADMAP.md`](SELF_HOSTING_ROADMAP.md) for gate evidence.

## 0.4 Native Distribution

Sollang 0.4 completes the bootstrap transition without changing how users invoke
the compiler.

- [x] Enforce the root-cause-only completion gate for every change: permanent
  minimal reproduction, owning-layer diagnosis, shared-invariant correction,
  retained regression, focused verification, complete cross-platform suite, and
  Stage 2/Stage 3 fixed point. Any temporary workaround, symptom patch,
  defensive success path, swallowed error, hard-coded command/test branch, or
  feature reduction blocks release.
- [x] Implement the complete supported `sollang` CLI contract in `.slg`.
- [x] Verify `--version`, help, `build`, `run`, `test`, `format`, `resolve`,
  `language-server`, and `bind-cpp` argument, diagnostic, output, and exit-code
  compatibility on Windows x64 and Linux x64.
- [x] Build the release compiler from `.slg` sources with the C# bootstrap
  compiler, then prove the Stage 2/Stage 3 fixed point.
- [x] Package that native result as the only `sollang` compiler executable.
- [x] Reject `.NET` bootstrap artifacts such as `.dll`, `.deps.json`,
  `.runtimeconfig.json`, and the C#-published `sollang` executable from every
  0.4 archive.
- [x] Verify the packaged executable hash equals the fixed-point native
  compiler hash and run package-level build/run smoke tests.

Current verified implementation slices:

- [x] Cross-platform `sys.directory.create` intrinsic for compiler-owned output
  directories, including native self-host lowering and Stage 2 execution.
- [x] Native `--version`, help, explicit-source, project-directory with
  `--product`, and workspace-package `build`, plus `run`.
- [x] Transitive local path-dependency source closure for selected products.
- [x] Full bundled-standard-library compilation for explicit-source builds.
- [x] Literal program-argument forwarding after `run ... --`.
- [x] Deterministic transitive path-dependency resolution, canonical lock-file
  generation, and `--locked` stale-lock rejection.
- [x] Native `test` and `format` command matrices on Windows and Linux.
- [x] Native streaming `language-server` parity on Windows, including fragmented
  framing, diagnostics, formatting, UTF-16 positions, shutdown, and failures.
- [x] Implement native `grammar build` with byte-identical generated modules,
  SHA-256 provenance, recursive output-directory creation, and managed diagnostic
  and exit-code parity on Windows (4/4 retained command matrix).
- [x] Verify native `grammar build` on Linux and implement native `bind-cpp`; a
  help entry is not parity evidence until the command executes the managed CLI
  contract on both release platforms.
- [x] Complete project/workspace dependency, lock, default-output, diagnostic,
  library, and Wasm parity plus the remaining public commands listed above.

The final Windows and Linux native compilers pass their 7/7 and 6/6 Stage 2
gates and reproduce at Stage 3. Windows reproduces 26,830,874 LLVM bytes at
normalized SHA-256
`D2CD4F2BB7358C30C880829CCC7749DAB1A7F8411F6DA62FD3312608FD0A6FDE`;
Linux reproduces 26,814,087 bytes at
`18C03D58475D8F64FEEC72153E45D7B10245829783510770CC65C93D1E67EE52`.
The complete platform suites pass 1085/1085 Windows cases and 1084/1084
Linux-applicable cases.

Both fixed-point executables pass 16 exact top-level CLI contracts plus native
build/run, grammar build 4/4, test 10/10, format 11/11, streaming language
server 4/4, and bind-cpp 6/6. The immutable executable hashes are
`68FA1105625CC9D46C8396A8A48E92E2ECB12F160A61EDE7269F49902C648B49`
for Windows and
`140D36C12C84F2145C7593AEFA64D69318B19139C11DBF58383773937C51A8AF`
for Linux. `publish-release.ps1` requires those hash-bound parity proofs,
copies only the matching native compiler, rejects managed/bootstrap artifacts,
and builds and runs a source file from each staged package.

The C# compiler remains a development bootstrap and reference oracle. It is not
a 0.4 release asset. An internal Stage driver cannot satisfy this milestone by
being renamed: the native executable must preserve the existing public CLI.

The first checklist item is an invariant over every later item, not a task that
can be checked once and forgotten. Frequent source changes and sequentially
exposed failures do not relax it. A reported issue is fixed only after the
owning layer's invariant and its permanent regression both pass the complete
verification ladder.

## Completed Goal: Flow Junctions

With every 0.4 native-distribution requirement above complete, the accepted
branching and joining design in [`FLOW_JUNCTIONS.md`](FLOW_JUNCTIONS.md) is now
implemented and verified.

- [x] Add ordinary and labeled product values without implicit argument
  expansion.
- [x] Add sequential named `branch`, exclusive `partition`, and value-preserving
  `tap`.
- [x] Add policy-specific lazy stream joins: `zip`, `merge`, `concat`, and
  `latest`.
- [x] Add explicit `parallel branch` through the existing structured parallel
  ownership and cancellation model.
- [x] Keep ownership, effects, evaluation order, buffering, backpressure, and
  nondeterminism visible and statically checked.
- [x] Add 10 separate user examples and at least 114 logical regression cases,
  then run the complete Windows/Linux, browser-applicable, Stage 2, and Stage 3
  verification gates.
- [x] Reject provisional aliases, temporary fallback parsing, implicit cloning,
  implicit materialization, and implicit parallelism.

## Design Direction

Sollang combines Rust-style ownership, `struct`/`enum`/`trait`/`impl`, and
explicit dynamic dispatch with familiar object-oriented method calls and
encapsulation. Values and static dispatch are the defaults. Reference identity,
heap boxing, and runtime polymorphism must be explicit. Class inheritance and
implicit null are outside the intended safe language surface.
