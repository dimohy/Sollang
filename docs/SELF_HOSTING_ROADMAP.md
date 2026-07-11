# SmallLang Self-Hosting Roadmap

Status: active
Updated: 2026-07-11

The end state is an SL compiler written in SL that reads a multi-file SL
program, performs lexical, syntactic, type, ownership, and module analysis,
emits LLVM IR, and invokes the platform toolchain. The existing C# compiler is
the bootstrap compiler until the SL compiler passes a reproducible stage-2
comparison.

## Research Basis

The design deliberately combines a small set of compatible ideas:

- Rust: affine ownership, explicit traits, associated types, and static
  dispatch by default. See the official
  [trait reference](https://doc.rust-lang.org/reference/items/traits.html) and
  [associated items](https://doc.rust-lang.org/stable/reference/items/associated-items.html).
- Mojo: the same visible `[]` surface for compile-time type and value
  parameters, with specialization at use sites. See
  [generics](https://docs.modular.com/mojo/manual/generics/) and
  [parameterization](https://docs.modular.com/mojo/manual/parameters/).
- Zig: an explicit root-module dependency graph and declaration discovery from
  reachable imports. See the official
  [compilation model](https://ziglang.org/documentation/master/#Compilation-Model).
- Swift: source files belong to modules, packages group modules, declarations
  are internal by default, and public API is opt-in. See
  [access control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
  and [packages](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/introducingpackages/).

SL keeps its own expression-first `=>` binding and fluent `->` application
syntax. It does not adopt class inheritance, implicit null, implicit garbage
collection, implicit heap allocation, or a default runtime dispatch layer.

## Progress Calculation

There are 60 auditable capability gates. A complete gate scores 1, a partial
gate scores 0.5, and a missing gate scores 0. The percentage is the score
divided by 60. A gate becomes complete only with a cumulative `.sl` example or
an automated compiler test. This count measures language/compiler capability,
not lines of code.

| Area | Gates | Complete | Partial | Missing | Score |
| --- | ---: | ---: | ---: | ---: | ---: |
| Core syntax and control flow | 10 | 8 | 2 | 0 | 9.0 |
| Types, traits, and generics | 12 | 6 | 3 | 3 | 7.5 |
| Ownership and storage | 10 | 7 | 2 | 1 | 8.0 |
| Modules, visibility, and builds | 8 | 2 | 3 | 3 | 3.5 |
| Compiler-construction primitives | 12 | 2 | 3 | 7 | 3.5 |
| Standard library and tooling | 8 | 2 | 3 | 3 | 3.5 |
| **Total** | **60** | **27** | **16** | **17** | **35.0 / 60** |

Current count-based progress: **58.3% (35.0 of 60 equivalent gates)**.
There are **25 equivalent gates remaining**. Because the missing compiler
primitives are harder than early syntax gates, this is not an elapsed-time
estimate.

## Gate Inventory

### Core syntax and control flow — 9.0 / 10

- Complete (8): functions, local functions, expressions, bindings, arithmetic
  and Boolean logic, `if`/`when`, ranges/loops, block-function calls.
- Partial (2): general multi-parameter functions; structured early exit with
  `return`/`break`/`continue` across ownership scopes.

### Types, traits, and generics — 7.5 / 12

- Complete (6): nominal structs, payload enums, exhaustive matching, impl
  methods, nominal traits/static dispatch, checked type/value specialization.
- Partial (3): generic functions are currently single-type; `[Int; N]` exists
  but general `[T; N]` does not; container element types remain `Int`-only.
- Missing (3): associated types and equality constraints, standard
  `Option[T]`/`Result[T, E]`, explicit `dyn Trait`.

### Ownership and storage — 8.0 / 10

- Complete (7): unique owned values, readonly borrow by default, `mut` borrow,
  explicit `move`, recursive static drop glue, lifetime-based stack placement,
  explicit `box T`.
- Partial (2): borrow lifetimes are intentionally narrow; ownership through
  fully generic containers is not implemented.
- Missing (1): a complete path-sensitive borrow checker for references returned
  from functions and stored in user values.

### Modules, visibility, and builds — 3.5 / 8

- Complete (2): file namespaces/import aliases; multiple user source files in
  one compilation unit.
- Partial (3): stdlib loading uses a fixed bootstrap list; imports resolve names
  but do not yet drive file discovery; one root file is enforced by executable
  top-level statements rather than an explicit module manifest.
- Missing (3): `public`/internal visibility, package manifest and dependency
  graph, module/interface cache with cycle diagnostics.

### Compiler-construction primitives — 3.5 / 12

- Complete (2): Text values and deterministic native file I/O wrappers needed
  by the existing demos.
- Partial (3): arrays/dictionaries are `Int`-specialized; string processing is
  output-oriented; diagnostics exist but have no reusable source-span type.
- Missing (7): byte buffers, Unicode/code-point iteration, generic collections,
  tagged error propagation, arena/bump allocation, command-line/environment
  APIs, process execution.

### Standard library and tooling — 3.5 / 8

- Complete (2): basic `sys.io` and three LLVM-backed target link paths.
- Partial (3): file/random/time APIs are narrow compiler intrinsics; VS Code
  support is grammar-only; tests are example-driven without an SL unit-test
  framework.
- Missing (3): portable path/filesystem library, package/build command, formatter
  and language server based on the real parser.

## Critical Path To Self-Hosting

1. Finish the module graph: imports discover files, visibility is enforced, and
   a project manifest names the root module and dependencies.
2. Finish the reusable type substrate: multi-parameter generics, associated
   types, generic `Array[T]`/`Dictionary[K, V]`, `Option`, and `Result`.
3. Add compiler data primitives: bytes, source spans, Unicode iteration, arena
   allocation, filesystem traversal, arguments, and process execution.
4. Write the SL lexer and parser using generated bootstrap tables only where
   necessary; compare tokens and AST snapshots against the C# compiler.
5. Port semantic/type/ownership analysis and serialize a stable typed IR.
6. Implement an SL LLVM IR text builder, then compile representative programs
   with both compilers and compare normalized IR plus runtime output.
7. Stage 1: C# compiler builds the SL compiler. Stage 2: that SL compiler builds
   itself. Stage 3: the stage-2 compiler rebuilds itself byte-for-byte or with
   normalized-IR equivalence, depending on target linker determinism.

## Immediate Implementation Order

1. Multi-file compilation (implemented by example 52).
2. Import-driven file discovery with cycle and duplicate-module diagnostics.
3. Internal-by-default visibility with explicit `public` exports.
4. Associated types, then generic collection element types.
5. `Option`/`Result` and compiler-grade byte/text/source-span libraries.
