# SmallLang Array And Ownership Design

Status: implemented slice plus future design
Date: 2026-07-09

This document records the proposed static and dynamic array model for
SmallLang and the first implemented container slice.

The implemented slice is intentionally narrower than the final design. It
supports `Int` static arrays, `Int` dynamic arrays, and `{Int: Int}`
dictionaries, with deterministic drop insertion for owned heap containers.
It also supports move-consuming owner transforms for growable arrays and
dictionaries, mutable indexing assignment, typed empty dynamic arrays and
dictionaries, block-local drop scopes for heap-owning containers, and owned
growable array/dictionary parameters and returns in functions. Borrowed slices
and generic element types remain future work.

## Rust Reference Points

SmallLang should use Rust as the main reference for this area, but should not
copy Rust syntax blindly.

- Rust manages memory through compile-time ownership rules rather than a tracing
  garbage collector:
  <https://doc.rust-lang.org/book/ch04-01-what-is-ownership.html>
- Rust arrays are fixed-size `[T; N]` values whose size is a constant
  expression:
  <https://doc.rust-lang.org/reference/types/array.html>
- Rust slices are borrowed views into a sequence, such as `&[T]` and
  `&mut [T]`:
  <https://doc.rust-lang.org/reference/types/slice.html>
- Rust `Vec<T>` is a contiguous growable heap allocation with length and
  capacity. SmallLang should take the ownership model, not the `Vec` surface
  name:
  <https://doc.rust-lang.org/std/vec/>

Further web review changed the emphasis:

- Rust is the best mainstream reference for ownership, borrowing, fixed arrays,
  slices, and growable arrays, but Rust does not guarantee leak freedom. Safe
  Rust can intentionally forget values, and reference-count cycles can leak:
  <https://doc.rust-lang.org/std/mem/fn.forget.html>
  <https://doc.rust-lang.org/book/ch15-06-reference-cycles.html>
- Zig is a useful reference for explicit allocator design and the "where are
  the bytes?" mindset, but it leaves memory management to the programmer rather
  than proving leak freedom at compile time:
  <https://ziglang.org/documentation/master/#Memory>
- Austral is a useful reference for linear resource checking. Its specification
  rejects linear values that are never consumed, consumed more than once, or
  still unconsumed at function return:
  <https://austral-lang.org/spec/spec.html#Linear-Types>

Conclusion: SmallLang should keep the Rust-shaped array model, but make safe
SmallLang stricter than Rust by removing safe `forget`/`leak`, implicit shared
ownership, and unproven cyclic ownership from the safe surface.

## Core Decision

SmallLang should split array concepts by ownership:

```text
[T; N]      owned fixed-size array
[T; ~]      owned growable heap array
&[T]        shared borrowed slice view
&mut [T]    exclusive mutable borrowed slice view
```

This avoids the common GC-language ambiguity where a dynamic array value may or
may not own its backing storage. In SmallLang, a value either owns storage or it
borrows storage from another owner.

The source syntax should also look like SmallLang, not Rust. `Vec<T>` is only a
reference model for the internal ownership shape. User code should say
`[T; ~]`, not `Vec<T>`.

`{ ... }` should not be used for dynamic arrays. Braces already delimit blocks,
and they are a better future fit for dictionaries or maps. Dynamic arrays stay
inside the `[]` family and use `~` to show that the sequence is open and
growable. A number immediately before `~`, as in `[Int; 1024~]`, is a capacity
hint, not an initial length.

## Implemented Container Slice

The current compiler implements the first `Int` container slice:

```smalllang
main {
    [1, 2, 3] => numbers
    numbers[0] => first
    numbers -> len => count

    [10, 20, ~] => values!
    values! -> push(30)
    values![2] => third
    99 => values![1]
    values! -> capacity => capacity

    [10, 20, ~] => values
    values -> append(30) => values
    values -> updated(0, 99) => values

    { 1: 100, 2: 200 } => scores!
    scores! -> put(3, 300)
    250 => scores![2]
    scores![3] => score

    { 1: 100, 2: 200 } => frozenScores
    frozenScores -> updated(2, 250) => frozenScores
}
```

Supported now:

- `[1, 2, 3]` creates an owned fixed-size `Int` array stored inline in the
  owner.
- `[0; 8]` creates a repeated fixed-size `Int` array.
- `[1, 2, ~]`, `[Int; ~]`, and `[Int; 1024~]` create owned growable `Int`
  arrays.
- `{ 1: 100, 2: 200 }` and `{Int: Int}` create owned `{Int: Int}`
  dictionaries.
- `value => name!` creates a mutable owner binding needed by mutating container
  operations. The `!` suffix is part of the local name and remains visible at
  every use site.
- `array[index]` and `dictionary[key]` are checked reads.
- `array -> len`, `array -> capacity`, `array -> push(value)`,
  `dictionary -> len`, `dictionary -> capacity`, and
  `dictionary -> put(key, value)` are implemented as receiver-flow operations.
- `array -> append(value)` consumes the source growable array owner and returns
  the moved owner with the appended value.
- `container -> updated(keyOrIndex, value)` consumes the source growable array
  or dictionary owner and returns the moved owner with one value changed or
  inserted.
- Static and dynamic `Int` arrays work with `each` and `fold`.
- Functions may accept `[Int]` readonly views. Static and growable `Int` arrays
  can be passed as `[Int]` without moving ownership, and the caller can keep
  using the owner after the call.
- Native Windows and Linux targets allocate through the selected platform
  runtime and emit deterministic cleanup at scope exit.

Current safety boundary:

- Heap-owning containers must be created directly at the binding site, such as
  `[Int; ~] => values!` or `{Int: Int} => scores!`.
- Heap-owning containers cannot be produced as anonymous intermediate values in
  a flow chain because the compiler would have no stable drop owner yet.
- Mutating operations such as `push` and `put` require a named mutable owner.
- Move-consuming heap-owning transforms such as `append` and `updated` must be
  final flow targets and must be bound directly with `=>`, so the moved owner
  has a known deterministic drop point.
- After a move-consuming transform, the source binding is no longer live. The
  target may reuse the same name, such as `values -> append(30) => values`,
  because the old owner is consumed before the new owner is bound.
- Container creation inside nested blocks is supported. Heap-owning containers
  created in a block are dropped at the end of that block unless the block's
  final expression moves the owner out.
- A block result may move out a block-local growable array or dictionary owner.
  Moving an owner from an outer scope through a block result is rejected, except
  when every function return branch transfers that function's own `move` input.
- Functions may return `[Int; ~]` and `{Int: Int}` owners. The caller must bind
  the returned owner directly, and then the caller owns the drop obligation.
  Anonymous flow use such as `makeValues() -> len` is rejected.
- Functions may accept `[Int]` readonly views. The callee may read with
  indexing, `len`, `each`, and `fold`; it cannot mutate the source or store the
  view beyond the call.
- Functions may accept `{Int: Int}` readonly views. The callee may use indexing,
  `len`, and `capacity`; it cannot mutate, move, return, or store the view, and
  the caller keeps ownership.
- Functions may accept `mut [Int; ~]` and `mut {Int: Int}` mutable borrows. The
  caller must pass a named mutable owner such as `values!` or `scores!`; the
  callee may `push`, `put`, or assign by index, and the caller keeps ownership
  after the call.
- Functions may accept `move [Int; ~]` and `move {Int: Int}` owners. Passing
  one moves the caller's owner into the callee; the source binding cannot be
  used after the call. The callee may return that owner directly or after
  `append` or `updated`; the caller must bind the result and receives the drop
  obligation. Conditional returns must transfer it on every branch or none.
- Browser WebAssembly currently rejects heap-owning containers because the
  browser target does not yet provide a linear-memory allocator.
- `Text` arrays and generic containers are not implemented yet.

## Function Call Surface

Web review also suggests that `func!` should not be the ordinary function-call
marker. Rust uses `name!(...)` for macros, Elixir uses trailing bang for
raising variants, and Julia uses trailing bang for functions that mutate their
arguments. Reusing `!` for ordinary calls would spend a valuable punctuation
mark on the wrong meaning:

- <https://doc.rust-lang.org/reference/macros.html>
- <https://hexdocs.pm/elixir/main/naming-conventions.html#trailing-bang-foo>
- <https://docs.julialang.org/en/v1/manual/style-guide/#bang-convention>

SmallLang should instead remove the empty-parentheses marker for value-flow
calls whose only explicit input is the value on the left:

```smalllang
getName() => name
7 -> square => num
values -> len => count
```

Parentheses should remain only when the flow target receives additional
arguments beyond the primary left value:

```smalllang
values! -> push(10)
values! -> reserve(1024)
```

This keeps the common case closer to pipeline languages, while preserving a
familiar argument list when extra arguments are present. It should supersede the
current empty-parentheses-only value-flow call marker when the parser and
semantic checks are updated.

## Static Arrays

Static arrays are fixed-size owned values:

```smalllang
[1, 2, 3] => numbers          # inferred as [Int; 3]
[0; 8] => zeros               # inferred as [Int; 8]
```

The type form is:

```smalllang
[Int; 3]
[Text; 4]
```

Rules:

- `N` is a compile-time constant expression.
- All elements are initialized before the array value exists.
- Safe indexing is bounds-checked.
- A local static array is stored inline where the owner lives unless later
  lowering decides a better storage class.
- Moving a static array moves the whole owned value.
- Copying a static array is only implicit when the element type is `Copy`.
- Array elements are dropped deterministically when the array owner is dropped.

Storage placement:

- `[T; N]` is stored inline inside its owner.
- If the owner is a local binding, the array is a stack allocation candidate.
- If the owner itself is heap-allocated, the fixed array lives inline inside
  that heap allocation.
- `[T; N]` does not mean "always stack"; it means "fixed-size inline storage".
- Large fixed arrays can be explicitly moved to heap-owned storage later with a
  flow operation:

```smalllang
[0; 1000000] -> heap => buffer
```

The `heap()` operation should produce an owned heap value whose drop recursively
drops the contained fixed array and deallocates the heap block. It is not a
borrow and not a garbage-collected reference.

## Dynamic Arrays

Dynamic arrays are owned growable array values. The internal model is
Rust `Vec<T>`-like, but the SmallLang source surface uses array syntax:

```smalllang
[Int; ~] => values!
[10, 20, ~] => seeded!
values! -> push(10)
values! -> push(20)
values! -> len => count
```

The runtime representation is conceptually:

```text
ptr: *mut T
len: Int
capacity: Int
```

Rules:

- A dynamic array owns its payload storage. Heap allocation is the normal
  placement; D063 permits proven local readonly literals to own stack storage.
- Moving a dynamic array moves the ownership of the buffer; the old binding
  cannot be used afterward.
- Dropping a dynamic array drops initialized elements and deallocates only a
  heap-placed buffer.
- `push` may reallocate and therefore requires exclusive mutable access.
- Any slice or element borrow into a dynamic array must end before a mutating
  operation that may reallocate.
- A dynamic array has no implicit shared ownership and no hidden reference
  counting.

Storage placement:

- The dynamic array owner value is a small handle: pointer, length, and capacity.
- A local dynamic array binding can store that handle on the stack.
- The element buffer normally uses heap storage when capacity is nonzero.
- A small literal payload may use stack storage when placement analysis proves
  that its immutable local owner never grows or escapes the current frame.
- Moving a dynamic array moves the handle and transfers ownership of the heap
  buffer. It does not copy the buffer.
- Reallocation may move the element buffer, so active element/slice borrows must
  end before `push`, `reserve`, or any operation that can reallocate.

### Stack And Heap Cost

- A local `[Int; N]` stores its elements inline and is currently emitted as an
  LLVM entry-slot allocation when it fits the planned frame budget. A fixed
  array that does not fit is automatically placed in owned heap storage and
  freed at its scope drop point. Its indexing and readonly-view surface does
  not depend on the selected storage.
- A local `[Int; ~]` or `{Int: Int}` stores only a three-word owner handle
  (`ptr`, `len`, `capacity`) in the local frame. Its elements or hash-table
  storage normally live in one owned heap allocation when capacity is nonzero.
- A direct nonempty `[Int; ~]` literal bound to an immutable local in `main`, a
  non-inline user function, or one of their nested control-flow blocks is
  stack-promoted when all later uses are readonly. Recognized readonly uses are
  checked indexing, `len`, `capacity`, `each`, `fold`, and calls through
  `[Int]` parameters.
- A direct nonempty `{Int: Int}` literal has the same placement rule. Its stack
  cost includes control bytes, alignment padding, and every 16-byte key/value
  slot in the Swiss table. Recognized readonly uses are checked lookup, `len`,
  `capacity`, and calls through `{Int: Int}` readonly parameters.
- Any `move`, `append`, `updated`, mutable binding, possible growth, or function
  result escape keeps the payload on the heap. `put` also keeps dictionaries on
  the heap. Local/standard-library inline functions and block-function bodies
  are not promoted in this slice, because an `alloca` emitted inside a caller
  loop could accumulate until the frame returns.
- The frame planner assigns every promoted payload a creation-to-last-use
  interval. Non-overlapping intervals may share one function-entry stack slot,
  including mutually exclusive branches and repeated loop bodies. LLVM
  `lifetime.start/end` calls delimit each use of the slot.
- Automatic array and dictionary promotion uses a 4096-byte planned frame
  budget. The budget is charged by physical slot size after reuse rather than
  by the sum of every candidate payload. Stack-promoted owners keep the normal
  `ptr`/`len`/`capacity` interface but emit neither allocation nor `free`.
- `[Int; ~]` and `{Int: Int}` begin as `{ null, 0, 0 }` when no capacity hint
  is supplied, so merely creating or readonly-borrowing an empty container does
  not allocate. The first `push` or `put` lazily allocates an initial capacity.
- Readonly dictionary calls copy only that three-word handle. They do not copy,
  allocate, rehash, or free dictionary storage. LLVM may keep the words in
  registers or spill them to the stack according to the target ABI.
- `move` also transfers only the handle and drop obligation. It does not copy
  elements. `mut` passes three addresses to the caller's handle slots so growth
  can update the original owner without another heap wrapper.

The type form is:

```smalllang
[Int; ~]
[Text; ~]
```

The literal form uses an open tail marker:

```smalllang
[1, 2, 3, ~] => values!
```

The `~` marker means the sequence is not a closed fixed-size value anymore; it
is an owned growable array initialized with the listed elements.

The first implementation can support `[Int; ~]` and `[Int; N~]` only, but the
language design should keep `[T; ~]` generic from the start.

## Dictionaries

Dictionaries use braces because braces are a natural fit for key-value data and
because dynamic arrays stay in the `[]` family:

```smalllang
{ 1: 100, 2: 200 } => scores!
scores![1] => firstScore
scores! -> put(3, 300)
scores! -> len => count
scores! -> capacity => capacity
```

The final type form should be:

```smalllang
{Text: Int}
{Int: Text}
```

The implemented slice supports only `{Int: Int}`. It normally stores owned heap
data behind a small owner handle and frees that storage at the owning binding's
drop point. Proven local readonly literals instead own one aligned stack block
and require no free. Lookup is checked: a missing key traps in the current
runtime slice instead of returning an arbitrary fallback value. A later `get`
API should return `Option<T>` once option types exist.

The empty literal `{}` is intentionally not accepted yet because it needs an
explicit type annotation or constructor form to avoid guessing key and value
types.

## Borrowed Slices

Most read-only array functions should accept a slice, not an owned dynamic
array:

```smalllang
sum values: &[Int] -> Int {
    values -> fold 0 total, value {
        total + value
    }
}

[1, 2, 3] => numbers
numbers -> sum => total
```

Slices are non-owning views:

```text
&[T]      ptr + len, read-only
&mut [T]  ptr + len, exclusive mutable
```

Rules:

- A slice never drops or deallocates the data it points to.
- A slice cannot outlive the owner it borrows from.
- Multiple shared slices may exist at the same time.
- One mutable slice may exist only when there are no other active borrows of the
  same data.
- Static arrays and dynamic arrays can both be borrowed as slices.

This keeps APIs flexible. A function that only reads elements can work with a
static array, a dynamic array, or a sub-slice without taking ownership.

## Mutability

SmallLang should keep immutable bindings as the default and introduce explicit
mutable bindings when arrays need in-place updates:

```smalllang
[Int; ~] => values!
values! -> push(10)
values! -> push(20)

99 => values![1]
```

Rules:

- `value => name` creates an immutable binding.
- `value => name!` creates a mutable owner binding.
- Assigning to `values![index]` requires a mutable owner binding or mutable
  borrow.
- Borrowing a mutable binding as `&mut` is exclusive for the duration of the
  borrow.

This is Rust-inspired, but keeps the binding direction aligned with SmallLang's
existing flow syntax.

Immutable bindings can still produce changed values by moving the owner into a
new owner:

```smalllang
[1, 2, ~] => values
values -> append(3) => values
values -> updated(0, 9) => values

{ 1: 100, 2: 200 } => scores
scores -> updated(2, 250) => scores
```

These operations consume the source owner. After `values -> append(3) =>
values`, the old `values` owner is dead and the target binding receives the
moved owner. Reusing the same name is allowed only because the old owner is
consumed first.

The compiler lowers this as a unique-owner transform:

- `append` reuses the existing dynamic-array buffer when capacity remains. When
  capacity is full, it grows the buffer and frees the old allocation, matching
  the amortized O(1) shape of Rust `Vec` growth.
- Dynamic-array `updated` checks bounds and writes into the moved buffer in
  place.
- Dictionary `updated` reuses the `put` path: existing keys update in place,
  while new keys probe into a Swiss-style hash table and grow/rehash only when
  the load factor requires it.

### Optimization Note: Move-Consuming Transforms

The current implementation now avoids whole-container copies for ordinary
move-consuming transforms. The remaining performance work is no longer
"append copies every time"; it is the next layer of construction and sharing
design.

Known tradeoffs:

- Repeated append is amortized O(1), but there is no bulk-reserve or builder API
  yet.
- `updated` consumes the source owner, so keeping multiple immutable versions
  alive still requires a future persistent-container design.
- Dictionaries now use a scalar Swiss-style open-addressed hash table. Lookup,
  update, and insert are expected O(1), with a 75% grow threshold. The current
  implementation scans control bytes scalar-by-scalar; target-specific SIMD
  group scans remain a future optimization.

Recommended follow-up direction:

- Keep `push`/`put` and indexed assignment as explicit in-place mutation for
  `=> name!` owners.
- Add a builder/transient form for bulk construction. A temporary unique builder
  can perform many local updates and then freeze into an immutable owner without
  copying on every step.
- If SmallLang later needs multiple immutable versions alive with efficient
  sharing, add a separate persistent container type based on a structural
  sharing design such as HAMT/RRB-vector. Do not hide this behind the ordinary
  growable array until ownership, reference tracking, and drop of shared nodes
  are statically modeled.
- Add benchmarks before replacing the lowering: repeated append, random update,
  fold/iteration over resulting arrays, and dictionary update/lookup.

## Indexing And Iteration

Indexing:

```smalllang
numbers[0] => first
99 => values![1]
```

Rules:

- Safe indexing checks bounds.
- Out-of-bounds access is a runtime failure in the first slice, not undefined
  behavior and not an arbitrary fallback value.
- A later `get` API can return an `Option<T>` once option types exist.

Iteration should extend the existing block-function model:

```smalllang
numbers -> each value {
    value -> println
}

numbers -> fold 0 total, value {
    total + value
} => sum
```

For `Int`, iteration can copy the item value into the block binding. For
non-`Copy` element types, the final design should decide whether `each` yields a
shared borrow by default or requires an explicit move/borrow iteration mode.

## Flow Calls With Additional Arguments

Flow target calls accept receiver-style additional arguments:

```smalllang
7 -> square
values! -> push(10)
```

Arrays and dictionaries use this shape for mutating operations:

```smalllang
values! -> push(10)
scores! -> put(3, 300)
```

Design rule:

- The value on the left is still the primary first argument.
- Parentheses on the target may contain additional arguments.
- The target function signature decides whether the left value is moved,
  borrowed shared, or borrowed mutable.

Examples:

```text
len: &[T] -> Int
push: &mut [T; ~], T -> Unit
reserve: &mut [T; ~], Int -> Unit
```

The target function or intrinsic decides whether the left value is read,
mutably updated, or moved. In the implemented slice, `push` and `put` require a
named mutable binding so the compiler can update the tracked owner value and
still emit exactly one drop.

## Allocation And Failure

There is no garbage collector.

Dynamic arrays allocate through a selected target allocator. The first runtime
slice can treat allocation failure as a runtime failure/trap, matching the
current preference for explicit failure over silent fallback. Later, fallible
APIs such as `tryPush` can return `Result<Unit, AllocError>` once `Result` is in
the language.

Target notes:

- Windows/Linux native targets can use the selected runtime allocator.
- Browser WebAssembly needs a linear-memory allocator before dynamic arrays can
  be fully supported there.
- Unsupported allocation targets must fail clearly at compile time or runtime,
  not pretend to support dynamic arrays.

## Leak Prevention

SmallLang's safe language surface must make memory-leak freedom a compile-time
property. The goal is not "catch most leaks"; the goal is that any safe program
which could leak owned memory is rejected unless the compiler can prove a unique
owner will drop that memory on every exit path.

If the compiler cannot prove ownership, lifetime, and drop coverage, the program
does not compile. Features that cannot meet this bar must remain outside the
safe surface until an explicit static model exists for them.

Compile-time checks:

- every allocation is immediately captured by an owned value;
- every owned value has exactly one live owner;
- every normal control-flow path out of a scope runs the required drops;
- every move transfers the drop obligation exactly once;
- every moved-from binding is rejected until reinitialized;
- every slice or element borrow is proven not to outlive its owner;
- every operation that can reallocate is rejected while borrows into the buffer
  are live;
- every partially initialized aggregate has a statically known initialized
  prefix for cleanup on failure paths;
- every generic container type must define how its owned fields are dropped;
- every API that stores or returns a borrow must express the required lifetime
  relationship in the type system.

### Owned Values Drop Deterministically

Every owned value has exactly one owner at a time. When that owner leaves its
drop scope, the compiler emits cleanup for the value:

```smalllang
[Int; ~] => values!
values! -> push(10)
values! -> push(20)

# leaving the scope drops 10 and 20, then deallocates the buffer
```

Drop rules:

- Static array drop recursively drops each initialized element.
- Dynamic array drop recursively drops all initialized elements and deallocates
  its heap buffer.
- Heap-owned fixed arrays produced by `heap()` drop the contained value, then
  deallocate the heap block.
- Drop runs on every normal control-flow exit path from the scope.
- A moved-from binding is considered uninitialized and is not dropped again.
- Partially initialized arrays track initialized elements so failure during
  construction drops only the initialized prefix.

### Move Prevents Double Free

Moving an owned array transfers the obligation to drop it:

```smalllang
[1, 2, 3, ~] => values!
values! -> takeArray => result

# values! is moved and cannot be used or dropped here
```

After a move, the source binding is no longer usable unless it is assigned a new
owned value. This prevents both double-free and use-after-free.

### Borrow Prevents Dangling Views

Borrowed slices do not own storage and therefore never deallocate it. The
compiler must prove that a slice cannot outlive the owner it points into:

```smalllang
[1, 2, 3] => numbers
numbers -> slice => view

# view must end before numbers drops
```

Borrow rules:

- Multiple shared borrows are allowed while no mutable borrow is active.
- One mutable borrow is allowed only while no other borrow is active.
- A dynamic array cannot reallocate while any slice or element borrow into its
  buffer is active.
- A function cannot return a slice into a local array or local dynamic array
  unless the owner is also returned or otherwise proven to outlive the slice.

### No Untracked Allocation In Safe Code

The safe language surface must not expose raw allocator pairs such as
`alloc/free`, raw owning pointers, or APIs that allocate without returning an
owned value. Allocation enters safe code only through an owned type such as
`[T; ~]` or the owned result of `heap()`.

If unsafe/raw interop is added later, it should be isolated behind an explicit
unsafe boundary and must not be required for ordinary arrays.

### No Cyclic Ownership In The First Model

The first array model has no reference-counted ownership and no implicit shared
owners, so cyclic ownership leaks are not part of the safe surface. If shared
ownership is added later, it must be a separate explicit type with a clear cycle
story that preserves compile-time leak freedom. If that cannot be proven, the
feature does not belong in safe SmallLang.

### Intentional Leaks Are Not A Default Feature

Rust has APIs that can intentionally forget or leak values. SmallLang should not
add an equivalent operation to the safe surface initially. If an explicit
`leak` or `forget` operation is added for systems interop later, it should be
clearly marked as unsafe or advanced and must not be used by normal array code.

### Compile-Time Failure Examples

Returning a slice into a local owner is rejected:

```smalllang
makeView: -> &[Int] {
    [1, 2, 3] => numbers
    numbers -> slice
}
```

Mutating a dynamic array while a slice borrow is live is rejected:

```smalllang
[1, 2, 3, ~] => values!
values! -> slice => view
values! -> push(4)
```

The `push` can reallocate the heap buffer, so the compiler must reject it while
`view` is still live.

Moving and then using the moved binding is rejected:

```smalllang
[1, 2, 3, ~] => values!
values! -> consume
values! -> len => count
```

The `consume` call moves ownership. The later `len` call would read a
moved-from binding, so it fails at compile time.

## First Implementation Slice

The first useful implementation is now present:

- `[` and `]` tokens plus array literals.
- `[Int; N]` static arrays with inferred length.
- read-only indexing for `[Int; N]`.
- `[Int; ~]` dynamic arrays with inferred `Int` element type, including typed
  empty `[Int; ~]` and capacity hint `[Int; N~]`.
- `{Int: Int}` dictionary literals, including typed empty `{Int: Int}`.
- read-only indexing for dynamic arrays and dictionaries.
- `len` and `capacity` receiver-flow operations.
- `push(value)` for mutable dynamic arrays.
- `put(key, value)` for mutable dictionaries.
- `append(value)` for move-consuming dynamic-array growth with buffer reuse
  when capacity remains.
- `updated(keyOrIndex, value)` for move-consuming dynamic-array or dictionary
  update.
- `array -> each item { ... }` for `Int` arrays.
- `array -> fold initial acc, item { ... }` for `Int` arrays.
- `value => name!` mutable owner binding syntax.
- mutable indexing assignment with `value => owner![index]`.
- deterministic drop emission for heap-owning local dynamic arrays and
  dictionaries on supported native targets.
- readonly `[Int]` function parameters for non-owning array views.
- readonly `{Int: Int}` function parameters for non-owning dictionary views.
- `mut [Int; ~]` and `mut {Int: Int}` function parameters for non-owning
  mutable container borrows.
- explicit `move` growable array and dictionary parameters, including returning
  consumed input owners with complete return-branch coverage.
- automatic stack promotion for small, non-escaping, readonly dynamic-array
  and dictionary literals, with LLVM allocation/free assertions in examples 38
  and 39.
- function-entry stack slots, last-use lifetime markers, and nested branch/loop
  slot reuse, with one-slot LLVM assertions in example 40.
- entry-slot planning for local inline functions and mutable container metadata,
  plus automatic large fixed-array heap placement, verified by examples 30, 41,
  and 42.

The next slice should add:

- builder/transient containers for efficient bulk immutable construction
- generic `[T; N]`, `[T; ~]`, and `{K: V}` containers

`pop`, `get`, and fallible allocation APIs should wait until `Option` and
`Result` exist.

## Non-Goals

- Do not add tracing garbage collection.
- Do not make dynamic arrays implicitly reference-counted.
- Do not make dynamic array assignment copy the backing buffer implicitly.
- Do not expose unchecked indexing in the safe language surface.
- Do not let a slice outlive the array or dynamic array it points into.
- Do not silently map unsupported allocation behavior to target-specific hacks.
