# Sollang AI Agent Coding Guide

Status: canonical agent onboarding and coding guide
Updated: 2026-08-18

This is the single maintained entry point for an AI Agent that must read,
write, review, or change Sollang code. Do not infer Sollang syntax from another
language, from an old release, or from one isolated fixture. Read the sources of
truth below and verify generated code with the real compiler.

Repository-root hygiene is part of the completion contract. Never place
temporary, diagnostic, benchmark, self-host, LLVM, or experimental outputs in
the repository root, including ignored `scratch*` executables. Put retained
intermediate artifacts under `artifacts/scratch/`; put disposable artifacts in
an OS-created temporary directory. Resolve and verify the output path before
starting a command that produces an executable or a large intermediate file.

## 1. Read in this order

1. [`PHILOSOPHY.md`](PHILOSOPHY.md) — design intent and the left-to-right rule.
2. This guide — current coding vocabulary and repository workflow.
3. [`examples/user/README.md`](../examples/user/README.md) and its 20 small
   examples — the preferred surface syntax.
4. [`SPEC.md`](SPEC.md) — normative semantics and target boundaries.
5. [`DECISIONS.md`](DECISIONS.md) — accepted choices and rejected alternatives.
6. [`FLOW_JUNCTIONS.md`](FLOW_JUNCTIONS.md) when branching, products, `tap`,
   `partition`, stream joins, or parallel flow are involved.

Focused normative references include [`GETTING_STARTED.md`](GETTING_STARTED.md),
[`ARRAYS.md`](ARRAYS.md), [`ROLE_BLOCKS.md`](ROLE_BLOCKS.md),
[`GRAMMAR_BOOTSTRAP.md`](GRAMMAR_BOOTSTRAP.md),
[`EXAMPLE_CATALOG.md`](EXAMPLE_CATALOG.md), and
[`STAGE3_COMPILER.md`](STAGE3_COMPILER.md). The checked-in
[`sollang.lexer`](../syntax/sollang.lexer) and
[`sollang.grammar`](../syntax/sollang.grammar) are the canonical lexical and
grammar inputs.

When these disagree, do not guess. Check `syntax/sollang.grammar`, the parser,
semantic compiler, code generators, retained regression fixtures, and a small
compile/run probe. Repair stale documentation in the same change.

Standard-library implementation is also a language-design probe. If the
clearest type-safe Sollang expression is rejected or lowered incorrectly, do
not preserve the compiler defect with explicit-type noise, temporary owners,
heap materialization, or nested-control-flow workarounds. Confirm that the
desired contract fits the language model, then repair parser, semantics, and
code generation as required and retain a minimal language regression alongside
the standard-library and cross-target fixture that exposed it.

## 2. Language model

Sollang code reads from left to right:

```sollang
source -> transform -> consume
expression => name
```

- `->` means flow, application, or transformation.
- `=>` means definition, binding, arm resolution, or assignment.
- Types, ownership, effects, evaluation order, allocation, buffering, and
  target capabilities must stay visible. Never add an implicit fallback that
  changes those semantics.
- Integer literals inside a `when` inherit the surrounding integer type in
  arguments, struct fields, returns, and numeric operations. Do not spell
  constructors such as `UInt8(0)` merely to compensate for missing contextual
  inference; repair semantic analysis and code generation when that context is
  lost.
- `.slg` is the source extension. `main { ... }` is the explicit entry block;
  top-level executable statements are also supported.
- `#` starts a line comment.

## 3. Core syntax

### Bindings and mutation

```sollang
21 => answer
[10, 20, 30; ~] => values!
99 => values![1]
values! -> len => count
```

Immutable names have no suffix. A mutable owner name carries `!` at declaration
and every access. Assignment remains value-first. Operations and properties
stay in the flow, so use `values! -> len`, not `values!.len`.
When a call that mutably borrows an owner is itself the source of a value-flow
pipeline, semantic inference must pass the current mutable-binding set through
the flow-source boundary. Re-inferring that call without its ownership context
is a compiler defect, not evidence that the user's `name!` is immutable.

### Functions and calls

```sollang
square value: Int -> Int => value * value
sum pair: (left: Int, right: Int) -> Int => pair.left + pair.right
answer: -> Int => 42

main {
    7 -> square => squared
    (left: squared, right: answer()) -> sum => total
    "$total" -> println
}
```

Inputs are written before `->`; the return type follows it. Expression bodies
use `=>`, while statement bodies use `{ ... }`. A flow sink such as
`value -> println` is a call, but an independent invocation must use call syntax:
`println()` for a zero-input function. A bare function name is not an invocation
and is a semantic error. Long calls may place comma-separated arguments on
separate lines inside parentheses; do not introduce temporary bindings merely
to avoid a parser formatting limitation. Lexical and parse failures are blocking compiler
diagnostics on every checked target. In particular, an unterminated string such
as `"Hello World!" -> println(")` must report `unterminated string literal`; it
must not reach LLVM generation, linking, or browser execution. Enum members and
computed self properties remain member-like, for example
`Status.Ready` and `point.doubled`.

### Control flow

```sollang
score -> when {
    90..100 => "A"
    80..89 => "B"
    else => "Needs practice"
} => grade

ready -> if {
    "ready" -> println
} else {
    "waiting" -> println
}

(indexReady and moreWorkRemaining and not skippedThisRound)
    -> if {
        "ready" -> println
    }
```

When one discriminant is compared against several values or ranges, flow it
into one subject-style `when` and keep the fallback in the final `else` arm.
Protocol frame, packet, message, opcode, and token dispatchers must not express
that shape as a deeply nested `if`/`else` ladder.

Ranges are inclusive with `..` and half-open with `..<`: `2..10` visits 10,
while `2..<10` stops at 9. Block functions keep the current value on the left,
such as `1..9 -> each value { ... }`. Compiler and playground regressions must
exercise both forms with exact output; testing only the inclusive form cannot
prove the half-open contract.

### Types, products, and collections

```sollang
struct Point {
    x: Int
    y: Int
}

(10, 20, 30) => ordinary
(left: 4, right: 2) => labeled
[1, 2, 3] => fixed
[1, 2; ~] => growable!
[Int; ~] => empty!
[1, 2; <=8] => bounded!
[Int; <=8] => emptyBounded!
{"one": 1, "two": 2} => lookup
{Int: Int; <=8} => boundedLookup!
```

Ordinary product fields are `_0`, `_1`, and so on. Labeled product fields use
their labels. Products do not implicitly expand into function arguments.
Structs and enums are nominal; products are structural. Arrays, dictionaries,
generic types, `Option`, `Result`, traits, `impl`, associated types, and owned
`dyn<Trait>` values are described in `SPEC.md` and demonstrated by retained
fixtures.

Collection storage is part of the type contract: `[T; N]` is fixed inline,
`[T]` is a readonly view, `[T; ~]` is heap-growable, `[T; N~]` is a heap owner
with an initial capacity hint, and `[T; <=N]` is bounded inline storage.
`{K: V; <=N}` is the corresponding bounded inline dictionary. Bounded owners
never allocate or spill, `N` is part of type identity, `capacity` reports `N`,
and `mut [T; N]` borrows only the fixed payload in place: it cannot change the
array length or capacity and therefore uses the fixed-array slice ABI.
and an overflowing `push` or new-key `put` traps without partial mutation.
Extended collections use explicit constructors: `Set<T>(capacity)`,
`Deque<T>(capacity)`, `BinaryHeap<T>(capacity)`, and fixed inline `BitSet<N>()`.
Do not model a set as a dictionary with a dummy value, a deque as a shifting
array, or a heap as a library wrapper that loses its nominal invariant.
`Set<T>` entries contain only an aligned key and membership operations return
`Bool`. Set deletion uses tombstones and performs one same-capacity cleanup when
the live count crosses exactly one eighth of capacity. `Deque<T>` is a
power-of-two ring with `front`/`back` and O(1) amortized
push/pop at both ends; it intentionally has no physical indexing surface.
Dictionary `putIfAbsent(key, value)` is the non-escaping entry primitive: it
performs one probe, inserts only when vacant, returns `Bool`, and consumes both
arguments even when an equal resident key already exists. Do not implement it
as `contains` followed by `put`.
Heap collections expose `reserve(nonnegativeCount)` as a final mutable flow.
Arrays/heaps reserve element slots, deques round to a power of two, and
dictionaries/sets reserve enough power-of-two buckets for the 7/8 load limit.
Requests at or below current capacity do not allocate. Bounded inline owners do
not expose `reserve` because their capacity is already part of type identity.
Ordinary heap arrays expose `pushAll(fixedArray)` for copyable elements. The
operation checks the combined length, performs at most one exact `reserve`,
copies the fixed source contiguously, and publishes the new length once. It does
not accept dynamic sources, heap/deque receivers, or owned elements: those need
separate alias-safe and move-explicit APIs rather than hidden cloning.

Prefer the narrowest representation the compiler can prove. Static literal
data exposed as `[T]` must lower to immutable module data rather than a runtime
`push` builder. A local whose final element count is known must use a fixed
array value instead of `[T; ~]`; reserve growable storage for values whose
length can actually change. Repeated fixed arrays accept inline copyable values,
so `[0; 64]` in a declared `[UInt64; 64]` context is the canonical mutable
SHA-style work buffer.
Use `[]` for an empty static array when the return, argument, or field context
supplies `T`; do not allocate `[T; ~]` merely to spell an empty readonly value.
The generated grammar must therefore keep the array body optional; rejecting
the closing `]` before semantic contextual typing is a parser defect.
Repeated fixed storage follows the same rule: use `[0; N]` in a contextual
`[T; N]` position. The compiler propagates `T`, preserves concrete repeat
counts, and permits `mut [T; N]` value-generic kernels when an algorithm fills a
caller-owned fixed destination. Do not wrap the array in a one-field struct or
allocate a growable buffer to compensate for lost repeat typing. The same
contextual rule applies to named struct fields, ordinary call arguments, and
the first source of a value-flow call. Semantic inference and LLVM
materialization must use one expected array type in all three positions; never
require `UInt8(7)` in `[7; 16]` when `[UInt8; 16]` is already known.
The generated parser recognizes the `Expression ; Number|Identifier` repeat
form before the more general comma-separated array alternatives. Keep that
ordered choice in the canonical grammar; otherwise the self-host parser can
reject a valid repeat after consuming its first expression. Fixed-array type
annotations independently retain the `Number` arm in `[T; N]`; do not confuse
that type-level length with bounded `[T; <= N]` or identifier-backed generic
lengths. File-backed
`checked` emission must run syntax diagnostics before semantic preparation and
return immediately on rejection, never lower a recovered partial AST.
The generated grammar accepts newlines immediately inside call parentheses and
after argument commas for ordinary, type-application, and enum-constructor
calls. Keep this aligned with the reference parser; otherwise the self-host
compiler rejects canonical multiline stdlib calls that the bootstrap accepts.
Flow-target calls use the same newline contract. Subject-`when` enum patterns
are one path with an optional payload binder;
standalone value-form `when` arms remain ordinary logical expressions. Do not
encode payload, payloadless, and qualified variants as competing alternatives
with the same identifier prefix in the generated PEG grammar.
The control-flow-statement production must retain the same trailing pipeline
and `?` continuation as `FlowExpression`; otherwise it commits after
`value -> if { ... } else { ... }` and rejects a valid following `-> println`.
The generic block-function statement alternative must reject control-flow
keywords before consuming a path. This lets `items -> take(0) -> when { ... }`
backtrack into `FlowExpression` instead of misparsing the `when` arms as a
block-function callback body.
Expression statements precede block-function callback statements in the
generated ordered choice. A real callback form reaches `{`, makes the ordinary
expression alternative fail, and then selects the block form; a multi-stage
`take(0) -> when` succeeds as an ordinary flow without premature commitment.
When a fixed array crosses a function boundary, its concrete `N` remains a
static type fact even if the lowered pointer/length pair uses an LLVM SSA value
for the runtime length. Compiler checks and generic specialization must consult
the canonical fixed-array type or the runtime value's explicit compile-time
length fact, never infer a type fact from the spelling of an arbitrary SSA
value. Small unconstrained integral repeat bindings use the normal stack-frame
promotion plan; repeat lowering must honor that plan instead of allocating
every repeated array on the heap.
Incremental semantic reuse must preserve every static-array identity, including
body-local `[T]` and `[T; N]` types that do not occur in the restored binding
map. Reserve their cached numeric ids without advancing the allocator, skip
those reservations when the current declaration universe already owns the id,
and materialize successful reservations before LLVM helper planning. Never let
a skipped function silently remove a type from the code-generation universe.
Protocol-sized struct fields use concrete fixed contracts such as
`secret: [UInt8; 32]`. A growable value may initialize such a field only through
the compiler's checked ownership conversion; generated code verifies the exact
length before the value enters the struct.

Prefer inferred numeric literals and immutable bindings. In an expected
`UInt32` position write `7`, not `UInt32(7)`, and omit `!` unless the binding or
its owned contents are mutated. The compiler reports S001 for a redundant
numeric constructor, S002 for unused mutability, S003 for a growable array
whose exact final length is evident from straight-line construction, S004 for
an empty success branch, and S005 when removing `!` would expose a reserved
name and the binding must instead be renamed. Those remain `warning Snnn`
source defects. Long control conditions are a separate `note Nnnn` series:
N001 when a condition of 45 or more characters shares a line with `if`,
`unless`, `while`, a standalone `when` arm, a `partition` predicate, or
`if break`/`if continue`. Keep short conditions inline, even with `and`/`or`.
When the condition is long, put it on its own line and write `-> if {` or
`-> while {` on the next line. Do not bind the Bool twice around `while`.
User sources may leave N001 as a note; repository `.slg`, the runtime
library, and samples wrap those lines. S006 through S045 are blocking
compiler-integrity diagnostics: S006 means a value-producing typed-IR node
reached LLVM storage selection without a canonical type; S007 means an array
storage identity disagrees with its first lowered operand; S008 means an
arithmetic node's semantic result width disagrees with the emitted operand
width; S009 means a scalar binding initializer names neither a local binding
nor a parameter ABI value; S010 means an inverse guard's AST and Typed IR
identity disagree; S011 means an enum subject pattern did not lower to an enum
constructor; S012 means a subject `when` lost its canonical comparison value.
S013 means one of its relational arms lost that value as its left operand or
retained a stale operand different from the control's canonical subject.
S014 means a member read reached final Typed IR without its canonical base.
S015 means an ordinary binary expression lost its canonical right operand.
S016 means a conditional expression lost its canonical condition operand.
S017 means a member base's canonical nominal owner cannot map to a source
module.
S018 means an enum match does not retain a canonical Option, Result, or nominal
enum subject. A container, struct, stale wrapper, or missing type is rejected
before LLVM tag/payload lowering.
S019 means a value-producing enum match has an arm without a canonical result
value; such a match is rejected before SSA emission.
S020 means an enum match subject name is neither a same-module parameter ABI
value nor linked to a concrete producer, and would therefore reference
undefined SSA. Symbol ordinals from another module cannot satisfy that check.
S021 means an enum match selected a return, declaration, control-transfer, or
region node that cannot materialize an LLVM value even if stale contextual
typing assigned it the expected enum type. Match selection prefers the exact
value producer over such control metadata at the same AST position.
S022 means a value-producing enum match arm result type disagrees with the
match result type. The declared function or enclosing value context determines
the match slot type, and every arm must retain its final flow constructor or
other value of that same type.
S023 means an arm retained a transparent parser wrapper that has no LLVM SSA
definition. Preserve an already-canonical arm result (including a short-circuit
logical join), unwrap transparent flow wrappers to their concrete producer,
and only search for a replacement when the arm result type is incompatible.
The CST-backed self-host path must apply the same standard generic enum rewrite
as the surface parser: `value -> Option<T>.Some` and
`value -> Result<T, E>.Ok` lower to enum constructors, not ordinary flow calls.
S024 means a value-producing `if` has no concrete result value in its then or
else region. Reject it before result-slot emission can index a missing IR node.
S025 is the result-store boundary check for any value-producing control. It
reports the exact control, branch, and invalid value index instead of allowing
malformed IR to crash the compiler during LLVM emission.
S026 means an enum payload binding type differs from the canonical payload type
of the matched variant. A stale non-negative typeId is invalid just like a
missing one, especially when it confuses fixed arrays with slice headers.
S027 means a direct fixed/bounded array return literal did not inherit the
function's canonical array type. S028 applies the same exact-shape contract to
array-valued nominal struct field initializers.
S029 means a fixed repeat literal's canonical length differs from its static
repeat count; the count, not the single lowered seed operand, defines shape.
Function-body and nested control-region emitters must both allocate that
canonical fixed length and repeat the one lowered seed value through every
element. Operand-list length is never the storage length for `[value; N]`.
Enum match arms likewise distinguish their payload binding from their result:
an expression-bodied arm returns its last direct value child whose canonical
type matches the arm result. This keeps a transform such as
`Err(error) => -error` from collapsing back to `error`, while preventing a
nested enum constructor from being stored into an enclosing scalar result
slot.
S030 means a binding whose final source operator is `?` retained `Result`
rather than the success payload. S031 means a dotted nominal member reached
final Typed IR without the declared field's canonical type after its base was
resolved.
S032 is the index-assignment emitter boundary: an array target must expose its
canonical element type before LLVM forms a typed GEP or store. Fixed arrays are
first-class array containers here, not a legacy fallback.
Nominal struct emission preserves a non-negative canonical owner `typeId`;
legacy `(origin,module,symbol)` lookup is fallback-only and must not replace it
with a duplicate identity that has no canonical field table.
S033 rejects exactly that duplicate-owner state before struct field ABI
selection.
S034 is the struct-emitter boundary when a canonical owner and source field
position cannot map to a declared `NominalField.ordinal`; field-array encounter
order is never a substitute for the recorded ordinal.
S035 applies the same boundary to struct literals emitted inside control
regions. A `when`, `if`, or loop arm cannot bypass canonical owner, explicit
field ordinal, or fixed-array carrier-to-inline materialization rules.
S036 is the fixed-array member-projection boundary. Inline `[N x T]` is a
storage representation only; reading that member must produce the canonical
borrowed `{ptr, len}` expression carrier from its address and static length.
S037 rejects an enum match that tries to re-emit an SSA constructor already
defined in a nested control region. An enclosing region whose terminal match
returns from every arm is terminating and has no merge value to synthesize.
S038 applies the fixed-array expression ABI to `?` success payloads. The enum
payload remains inline storage, but the bound success value must be a borrowed
`{ptr, staticLength}` carrier with canonical element and length metadata.
S039 rejects an empty array literal that reaches emission without a canonical
slice, fixed-array, or growable-array ABI. A contextual empty slice is a real
`{null, 0}` expression value and must never become an undefined SSA argument.
S040 rejects a subject-style `when` whose canonical subject points back to the
control node itself. Late Typed IR repair must replace a missing or
self-referential subject with the exact preceding same-region integer producer;
the LLVM emitter must never compensate by inventing an SSA value.
S041 rejects a binding, direct read, value-producing control, or arithmetic
result whose aggregate storage class disagrees with its canonical producer.
S042 rejects `len` when final receiver resolution produces a scalar value.
S043 rejects a dotted member whose base is outside the member's structural AST
span or resolves to a scalar at emission. S044 applies the scalar-receiver
guard to `capacity`; intrinsic names are recognized only as stages following a
top-level `->`, never from unrelated local identifiers in the same expression.
S045 rejects a partition whose structural route product does not preserve the
canonical `Stream<T>` or `EventStream<T>` source wrapper on every field. Type
fixed-point analysis must not commit a route product from an earlier `Range` or
other provisional predecessor, and must update an existing partition
expression when its canonical product becomes available.
Slice bounds that are numeric literals are emitted through `writeValue` in the
entry, function, and control-region paths; a literal has no `%vN` SSA name.
When implementation work exposes a malformed compiler state that can still
execute today but violates a semantic, ownership, Typed IR, ABI, or codegen
invariant, do not leave it as a local workaround. Assign the next Snnn
compiler-integrity diagnostic at the earliest authoritative boundary, add a
focused failing regression fixture, repair the producer of the malformed
state, and keep the boundary diagnostic as a permanent guard against recurrence.
Every LLVM path that writes a kind-3 integer literal uses
`writeIntegerLiteral`; raw source-token slices may contain Sollang digit
separators and are never valid LLVM integer tokens. Boolean literals similarly
lower to `1` or `0`, including dictionary hash and index paths.
Binary recovery may use exact same-parent continuation structure, never nearby
type compatibility or source spelling.
Pipeline conditional recovery follows the same exact-predecessor rule.
E20 must not require reinitialization of a binding declared inside the region
being exited; only move paths live across the join or back-edge are merged.
Nominal member projection uses recursive semantic `typeId` identity before
legacy origin/module fields, especially for imported owners.
Legacy nominal identity may publish `typeId` only through a unique exact
`(origin, module, symbol)` semantic-type match.
Compile-time value generics remain visible to interpolation-based control
expressions and lower as hidden trailing `Int` parameters; never synthesize an
unbound `%vN` temporary for them.
Mutable fixed arrays pass their canonical `{ ptr, i64 }` value by pointer.
Never project a capacity address from a fixed-array value.
Never work around these diagnostics in source;
repair semantic typing, typed-IR projection, or the responsible ABI lowering.
Treat every Snnn warning as a source
defect outside its dedicated warning fixtures. Conditional
or loop-dependent pushes are not straight-line and must not be rewritten into
a fixed array merely to silence S003; fixture 953 guards that analysis. S003
also stays silent when a downstream function contract explicitly requires a
growable array, because replacing that value with a fixed array would not type
check; fixture 975 guards the contract-sensitive analysis. A conditional
with an empty success branch is never canonical Sollang. Write
`condition -> unless { failure }` instead of
`condition -> if {} else { failure }`; S004 reports the latter form.
A control condition of 45 or more characters on the same line as `if`,
`unless`, `while`, a standalone `when` arm, a `partition` predicate, or
`if break`/`if continue` is a note, not a warning. N001 asks for the
condition on its own line and `-> if {` or `-> while {` on the next line.
Fixture 1004 retains the note; fixture 1005 retains the wrapped form.
User sources may keep the note. Repository `.slg`, the runtime library, and
samples wrap those lines. Short `and`/`or` conditions stay inline.
Expected integer types propagate recursively through arithmetic and value-form
`if`/`when` branches. A typed `UInt64` field therefore infers the `0` in
`known + (condition -> if { value } else { 0 })` without a constructor.
The first independently typed numeric element of an array literal likewise
provides context to following bare numeric elements. A mutable binding changes
fixed-array elements, not its shape; `[UInt64(1), 2, 3] => values!` remains an
inferred `[UInt64; 3]`, and indexed writes must preserve that fixed-array ABI.
A nested expression inside an array element is never the element type anchor;
after lowering, the direct operand chain is authoritative. LLVM control-region
stores must print function-parameter operands through the canonical parameter
reference writer rather than inventing an SSA `%v` name. Immutable local aliases
of parameters follow the same rule because parameter names intentionally have
no standalone `%v` producer. In binary arithmetic, a bare integer literal
inherits the exact type of its independently typed peer. Nested arithmetic
result identities stabilize to the widest canonical integer operand even when
a parent precedes its child in the flat Typed IR.
Runtime print entrypoints accept i32 or i64, so UInt8/UInt16 call results are
explicitly widened before that ABI boundary.
LLVM text emission removes numeric digit separators instead of copying `_`
into an LLVM integer token. A resolved integer call argument is converted to
the declared parameter width before the call, using signedness-aware
`sext`/`zext` or `trunc`. Integer return literals are different: they have no
SSA producer to convert, so emit the literal directly at the function's
declared return width. Do not invent `%v` conversion sources for literals or
make callers annotate valid source to satisfy an ABI boundary.
All entry, named-function, and nested control-region emitters use the same
direct and short-circuit branch-target writers. An `unless` body executes only
when its condition is false in every scope; never duplicate this polarity rule
inside one emitter.

### Ownership, references, and effects

Sollang checks affine owners, partial moves, readonly and mutable borrows,
captured values, async frames, and drops. Do not insert cloning or heap
materialization to silence an ownership error. Use the ownership form required
by the callee or flow arm and let the compiler reject illegal reuse.
A direct binding of an explicit `move` input transfers that owner into the new
binding; codegen must invalidate the parameter exactly as it does for other
move-consuming container expressions. Inline lowering is a lexical function
scope: parameters and locals may shadow caller names, and every name-keyed
mutable/borrow slot plus every readonly aggregate-value slot must be replaced
for the duration of the inline call and restored afterward. Never let caller
storage metadata leak into a shadowing fixed-array or struct binding.
Mutable-borrow calls accept a field or index place when its root is a named
mutable owner. Prefer `state!.transcript -> append(message)` over copying the
field into a temporary owner. Struct fields also provide their declared array
element and storage type as initializer context, so `Buffer { bytes: [] }`
constructs the declared growable array without repeating `[UInt8; ~]`.
Any mutable-borrow call is an origin-invalidating site for live borrowed
`Text`, including when the view came through a user function that returns a
materialized arena view. If two returned views must remain live together, give
them distinct `Arena` owners; do not reuse one arena and rely on target-specific
allocation behavior. The C# and self-host ownership checkers must both reject
that source before LLVM emission.
Readonly aggregate borrows may reuse an LLVM alloca, but every borrow site must
store the current SSA aggregate into that slot. A slot first materialized in one
branch does not dominate a sibling branch or a later loop iteration; reusing its
old contents changes an immutable binding's value. Fixture 952 retains this
branch-and-loop contract, while fixture 428 retains the real source-root case
that exposed it.

Functions declare observable capabilities:

```sollang
audit value: Int -> Unit uses Console => "audit=$value" -> println
```

Effect requirements are transitive. Do not suppress them or add a success
default for an unavailable target capability.

## 4. Flow Junctions

### One value to many named results

```sollang
5
    -> branch {
        doubled: -> double
        incremented: -> increment
    }
    => parts
```

`branch` is sequential and evaluates arms in source order. It returns a labeled
product. It does not clone affine input and does not imply parallelism.

### Observe while preserving the outer value

```sollang
9
    -> tap {
        -> double
        -> audit
    }
    -> increment
    => result
```

`tap` executes its side pipeline from left to right and then restores the outer
input. Moving the outer affine value from a tap arm is an error.

### Route one stream item to exactly one output

```sollang
values -> partition value {
    even: when value % 2 == 0
    large: when value >= 3
    other: else
} => routed
```

`partition` uses first-match order, requires a final `else`, and produces
separately consumed labeled streams.

### Join streams with an explicit policy

```sollang
(left: left, right: right) -> zip => paired
(first, second) -> merge => interleaved
(first, second) -> concat => ordered
(left: left, right: right) -> latest => updates
```

- `zip` stops at the shortest input and returns products.
- `merge` emits by fair availability order and requires compatible elements.
- `concat` consumes inputs in product order.
- `latest` emits labeled current-state products after updates.

These streams remain lazy and affine. Buffering, completion, cancellation, and
nondeterminism follow `FLOW_JUNCTIONS.md`; never materialize them implicitly.

### Explicit parallel flow

```sollang
7 -> parallel branch {
    doubled: ref -> double
    squared: ref -> square
} => results
```

`parallel branch` uses structured parallel ownership and cancellation. Its arms
must satisfy the allowed readonly/Copy ownership and effect rules. Native
Windows and Linux provide the compute worker pool. `wasm32-browser` currently
reports an explicit capability diagnostic; do not lower it to sequential
execution as a compatibility shortcut.

## 5. Modules, standard library, and targets

Use `import std.sequence` and other explicit module imports. The final path
segment is the default alias. Standard-library sources live under `stdlib/`.
Supported release targets are `windows-x64`, `linux-x64`, and browser WebAssembly
within the capabilities recorded in `SPEC.md`.

`sys.socket` is the canonical native TCP/UDP surface and `sys.quic` is the
canonical QUIC surface. Their public operations return structured `Result`
values and declare `uses Network`; examples should compose fallible steps with
postfix `?` inside one Result-returning function and reserve `when` for the
outer recovery or presentation boundary. Subject-style `when` is also the
preferred flat dispatcher for one decoded protocol discriminant. Socket handles
are affine. When a flowing value is an enum payload, keep the flow intact with
`value -> Result<T, E>.Ok` or `value -> Option<T>.Some`; multi-type Result
annotations are valid flow targets, not a reason to introduce a temporary.
Postfix propagation may follow the complete flow directly, as in
`owner -> fallibleTransform?`. An owned enum payload may be transferred from a
named enum or from an owned field projection. A projected transfer consumes the
root owner, transfers the selected field exactly once, and drops its remaining
owned fields on every branch; lowering must never retain and later drop the
original aggregate.
An owned payload bound by `when` transfers when it is rebound, returned, or
stored into an owned struct field or collection element. LLVM cleanup must
recognize each of those destinations before deciding whether to drop the enum
subject; otherwise it frees storage that the destination now owns. Retain a
fixed-array `Result` payload-to-field fixture plus the owned enum payload-field
and projected-enum fixtures whenever this transfer analysis changes.
Returning an owned struct field through `Result.Ok` or another owning enum
constructor follows the same rule: the selected field moves into the result,
the source root is no longer dropped as a whole, and every untransferred owned
sibling is still dropped. Fixture 970 protects this function-cleanup boundary
independently of QUIC.
Explicit `return` and tail return use one aggregate-transfer resolver. A local
owner carried through value-preserving wrappers and one or more enum
constructors is excluded from return-edge cleanup exactly once; neither return
path may implement a narrower direct-name-only ownership rule. The Stage2 path
normalization fixture executes this contract on both Windows and Linux.
After binding a UDP endpoint with port `0`, obtain the kernel-assigned port
through `sys.socket.localPort`; do not guess an ephemeral port or add a
platform-specific native declaration in a higher-level library.
QUIC Initial datagrams use `sys.quic.initial_engine`: derive Initial keys from
the client's original destination connection ID, apply the client/server key
direction correctly, require the client datagram to be at least 1200 bytes,
and validate CRYPTO framing and remaining PADDING before accepting a hello.
Handshake packets use `sys.quic.handshake_engine`; 1-RTT packets and key-phase
updates use `sys.quic.application_engine`. A receive key phase changes only
after AEAD authentication with the derived next traffic secret. Keep
CONNECTION_CLOSE and HANDSHAKE_DONE in the shared frame codec rather than in a
connection-specific byte builder.
Flow-control signaling likewise uses the shared MAX_DATA, MAX_STREAM_DATA,
MAX_STREAMS, DATA_BLOCKED, STREAM_DATA_BLOCKED, and STREAMS_BLOCKED frame
variants; connection and stream state consume those nominal values rather than
re-decoding frame bytes.
Real 1-RTT packets may carry an ordered frame sequence. Use `frame.encodeAll`,
`frame.decodeAll`, and the application engine's multi-frame operations; do not
force one protected packet per frame.
The stable native QUIC contract targets RFC 9000/9001/9002, TLS 1.3 from RFC
9846, QUIC v2 from RFC 9369, compatible version negotiation from RFC 9368, and DATAGRAM from RFC
9221. Draft-only extensions such as multipath remain explicit experimental
work and must not be described as implemented standards.
When an expected struct type is already known, `{ field: value, ... }` is one
contextual struct literal in every position, including typed array elements,
function arguments, and nested struct fields. Codegen must not reinterpret it
as a dictionary and attempt to resolve field labels as runtime bindings.
Existing mutable bindings and indexed destinations also supply their existing
type to the new value. Write `0 => counter!` and `9 => bytes![0]`; do not add a
numeric constructor that merely compensates for missing rebind or element
context. Function return types recurse through nested value-form `if` blocks in
both semantic analysis and codegen. Contextual inference performed while
validating a mutable rebind inside a block must retain that block's `yield`
input type; do not restart inference with an empty control-flow context.
The same expected numeric type recurses through arithmetic expressions in both
semantic analysis and codegen. A UInt64-returning `maximum - value` accepts the
full UInt64 literal directly; do not parse a contextual literal through signed
Int64 first or add a source conversion to hide a lowering mismatch.
Intrinsic arguments receive the same declaration context as ordinary function
arguments. In particular, write `random.bytes(8)`, not
`random.bytes(UIntSize(8))`; fixture 955 protects the UIntSize lowering. Fixed
`Int` indexed assignment stores `i32` with four-byte alignment, guarded by
fixture 956.
Unqualified calls inside a named module resolve a same-module declaration
before a declaration in the executable root. Reachability analysis, semantic
resolution, incremental restoration, and LLVM symbol emission must use that
same rule and the same canonical module-qualified function identity; never
repair a missing definition by retaining every function. Generated callbacks,
including direct `parallel` workers, must be collected only from reachable
owners so a callback cannot retain a call to a deliberately eliminated helper.
Property calls and implicit dictionary traits belong to this same resolved-call
graph. A resolved call is call-site specific: when one generic body is emitted
for multiple receiver types, resolve its instance method in the current
specialization instead of reusing a target recorded for another instantiation.
Closed-world self-host emission must also retain implementation methods reached
through runtime tables or trait witnesses even when no direct-call IR edge names
them; dictionary Hash/Eq, dynamic dispatch, and explicit serialization are
representative indirect roots. Their ordinary callees then participate in the
same transitive reachability closure.
Reachability walkers must visit both ordinary calls and type applications such
as `readAsync<UInt16>()`. Record a reached runtime intrinsic before deciding
whether it has a Sollang body, but preserve capability-specific side effects
such as directory type emission before returning from that record step.
Stable semantic call-site identities must include the syntactic target path and
generic/value arguments, not only an ordinal. Changing `llvm.emit` to
`llvm.emitLinux` at the same source position must invalidate the old resolved
target instead of restoring it from the incremental semantic cache.
The LLVM module-fragment cache key must also include the exact reachable
function identities emitted into that module. A source-unchanged imported
module can gain or lose a reachable function when only the executable root
changes, so its source hash alone is not a valid reuse key.
Cross-target fixtures whose generated stdout is intentionally target-specific
use `<name>.stdout.<target>.txt`; the ordinary `<name>.stdout.txt` remains the
catalog entry and default expectation.
Generic specialization may classify a source-defined block as `UserBlock`, but
must preserve intrinsic block kinds such as `parallel` and `tryParallel`.
QUIC protocol, cryptography, packet, TLS, transport, and recovery
logic is implemented in reachable pure Sollang standard-library modules; it
must not require a Rust adapter or separately distributed native QUIC library.
Keep nominal wire/state declarations separate from transition logic when that
makes ownership and enum construction explicit; QUIC streams use
`stream_types` and `stream_state`. Preserve exact QUIC transport error codes.
TLS 1.3 key scheduling includes zero-PSK full handshakes and external or
resumption PSK binder derivation; keep `ext binder` and `res binder` distinct,
and compute binder verification data with the normal Finished-key construction.
Hello messages are owned, length-checked TLS records: preserve SNI, ALPN,
supported_versions, signature_algorithms, X25519 key_share, and QUIC transport
parameters, and reject duplicate required extensions. Certificate,
CertificateVerify, and Finished framing must retain the RFC 9846 transcript
context bytes exactly. Framing alone is not certificate authentication; do not
mark interoperability complete before chain/name/signature verification exists.
For the SHA-256 handshake suite, the CertificateVerify signed input is a fixed
`[UInt8; 130]`; do not allocate and grow a buffer whose protocol length is
already known.
The generic TLS state transition must not accept authentication messages by
shape alone. A client accepts CertificateVerify only through a verifier that
uses the transcript hash before that message and the key extracted from the
authenticated or explicitly pinned certificate; a server creates CertificateVerify from its private seed and
the same transcript point. Received Finished messages advance state only after
the expected verify_data matches. Any failure moves the state to `Failed` before
returning its TLS alert. Exact-DER pinning compares every certificate byte,
requires the RFC 8410 Ed25519 SPKI OID with absent parameters, and then proves
possession through CertificateVerify. The pinned server path also requires an
ASCII case-insensitive exact dNSName match in subjectAltName; wildcard, IP,
IDNA, general WebPKI path, validity, and revocation handling remain separate
gates and must be named accordingly.
Handshake and 1-RTT packet keys come from `sys.quic.traffic_keys`; select the
RFC 9001 `quic key`/`quic iv`/`quic hp` labels for v1 and the RFC 9369
`quicv2 key`/`quicv2 iv`/`quicv2 hp` labels for v2. Keep the traffic secret in
connection state and derive the next secret with the TLS 1.3 `traffic upd`
label before changing the QUIC key phase.
When a natural standard-library expression exposes a missing expected-type,
fresh-value, transfer, or lowering rule, retain the natural expression and fix
the compiler contract. In particular, function-body array literals inherit the
declared return element type, and a payloadless enum variant is a fresh value
even when sibling variants own payload storage. Do not add numeric constructors,
temporary owners, copying helpers, or dynamic containers solely to make a
compiler defect disappear.
Expected numeric types propagate through value-form `if`/`when` inside both
primary and additional function arguments and through explicit returns. A
branch that always returns, breaks, or continues does not contribute Unit to a
value join; only continuation-reaching branches determine the joined type and
LLVM phi inputs.
Moving an owned field projection into a collection consumes the root struct and
drops only its other owned fields. Semantic analysis must reject any later root
use. Conversely, `mutableStruct!.dynamicField -> take(index)` is a valid mutable
place: lowering updates the field's pointer/length/capacity in the struct slot
without detaching a temporary owner.
Client and server TLS flights are explicit state machines. Extend the shared
transcript only after a complete message is valid for the current phase, and
move an invalid transition to `Failed`; never treat ordered framing as proof of
certificate or Finished authentication.
TLS key exchange uses the pure Sollang X25519 implementation and RFC 7748
vectors. Do not call an OS or adapter crypto implementation as an implicit
fallback. Private scalars come from `sys.crypto.random.bytes`, whose small
reachable native boundary uses Windows CNG or Linux `getrandom`, returns a
typed failure, and is absent when unused. Never substitute `sys.random.below`
for cryptographic entropy. Interoperability completion still requires a
constant-time audit of secret-dependent field operations.
`Result<Unit, E>.Ok` uses payload-free member syntax because Unit has exactly
one value and no runtime storage. Array-repeat literals passed to a slice must
inherit the slice element type in semantic analysis and codegen, just like
ordinary array literals.
CRYPTO stream bytes are offset-addressed, deduplicated before counting against
the buffer limit, rejected on conflicting overlap, and released to TLS only as
a contiguous prefix. Retain the send buffer by offset so loss recovery can
request the same bytes again without rebuilding handshake messages.
Any change to these APIs must keep C# and self-host ownership/ABI lowering,
Windows/Linux execution, and the relevant socket and QUIC fixtures aligned.
Freestanding runtime helpers must include optimizer-emitted memory symbols:
`memset`, `memcpy`, and overlap-safe `memmove`. Do not fix a missing symbol by
linking an ambient C runtime on only one target.
The Windows native CLI link path must retain `ws2_32` alongside `shell32` so a
globally installed self-host compiler can link reachable TCP/UDP intrinsics.

The public playground ships the current self-host Stage 2 compiler as a
versioned WASM asset together with the matching standard-library JSON. A
compiler or standard-library change must update both asset references, rebuild
the browser compiler, run its retained compile/assemble/execute cases, and run
the real browser catalog before deployment. Browser LLVM may lower memory
intrinsics to `env.memcpy`/`env.memset`; the host ABI must implement both and
the emitted LLVM must declare the intrinsics explicitly.

The public 0.4 `sollang` executable is the Stage 3 fixed-point native compiler
built from `.slg` sources. The C# compiler is a bootstrap and differential
oracle, not a 0.4 release artifact.

Common commands:

```text
sollang --version
sollang run path/to/program.slg
sollang build path/to/program.slg -o program --target windows-x64
sollang test path/to/project --target windows-x64
sollang format path/to/program.slg
```

`--llvm <directory>` takes precedence when supplied. Otherwise native CLI
commands read `SOLLANG_LLVM_HOME`; if neither is set, they resolve LLVM tools
from `PATH`. Release and global-install verification must exercise the
environment-variable path as well as the explicit option.

## 6. How an Agent changes Sollang safely

1. Read the philosophy, specification, decisions, grammar, and nearest retained
   examples before changing a language rule.
2. For a proposed syntax change, show concrete before/after alternatives and
   obtain approval before implementation.
3. Add a minimal permanent positive or diagnostic fixture that reproduces the
   requirement.
4. Fix the owning parser, semantic, ownership, IR, runtime, or target invariant.
   Temporary parsing aliases, defensive success paths, swallowed errors,
   hard-coded sample output, and target-semantic fallbacks are forbidden.
   LLVM lifetime markers are optimization hints, not instructions that may be
   emitted after `ret`, `br`, or `unreachable`. A terminating path omits its
   pending `lifetime.end`. An affine operation anywhere in a flow, including
   `task -> await -> transform`, consumes its source even when a later target is
   a resolved generic call.
5. Keep the C# bootstrap and the Sollang self-host implementation semantically
   aligned.
6. Update user examples, regression expectations, browser samples, formatter,
   language server, and standard library wherever the public surface requires.
7. When implementation work reveals a deterministic pattern that still runs
   today but is likely to become a correctness, ownership, portability,
   maintainability, or performance defect, encode it as the next stable Snnn
   diagnostic when the compiler can prove it without speculation. Add a
   positive or negative regression first, fix all ordinary Sollang sources the
   diagnostic exposes, and require warning-free standard-library, self-host,
   and release builds. Do not add a warning whose suggested rewrite fails the
   current type or ownership contract.
8. Run focused probes, complete Windows/Linux suites, applicable browser gates,
   and required Stage 2/Stage 3 fixed-point verification. Browser execution
   changes must include exact stdout from named roles used directly and in
   interpolation expressions, plus the default contextual `it` role, not only
   a one-line implicit-main smoke test.
   A target-specific `name.linux-x64.slg` overrides the first root in the
   fixture's `.sources.txt` as well as a single-source fixture. Otherwise a
   multi-source Linux test can silently compile its Windows/default root.
   Self-host intrinsic recognition must be syntax-directed: a local binding
   named `capacity`, `len`, `push`, or another intrinsic is still an ordinary
   value read unless the AST/token span contains the corresponding top-level
   flow arrow. Collection intrinsics must additionally prove the canonical
    receiver type before assigning an opcode; a user function such as
    `set value: Int -> Int` remains an ordinary call in `3 -> set`. Keep a
    collision fixture whenever adding an intrinsic opcode.
    Collection mutation opcodes are also ownership and scheduling contracts:
    owned arguments to `push`/`insert` move on success, duplicate Set keys are
    dropped, and unused-result mutations must remain ordered effects. A
    dictionary-shaped mutable borrow such as `Set<T>` passes a pointer to the
    whole four-field structure; the single-buffer three-address ABI is only for
    array-shaped containers.
   Structural-product member ordinals must be resolved after the final
   canonical type projection. A synthesized product can exist only in the
   recursive type arena, beyond the semantic snapshot's nominal type table;
   emit it directly with `extractvalue` from its canonical product type instead
   of treating a missing nominal symbol as an indexable declaration.
   Partition route products are compile-time routing handles, not materialized
   SSA values. Before entry scheduling, mark every route terminal's structural
   member projection chain as consumed by direct dispatch; emitting the base
   binding read after the partition would reference a product value that is
   intentionally never defined.
   Partition typing must wait until the exact source producer has a canonical
   `Stream<T>` or `EventStream<T>` type. Retain both direct
   `producer -> partition` and bound `producer => values; values -> partition`
   fixed-point regressions; source order must not change route field types.
   A cross-language performance claim must also pass Perf100's exact-output
   gate for all six implementations, its at-most-10% idle CPU gate, and all 100
   ranking cases. Build with `scripts/perf100-build.sh`, verify representative
   family checksums with `scripts/perf100-check.sh`, measure with
   `scripts/perf100-run.mjs`, and generate the SHA-256-bound checked-in English
   and Korean summaries with `scripts/perf100-report.mjs`. Never publish an
   interrupted, stale-hash, CPU-contended, or correctness-mismatched run.
9. If compiler or standard-library artifacts changed, synchronize and verify
   the installed compiler at `P:\\Utils\\sollang`.
10. Update this guide when the preferred syntax, semantics, CLI, target boundary,
   standard library, examples, or required verification workflow changed.
11. Commit and push only after `git diff --check`, a clean test result, and a
    deliberate review of every tracked and untracked file.

Useful repository checks:

```powershell
dotnet run --project tests/Sollang.ExampleTests/Sollang.ExampleTests.csproj --no-build
npm run build
pwsh -NoProfile -File scripts/build-stage2-browser.ps1
git diff --check
```

Use the more specific verification scripts documented in `ROADMAP.md`,
`STAGE3_COMPILER.md`, and the relevant decision when compiler layers change.

## 7. Maintenance contract

This file is canonical and must evolve with the language. `AGENTS.md`,
`CLAUDE.md`, `.github/copilot-instructions.md`, the root `llms.txt`,
`README.md`'s AI section, the website's `/ai/AI_AGENT_GUIDE.md`, and
`/llms.txt` are discovery entry points; they must refer to this file and its
read order instead of copying its full contents or teaching a conflicting
surface syntax.

A change is incomplete when it modifies any of the following without reviewing
and, when necessary, updating this guide:

- preferred grammar or formatting;
- type, ownership, effect, evaluation-order, or target semantics;
- CLI commands or project/package behavior;
- standard-library vocabulary;
- user learning examples or browser samples;
- compiler verification and release requirements.

The guide must describe verified current behavior, not a roadmap aspiration.
Historical decisions remain in `DECISIONS.md`; exhaustive formal detail remains
in `SPEC.md`.
