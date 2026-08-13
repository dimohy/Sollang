# Sollang Explicit-Storage Collections

Status: implemented and cross-platform verified; universal performance leadership is not claimed
Approved: 2026-08-12

Sollang collections expose storage, ownership, capacity, allocation, and
failure costs in their types. A general growable collection never changes from
inline to heap storage behind the programmer's back.

## Storage Families

```sollang
[T; N]       # fixed length, inline in its owner
[T]          # readonly borrowed contiguous view
[T; <=N]     # variable length up to N, inline in its owner, never allocates
[T; ~]       # heap growable owner
[T; N~]      # heap growable owner with an initial capacity hint

{K: V}       # heap growable Swiss dictionary
{K: V; <=N}  # bounded inline Swiss dictionary, never allocates
```

`N` in a bounded type is part of type identity. `[Int; <=16]` and
`[Int; <=32]` are different types. Bounded values contain their initialized
length and inline element/table storage. Moving one moves its inline value;
borrowing it never transfers ownership.

The native representation is a by-value aggregate: length plus inline storage.
It is valid in function results and struct fields and never contains a pointer
to a callee-local allocation. Scalar-only bounded owners produce no drop/free
helper; owned element types recursively drop only initialized slots.

## Capacity Failure

`push` and `put` retain the existing direct mutation spelling. On a bounded
owner they trap with a precise capacity diagnostic if the operation would
exceed `N`. Fallible `tryPush` and `tryPut` return a typed `Result` and never
partially mutate the collection. There is no automatic heap spill.

## Extended Standard Collections

- `Set<T>(capacity)` creates a nominal heap Swiss set with control bytes and key storage
  but no dummy value. `insert`, `remove`, and `contains` are its core operations.
- `Deque<T>(capacity)` creates a nominal heap power-of-two ring with O(1) amortized
  `pushFront`, `pushBack`, `popFront`, and `popBack`.
- `BinaryHeap<T>(capacity)` creates a contiguous max-heap with `push`, `peek`,
  and `pop`; ordering is statically specialized.
- `BitSet<N>()` creates a fixed inline bit set whose positive bit count is part
  of type identity. It exposes `set`, `clear`, `contains`, `count`, and `len`.
- `collect` consumes stream size hints and reserves or validates capacity before
  writing elements, without an intermediate iterator object or collection.

The bootstrap compiler implements the first four constructors and operations.
`Set<T>` stores only keys: its entry stride is the aligned key size and contains
no zero-sized stand-in field. It uses a maximum 7/8 load threshold, tombstones,
mirrored control bytes, and key-preserving rehash. `insert` and `remove` return
whether membership changed. `Deque<T>` keeps its head in an allocation header,
rounds capacity to a power of two, masks logical indices into the ring, and
linearizes live elements only when growing. `front`, `back`, and empty pops trap
before reading storage. Recursive destruction follows logical deque order.

Heap and bounded dictionaries reserve a 16-byte mirrored control tail before
their aligned entry region. Integer and generic-key lookup broadcast the H2 byte
over an LLVM `<16 x i8>` control group, derive candidate and empty masks in one
comparison, and visit only candidate keys using `cttz`. Probing advances by one
whole group and can read across the final bucket without a wrap branch because
the first controls are mirrored. Control mutation updates the mirror atomically
with the primary byte; tombstones remain available for insertion reuse.

`putIfAbsent(key, value)` is the first dictionary entry operation. It reuses
the grouped lookup result directly, returns `Bool`, and never performs a
`contains`/`put` double probe. Owned key and value arguments transfer into the
operation; on a duplicate, the resident entry remains unchanged and both
incoming owners are destroyed exactly once.

`reserve(count)` is implemented for every nominal heap collection plus legacy
and generic heap arrays/dictionaries. It performs at most one allocation and
one ownership-preserving move pass. Deques round to their ring power of two;
dictionaries and sets convert requested entries into a 7/8-safe bucket count.
Requests within current capacity are allocation-free, and bounded owners reject
the operation rather than pretending their type-level bound changed.

`pushAll(fixedArray)` is the first bulk operation. It is available on ordinary
heap arrays with copyable, exactly matching elements. It computes the final
length with an overflow trap, executes at most one exact `reserve`, copies the
fixed source contiguously, and updates length once. Restricting the source to a
fixed array removes reallocation aliasing; excluding owned values prevents an
implicit clone. `BinaryHeap`, `Deque`, and bounded arrays keep their distinct
invariants and therefore do not inherit raw bulk append.

## 2026-08-12 Comparison Baseline

The comparison target is the documented behavior of current standard
collections, not names alone:

- [Rust collections](https://doc.rust-lang.org/std/collections/index.html)
  expose `VecDeque`, `HashMap`, `HashSet`, and `BinaryHeap` as separate owners
  with capacity and entry-oriented APIs.
- [Mojo collections](https://docs.modular.com/mojo/std/collections/) expose
  `List`, `Dict`, and `Set`; the current
  [Mojo changelog](https://docs.modular.com/mojo/changelog) describes Swiss-table
  dictionary probing in SIMD-sized groups, a 7/8 load limit, power-of-two
  capacities of at least 16, and in-place tombstone rehashing.
- Mojo's public [`Set`](https://docs.modular.com/mojo/std/collections/set/Set)
  API identifies its iterator as a dictionary-key iterator parameterized with
  `NoneType`. Sollang's nominal `Set<T>` instead gives value storage an exact
  size of zero and lays out only controls plus keys.

Sollang's implemented differentiators are explicit bounded inline owners that
cannot spill, a true key-only set stride, fixed inline `BitSet<N>`, and nominal
ring/heap owners while retaining affine destruction. These are representation
and semantic advantages, not yet a throughput victory claim. Matching or
exceeding the current baseline still requires remaining invariant-specific bulk paths, self-host
parity, and the benchmark gates below. `Set` bounds accumulated tombstones by
rehashing at the exact one-eighth-live transition; this incurs one same-size
allocation at that transition and therefore does not yet claim Mojo's in-place
compaction property.

## Performance Contract

The implementation must verify exact output, allocation count, total allocated
bytes, peak live bytes, throughput, and latency against C++, Rust, C# NativeAOT,
Go, and Java under the existing idle-CPU benchmark gate. Bounded collection
tests additionally inspect generated LLVM and reject allocator calls on the
executed construction, mutation, iteration, and drop paths.

The C# bootstrap and Sollang self-host compiler must agree on syntax, semantic
type identity, ownership, typed IR, LLVM layout, diagnostics, and execution.

## 2026-08-13 Verification Checkpoint

Fixtures 848–865 cover bounded storage, nominal collection operations,
dictionary entry/bulk operations, self-host type identity, constructor Typed
IR, constructor LLVM assembly/execution, and intrinsic-name collisions. The
Windows full suite passes 1,115/1,115 at the constructor checkpoint; Linux
passes 1,114/1,114 with the Windows-only fixture excluded. After the
intrinsic-name collision correction, Windows Stage2 passes all 7 differential
gates at 27,315,888 LLVM bytes and Stage3 reproduces the complete compiler at
fixed-point hash
`E5484BAB603F334FA252C76AC617C30770A472E6E802D60F2CA2DF2BEB1FFCD2`.

The qualified same-host benchmark is retained at
`benchmarks/collections2026/results-2026-08-13.md`. The deterministic runner
enforced a 10% idle-CPU gate (9.2% observed average), pinned logical CPU 0, and
interleaved ten independent runs. Sollang's key-only Set retained a 297 ms
median and the lowest sampled peak working set at 87,117,824 bytes. It ran
faster than measured Java, Rust, C++, and Go, while .NET NativeAOT remained
3.37x faster. Allocator-exact Sollang metrics were unavailable, so this is
complete-language runtime evidence rather than a performance-leadership claim.

Fixtures 866–867 add the first complete self-host operation slice after the
constructor checkpoint. `BitSet<N>` now agrees on canonical semantic result
types, Typed IR opcodes, fixed-inline LLVM mutation, bounds traps, membership,
word-popcount, and compile-time length. The LLVM fixture mutates both an entry
local and a `mut BitSet<N>` function parameter, assembles the emitted module,
and executes the exact `true/true/true/false/3/130` result without heap
materialization. Fixture 865 also proves that an Int user function named `set`
is not captured by the collection intrinsic recognizer.

Fixtures 868–874 complete the self-host Deque, BinaryHeap, and Set operation
slice. Typed IR assigns receiver-specialized opcodes only after canonical type
proof; fixture 865 now also excludes user functions named `push`, `peek`,
`pop`, `insert`, and `remove`. Deque covers ring growth, both-ended operations,
mutable borrows, and owned pop transfer. BinaryHeap covers max-heap growth,
sift-up/down, peek/pop empty traps, and authoritative length updates.

Set uses key-only storage with controls-first single allocation, 7-bit H2,
hash-indexed probing, tombstone reuse, a 7/8 growth threshold, and same-capacity
rehash when removal reaches one eighth capacity. Its mutable ABI passes the
complete `%sollang.dict` structure, so both storage pointers change atomically
across rehash. Integer, Text, and nominal `Hash`/`Eq` keys assemble and execute
on Windows and Linux. Owned-key insertion moves into the Set, duplicate inputs
are dropped, removal drops the stored key while retaining the borrowed query,
and final cleanup visits only occupied entries.

The post-operation checkpoint builds with zero warnings and passes the Windows
fast suite 896/896. Focused LLVM fixtures 869 and 871–874 pass exact execution
on both Windows and Linux. Rebuilt Windows Stage2 and Stage3 each emit
28,234,674 LLVM bytes and reach normalized fixed-point SHA-256
`0584AB0F40AA6033B5D40B0524915961DC6368FFCD359E45487E782B53195EA3`;
Stage3 also assembles and links to a 3,489,792-byte executable.

The final full-regression checkpoint repairs one ordering defect exposed by
parallel and partition fixtures: a synthesized structural product receives its
canonical recursive type only at the final type-projection boundary, so member
labels are resolved to ordinals after that projection and LLVM emits the
recursive product directly rather than indexing a nonexistent nominal symbol.
It also closes two Set fixed-point gaps: `Set.each` now iterates occupied
key-only buckets in both entry and function lowering, and a normal function
whose result is `Set<T>` is no longer mistaken for a Set constructor because
constructor specialization requires a constructor symbol.
The Release solution builds with zero warnings. Windows passes the complete
1,125/1,125 fixture catalog; Linux passes 1,124/1,124, with only the explicitly
Windows-only COM fixture excluded. Rebuilt Windows Stage2 and Stage3 each emit
28,308,563 LLVM bytes and reach normalized fixed-point SHA-256
`A1908F55E97BB057E1B07F067E89FB1EC635DAC5A84DCAB1890DC7349C90A4CB`.
Rebuilt Linux Stage2 and Stage3 each emit 28,288,193 LLVM bytes and reach
normalized fixed-point SHA-256
`867D03B514F64C68318A8D9C05C1911C3DF4C072CFC4FDD12480563D040996A5`.
