# Native interoperability

Status: implementation contract for Sollang 0.3

Current vertical slices: grouped C ABI declarations, contextual numeric
literals, explicitly stable C aggregate values, bind-once dynamic loading,
cached indirect calls, affine native handles, and deterministic cleanup are
implemented in both compilers on Windows x64 and Linux x64. The C# reference
compiler builds and consumes Sollang shared libraries on both targets. The
self-hosted compiler preserves `library ... from ...` declarations, resolves
their source-relative target manifests, maps each canonical interface once,
and decodes schema, ABI, hashes, exports, and scalar signatures into flat
span-backed catalog tables without manufacturing or reparsing Sollang source.
Qualified catalog lookup, contextual argument typing, ordinary call/Typed IR
projection, cached symbol initialization, and direct Windows/Linux execution
are implemented in the self-hosted compiler. Windows COM activation, checked
`QueryInterface`, scalar calls, explicit cloning, and deterministic release
have reference-compiler and self-hosted lowering plus actual COM-server
execution coverage. The
Clang-based binding tool generates and executes direct and checked C++ shims,
including affine class handles, through both compilers on Windows and Linux.

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

The implemented reference-compiler syntax groups a class and its interfaces:

```slg
com fixture class "00000000-0000-0000-C000-000000000046"
    from "artifacts/com-interop/com_fixture" in mta {
    interface Calculator "11111111-2222-3333-4444-555555555555" {
        add left: Int32, right: Int32 -> Result<Int32, Int32> at 3
    }
}
```

`from` selects direct in-process activation through the DLL's
`DllGetClassObject`; omitting it uses registered activation through
`CoCreateInstance`. `in sta` and `in mta` make the apartment contract visible.
The first interface receives `fixture.create`, every interface receives an
explicit `fixture.clone`, and methods retain normal flow syntax:

```slg
fixture.create -> match {
    Ok calculator {
        calculator -> fixture.add(20, 22)
    }
    Error hresult { hresult -> println }
}
```

The interface value is affine. Dropping it invokes vtable slot 2 (`Release`);
`clone` invokes slot 1 (`AddRef`), and declared methods use their explicit
vtable slot. Apartment initialization, direct-server loading, class-factory
lookup, and symbol lookup are cached at program entry. Steady-state scalar
method calls use one indirect LLVM call and introduce no heap allocation,
reflection, wrapper object, or per-call lookup.

The supported 0.3 COM surface covers activation, scalar methods returning `Unit` or
`Result<scalar, Int32>`, checked `QueryInterface` conversions, explicit
cloning, and deterministic release. Owning `BSTR` and `VARIANT` wrappers are
outside the 0.3 surface and will be added only with explicit encoding,
ownership, and cross-apartment tests. Self-hosted COM runtime
lowering lives in a dedicated emitter submodule rather than growing
`selfhost/llvm/text.slg`.

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

The implemented first C++ slice is:

```text
sollang bind-cpp math.hpp --module math --output generated/math --build
```

It loads the pinned toolchain's `libclang`, parses the real C++ AST, preserves
namespaces, gives overloads deterministic type-qualified Sollang names, and
emits `math.slg`, `math_shim.cpp`, and a deterministic target manifest.
`--compile-commands <directory-or-file>` reuses the selected compilation
database entry, while `--compile-entry <source.cpp>` disambiguates multiple
entries. The lossless `arguments` form is required instead of a shell-quoted
`command`.

This slice accepts fixed-width-compatible scalar parameters and results on
non-variadic free functions and public class members. `noexcept` functions and
methods keep the direct ABI. Potentially throwing functions and methods use a
generated exception barrier, while every constructor uses the checked path so
allocation failure cannot become a hidden null handle. A generated class
projection uses an affine Native ABI handle:

```slg
native geometry from "geometry_shim" {
    handle Counter drop "sollang_cpp_Counter_drop_..."
    try createCounter initial: Int32 -> geometry.Counter as "..."
    counterAdd self: ref geometry.Counter, amount: Int32 -> Int32 as "..."
}
```

`try ... -> T` has source type `Result<T, Int32>`. Its physical C ABI is
`int32_t(args..., T* out) noexcept`: status zero constructs `Ok`, and a nonzero
status constructs `Err`. Generated C++ barriers currently use stable error code
`1` for any caught exception, including allocation failure. The output slot and
the Result value are stack aggregates; no Sollang heap allocation, reflection,
or wrapper object is introduced. `noexcept` calls do not pay for this branch or
out pointer.

The handle occupies one pointer-sized ABI word, cannot be constructed,
inspected, copied, or mutated as an ordinary struct, and invokes its generated
destructor export exactly once when ownership leaves scope. Calls borrow the
handle by readonly reference, so no wrapper object, heap allocation, or handle
copy is introduced on the steady-state method path. The C++ object allocation
itself remains the constructor's explicit cost.

The supported 0.3 C++ projection is complete for fixed-width scalar functions,
checked exception barriers, and affine class handles. Both the reference
compiler and the self-host compiler execute checked scalar
and affine handle results on Windows and Linux. The self-host path parses
generated Native Handle declarations, resolves their nominal pointer type,
rejects struct-literal forgery, traps null constructor results, resolves and
caches the declared drop symbol at startup, and invokes it exactly once at
scope exit. Its steady-state handle path has no wrapper heap allocation or
per-call symbol lookup. Selected template instantiations and callback lifetimes
are outside the 0.3 surface and require explicit generated lifetime contracts.
Raw pointers are never exposed or temporarily
disguised as user-visible integers.

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
native examples through Stage1 and Stage2 on Windows and Linux. The gate covers
calls in `main`, user functions, and conditional regions, plus scalar,
readonly-reference, mutable-reference, register aggregate, memory aggregate,
aggregate-return, narrow signed/unsigned scalar, and register-pressure paths
in both compilers. It compares C `sizeof`, `_Alignof`, and `offsetof` results
and inspects the emitted Windows/SysV LLVM signatures. It also checks that
symbol lookup occurs only in initialization and that each steady-state call
loads the cached function pointer exactly once. The self-hosted WebAssembly
backend rejects native declarations before emitting invalid host-loader IR.
Both compilers reject non-ABI-safe signatures such as `Text` before code
generation.

Run `scripts/verify-sollang-library-export.ps1` to build a Sollang DLL and
Linux `.so`, consume both through a one-line `library` declaration, verify
their exported hash-qualified symbols and exact output, inspect LLVM for
directly typed numeric literals, and assert diagnostics for unsafe or empty
public surfaces.

Run `scripts/verify-cpp-interop.ps1` to generate the same C++ binding for
Windows x64 and Linux x64, build the DLL and `.so`, and execute consumers
through both Stage1 and self-hosted Stage2. The gate exercises direct and
throwing functions, checked construction, Native Handle forgery rejection,
null-result validation, exact destruction counts, cached drop lookup,
zero-wrapper-heap lowering, stack-only Result lowering, deterministic overload
naming, and byte-identical manifest regeneration.
