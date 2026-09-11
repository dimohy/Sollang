# SLG Best Practices for AI Agents

Status: canonical single AI guide to current SLG syntax and beautiful code

Read this document to learn Sollang's syntax, design model, coding style,
ownership, and verification method. No second AI guide is a prerequisite.
`AI_AGENT_GUIDE.md` is only a compatibility pointer here. Detailed normative
rules remain in [`SPEC.md`](SPEC.md); exact lexical and parser productions are
[`sollang.lexer`](../syntax/sollang.lexer) and
[`sollang.grammar`](../syntax/sollang.grammar). Consult those focused sources
when the task needs more detail or a minimal compiler probe exposes a conflict.

Examples with domain names such as `Request`, `Error`, or `codec` demonstrate
composition; they are not promises that every illustrated name is a stdlib API.
The complete program below can be compiled directly. Find actual APIs in their
module declarations and the specification.

Reading and applying this document is mandatory before every SLG creation,
modification, generation, or review. Beautiful SLG is not ornamental formatting:
it combines natural left-to-right value flow, domain-accurate
`struct`/`enum`/trait and instance boundaries, explicit
ownership/effects/storage/cost, minimal temporary state and duplication, and no
workaround syntax or abstraction tax. Parser acceptance alone is insufficient.

## 1. Design model to internalize first

Sollang is not C#, Rust, or a conventional statement-first language with new
punctuation. Its design joins four commitments:

- **Sun:** reveal value origin, destination, ownership, effects, and cost.
- **Sol:** give related ideas the same visual rhythm.
- **Solution:** remove accidental complexity without hiding real work.
- **S·O·L:** keep forms Simple, Original, and Logical together.

The central reading direction is:

```sollang
source -> transform -> consume
expression => name
```

`->` carries or applies a value. `=>` defines, binds, resolves an arm, or
assigns a destination. Do not translate code from another language token by
token. First identify the value flow, ownership transfer, effects, storage,
failure boundary, and target capability; then express that model in SLG.

## 2. Authority and working method

Before changing `.slg` code:

1. Read and apply this document to the planned SLG. Reuse it within the session;
   revisit changed sections rather than rereading every document after each edit.
2. Find one preferred example under `examples/user/` and one retained
   regression that exercise the same language feature.
3. Read the exact stdlib or compiler implementation being extended. Do not
   infer a public surface from a single call site.
4. Make the smallest natural SLG probe when syntax, ownership, or lowering is
   uncertain.
5. Compile the probe before expanding the change.

If natural, ownership-correct SLG is rejected or reaches malformed LLVM, do not
add explicit-type noise, temporary heap owners, cloning, fallback branches, or
function-name special cases. Locate the parser, semantic, Typed IR, scheduler,
codegen, or runtime invariant that owns the defect.

### Syntax at a glance

| Purpose | Current SLG form |
| --- | --- |
| Entry and comment | `main { ... }`; `# comment` |
| Immutable binding | `expression => name` |
| Mutable owner and assignment | `expression => name!`; `next => name!` |
| Primary flow and additional inputs | `value -> operation(other)` |
| Zero-input declaration and call | `answer: -> Int => 42`; `answer()` |
| Function | `square value: Int -> Int => value * value` |
| Inherent method | `impl Point { value: self -> Int => self.x }` |
| Type parameters and constraint | `read<T> value: T -> Int where T: Measure { ... }` |
| Generic inherent method | `identity<T>: self, value: T -> T => value` inside `impl` |
| Branching | `value -> when { ... }`; `condition -> if { ... }` |
| Guard and loop | `condition -> unless { ... }`; `condition -> while { ... }` |
| Typed propagation | `source -> operation? => result` |
| Borrowing and transfer | `ref T`, `mut` input, `move` input |
| Effects and suspension | `uses Console`; `-> async T`; `task -> await` |
| Generic types and erasure | `Result<T, E>`, `box T`, `dyn Trait` type, `-> dyn<Trait>` conversion |
| Empty record and storage | `Empty { }`; `[T]`; `[T; N]`; `[T; ~]`; `[T; <=N]` |

Generic method parameters follow the method name, before `:`, and constraints
follow the signature. The managed compiler supports this form. Native direct
calls specialize ordinary functions and inherent methods for concrete argument
types, including distinct integer and Text instantiations. A direct call through
a generic trait constraint selects the implementation for the concrete receiver
and the requested trait. Managed nested generic helper calls preserve distinct
type instantiations. Native nested helper calls and recursive calls preserve
concrete integer and Text specializations and reuse identical instantiations.
Other recursive type shapes require target verification. Do not infer native support
from parsing alone, and do not replace the intended API with global
helpers to hide that boundary. An empty struct literal is valid for a fieldless
struct; a nonempty struct still requires its declared fields.

Keep receiver dispatch exact across chained flows. The result of the immediate
preceding call determines which inherent methods are eligible, and only the
nominal type written in an `impl` header owns those methods. A qualified type
mentioned inside an impl method signature is not an owner and must not shadow a
matching lexical function.

### What makes code beautiful

| Criterion | What a reviewer should be able to see |
| --- | --- |
| Value flow | The source, transformations, and destination read left to right. |
| Domain model | Structs, enums, traits, and methods name actual concepts and invariants. |
| Ownership | Borrow, mutation, transfer, and cleanup have one clear responsibility. |
| Cost and authority | Storage, allocation, effects, and limits are explicit. |
| Control shape | One subject uses one `when`; a failure-only guard uses `unless`. |
| Simplicity | Every temporary, branch, copy, and abstraction has a purpose. |

For example, this complete program puts score behavior on its domain value,
evaluates one discriminant, and binds only the result needed for output:

```sollang
struct Score { value: Int }

impl Score {
    normalized: self -> Int {
        self.value -> when {
            < 0 => 0
            > 100 => 100
            else => self.value
        }
    }
}

main {
    Score { value: 120 } -> normalized => score
    "$score" -> println
}
```

It prints `100`. The goal is not fewer characters: keep a named intermediate
when it explains a domain decision or lifetime. Remove one when it merely
breaks a natural flow. Do not trade explicit ownership or typed failure for a
shorter expression.

## 3. Organize modules, visibility, and foreign boundaries

A source file may start with one namespace, followed by file-local imports and
then interleaved declarations:

```sollang
namespace app.geometry

import std.text.json as json
import std.sequence

public struct Point {
    x: Int
    y: Int
}
```

Use explicit import aliases when two modules share a final segment or when a
short domain name improves the flow. `public` is an API commitment; leave
helpers private unless another module should depend on them. Several files may
share one namespace and form one logical module, but each file owns its imports.
Do not encode module identity through source order or manifest position.

Keep runtime and foreign authority explicit. `library ... from`, `native ...
from`, native `handle ... drop`, and `com ... class` declarations are ABI
boundaries, not ordinary portable implementation:

```sollang
native counter from "counter" {
    handle Counter drop "counter_drop"
    create initial: Int32 -> counter.Counter as "counter_create"
    add self: ref counter.Counter, amount: Int32 -> Int32 as "counter_add"
}
```

Specify symbol, handle cleanup, ownership, error mapping, target availability,
and ABI layout. Do not silently substitute a different library or portable path
when a declared native dependency is absent. Wrap raw authority under
`sys.runtime/**`; expose portable policy and domain instances from `std`.

## 4. Model data with struct, enum, products, Option, and Result

Use a `struct` when all fields coexist and their names are part of the domain:

```sollang
public struct Endpoint {
    address: IpAddress
    port: UInt16
}

public struct Request {
    endpoint: Endpoint
    headers: [Header; ~]
}
```

Initialize fields by name. Preserve the declared field storage type instead of
constructing a differently shaped temporary. A mutable owner may replace an
individual field value-first (`next => request!.endpoint`), while growable
collection fields should normally be mutated through projected instance calls.

Struct fields are private to their logical module by default. Mark only fields
that are deliberately part of the public data contract with `public`. Keep
validated domain-value storage private and expose a factory plus inherent
methods:

```sollang
public struct StreamCount {
    raw: UInt64
}

public streamCount value: UInt64 -> Result<StreamCount, Error> {
    # validate, then construct inside this logical module
}

impl StreamCount {
    public value: self -> UInt64 => self.raw
}
```

Code in another module must use the public factory and instance methods; it
cannot construct the value or read or write `raw`. A transparent data carrier
may instead spell `public value: Type` for each intentionally exposed field.
Field visibility changes compile-time access only, not ABI layout, allocation,
dispatch, or ownership. Do not replace a one-word domain value with a heap
object merely to hide its field.

Use an `enum` when exactly one variant is live. Give a variant a payload when
the state owns associated data:

```sollang
public enum ConnectionState {
    Idle
    Connecting(Endpoint)
    Established(Connection)
    Failed(Error)
}

state -> when {
    Idle { begin() }
    Connecting(endpoint) { endpoint -> poll }
    Established(connection) { connection -> serve }
    Failed(error) { error -> report }
}
```

Prefer exhaustive enum matching for protocol, state-machine, ownership, and
compiler-model code. Use `Option<T>` for present/absent and `Result<T, E>` for
success/failure; do not replace either with a sentinel scalar, empty text, or
nullable-looking convention. An owned payload pattern borrows unless the match
subject is a named owner or fresh owned temporary; moving that payload must be
explicit and must leave one cleanup path.

Use products for short structural joins whose fields do not need a nominal
type. Prefer labels when downstream meaning matters:

```sollang
(left: 10, right: 20) => pair
pair.left + pair.right => total

combine values: (left: Int, right: Int) -> Int {
    values.left + values.right
}
```

Use a nominal struct when invariants, methods, repeated use, ABI identity, or
domain vocabulary matter. Use a product for a local transparent grouping or a
flow-junction result. Do not turn every two-value result into an anonymous
array or heap object.

Core values include `Unit`, `Bool`, signed/unsigned fixed-width and target-sized
integers, floating-point values, `CodePoint`, and UTF-8 `Text`. Let contextual numeric
literals adopt the declared field, argument, return, or arm type; redundant
constructors usually indicate lost type context. Ordinary quoted strings allow
`$name` and `$(expression)` interpolation. Triple-quoted strings are raw and do
not interpolate.

## 5. Build abstractions with functions, generics, traits, impl, and blocks

Choose the smallest function form that keeps inputs and effects visible:

```sollang
answer: -> Int => 42
square value: Int -> Int => value * value
clamp value: Int, minimum: Int, maximum: Int -> Int {
    value -> when {
        < minimum => minimum
        > maximum => maximum
        else => value
    }
}
```

Zero-input calls use `answer()`. A primary input should flow on the left;
additional inputs stay in parentheses. Local functions belong at the start of
their containing function and are appropriate for one lexical algorithm, not
for hiding reusable module behavior.

Use generic parameters when the algorithm is representation-independent and
type inference remains clear:

```sollang
identity<T> value: T -> T => value
```

Put a `where` clause after the signature. A constraint may require a trait or
an associated-type equality, and several constraints remain comma-separated:

```sollang
sumBoth<T> value: T -> Int where T: LeftValue, T: RightValue {
    value -> LeftValue.leftValue => left
    value -> RightValue.rightValue => right
    left + right
}
```

Use a trait for a behavioral contract and associated types; use `impl Trait for
Type` for conformance and `impl Type` for inherent behavior:

```sollang
trait Magnitude {
    type Output
    magnitude: self -> Output
}

impl Magnitude for Point {
    type Output = Int
    magnitude: self -> Int => self.x * self.x + self.y * self.y
}

impl Point {
    public translated: self, dx: Int, dy: Int -> Point {
        Point { x: self.x + dx, y: self.y + dy }
    }
}
```

Trait methods declare the receiver first and additional inputs in source order.
Use the same ownership and types in the declaration and implementation. Keep
caller-owned output buffers explicit through a generic mutable borrow:

```sollang
trait Reader {
    type Failure
    readInto: mut self, output: mut [UInt8; ~] -> Result<Int, Failure>
}

read<T> reader: mut T, output: mut [UInt8; ~] -> Result<Int, Error> where T: Reader, T.Failure == Error {
    reader -> Reader.readInto(output)
}
```

Bind the associated failure to the concrete domain error instead of erasing a
socket or file failure. Generic policies that require the portable error state
that equality explicitly. For partial output, borrow the caller's growable byte
owner and put the unwritten range in the protocol instead of copying or deleting
a written prefix: `Writer.writeRange(input, offset, length)`. A
bounded transfer policy should be an instance that owns its byte and reusable
buffer ceilings, retries exact partial ranges, treats successful zero progress
as an error, and distinguishes source end from reaching the caller's limit.
For a bounded aggregate read, compose that policy with `ReplayBuffer`: reserve
space for `maxBytes + 1`, publish the owned aggregate only after observing end,
and retain the one-byte over-limit probe so a larger-limit retry loses no
source data. Reject insufficient replay capacity before the first source read.
Keep this protocol synchronous; use a separate task-returning protocol when the
underlying file or socket operation actually suspends.

For files, wrap the affine native owner rather than introducing an ambient
cursor. Keep the position in the adapter, call a position-independent bulk
primitive, and advance only after `Ok(count)`. Read into the caller's existing
visible buffer length; do not resize it or allocate an intermediate payload.
Validate a writer's `(offset, length)` range before the first file effect, and
provide a consuming recovery method when callers must regain the native owner
for sync or another ownership-preserving operation.

Associated types may occur inside input or result storage: for example,
`[Item; ~]`, `[Item; 2]`, and `{Text: Item}` retain their declared shape when
an implementation binds `Item` to `Int`. Keep the associated-type equality
visible in a generic algorithm when an input type must agree with the trait's
item type, as in `where C: Comparison, C.Item == T`. Qualify an imported trait
through its module alias when another module declares the same trait name.
The Windows and Linux native static-dispatch paths support these
additional-input and mutable-buffer forms; this does not establish every other
target backend or nested generic shape.

Constrain generics with a trailing `where` and call the intended trait
explicitly when several implementations could compete. `dyn Trait` is a
runtime trait object and `box T` is explicit owner/type erasure; use them only
when heterogeneous runtime dispatch is required. Prefer monomorphized generic
or direct instance calls on hot paths. The current `dyn` subset accepts only
traits without associated type declarations and methods with readonly `self`,
no additional inputs, and an `Int` result. A static trait with additional inputs
is not thereby dyn-compatible; use its direct or constrained generic call.

Block functions express an algorithm that controls a caller-supplied block.
They are not ordinary callbacks disguised as syntax:

```sollang
collect<T> value: T -> Int block items: [T; ~] {
    [value,; ~] => yielded
    yielded -> yield
    1
}

9 -> collect items {
    items -> len => count
} => collected
```

The block signature, `yield` result, ownership, effects, and evaluation count
are part of the contract. Use local fusion or direct lowering where available;
do not introduce a heap closure or indirect call merely to imitate another
language's iterator API.

Local functions are declared before ordinary statements in their containing
function. Use them for lexical decomposition and capture, while preserving the
same ownership and effect rules as module functions. Do not move reusable
behavior into a local function merely to avoid choosing its public module.

## 6. Write value flow, not translated syntax

Prefer a visible primary input:

```sollang
text -> trim -> lower -> slugify => slug
```

Use ordinary call syntax when there is no primary input or when several inputs
are equally important:

```sollang
answer() => result
choose(left, right) => selected
```

Do not write an empty call marker on a flow target:

```sollang
# Preferred
7 -> square => result

# Avoid
7 -> square() => result
```

Keep long flows vertical. A leading `->` or `=>` continues the preceding value
without changing evaluation order.

## 7. Bind and mutate value-first

Immutable names have no suffix. Mutable owner bindings use `!` at declaration
and every access:

```sollang
[10, 20, 30; ~] => values!
99 => values![1]
values! -> len => count
```

Do not use assignment forms imported from other languages. Do not drop `!`
from a mutable access. Bind an owned container once; choose the producing branch
first, then bind its single result. Mutate its contents through instance methods
instead of replacing the complete owner through a second `=> owner!`.

## 8. Make ownership visible and zero-copy by default

Treat owners as affine:

- use `move` only when the callee or result takes the drop obligation;
- use `ref` for readonly borrowing and `mut` for mutable borrowing;
- do not clone or heap-materialize merely to silence an ownership diagnostic;
- after moving a field, never assume the complete former owner remains live;
- bind an owned block-function result before returning or transferring it;
- use `take` only when extracting a value and leaving the container in its
  defined replacement state is the intended operation.

An ownership diagnostic should lead to one of four explicit designs: transfer,
borrow, mutate in place, or copy by deliberate policy. Hidden copies are not a
compatibility solution.

`sys.process.arguments()` returns a copyable, process-lifetime `Arguments`
view. Pass or return that value directly and store it in a domain record when
needed; do not add `move` or materialize an owned array merely to forward it.
Its elements are borrowed `Text`. Windows managed and self-host support
ordinary and generic function forwarding, branch results, aggregate fields,
and local captures. See
[`1668-arguments-return-forwarding.slg`](../examples/regression/1668-arguments-return-forwarding.slg)
for the direct value-flow form. Host availability remains governed by the
[`Arguments` contract in SPEC.md](SPEC.md).

## 9. Put behavior on instances

Library state and resource lifecycle belong to values:

```sollang
limits -> codec? => codec
codec -> decoder(decoderLimits)? => decoder!
decoder! -> write(chunk)? => accepted
decoder! -> finish(output!)? => written
```

Prefer constructors or immutable option values that create affine mutable
instances. Public global functions are appropriate only for genuinely
stateless vocabulary explicitly accepted by the stdlib design. Socket, QUIC,
process, compression, hashing, readers, writers, clocks, and similar stateful
facilities should not hide state in globals.

For SHA-256, create one `std.crypto.sha256.Hasher`, update it with each byte
slice, then consume it with `finish`. Use the same instance API for one-shot
input; do not add a global digest wrapper or copy the input into a new buffer.

```sollang
sha256.create() => hasher!
hasher! -> update(bytes)
hasher! -> finish => digest
```

For HMAC-SHA256, flow the borrowed key into `hmac.create` to create a
`std.crypto.hmac_sha256.Hasher`. Call `update` for each message slice and
consume the hasher with `finish` to obtain all 32 MAC bytes. One-shot input
uses the same instance API; there is no public `hmac.digest` wrapper.

Instance syntax must not impose an abstraction tax. Keep receiver lowering
direct, caller-owned buffers visible, and hot paths allocation-free where the
contract permits it. Measure before replacing a proven fast path.

## 10. Keep storage and cost explicit

Choose the collection form that states the intended storage:

- `[T; N]`: fixed inline owner;
- `[T]`: readonly borrowed view;
- `[T; ~]`: growable heap owner;
- `[T; N~]`: growable heap owner with a capacity hint;
- `[T; <=N]`: bounded growable inline owner;
- `{K: V; <=N}`: bounded inline dictionary.

A growable array can own growable array elements: `[[Int; ~]; ~]` stores each
inner owner's pointer, length, and capacity. Transfer the inner owner into the
outer array; copying it from a readonly borrow is invalid. Destruction releases
the inner owners before the outer buffer. Do not infer support for every nested
fixed, bounded, or borrowed container form from this growable-owner contract.

Literal, typed-empty, and repeated forms preserve that storage choice:

```sollang
[1, 2, 3] => fixed
[UInt8; ~] => growable!
[0; 64] => words!
{"one": 1, "two": 2} => lookup
{Text: Int; <=32} => boundedLookup!
```

For an array of records, write the nominal element type once:
`[Point; { x: 10, y: 20 }, { x: 30, y: 40 }]`. Prefer declaration order for
readability, but field names determine storage identity. Initialize each field
exactly once and preserve the source order of effectful initializers. The
compiler rejects unknown, duplicate, missing, and incompatible fields before
LLVM emission. Integer literals inherit the declared field type with range
checking; typed values still require an explicit conversion when narrowing.

A fixed literal retains its exact length after binding: `[10, 20]` and
`[10; 2]` have type `[Int; 2]`, and `["one", "two"]` has type `[Text; 2]`.
Pass that owner to a matching fixed-array parameter without converting it to a
growable container. A known length mismatch is a compile-time error, including
for an additional input. A mutable fixed-array borrow permits element updates
while preserving the length and the owner's cleanup responsibility.

Use indexing for a checked element place and keep mutation value-first.
Dictionary reads and writes remain explicit collection operations rather than
an ambient dynamic-object convention. Use `map read` and `map write` only for
memory-mapped file ownership with declared `File` effects, offsets, lengths,
and writable lifetime; they are not dictionary operations.

Do not silently spill inline storage to the heap. Reserve once when a safe size
is known. Pass readonly tables by `ref` instead of cloning them. Use caller-owned
output buffers for streaming and native-style APIs when that makes allocation,
capacity, and transfer visible.

## 11. Express control flow in SLG rhythm

Short conditions stay inline and do not wrap the whole condition in
parentheses:

```sollang
ready and hasWork -> if {
    run()
}
```

When a condition reaches the repository style limit, put the condition on its
own line and the control target on the next line:

```sollang
index! < (input -> len) and output! -> len < maximumOutput
    -> while {
        step()
    }
```

Remove only redundant outer parentheses. Keep a pair that establishes
precedence inside a larger expression. N001 reports a control condition of 45
or more source characters left inline; N002 reports parentheses around the
entire `if`, `unless`, or `while` condition.

An ordinary value transformation is already one comparison or logical
operand. Thus `ready and text -> predicate` means
`ready and (text -> predicate)`, while `text -> len < limit` means
`(text -> len) < limit`. Do not add parentheses around those value flows.
Control and junction targets consume the completed outer expression.

Use `unless` for a failure-only validity guard:

```sollang
limit > 0 -> unless {
    Result<Value, Error>.Err(error) -> return
}
```

Use subject-style `when` when one value is compared against variants, values,
or ranges. Keep enum and protocol dispatch exhaustive; do not add a broad
`else` merely to survive future variants.

Do not translate three or more related tests into an `if`/`else` ladder. Flow
the shared subject once so it is evaluated once and the decision reads as data:

```sollang
score -> when {
    90..100 => "A"
    80..89 => "B"
    70..79 => "C"
    else => "F"
} => grade
```

Use full-condition `when` when arms do not share one subject:

```sollang
when {
    expired { Expiry.Expired }
    retries! >= maximumRetries { Expiry.Exhausted }
    else { Expiry.Active }
} => state
```

Match enums and `Result` directly. Name every protocol variant when a newly
added variant must force consumers to make a decision:

```sollang
frame -> when {
    Ping { handlePing() }
    Stream(payload) { payload -> handleStream }
    Close(error) { error -> handleClose }
}
```

Use `if` for one local yes/no decision, `unless` for one failure-only guard,
and `when` for ordered multi-way choice. This is a semantic choice, not merely
a formatting preference.

Use inclusive `..` and half-open `..<` ranges deliberately. Use `while` for a
state-driven loop, `fold` for one accumulated value, and `each` for direct
range or stream consumption. `break` and `continue` may be unconditional or
guarded with `condition -> if break` / `condition -> if continue`. `return`
belongs only in a declared function and may carry its value on the left. Avoid
encoding a fold as mutable state when the accumulator is the actual result.

An `each` role uses the element type of its source collection, including a
collection returned by an imported function. Access record fields directly;
do not add casts or copy the collection to repair compiler type inference.

## 12. Use typed failure, not arbitrary fallback

Postfix `?` propagates only `Result<T, E>` and performs deterministic cleanup:

```sollang
source -> parse? => parsed
parsed -> validate? => valid
```

Return distinct typed errors for distinct actionable failures. Never turn I/O,
parse, limit, capability, checksum, ownership, or target failures into an empty
value, zero, success, or catch-all default. Validate cheap input contracts
before allocating, spawning, linking, or performing external work.

## 13. Declare effects and target boundaries

Functions are pure by default. Declare every observable capability in `uses`,
and let requirements propagate:

```sollang
audit value: Int -> Unit uses Console {
    "audit=$value" -> println
}
```

An `effect` declaration names operations supplied by a capability handler; it
does not perform the operation by itself. Keep effect operations, function
`uses` clauses, and target capability diagnostics aligned.

Do not make real I/O look pure. Do not confuse `async` with authority: async
describes suspension, while `Console`, `File`, `Clock`, `Random`, `Process`, and
`Environment` describe external capabilities. A browser or unsupported target
must fail through an explicit capability boundary, not an ambient native
fallback.

## 14. Use flow junctions instead of temporary plumbing

A flow may fan out, observe, route, or join without abandoning `->`. Select the
operator by topology and policy.

### Compute several named results

`branch` is sequential and preserves arm source order. It produces one labeled
product, so downstream code keeps names instead of positional temporaries:

```sollang
order
    -> branch {
        priced: -> price -> applyDiscount
        checked: -> validate
        checksum: ref -> checksum
    }
    => examined

(price: examined.priced, check: examined.checked) -> reconcile => decision
```

For an affine input, at most one arm may move it. Use `ref` for several readonly
inspections. `branch` never implies parallelism.

### Observe without breaking the outer flow

`tap` runs an audit or diagnostic side flow and returns the original value:

```sollang
request
    -> tap {
        -> summarize
        -> writeAudit
    }
    -> send
```

Do not replace this with a temporary plus duplicated continuation. A `tap` arm
may not consume an affine outer value that the following flow still needs.

### Route each stream item exactly once

`partition` tests arms from top to bottom, requires a final `else`, and sends
each item to exactly one output stream:

```sollang
events -> partition event {
    errors: when event -> isError
    warnings: when event -> isWarning
    normal: else
} => routed

routed.errors -> each error { error -> writeError }
routed.normal -> each event { event -> process }
```

### Join streams with an explicit policy

Never write a generic `join` when timing and completion matter:

```sollang
(left: left, right: right) -> zip => paired
(first, second) -> merge => interleaved
(first, second) -> concat => ordered
(sensor: sensor, threshold: threshold) -> latest => current
```

- `zip` emits one product per input and stops at the shortest stream.
- `merge` emits by fair availability and completes after all inputs.
- `concat` consumes complete inputs in product order.
- `latest` waits for one value from every input, then emits on updates.

These operators are lazy. Bounded buffering, backpressure, completion, and
cancellation remain observable; never replace them with an unbounded queue.

### Request overlap explicitly

Use `parallel branch` only when the work is independent enough to overlap:

```sollang
document -> parallel branch {
    tokens: ref -> tokenize
    metadata: ref -> inspectMetadata
    checksum: ref -> checksum
} => analyzed
```

Arms may complete in any order, but result fields retain declaration order.
The compiler must prove that borrows, moves, mutable access, and effects can
overlap. Do not use parallelism for tiny work, effect ordering, or as a way to
duplicate an owner. Measure task setup and callback shape on hot paths.

## 15. Build lazy Stream and bounded EventStream pipelines

`Stream<T>` is an affine deferred producer, not an iterator object and not an
eager intermediate array. Local `map`, `filter`, `tap`, `flatMap`, `take`,
`skip`, and terminal `each` should fuse so each value travels directly through
the stages:

```sollang
1..1_000_000_000
    -> map sensorId {
        Reading {
            sensorId: sensorId
            celsius: temperature(sensorId)
        }
    }
    -> tap reading {
        scanned! + 1 => scanned!
    }
    -> filter reading {
        reading.celsius >= 57
    }
    -> take(5)
    -> each alert {
        alert -> publish
    }
```

This pipeline must not allocate a billion-element range, mapped array, or
filtered array. `take(5)` propagates `stop` upstream as soon as the fifth value
is consumed. `break` and `continue` in the terminal consumer control the fused
source loop.

A first-class stream may cross a function boundary and remains affine:

```sollang
makeValues values: Range -> Stream<Int> {
    values -> defer
}

1..20 -> makeValues => values
values -> map item { item * 2 } => doubled
doubled -> each item { item -> consume }
```

The terminal operation consumes the stream once. A second terminal use is an
ownership error. Persistent stage state uses the explicit `state` binding and
is initialized once per pipeline, not once per item:

```sollang
public take<T> value: T, count: Int -> stream T {
    0 => state taken!
    taken! < count -> if {
        taken! + 1 => taken!
        taken! >= count -> if { stop }
        value -> emit
    }
}
```

`EventStream<T>` is the hot-source counterpart. Its constructor must require a
capacity and overflow policy; subscription, cancellation, worker join, and host
state restoration belong to its affine lifetime:

```sollang
32 -> mouse.source(mouse.OverflowPolicy.CoalesceMotion)? => source
source -> events => rawEvents
rawEvents -> passThrough => events
events -> each event {
    event -> handleMouse
    stop
}
```

Do not model an event source as an unbounded ordinary stream or hide a worker
that outlives its owner. Browser targets require a host event-loop capability
rather than a synchronous native fallback.

## 16. Use structured async, await, yield, and cancellation

An `async` call returns an affine task. Start independent children before the
first `await` to expose concurrency, then await them in the deterministic order
needed by the result:

```sollang
work value: Int -> async Int {
    value * 10 + 1
}

combine: -> async Int {
    3 -> work => firstTask
    7 -> work => secondTask
    firstTask -> await => first
    secondTask -> await => second
    first + second
}
```

Use direct await when no sibling task can overlap:

```sollang
6 -> squareAsync -> await => squared
```

Suspension is structured: live values move into the coroutine frame, owned
results transfer exactly once, and leaving scope joins or cleans up outstanding
children. `yield` cooperatively returns to the ready queue without granting an
I/O effect. Long CPU loops use it deliberately when fairness matters:

```sollang
index! < limit -> while {
    index! -> process
    index! + 1 => index!
    yield
}
```

Cancel an affine task explicitly when its result is no longer needed:

```sollang
7 -> forever => spinning
4 -> finite => finiteTask
spinning -> cancel
finiteTask -> await => result
```

Keep monotonic readings bound to their clock source. Build deadlines through
the source instance, compare them only with a reading from that source, and
propagate the typed different-clock error. Fixed and offset wall clocks do not
replace a monotonic source for elapsed time or scheduling.

Inspect `clock -> capabilities` when behavior depends on resolution, maximum
delay, or whether monotonic time includes system suspend. Match every
`SuspendPolicy` case explicitly; `Unspecified` is a real target boundary, not a
reason to assume either native policy.

Treat periodic timers as affine schedules. Move a `Timer` into `wait`, await the
Task, inspect the returned `TimerTick`, then recover the next owner with
`intoTimer`. Use `Burst` only when every overdue tick must remain observable,
`Skip` for aligned schedules that may discard missed ticks, and `Delay` when the
next period begins at the actual wake time. Cancel the Task for an in-flight
wait; consume an idle timer through `cancel` or `close`.

Fallible async helpers use ordinary postfix propagation. An error completes
the Task with `Err`; it does not escape through the readiness worker itself:

```sollang
load id: Int -> async Result<Record, Error> {
    id -> fetch? => record
    Result<Record, Error>.Ok(record)
}
```

Do not create a task and immediately await it when independent work could have
started first. Do not detach tasks, hide unbounded task creation, hold a mutable
borrow across overlap, or assume `async` grants `File`, `Clock`, or `Process`.

For structured logging, let `std.log.Logger.record` filter before constructing
fields. Match the returned `Option<Record>`; only the `Some` branch should
build caller-owned fields and call an explicitly chosen concrete
`std.log.Sink`. Keep formatting, buffering, and destination effects in that
sink, and propagate its typed `std.log.Error`. Do not add an ambient logger,
default sink, hidden fallback, or a generic forwarding wrapper that obscures
the concrete sink ABI.

## 17. Design stdlib surfaces as contracts

For every new module, write down before implementation:

- owner and namespace (`sys` for raw OS/runtime authority, `std` for portable
  policy and user-facing abstractions);
- immutable options and limits;
- instance lifecycle, including consuming `close`, `finish`, or `wait`;
- caller-owned versus callee-owned buffers and results;
- effects and target capabilities;
- typed failures and exact invalid states;
- bounded memory, work, retry, queue, frame, member, and expansion policies;
- one-shot versus streaming parity and whether they share one core path;
- the expected direct-call, allocation, copy, and cleanup shape.

Do not expose an easy one-shot API by keeping a second parser or protocol engine
beside the streaming implementation. Convenience should route through the same
bounded instance or a measured shared core.

For a reusable async I/O owner, validate every capacity relation before the
first effect, move caller storage into one affine operation value, keep native
identity and lifecycle mutation private, and provide a consuming method that
returns the original storage. Do not label synchronous readiness as completion
or add an async-looking wrapper around a blocking worker.

## 18. Comments, names, and embedded SLG

Use short English `#` comments in examples and regression fixtures to state the
contract being proved. Name values by domain role, not by incidental compiler
representation. Avoid `tmp`, `thing`, and numbered workaround names when a
semantic name exists.

When SLG source is embedded in `Text`, use a triple-quoted multiline string.
Do not construct large source programs with escaped `\n` fragments. Embedded
examples must still follow value-first bindings and the same source-style
rules as ordinary files.

## 19. Focused verification ladder

Stop at the first failing layer, fix its authority, then continue:

1. format and source-style notes (`N001`/`N002`);
2. smallest parse and semantic fixture;
3. ownership/effect diagnostic and actionable repair fixture;
4. managed exact compile/run;
5. self-host differential for the affected feature;
6. LLVM direct-call closure and structural assertions;
7. `llvm-as`, link, exact native execution, and warning/note zero;
8. same-input performance and allocation comparison for a hot path;
9. Stage2/Stage3 fixed point only when compiler-owned source changed or the
   focused evidence exposes a compiler defect;
10. affected Windows, Linux, and browser target closure.

Finish integrating compiler and fixture changes before starting full suites.
Run the full Windows managed reference suite through
`scripts/verify-managed-reference.ps1` with an empty output directory under
`artifacts/`. This wrapper preserves live logs and requires unchanged compiler,
runner, source, expectation, and tool inputs before publishing success. An
interrupted run is partial evidence; changed inputs require fresh verification.

Before a full self-host build, the seed must pass small capability fixtures for
features used by the current compiler, including Dictionary `putIfAbsent`.
An incompatible seed requires the explicit bootstrap recovery path followed by
Stage2/Stage3 fixed-point verification before publishing a replacement seed.

Formal Stage2/Stage3 commands run through the detached self-host verification
supervisor. Reserve distinct durable-log and structured-completion-record paths
before launch, read progress from the recorded PID and stage markers, and accept
completion only from the structured record containing the supervised process
exit code and exact failure identifiers. Successful exits have no failure
identifiers, require every observed descendant to terminate, and record an empty
`orphanProcessIds` array; failed exits derive identifiers only from
failure-context lines. A
final visible log line is not a completion signal. Stop an active verification
through its recorded cancellation-request path rather than a raw process kill;
accept cancellation only when the structured result reports `cancelled`, a
non-zero exit code, the exact `CANCELLATION_REQUESTED` identifier, and zero
orphan processes.

A stdlib-only change that passes focused verification should proceed to the
next stdlib slice. Do not repeatedly run the full compiler gate unless the
change or evidence actually enters compiler-owned semantics or codegen.

## 20. AI pre-edit and pre-completion checklists

Before editing:

- [ ] I can state the value flow from source to sink.
- [ ] I know every owner, borrow, move, mutation, and cleanup edge.
- [ ] I know the effects, target capabilities, allocation, buffering, and
      failure limits.
- [ ] I found an authoritative preferred example and a regression analogue.
- [ ] I will compile a minimal uncertain construct before expanding it.
- [ ] I am not modifying a file currently consumed by a long-running gate.
- [ ] Formal Stage2/Stage3 uses the detached supervisor, distinct durable log
      and structured completion record, and PID-backed progress reader.

Before completion:

- [ ] `->` and `=>` have their native roles; binding and assignment are
      value-first.
- [ ] Mutable accesses retain `!`; no owned container is rebound wholesale.
- [ ] No redundant whole-condition parentheses, N001, N002, warning, or note
      remains in repository SLG.
- [ ] No silent fallback, hidden copy, unbounded queue, ambient authority, or
      duplicate convenience implementation remains.
- [ ] The smallest fixture proves behavior and the invalid counterpart fails
      early with repair guidance where applicable.
- [ ] Hot-path performance claims use the same compiler, source fingerprint,
      input, output hash, and repeated measurement.
- [ ] Documentation, contract, fixture, implementation, and target evidence
      describe the same surface.

## 21. Common mistranslations to reject

| Imported habit | Natural SLG direction |
| --- | --- |
| `var result = transform(value)` | `value -> transform => result` |
| `values[i] = value` | `value => values![i]` |
| `(condition) -> if` | `condition -> if` |
| global stateful helper | options/value creates an instance; call methods |
| catch-all success/default | typed `Result` error with actionable context |
| clone to satisfy ownership | transfer, borrow, mutate, or deliberate copy |
| iterator object by default | fused `Stream<T>` or explicit affine producer |
| hidden grow/spill | explicit storage form and capacity/limit |
| full compiler suite after every edit | focused fixture, escalate on evidence |

The standard is not merely “accepted by the parser.” Good SLG reveals who owns
the value, where it flows, which authority it uses, what it costs, how it can
fail, and why the chosen form belongs to the language's rhythm.

## 22. Feature coverage map

The machine-readable coverage contract is
`scripts/contracts/ai-slg-best-practices.json`. It maps every required feature
family to this document and to a compiling user or regression example. The
inventory is derived from `syntax/sollang.grammar`, grouped by user-facing
semantic responsibility rather than by an arbitrary target count. Every row
is required by the machine contract:

| Family | Preferred SLG strength |
| --- | --- |
| modules and visibility | `namespace`, `import`, aliases, `public`, split logical modules |
| scalar and text values | numeric context, `Bool`, `Unit`, `CodePoint`, UTF-8 `Text`, interpolation |
| structs | nominal records, named initialization, field access and assignment |
| enums and patterns | nominal variants, payloads, exhaustive subject-style `when` |
| Option and Result | absence, typed failure, enum construction, postfix `?` |
| products | positional and labeled structural grouping and product types |
| functions and calls | expression/block bodies, primary flow input, additional inputs, explicit zero-input calls |
| local functions | lexical declarations, captures, ownership and effect parity |
| block functions | block signature, controlled invocation, `yield`, result binding |
| generics and constraints | type/value parameters, `where`, traits and associated-type equality |
| traits and impl | behavioral contracts, associated types, trait and inherent `impl` |
| dynamic ownership | explicit `box T` and owned `dyn Trait` only for runtime heterogeneity |
| foreign and ABI boundaries | `library ... from`, `native ... from`, handle drop, COM class/interface, ABI marker |
| flow and binding | left-to-right `->`, value-first `=>`, mutable `!` |
| expressions and operators | precedence, short-circuit logic, arithmetic, comparison, unary operations |
| control choice | `if`, `unless`, subject/full-condition `when` |
| loops and ranges | inclusive `..`, half-open `..<`, `while`, `fold`, `each`, break/continue/return |
| ownership | affine `move`, readonly `ref`, mutable borrow, deterministic drop |
| effects | effect declarations, explicit `uses`, transitive target capabilities |
| explicit storage | fixed, borrowed, heap-growable, hinted, and bounded inline collections |
| collections | arrays, dictionaries, indexing, field/index assignment, explicit mutation |
| mapped bytes | effectful `map read` / `map write` with explicit ranges and ownership |
| flow junctions | `branch`, `tap`, `partition`, `zip`, `merge`, `concat`, `latest` |
| lazy stream | fused `map`/`filter`/`flatMap`/`take`/`skip` and terminal `each` |
| event stream | bounded hot sources, overflow policy, cancellation, lifetime restoration |
| parallel flow | ownership-checked `parallel branch`, `parallel`, and `tryParallel` |
| structured async | affine tasks, sibling start before `await`, typed coroutine frames |
| cooperative lifetime | `yield`, `cancel`, scope join, timer/readiness suspension |
| compile-time expression | constant ranges/`each`, contextual literals, fixed storage and value arguments |
| source as data | triple-quoted multiline SLG with the same syntax and style rules |

When a new normative SLG feature family is accepted, add it to that contract,
add or identify a compiling example, and update this document in the same
change. A prose-only feature with no authoritative example is incomplete.

## 23. Keep this guide current without turning it into a log

When syntax, semantics, public API conventions, target support, or SLG beauty
criteria change, update the relevant section here and its example. Update the
corresponding detailed contract in `SPEC.md` and the grammar when affected.
Keep the feature coverage contract aligned with the actual grammar. A parser
production proves syntax coverage, not execution on every backend.

Do not append progress counts, defect histories, build output, timing reports,
or session notes here. Keep those in existing task evidence. Update
`SESSION_HANDOFF.md` only when the user explicitly requests a session handoff.
Ordinary implementation work does not require rewriting this guide or a handoff.

Preserve unrelated changes and keep temporary compilation artifacts under
`artifacts/scratch/` or an OS-created temporary directory. Use focused checks
and reuse successful evidence until a relevant input or requirement changes.

Focused references, when needed: [`PHILOSOPHY.md`](PHILOSOPHY.md),
[`GETTING_STARTED.md`](GETTING_STARTED.md), [`ARRAYS.md`](ARRAYS.md),
[`ROLE_BLOCKS.md`](ROLE_BLOCKS.md), [`FLOW_JUNCTIONS.md`](FLOW_JUNCTIONS.md),
[`GRAMMAR_BOOTSTRAP.md`](GRAMMAR_BOOTSTRAP.md),
[`EXAMPLE_CATALOG.md`](EXAMPLE_CATALOG.md),
[`STAGE3_COMPILER.md`](STAGE3_COMPILER.md), and
[`DECISIONS.md`](DECISIONS.md). They extend this guide; reading all of them
is not a prerequisite for every SLG task.
