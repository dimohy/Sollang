# Native interoperability

Status: implementation contract for Sollang 0.3

Current vertical slices: grouped C ABI declarations, contextual numeric
literals, bind-once dynamic loading, cached indirect calls, and deterministic
cleanup are implemented in both compilers. The C# reference compiler also
supports explicitly stable C aggregate values and builds and consumes
scalar-only Sollang shared libraries on Windows x64 and Linux x64; self-hosted
parity for those newer slices remains in progress.

Sollang native interoperability is one feature with four projections:

1. C ABI libraries (`.dll` on Windows and `.so` on Linux)
2. Sollang libraries exported through a stable C-compatible ABI
3. COM libraries on Windows
4. C++ libraries exposed through a generated C shim

The compiler must not grow four unrelated foreign-function systems. Parsing,
semantic checking, ownership checking, ABI classification, LLVM lowering, and
diagnostics share one target-aware Native ABI model.

## Performance contract

“Zero memory” means zero hidden heap allocation and zero avoidable copy on the
steady-state call path. A native call whose arguments and result are ABI-safe
scalars or borrowed pointers:

- performs no heap allocation;
- performs no symbol lookup after binding;
- performs no encoding conversion;
- performs no temporary aggregate copy beyond the platform ABI;
- lowers to an ordinary LLVM call using the target C calling convention.

Library loading, symbol validation, COM activation, and generated wrapper setup
may allocate outside the steady-state call path. Every such cost must be
visible in the API or paid once and cached. “Zero memory” does not mean that an
owned native result can exist without storage or that COM reference counting
can be removed.

## Target model

The common ABI description records:

- target triple and pointer width;
- library identity and platform file mapping;
- symbol name and visibility;
- calling convention;
- parameter and result ABI classes;
- structure size, alignment, field offsets, and packing;
- ownership direction (`borrow`, `move`, or returned owner);
- nullable pointers and callback lifetime;
- error convention and thread requirements;
- ABI schema version and signature hash.

Windows x64 and Linux x64 have different aggregate classification and calling
rules. The compiler classifies the source aggregate into the platform ABI's
logical argument/result classes, then delegates physical register and stack
assignment to LLVM by emitting the exact lowered function type and attributes.
It does not contain a hand-written register allocator.

Externally visible functions use LLVM's target C calling convention. Internal
Sollang functions remain free to use internal optimizations. A caller/callee
calling-convention mismatch is a compile-time error whenever the declaration is
known and otherwise a binding-time error.

## Source shape

The intended source form groups declarations under one logical library name:

```slg
native math from "math" {
    abs value: Int32 -> Int32
    hypotSquared left: Float64, right: Float64 -> Float64 as "native_hypot_squared"
}

main {
    math.abs(-42) => magnitude
    math.hypotSquared(3, 4) => squared
    "$magnitude" -> println
}
```

The current slice expects a suffix-free logical path and maps it to `.dll` on
Windows and `lib*.so` on Linux. Explicit per-target manifest mapping is a later
slice. Declaration names are also native symbol names by default.
`as "symbol"` keeps an inconvenient native export name at the declaration
boundary while the rest of the program uses the readable Sollang member name.

Native declarations have no Sollang body. They participate in ordinary type,
effect, import, and ownership checking. Implemented ABI-safe types are:

- `Unit`;
- fixed-width signed and unsigned integers;
- `Float32`, `Float64`;
- explicitly declared `abi struct` values composed recursively from those
  fixed-width scalar types;
- `ref AbiStruct` readonly pointers and `mut AbiStruct` mutable pointers as
  inputs.

`Int`, `Size`, `Text`, dynamic arrays, dictionaries, streams, closures, and
other Sollang-owned layouts do not cross the C boundary implicitly. Higher-level
bindings must state their encoding, shape, ownership, and destruction rule.
`Bool`, raw native pointers, borrowed pointer results, and owned native handles
remain subsequent slices because their representation and ownership rules must
be explicit.

An ABI-stable value is opt-in:

```slg
abi struct Point {
    x: Float64
    y: Float64
}

native geometry from "geometry" {
    lengthSquared point: Point -> Float64
    inspect point: ref Point -> Float64
    translate point: mut Point, dx: Float64, dy: Float64 -> Unit
    makePoint x: Float64, y: Float64 -> Point
}
```

Ordinary `struct` is deliberately rejected at a native boundary. `abi struct`
uses natural C field alignment with no implicit packing override; the compiler
computes and tests its size, alignment, and field offsets. Windows x64 lowers
1/2/4/8-byte aggregates through integer ABI values and larger aggregates
through caller storage and `sret`. Linux x64 follows the SysV INTEGER/SSE
eightbyte classification, using `byval`/`sret` for memory-class aggregates.
The required caller storage is stack-only; there is no hidden heap allocation.

Numeric literals use the declared native parameter as their expected type.
Consequently `multiply(6, 7)` emits `i64` literals for an `Int64` signature and
`hypotSquared(3, 4)` emits `double 3.0, 4.0`; wrapper conversions are unnecessary.

### Why this syntax fits Sollang

The 0.3 spelling was checked against the current official interoperation and
ownership designs of
[Rust](https://doc.rust-lang.org/stable/reference/type-layout.html),
[Zig](https://ziglang.org/documentation/0.15.2/),
[Swift](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/),
[Mojo](https://docs.modular.com/mojo/manual/values/ownership), and
[Carbon](https://docs.carbon-lang.dev/docs/design/interoperability/).
They reinforce four rules:

- a normal language structure must not silently acquire a stable foreign
  layout;
- value, readonly-borrow, mutable-borrow, and owned-handle crossings must be
  distinguishable in source;
- a C or C++ boundary is an explicit compatibility surface, not permission to
  expose a language's private optimized layout;
- the explicitness must compile away on the steady-state call path.

Sollang therefore keeps `abi struct Point`, `ref Point`, and `mut Point`.
`abi` modifies the value declaration whose layout it stabilizes; `ref` and
`mut` modify the parameter whose access contract they express. This is shorter
and more flow-oriented than an attribute such as `#[repr(C)]`, while avoiding
the overloaded meaning that `extern` would have for both declarations and
values. Plain `Point` means an ABI value, `ref Point` means an immutable
borrow, and `mut Point` means a mutable borrow. None of the three requires a
wrapper object or heap allocation.

For 0.3, `abi` denotes the common C-compatible value ABI used by C libraries,
Sollang library exports, COM projections, and generated C++ shims. The syntax
will grow a dialect only when a second real value layout is implemented and
tested; `abi(c) struct` is reserved as the likely compatible extension rather
than adding punctuation before it has semantic value. Opaque owned handles,
callbacks, nullable pointers, and error conventions remain explicit future
syntax decisions and must undergo the same official-language comparison,
cross-platform ABI tests, allocation tests, and compile-time benchmarks.

## Sollang shared libraries

`--library` builds public, synchronous, effect-free scalar functions as a
`.dll` or `.so`. Internal Sollang functions keep their optimized runtime
context ABI; one thin C-compatible wrapper is emitted for every public entry.

The compiler writes a deterministic target-specific interface beside the
binary:

- `math.windows-x64.slglib.json`
- `math.linux-x64.slglib.json`

A consumer needs no repeated signature block:

```slg
library fixture from "../build/fixture"

main {
    fixture.multiply(6, 7) => product
    fixture.hypotSquared(3, 4) => squared
}
```

The import path is resolved relative to the importing source file. Its
interface is a tracked compiler input, so an ABI change invalidates frontend,
semantic, codegen, and product caches. Exact warm builds restore and verify the
cached interface without parsing or linking again.

The complete ABI hash is embedded in every exported symbol name as well as the
interface. A stale binary therefore cannot be called through a compatible-
looking old symbol: binding fails before the first call. This costs no extra
steady-state comparison, allocation, or lookup. Literal arguments are lowered
directly from the imported signature, so `fixture.multiply(6, 7)` contains
`i64 6, i64 7`, while `fixture.hypotSquared(3, 4)` contains
`double 3.0, double 4.0`.

## Binding and linking

Direct imports are preferred when the dependency is known at build time. They
allow the platform linker to resolve the symbol and leave an ordinary direct or
PLT/IAT call in generated code.

Dynamic loading is a separate owned operation:

- the current slice uses `LoadLibraryA` and `GetProcAddress` on Windows;
- Linux uses `dlopen` and `dlsym`;
- the resulting library handle is affine and closes deterministically;
- a typed symbol is resolved once and stored as a function pointer;
- repeated calls through that typed symbol perform no name lookup.

Loading by ordinal is not the default. Names are auditable and stable across
ordinary builds; ordinals are allowed only through explicit generated metadata.

## Sollang library ABI

A Sollang library exports a stable C-compatible surface, not its internal
optimized function ABI. The implemented scalar slice records the target, ABI
schema, exported signatures, target file, per-signature hashes, and a
deterministic whole-interface ABI hash. Layout, ownership, and error metadata
will be added with stable structures and opaque owners.

Owned Sollang values never expose their private layout. They cross the boundary
as opaque affine handles with generated retain-free move and drop operations, or
through an explicitly stable value representation. Importing a Sollang library
validates all manifest hashes at compile time and binds ABI-hash-qualified
symbols at startup.

## COM

COM is a Windows-only projection of the same ABI model. Generated bindings map:

- `IUnknown` interface pointers to affine owned handles;
- `QueryInterface` to a checked interface conversion;
- `Release` to deterministic drop;
- an explicit clone to `AddRef`;
- failing `HRESULT` values to `Result`;
- `BSTR` and `VARIANT` through explicit owning wrappers.

COM apartment initialization and thread affinity remain explicit effects. No COM
surface is synthesized for Linux.

## C++

Sollang does not directly promise compatibility with arbitrary C++ name
mangling, class layout, exceptions, templates, or standard-library types. A
Clang-based binding tool reads the actual headers and compile flags, then emits:

- a narrow `extern "C"` shim compiled by the target C++ compiler;
- Sollang declarations using the common Native ABI;
- opaque handles for classes;
- constructor, method, and destructor wrappers;
- exception barriers that translate failures before crossing the C ABI.

Templates are supported only after concrete instantiation. STL types never cross
the boundary by value unless a generated adapter defines an explicit stable
representation.

## Verification gates

Each implementation slice must pass:

- reference-compiler and self-hosted Stage2 semantic parity;
- Stage3 fixed-point verification;
- exact success output and exact failure diagnostics;
- Windows x64 DLL and Linux x64 `.so` fixture execution;
- ABI layout tests compiled by the platform C/C++ compiler;
- steady-state allocation and call-throughput tests;
- cold and warm compiler benchmarks with regression thresholds.

Version 0.3 is released only after all four projections and these gates are
complete.

Run `scripts/verify-native-interop.ps1` to build the C fixture and execute the
native examples through Stage1 and Stage2 on Windows and Linux. The aggregate
part currently runs through Stage1 while self-host parity is being implemented.
The gate covers calls in `main`, user functions, and conditional regions, plus
scalar, readonly-reference, mutable-reference, register aggregate, memory
aggregate, and aggregate-return paths. It compares C `sizeof`, `_Alignof`, and
`offsetof` results and inspects the emitted Windows/SysV LLVM signatures. It
also checks that symbol lookup occurs only in initialization and that each
steady-state call loads the cached function pointer exactly once. The
self-hosted WebAssembly backend rejects native declarations before emitting
invalid host-loader IR. Both compilers reject non-ABI-safe signatures such as
`Text` before code generation.

Run `scripts/verify-sollang-library-export.ps1` to build a Sollang DLL and
Linux `.so`, consume both through a one-line `library` declaration, verify
their exported hash-qualified symbols and exact output, inspect LLVM for
directly typed numeric literals, and assert diagnostics for unsafe or empty
public surfaces.
