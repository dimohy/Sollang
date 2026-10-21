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

A result-producing user block follows the same explicit storage boundary as
ordinary expressions. A callback that yields interpolation must materialize it
in an owned arena before its result is bound, including a binding inside the
producer. Plain `Text` results keep their ordinary binding behavior. A block
result may continue through ordinary calls and later callbacks. Bind the final
flow result in the enclosing scope, and use explicit arena materialization
before storing deferred interpolation; an immediate sink can consume it directly.
At user-block invocation and yield boundaries, evaluate inputs before binding
roles and executing callback effects. Source offsets from different declarations
cannot order these phases; preserve their data dependencies and lexical scopes.
Generic user-block inputs infer parameters recursively through `Option`,
`Result`, dictionary key/value types, growable arrays, and readonly references.
Use ordinary addressable bindings for `ref T` inputs; a literal or temporary
does not become borrowable merely because the call has a callback.

If natural, ownership-correct SLG is rejected or reaches malformed LLVM, do not
add explicit-type noise, temporary heap owners, cloning, fallback branches, or
function-name special cases. Locate the parser, semantic, Typed IR, scheduler,
codegen, or runtime invariant that owns the defect.
Keep function ownership scopes distinct from nested control regions. Cleanup
analysis may inspect both, but a control-termination query must never consume a
function owner's `-1` parent as a function index.
When indexing function declarations by AST, exclude synthetic input and `self`
symbols that reuse the declaration's AST node. Read declared return contracts
from the function symbol, including for fixed-length growable-array warnings.
Infer omitted signatures from complete value contracts. A stored field read
uses its canonical declared type, including nested and readonly receivers.
An inherent method counts as a consuming function scope for an inferred private
helper; do not add signature annotations to bypass a missing consumer edge.
A declared integer input supplies context recursively to arithmetic in a direct
or additional argument. Preserve independently typed operands and report an
invalid child literal before checking the enclosing operation. A primary flow
source is inferred before its callee supplies argument context. Generic calls
use only the expected types available before that argument is inferred; preserve
this decision when restoring semantic owner facts from a cache.
An expected `CodePoint` type does not enable arithmetic; convert operands to
`UInt32` before performing numeric operations.
An integer-typed peer supplies context to an `if` or `when` numeric operand.
Propagate that context through terminal arm values, keep independently typed
values intact, and preserve the committed result type through generic cloning,
semantic cache reuse, and emission. Evaluate each operand once in source order;
do not recover a missing type by emitting a conditional again.
Boolean-condition and subject-style `when` share the same all-arms-return
termination rule. A nested selection that returns on every path produces no
continuing value; enclosing control emission must preserve that termination
rather than storing a result or creating a merge edge.
Read a readonly integer subject through its canonical value type in both
relational and range arms, preserving its width, signedness, and reference ABI.
Keep distinct AST grammar identities disjoint. Registered expression kinds and
their semantic consumers follow `scripts/contracts/ast-expression-kinds.json`;
run `scripts/verify-ast-expression-kind-contract.py` before compiler generation.
A value-flow comparison wrapper owns only comparison operators after its first
value-flow child. Operators consumed by that child retain their existing AST
nodes; do not classify the enclosing wrapper as another comparison.
Boolean collection values remain literals; compile-time `each` owns its own
selector identity and expansion decisions.
Resolve runtime intrinsics by their canonical declaration identity for both
direct and flow calls. Disabling spelling-based recognition for a resolved call
must not erase that declaration's intrinsic operation. Keep same-named user
functions on their ordinary call path.
Intrinsic collection callbacks bind roles to the source element type, including
roles read only inside interpolation. Evaluate the source before entering the
callback and resolve each role from its lexical callback owner; emitting the
callback body must not evaluate that source again.
Resolve a projected receiver from the field's canonical type. A structural or
array field replaces its containing nominal owner; `self.values -> push(value)`
inside `Queue.push` must use the array operation unless that array type owns an
explicit matching method. Retain exact nominal dispatch for nominal fields.
Keep a committed full receiver type authoritative. Fields referenced inside a
constructed receiver's initializer do not replace that receiver, and an earlier
lexical impl-method candidate still requires exact receiver-owner validation.
Inside interpolation, resolve a method for the canonical receiver before a
same-named free function, and a declared function before a spelling-based
collection intrinsic. Commit one declaration before result and argument type
inference, ownership checks, and emission. A selected method's error cannot
silently redirect the call to the free function.
Treat `=> expression` and `{ ... }` selection arms as body regions with the
same result and continuation rules. An expression arm retains the arrow's
source location; nested generic type arguments cannot change a flow stage's
constructor identity. Resolve the owned target after the AST source span.
For an all-return `when`, distinguish conditional arms from `else` by their AST
role, then test each arm's actual emission region for termination. A flat IR
kind-19 arm alone cannot make that distinction. Keep a later sibling's
continuation live; a source-final all-return `when` emits no merge or implicit
return value. Apply that same completed-control reachability to ownership:
a moved owner inside an all-return branch cannot invalidate a later read on a
non-moving continuation, while a moving branch that continues must fail at its
ownership join.
A returned match uses only each continuing arm's linked terminal value. Exclude
terminating arms and compare complete canonical types, including generic payloads;
never select an earlier nested call or rewrite its declared result type.
Ordinary and subject-style `when` share the same arm value-demand rules.
Propagate an enclosing value use through either form; a loop body still discards
its terminal value unless that value has a separate consumer.
Evaluate selection subjects before their arms when checking ownership. A move
in a `when` or enum-match subject persists on each continuing arm; exclude arms
that return and diagnose mixed ownership before LLVM generation.

### Syntax at a glance

| Purpose | Current SLG form |
| --- | --- |
| Entry and comment | `main { ... }`; `# comment` |
| Immutable binding | `expression => name` |
| Mutable owner and assignment | `expression => name!`; `next => name!` |
| Primary flow and additional inputs | `value -> operation(other)` |
| Zero-input declaration and call | `answer: -> Int => 42`; `answer()` |
| Function | `square value: Int -> Int => value * value` |
| Inherent method | `impl Point { value: self -> Int => self.x }`; `impl [UInt8] { digest: self -> Digest { ... } }` |
| Type parameters and constraint | `read<T> value: T -> Int where T: Measure { ... }` |
| Generic inherent method | `identity<T>: self, value: T -> T => value` inside `impl` |
| Branching | `value -> when { ... }`; `condition -> if { ... }` |
| Guard and loop | `condition -> unless { ... }`; `condition -> while { ... }` |
| Typed propagation | `source -> operation? => result` |
| Borrowing and transfer | `ref T`, `mut` input, `move` input |
| Effects and suspension | `uses Console`; `-> async T`; `task -> await` |
| Generic types and erasure | `Result<T, E>`, `box T`, `dyn Trait` type, `-> dyn<Trait>` conversion |
| Unary expressions | `not condition`, `box value`; each requires an operand and a bare `not` or `box` is not a value expression |
| Expression keywords | `when` starts a when expression and `map` starts a map access; bare `when` or `map` is not a value expression, though each can name a binding |
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
An instance method declared with `move self` consumes the named receiver; a
later read requires the returned owner or a newly bound owner. The same rule
applies to a named value passed to a `move` parameter at any argument position.
An imported struct with only copyable fields remains copyable when stored in
an array or field. A struct that recursively owns storage transfers its owner
on storage; use the new owner or create a replacement before reading the old
name again.
An array `each` item is borrowed. Do not push a non-copyable item or one of its
owned fields into another owning container. Extract the owner with `take`, or
append new values directly into the destination through a mutable parameter.
Copyable fixed-storage items retain their independent value-copy behavior.
After moving an owned field, use only independent sibling fields until the
owner is repaired. A second access to the moved field or an overlapping parent
or child field is an ownership error diagnosed at the projected field path.
Binding a copyable fixed scalar array or a struct containing fixed storage
copies that storage into independent backing. This also applies to a field read through a borrowed
struct reference; the source keeps its lifetime and the new binding owns its
cleanup, including inside a control arm.
An array literal passed to a borrowed input is a call temporary. Its backing
lives through the call and is then released by the caller; an empty literal
still has temporary backing while its logical length remains zero.
For a single element that is a lexical name, write `[value,; ~]`. The comma
keeps the value distinct from the typed empty-array form `[T; ~]`; the same
rule applies inside interpolation. Let the declared element type provide
numeric context instead of adding a redundant scalar conversion.
Ordinary fixed array literals also allow a final comma, as in `[value,]`.
Use it consistently when formatting a multiline collection; it adds no element.

Apply the same receiver-first rule to inherent block methods. Keep `self` as the
dispatch receiver and infer generic callback roles from their declared explicit
inputs: `partitionPoint<T>: self, values: [T] -> Int block item: ref T -> Bool`
borrows each yielded `T` as `ref T`; it must not specialize `T` to the type of
`self`. Do not introduce a global helper or strip a wrong qualified owner to
make such a call compile.

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
When a dictionary declares a nominal struct value type, a nested
`{ field: value }` entry value is a contextual struct literal. Its names must
identify declared fields; initializer order does not change field layout or
ownership. Prefer the explicit `Type { ... }` form when the intended nominal
type would otherwise be unclear.
The same field-name and declared-type rules apply to an inferred struct key in
`dictionary[{ field: value }]`, including when the index appears in text
interpolation.
Field labels do not read same-named local bindings, including consumed owners.
Bare numeric values inherit the declared field type. Integer arithmetic passes
that context to its bare operands recursively; floating values and already typed
values retain their types. Integer-valued `if` and `when` initializers pass
field context to continuing arms' terminal numeric literals and nested
selections; subjects, conditions, and earlier statements keep their own types.
Array literal fields use their declared storage and element type. Validate
elements before fixed length or bounded capacity. Repeated array fields keep
the source repeat count as logical length and retain their declared storage;
a single repeated value node does not imply a one-element array. Convert an already typed
value explicitly when its type differs. Construction visibility is checked first,
then labels and duplicates, then required values in declaration order and extra
fields. Preserve the first owning diagnostic instead of adding a generic
initializer error. Index assignment, `put`, and `putIfAbsent` use the same record
context for mutable local owners and mutable parameters.

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
explicit and must leave one cleanup path. On an early-returning arm, a payload
from a fresh or consumed subject is cleaned there; a genuinely borrowed subject
is still released only by its outer owner.

A `Unit` payload carries no associated data to name. Match a success value
such as `Result<Unit, Error>.Ok` with `Ok { ... }`; keep the payload binding
for a variant carrying another type, such as `Err(error) { ... }`.

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
After a named branch, pass its completed product to the next flow target.
Transparent flow wrappers preserve that product's type and value; the branch's
original source remains the input to its arms.

Core values include `Unit`, `Bool`, signed/unsigned fixed-width and target-sized
integers, floating-point values, `CodePoint`, and UTF-8 `Text`. Let contextual numeric
literals adopt the declared field, argument, return, or arm type; redundant
constructors usually indicate lost type context. For a field literal outside
its declared integer range, preserve a specific literal-and-bounds diagnostic;
reserve a field-type mismatch for nonliteral values with incompatible types.
For `CodePoint`, distinguish a surrogate from a value outside the Unicode
scalar range, and report decimal literals without digit separators.

Write textual byte and scalar comparisons with single-quoted character literals
such as `'a'`, `'*'`, and `'\n'`, not unexplained ASCII numbers. A character
literal contains exactly one Unicode scalar or a supported escape and adopts
an integer context such as `UInt8` or `CodePoint`; otherwise it defaults to
`Int`. Explicit numeric conversions use its decoded scalar, including for
floating-point targets, and report the decimal scalar on range errors.
Ordinary quoted strings allow
`$name` and `$(expression)` interpolation. Parentheses in single-quoted
character literals inside a hole are values, so `"$(')')"` displays `41`.
Character escapes and scalar count follow the ordinary character rules; this
does not change the outer quoted-string lexical delimiters. Triple-quoted strings are raw and do
not interpolate. Use a raw string for literal source newlines; an ordinary
quoted string must close before `CR` or `LF`. For a multiline raw string
expression beginning with `LF` or `CRLF`, put the closing delimiter on its own
line after exactly the opening delimiter's UTF-16 column minus one spaces or
tabs. Give each nonblank content
line that exact space/tab prefix; the parser removes it and normalizes line
endings to `LF`. Whitespace-only lines become empty. Raw-string formatting
preserves trailing spaces and tabs on nonblank content lines; do not trim
literal suffixes while adjusting indentation. Empty raw-string lines stay
empty when indentation increases; reducing indentation counts leading Unicode
whitespace in UTF-16 characters. Inline raw content and raw native-library or
COM metadata retain their lexical content. Bare `$name` follows the same
identifier boundary as source names: a BMP letter or `_` starts it, and letters,
decimal digits, or `_`
continue it. A symbol or emoji after `$` stays literal; use `$(expression)`
when an interpolation needs more than a single name.
Formatter continuation keywords use that same BMP identifier boundary:
`and漢字` and `or가` are names and do not receive boolean continuation indentation.
If `$name` is unresolved, only bindings visible before that interpolation in
its lexical scope can suggest a shorter boundary. For example, with a visible
`user`, write `"$(user)Name"` when `"$userName"` should append literal text.
A later or out-of-scope `user` cannot resolve the shorthand. An unresolved
name inside `$(expression)` follows the ordinary unknown-binding rule.
A bare function name is not interpolated as a value: call a zero-input
function with `()` and use call or flow syntax for a function with an input.
A local function name is recognized only in its lexical function scope. A
visible binding with the same name is read as the binding.
Inside `$(expression)`, `receiver -> method` uses the same receiver-first
method lookup as an ordinary flow, including public methods on imported types.
The semantic analyzer resolves the target before LLVM emission; an unknown
target reports the target name's position within the interpolation expression.
An imported private method reports its qualified name and declaring module as
a visibility error.

Write numeric literal digits with ASCII `0` through `9`. Use underscores inside
long decimal literals only between digits. Leading,
trailing, consecutive, or underscore-only spellings are invalid; do not rely on
the backend to normalize malformed numeric text.

Keep binary wire values, compression lookup-table boundaries, lengths, and
state identifiers numeric even when a value happens to equal an ASCII code.

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

Generic element types preserve the declared storage shape. Use `mut [T; ~]`
for a caller-owned growable buffer; `mut [T]` remains a slice and is rejected.
The same admission rule applies to the primary and additional inputs. A bare
`mut T` defers the storage check until specialization.

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
On Windows, preserve UTF-8 path identity across path queries, owned-file
effects, directory snapshots, process file redirection, and mapped source or
byte files by validating the path and calling the UTF-16 native API. In
particular, `statusToFile`, configured file stdio, `mapText`, and mapped-byte
opens must not send raw UTF-8 bytes to an ANSI path API. Keep each operation's
length limit explicit; a passing basename case does not cover a Unicode parent
directory. The self-host native CLI must reject an ambiguous output path before
claiming staging files. It must claim both final output resource locks before
staging and release its own locks after publication or failure.
Validate final file paths and derived semantic-cache destinations against the
file publication contract before starting frontend or link work. An output path
that fits does not establish that its longer derived cache path also fits.

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
or direct instance calls on hot paths. For built-in types, `box` accepts `Int`,
`Bool`, and `Text`; other built-ins are not boxable in this slice. Eligible
declared structs and enums can be boxed; arrays, dictionaries, and `BitSet<N>`
cannot. Instantiated built-in `Option`, `Result`, and collection types are not
registered box types.
`box T` inputs infer their element type, and generic box returns preserve the
same eligibility rules after specialization. Construct a fresh owned box when
returning one; generic `move` inputs remain outside the current subset.
The same input contract applies to `Option<box T>` and `ref box T`; inference
does not turn an unboxed value into a heap owner.
Standard runtime identities such as `sys.path.Style` and
`sys.directory.kind.Kind` are also excluded. The current `dyn` subset accepts only
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

A user-block role borrows the producer's yielded storage. Read it through the
role; do not pass that role to a `move` input or bind it as a second owner.
Create a separate owner in the callback only when the algorithm requires one.
The same rule applies to additional roles and generic callback inference.

Runtime `each` completes as `Unit`, including at a function or branch tail.
Preserve its completed statement result when composing control flow; its array
source and callback operands keep their own types. Ordinary user-defined block
functions and collection comprehensions retain their declared value contracts.

The block signature, `yield` result, ownership, effects, and evaluation count
are part of the contract. Use local fusion or direct lowering where available;
do not introduce a heap closure or indirect call merely to imitate another
language's iterator API.

Local functions cannot be declared `public`.
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

Immutable names have no suffix. A local mutable owner introduced with
`=> name!` uses `!` at declaration and every access rooted in that local owner:

```sollang
[10, 20, 30] => values!
99 => values![1]
values! -> len => count
```

The `!` suffix belongs to a local mutable owner binding; it is not added to a
function input merely because that input has the `mut` ownership mode. Inside a
function or block function, write a parameter declared `name: mut Type` as bare
`name`, and write `mut self` as bare `self`. The caller supplies the writable
local owner, such as `values!`:

```sollang
partitionInPlace<T>: self, values: mut [T; ~] -> Int block item: ref T -> Bool {
    values -> exchange(0, 1)
    values -> len
}

algorithms -> partitionInPlace(values!) item {
    item > 0
} => boundary
```

Do not use assignment forms imported from other languages. Do not drop `!`
from an access rooted in a local mutable owner. Bind an owned container once; choose the producing branch
first, then bind its single result. Mutate its contents through instance methods
instead of replacing the complete owner through a second `=> owner!`.
This does not prohibit a single transfer into a new owner: matching a fresh
owned Result may use `Ok(payload) { payload => owner!; ... }`. Keep all later
mutable accesses as `owner!`; neither the transferred payload nor its consumed
subject remains usable. A borrowed match payload cannot become an owner this way.

## 8. Make ownership visible and zero-copy by default

Treat owners as affine:

- use `move` only when the callee or result takes the drop obligation;
- pass a named owner, a direct field of a current `move` input, or a fresh owner
  to every `move` parameter; first and additional arguments follow the same
  rule. Bind a nested owned field to a name before passing it;
- use `ref` for readonly borrowing and `mut` for mutable borrowing;
- treat equal-valued constant indices as one borrowed place: changing `0` to
  `00`, `0_0`, or `-0` cannot bypass a live element loan;
- extract a nested owned field only from an affine local or a `move` input;
  mutable extraction would require unsupported nested field assignment to
  restore the path. Borrow the field for a readonly call when ownership stays
  with the mutable owner;
- do not clone or heap-materialize merely to silence an ownership diagnostic;
- after moving a field, never assume the complete former owner remains live;
- bind an owned block-function result before returning or transferring it;
- use `take` only when extracting a value and leaving the container in its
  defined replacement state is the intended operation.

An ownership diagnostic should lead to one of four explicit designs: transfer,
borrow, mutate in place, or copy by deliberate policy. Hidden copies are not a
compatibility solution.

An enum constructor inside interpolation follows the same payload ownership
rules. After transferring a named payload, do not reuse it in a later argument,
operand, hole, or statement. A borrowed fixed payload remains available when
the constructor's fixed-storage copy rule applies.

`sys.process.arguments()` returns a copyable, process-lifetime `Arguments`
view. Pass or return that value directly and store it in a domain record when
needed; do not add `move` or materialize an owned array merely to forward it.
Its elements are borrowed `Text`. Windows managed and self-host support
ordinary and generic function forwarding, branch results, aggregate fields,
and local captures. Index `Arguments` with `UIntSize` also inside `$(...)`;
the indexed value is borrowed `Text`. See
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

For bounded text matching, compile the borrowed pattern once into an immutable
`std.text.glob.Pattern` or `std.text.regex.Pattern`, then call its instance
method. Keep work ceilings explicit. Regex search also receives its exact
caller-owned two-bank scratch array; do not replace that visible storage with a
hidden allocation, recursive backtracking, copied input, or ambient cache.

Instance syntax must not impose an abstraction tax. Keep receiver lowering
direct, caller-owned buffers visible, and hot paths allocation-free where the
contract permits it. Measure before replacing a proven fast path.

A concrete array storage type may own inherent behavior directly, including a
readonly view such as `impl [UInt8]`. Fixed, growable, and bounded owners may
borrow that view when their element type matches; exact storage-owner methods
win before the readonly-view candidate. Keep the declaring module in the
method identity, so equal method names in unrelated modules remain distinct.
This is direct static dispatch and must not create a wrapper, copy, or
allocation.

## 10. Keep storage and cost explicit

Choose the collection form that states the intended storage:

- `[T; N]`: fixed inline owner;
- `[T]`: readonly borrowed view;
- `[T; ~]`: growable heap owner;
- `[T; N~]`: empty growable heap owner with length zero and capacity `N`;
- `[T; <=N]`: bounded growable inline owner;
- `{K: V; N~}`: empty growable dictionary with a capacity hint; normalize
  bucket capacity in 64-bit arithmetic even though `N` is a nonnegative `Int32`;
- `{K: V; <=N}`: bounded inline dictionary.

Declare an owning array return such as `[Int; 1]` when returning runtime
array storage. Omitting the result type of `[value]` infers a borrowed `[Int]`
contract and cannot extend the local backing's lifetime. A readonly consumer
can accept the owned result through an explicit `[Int]` input; an omitted
input still distinguishes a declared fixed result from an ordinary literal.
Compile-time integer literal arrays may use immutable static backing in both
tail and explicit returns. Do not add hidden allocation to make a borrowed
return outlive its owner.

`Set<T>(N)` takes a positive `Int32` capacity hint. Normalize its bucket count
in 64-bit arithmetic to the next power of two at least `max(ceil(8 * N / 7), 16)`.
The `capacity` query checks whether that bucket count fits its public `Int`
result; a wide hint remains valid even when querying its capacity would trap.
Use `mut Set<T>`, `mut Deque<T>`, or `mut BinaryHeap<T>` when a function
borrows these concrete owners for mutation.

Set `insert` and `remove` return `Bool`, which can flow directly to a consumer
such as `println`. Keep the set owner mutable; the returned value reports the
membership change rather than carrying the set owner.

A fresh generic container constructor can be the final block or function
result. Bind the returned owner at the caller so cleanup has an owner. This
does not authorize moving an outer owner through a nested block result.

Size dictionary payloads from the canonical key/value entry stride, not the
owner descriptor size. Heap and inline placement use the same entry layout;
an `Int` key/value pair occupies 8 bytes.
Pass each field's alignment explicitly when calculating entry offsets: an
aggregate's byte size alone does not determine its alignment. Derive indexed
field addresses from the storage base, entries offset, entry stride and field
offset through the shared address calculation.

Read each collection's storage suffix independently. `{Int: [Int; <=4]}` has a
growable dictionary containing bounded array values. Adding `; <=8` inside the
dictionary's outer braces bounds the dictionary at 8; the value array keeps 4.

Dictionary `take(key)` transfers the removed value to a result binding. A
growable dictionary rebuilds its remaining entries at the same capacity and
releases the old backing; a bounded inline dictionary keeps its backing and
marks a tombstone. Preserve this storage distinction when sharing emission.

Bounded inline storage owns only the resources contained in its elements,
keys, or values. A record containing scalar bounded storage remains copyable;
fixed and growable array backing retains its own storage responsibility.

A growable array can own growable array elements: `[[Int; ~]; ~]` stores each
inner owner's pointer, length, and capacity. Transfer the inner owner into the
outer array; copying it from a readonly borrow is invalid. Destruction releases
the inner owners before the outer buffer. Do not infer support for every nested
fixed, bounded, or borrowed container form from this growable-owner contract.

Concrete `[T; N]` type lengths use decimal integers in `0..2147483647`;
`[T; <=N]` type capacities use decimal integers in `1..2147483647`. A zero
fixed length is valid; a zero bounded capacity, fractional token, or overflow
is rejected at the extent token before later brackets or bodies are parsed.
Fixed-array compile-time value parameters keep their generic contract.
Digit separators are valid in these numbers: `4_096` means `4096`. Empty-array
capacity hints and numeric repeat counts allow zero and must fit a nonnegative
`Int`. A hint is checked before `~`; a repeat count is checked after `]`, so a
missing closing bracket takes priority over an invalid repeat count.
Bounded dictionary type capacities and `BitSet<N>` sizes must be positive
integers fitting `Int`; zero, fractions, and overflow are diagnosed before the
closing type delimiter. Digit-separated positive sizes remain valid.

Borrow a fixed inline bit set with `flags: mut BitSet<N>`. Use the bare
parameter name inside the function; `!` belongs to mutable local bindings.
The borrow passes the original word storage by address, including additional
parameters and mutable struct fields. It does not copy or allocate bit storage.
Dictionary literal capacity hints allow zero; bounded literal capacities must be
positive and at least the number of initializer entries. Nested dictionary
entries are counted within their own literal. Invalid capacities are diagnosed
at their number before a missing closing brace can replace that diagnostic.
The final suffix belongs to its own literal. Nested dictionary values retain
their recursively inferred type and capacity; explicit key/value annotations
and contextual record types remain authoritative.

Literal, typed-empty, and repeated forms preserve that storage choice.

A bare `[]` has fixed length zero and defaults to `Int` elements when no
context supplies an element type. Preserve a contextual element type instead
of adding a type annotation to work around inference.

```sollang
[1, 2, 3] => fixed
[UInt8; ~] => growable!
[0; 64] => words!
{"one": 1, "two": 2} => lookup
{Text: Int; <=32} => boundedLookup!
{1: 10, 2: 20; <=3} => boundedEntries!
{Int: Int; 1: 10, 2: 20; <=3} => typedBoundedEntries!
```

For a populated bounded dictionary, place `; <=N` after the entries. `N` must
be positive and at least the number of initializer entries.
The bound is part of the type: `{Int: Int; <=2}` and `{Int: Int; <=3}` are
different types. A bounded dictionary carries its table inline through calls
and returns. Pass it readonly to inspect it; use `move` only when its type
recursively owns storage, such as an owned value inside an entry. A bounded
dictionary of scalar keys and `Text` values is not a valid `move` input.

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
An owned enum match can transfer a fixed-array payload to its pattern binding.
The binding releases its backing when its scope ends unless it transfers the
value onward; copyable scalar elements do not remove that responsibility.
Matching a borrowed subject preserves the original owner's responsibility.
Returning a copyable fixed payload from an arm creates independent result
backing. The original payload is still released by its owner; do not treat
the returned name alone as evidence of an ownership transfer.
An owning enum constructor that receives a named heap-backed fixed local
transfers the backing into its payload. Preserve that owner through the
returned enum rather than releasing the local backing at the arm boundary.
Heap fixed literals must also be released at entry and nested region exits.
Loop-condition reads of fixed struct fields borrow the existing backing;
they preserve the same element view for value and reference bases.
`?` extracts an owning fixed-array payload using the same backing descriptor.
After copying that payload into a struct initializer, release the original owner
and preserve the field's independent backing.
A struct or product initializer that copies a named fixed-storage value keeps
the source's cleanup responsibility. Do not equate heap backing with a move:
explicit move inputs and owning enum or collection payloads still transfer.
Direct named assignment to an existing owned fixed field transfers the backing
and releases its previous value. Clear the pattern owner's liveness flag after
the store on that path; a non-transferring path still releases the payload.
Apply the same transfer marker when an owning enum receives an owned fixed
pattern payload. Constructing that enum from a reference subject's pattern or
a readonly fixed input copies the backing and preserves the original owner
only when the payload is eligible for a fixed-storage value copy. Borrowed
fixed storage with owned, noncopyable elements cannot enter an owning enum
payload; reject it before LLVM emission. A match payload whose subject grants
ownership transfer keeps its existing transfer and cleanup authority.
An owned payload used as the subject of a nested match keeps that authority.
When the inner arm transfers it, discharge the outer payload's cleanup and
keep one cleanup responsibility on the new owner. A view borrowed from a
genuinely borrowed subject never acquires this authority through nesting.

Use indexing for a checked element place and keep mutation value-first.
Dictionary reads and writes remain explicit collection operations rather than
an ambient dynamic-object convention. Use `map read` and `map write` only for
memory-mapped file ownership with declared `File` effects, offsets, lengths,
and writable lifetime; they are not dictionary operations.
Supply a `Text` path; the path expression is type-checked before the map
producer is lowered, with a diagnostic at that expression.
Use `UInt64` values for `at` and `size`, and `UIntSize` for `for`; integer
literals receive that context directly.
Only `map write` accepts `size`; `map read` reports a parse error at that keyword.
Bind a `map write` result as a mutable owner, for example `=> data!`.
A call result typed `MutableMappedBytes` has the same binding requirement.
Functions returning `MappedBytes` or `MutableMappedBytes` pass the mapped
aggregate to the caller; keep the mutable owner binding on the receiving side.
Interpolating a mapped index, such as `"byte=$(data[0])"`, reads a `UInt8`
after checking that the index is inside the mapped length. Use `UIntSize`
for a non-literal mapped index, including one inside interpolation.
Compiler implementations prepare interpolation syntax identity once per source
in the semantic snapshot. Ownership checks and LLVM context preparation use
those prepared nodes and source ranges without reparsing the source string.
Fold interleaved field and index suffixes from left to right inside
`$(expression)`, as in ordinary expressions. Each suffix uses the preceding
value as its receiver; an index keeps its subscript as a separate operand.
Keep source operand identity structural when parentheses surround a field or
index receiver. Its byte start may differ from the outer expression's start;
ownership and type propagation must use the same receiver subtree.
Mapped byte, array, and dictionary interpolation index type mismatches are
inferred by the semantic interpolation analyzer; LLVM consumes its diagnostic
result. Signed numeric unary interpolation operands are checked there too.
For a known collection owner, nested unary `-` retains its signed index type,
while a valid `not` result is Bool and fails an `Int` index requirement. Commit
that owner-first decision in pre-IR facts before Typed IR or LLVM.
After a valid index, record a non-owned aggregate element's semantic type in
pre-IR too, so a following field access reads that result instead of asking
LLVM to rediscover the indexed type.
Pass a recorded indexed result type into the LLVM context and consume it when
emitting the interpolation value.
For every supported indexed interpolation, semantic inference determines the
result type after resolving the owner and index. LLVM uses that type for value
emission and uses the owner type only to select its storage layout and read.
For a resolved struct field in interpolation, semantic inference also records
the field result type. LLVM consumes that type while resolving the field's
storage position for emission.
For an explicit nominal struct literal used as a field receiver, retain its
type name, field labels, and initializer values as separate interpolation IR
nodes. Resolve the declared struct type and check its initializers before
inferring the field access; emit the constructed value before extraction.
Parse an interpolation fragment with the surrounding namespace and imports.
Carry the whole qualified constructor path, resolve its import alias to the
declaring module, and keep a transparent parenthesized constructor wrapper
out of the member-access IR. This preserves the constructor as the receiver
of a following field access.
For a complete module path without an alias, match the exact module path in
the source closure before selecting the declared nominal type. A path node
inside that constructor is part of the type name, not a member read.
Match the ordinary nominal constructor's diagnostic order: duplicate names,
then each initializer's field existence and value type in source order, then
missing required fields. Keep contextual dictionary-literal diagnostics on
their own existing path.
Validate explicit nominal initializer values after their interpolation
expressions have inferred types. A computed value must pass the field type
check before LLVM inserts it into the struct; retain the existing early
duplicate-name and unknown-type checks.
For a nominal value or floating literal used as the complete interpolation
expression, determine its display eligibility from semantic type facts before
Typed IR. Validate the nominal initializer first; its field error takes
precedence over the outer display-type error.
For a unary expression with a known semantic result type, validate the unary
operand before checking the result's display eligibility. Carry the unary
result type into the pre-IR display decision, including a floating result.
For a direct binary interpolation whose operand types are already known, use
semantic numeric, comparison, and logical decisions to determine the result
type before Typed IR. Check invalid operands first, then the result's display
eligibility; leave unresolved operand shapes to later semantic inference.
For a direct numeric conversion interpolation, validate its argument count,
known operand type, CodePoint restriction, and literal range before carrying
the target type into the pre-IR display decision. Keep unresolved operands
undecided for later semantic inference.
Compose nested binary results from their typed children before the outer
display check. An invalid inner operator remains the first error; do not
replace it with the outer expression's display error.
Resolve nested numeric conversions and binary expressions in child-before-parent
order, including either expression kind inside the other. Carry only validated
child types into the outer pre-IR display decision; leave invalid or unresolved
children undecided and report their own error first.
Apply the same dependency order to unary `-` and `not` around conversions or
binary expressions. Validate the child and the unary operand rule before
publishing the unary result type or checking its display eligibility.
When several interpolation nodes contain errors, follow operand evaluation
order: report a blocking descendant before its enclosing operator, and keep
the earlier sibling ahead of a later sibling.
An unresolved explicit nominal type needs a semantic diagnostic at the type
name; never emit an LLVM struct value with an unresolved type.
Reconstruct interpolation call suffixes from all direct parent/span relations
before assigning operand slots. Each stage owns only its explicit arguments and
consumes the preceding result; preserve ordinary nested calls as argument values.
For a nested field, indexed path, or call result such as
`$(outer.inner.value)`, `$(rows[1].values[0])`, or `$(makePoint().x)`, resolve
each receiver before its member or index use and before Typed IR. An instance
call on an indexed receiver also uses the semantic element type after inferred
bindings and field projections resolve. Select its exact inherent method and
parameter types during semantic analysis; do not select a same-named method
from the receiver's spelling or defer this decision to Typed IR. An instance
method result such as `$((maker -> make).x)` contributes its declared return
type only after the method is visible and its additional argument count is
valid. An indexed field of that result, such as
`$((maker -> make).values[0])`, resolves its element type after the method
result and field types; apply the ordinary index type and ownership rules.
An invalid index reports its index error before checking the outer expression's
display type, even when that field's valid element type would not display.
Propagate a field type to the next access only when that field is
accessible. Check the outer result's display type after the path resolves; a
private intermediate field keeps its field-access diagnostic.
When a path contains `?`, validate the Result operand, enclosing function's
Result error type, and ownership before checking the propagated payload's
field or the outer display type. Infer a computed operand before validating
`?`: valid arithmetic, comparison, logical, unary and conversion expressions
reuse the semantic composed-type decisions before Typed IR. An invalid operand
keeps its ordinary operator or conversion diagnostic; it must not be replaced
by a Result propagation error. An invalid `?` reports its propagation error.
The semantic type of `$(value -> len)` depends on the receiver: arrays,
slices, dictionaries, and bit sets return `Int`; `Text`, `SourceText`,
`Arguments`, and mapped bytes return
`UIntSize`. LLVM uses that result when choosing signed output.
`capacity` follows the same semantic rule: arrays and dictionaries yield `Int`,
while `Arena` yields `UIntSize`. LLVM may use a wider storage field but must
format the expression using its semantic signedness.
An `Int` capacity query must check the wider backing value before narrowing;
an unrepresentable capacity traps rather than wrapping to zero or a negative
number. Keep valid source capacity hints independent of this result check.
The semantic diagnostic for an interpolation expression uses a position inside
that parsed expression. A `main` error names `<main>`; a named function error
names its module. For these semantic failures, the CLI relays the diagnostic
without the LLVM worker note. Compiler diagnostic streams use UTF-8 without a
byte-order mark on Windows as well as other targets; decode captured stderr
strictly before comparing C# and self-hosted results.
When a nominal constructor result is followed by a missing field, report the
member access position and the field name alone. The constructor's qualified
type path, a transparent parenthesized wrapper, and trivia around the member
access do not belong to that name. Carry the parsed dot and identifier token
spans into interpolation IR; diagnostics consume those spans instead of scanning
the source text again. Keep the dot offset separate from the expression's
diagnostic offset so other member errors retain their existing locations.
For a plain identifier-only dotted path, a missing-member diagnostic uses the
first identifier span. After a call, index, `!`, or parenthesized expression,
postfix member access uses the parsed dot span; do not reuse the path start.
Use the same identifier span when resolving a readonly computed member; trivia
after the dot is not part of its lookup name.
Enum variant lookup follows the same token rule. Once a variant resolves, the
interpolation display check still rejects an enum value.
An uninvoked zero-input associated function also uses the parsed identifier
for lookup and renders `Owner.member()` in its diagnostic, without source trivia.
`Size` is signed, so `-Size(9)` is valid inside interpolation. Nested
conversions used by unary or binary expressions retain their target width in
entry and function bodies.
Interpolation index source eligibility is also checked before LLVM emission;
unsupported collection owners receive the same semantic boundary as ordinary
index expressions.
Interpolation displays `Text`, `Bool`, and integer values. The semantic
analyzer rejects a known incompatible result type before LLVM emission.
`Text == Text` and `Text != Text` inside interpolation compare contents in
entry code, function arguments, and nested control blocks.
Floating-point comparisons inside interpolation use the operand's width and
produce `Bool` in those same contexts. Emit a bare integer-shaped operand as
a floating LLVM constant when semantic inference gives it floating context;
an integer token in a `float` or `double` LLVM operation is invalid.
For a valid numeric binary expression, report `S001` only when the other
operand already supplies the type of an explicit literal conversion. With two
explicit conversions, keep the left one as the type anchor and report the
right one. A contextual bare literal is not an independent type anchor.
For a numeric call parameter, write a bare literal when the parameter already
supplies its type, including in both value branches of an `if`; the matching
explicit literal conversion receives `S001`. A conversion to a different
numeric type is an argument type error. The literal must fit the declared
integer width in ordinary and instance calls; character literals use their
decoded scalar, and `-0` fits an unsigned parameter.
Preserve the interpolation fragment's own line and column in that warning.
An `each` role is checked using its iterable's element type, including inside
`$name`; a nominal element without supported display behavior is rejected.
Numeric conversions inside `$(expression)` accept numeric targets and operands,
including `Float`/`Float32` and `Float64`/`Double`; `Bool(value)` is not a numeric
conversion. A direct numeric literal takes the floating destination precision;
an already computed operand keeps its committed rounding before conversion.
Apply the same rule to decimal, exponent, and negated literals inside and
outside interpolation. Convert a floating-point intermediate to a supported integer
display type when interpolating it. Floating `+`, `-`, `*`, and `/` retain their
operand type; `%` requires integers. A `Float32` result converted to `Int` still
requires a numeric conversion despite both values having 32-bit storage.
`CodePoint` conversion requires an integer
Unicode scalar, not a floating-point operand.
For `Text` or `SourceText`, computed arguments to `byte(index)` and
`slice(start, length)` must be `UIntSize`; integer literals use the argument's
expected type. Nested conversions such as `slice(UIntSize(1), UIntSize(2))`
retain separate one-argument calls inside interpolation. `byte` accepts one
argument and `slice` accepts two; wrong arity is diagnosed before argument types.
An integer-shaped literal passed to a floating-point conversion is parsed as
`Float64` before any `Float32` narrowing; it does not pass through default `Int`.
An integer conversion rejects a literal with a decimal point or exponent as
`not an integer`, before range checks; convert a floating result explicitly.
For a computed integer value, conversion checks the destination range before
changing width or signedness. A direct integer literal is checked at the
destination width; a computed same-width conversion keeps the original value
 after its checks. `CodePoint` also rejects Unicode surrogates.
When multiple interpolation fragments fail semantic checks, report the first
failure in source order before evaluating later fragments.
For dictionary `put` and `putIfAbsent`, supply exactly one key and one value
matching the declared `Dictionary<K, V>` types. A same-named user method is
resolved as that method, not as a dictionary operation.

Do not silently spill inline storage to the heap. Reserve once when a safe size
is known. Pass readonly tables by `ref` instead of cloning them. Use caller-owned
output buffers for streaming and native-style APIs when that makes allocation,
capacity, and transfer visible.

Keep interpolation deferred for immediate sinks. Before storing it in an
array, record, or collection, materialize it explicitly; the resulting `Text`
borrows its arena and must not outlive that owner:

```sollang
7 => value
Arena(64) => storage!
"value=$value" -> materialize(storage!) => text
["prefix", text] => fields
```

For constant text containing quotes or backslashes, prefer a raw literal over
interpolation that would introduce an unnecessary materialization boundary.

## 11. Express control flow in SLG rhythm

In expression position, `true` and `false` are boolean literals. They are
classified before a call or ordinary name, so `true()` and `false()` are not
calls. A binding target after `=>` may still use either spelling.

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

Range bounds may be names, member reads, or calls without extra grouping:
`lower()..upper()` is a numeric condition, not an enum pattern. Evaluate the
subject once; for each reached range arm, evaluate the lower bound and then
the upper bound once, even when the lower comparison is false. Read borrowed
scalar subjects and bounds as values while retaining their reference ABI.

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
a formatting preference. Do not introduce a prefix-style `elsif condition`
after a flow-style `condition -> if`; that reverses the reading direction
inside one decision. Keep a binary choice as `if { ... } else { ... }`, and
write three or more ordered conditions as one full-condition `when`.

Use inclusive `..` and half-open `..<` ranges deliberately. Use `while` for a
state-driven loop, `fold` for one accumulated value, and `each` for direct
range or stream consumption. `break` and `continue` may be unconditional or
guarded with `condition -> if break` / `condition -> if continue`. `return`
belongs only in a declared function and may carry its value on the left. Avoid
encoding a fold as mutable state when the accumulator is the actual result.
The complete `Int` endpoint domain is valid: a half-open range ending at the
minimum is empty, and an inclusive range ending at the maximum terminates
after that element. Do not add a wider user-level bound or a sentinel element
to work around an internal loop cursor.

A fold may declare both body roles (`fold initial accName, itemName { ... }`)
or omit the pair to use `acc` and `it`. Role names come from that fold header;
commas inside initial expressions or body expressions do not declare roles.
Keep both roles scoped to their own fold, including nested folds and string
interpolation.

Integer ranges, fixed or growable integer arrays, and readonly `[Int]` views
are valid fold inputs. Empty inputs return the initial accumulator; borrow a
named array directly through a readonly parameter instead of cloning it.
Use a named `Range`, a `Range` parameter, or a function returning `Range`
directly. The source is evaluated once; do not rewrite it as literal endpoints
or mutable loop state to work around input classification.
Readonly range and integer-array references are valid fold sources, and a
readonly `Range` reference can flow directly to `each`. Keep the borrow intact
instead of cloning its storage or adding a conversion to obtain its value.

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

Calling `sys.process.exit` requires `Process`, even on an error branch.
Compiler helpers must expose that requirement in their signatures and callers.

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

`sys.path.nativeStyle()` is a pure, zero-argument target constant. Use it in
ordinary functions when constructing a native Path; it does not require
`uses File`. Filesystem queries and absolute-path resolution retain their
explicit `File` capability and target restrictions.

For exact standard-error text, use `sys.runtime.eprint(Text)` under
`uses Console`; it adds no newline. Use `eprintln` only when the platform line
ending is part of the intended output. Do not append or remove a line ending
implicitly while relaying compiler diagnostics.

For an exclusive filesystem claim, use `sys.file.createExclusive` and release
it with `sys.file.removePath`, both under `uses File`. Their `Int` status
distinguishes success, expected contention or absence, and other failure;
do not treat a failed close after creation as proof that no path exists. These
are native file capabilities, not browser filesystem fallbacks. The exact
status and path contract lives in [the file section of the specification](SPEC.md).

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
routed.warnings -> each warning { warning -> writeWarning }
routed.normal -> each event { event -> process }
```

Register every route before expecting output. The final registration starts the
shared dispatch; initialize captured storage before that registration. Effects
between registrations run before the source is consumed.

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

`merge` and `latest` return `EventStream`, including joins of cold `Stream`
inputs. `concat` and `zip` return `EventStream` when any input is hot, and
otherwise return `Stream`. Keep these wrapper types across function boundaries.

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

An affine `SourceText` may be a direct payload of the top-level `Result` returned
by `tryParallel` when the callback moves its complete representation into the
joined result. Keep the structured join as the ownership boundary: unselected
results are destroyed exactly once according to whether their storage is
borrowed, heap-backed, or mapped. Do not place it in a plain `parallel` result or
inside an array, `Option`, or nested `Result` until recursive worker cleanup for
that carrier is implemented.

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
ownership error; the original name is no longer available after consumption.
The self-host semantic ownership pass classifies a named read after the move
as an unknown binding before LLVM output, using the same canonical move and
reachability analysis as other affine values. The diagnostic points to the
later read in its source module. An unnamed producer reuse keeps
its separate ownership diagnostic.
Persistent stage state uses the explicit `state` binding and
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
children. Keep restored frame reads after their await or yield boundary, even
when the binding is immutable or supplies an aggregate field receiver. An alias
readiness shortcut must preserve that continuation ordering.
`yield` cooperatively returns to the ready queue without granting an
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

Current self-host support is intentionally narrower than the managed contract.
The canonical `Duration.sleep`/`await` path owns a real affine Task and scheduler
timer queue; it is not a synchronous compatibility lowering. Ordinary async
functions preserve primary and additional inputs in one aligned typed Task
context, including an affine input on the verified normal-completion path.
Standalone Windows and Linux native modules emit their own complete scheduler
when no stdlib runtime module is present. Prefer binding a Task owner and then
awaiting it when ownership or overlap should be explicit. Direct chained await
with an affine additional input, captures, cancellation before first execution,
multiple suspension states, typed spill/resume, fallible completion, and full
cancellation ownership remain unsupported until their focused fixtures and
required platform gates pass.

For structured logging, let `std.log.Logger.record` filter before constructing
fields. Match the returned `Option<Record>`; only the `Some` branch should
build caller-owned fields and call an explicitly chosen concrete
`std.log.Sink`. Keep formatting, buffering, and destination effects in that
sink, and propagate its typed `std.log.Error`. Do not add an ambient logger,
default sink, hidden fallback, or a generic forwarding wrapper that obscures
the concrete sink ABI.

## 17. Design stdlib surfaces as contracts

For URI normalization, parse once and call `Reference.normalizeBytes` with an
explicit `NormalizationPolicy` and byte ceiling. Resolve a child through the
base reference's `resolveBytes` method. Keep the returned byte array owned;
borrow a text view only while that owner remains live. Parser validation does
not authorize DNS, IDNA, default-port rewriting, or filesystem canonicalization.

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

For nonblocking child observation, call `child! -> tryWaitTermination` when the
termination domain matters. Treat `Exited(ExitStatus)` and
`Signaled(SignalStatus)` as terminal values and reserve `Err` for a failed host
poll. The older `tryWait` spelling may project a signal to `Err("signal")` for
compatibility, but it must delegate to the same single poll/reap authority and
must not discard an exact signal number before typed callers can observe it.

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

Build test infrastructure before capturing a pinned compiler's verification
inputs. Execute the already-built test DLL, or use `dotnet run --no-build`;
plain `dotnet run --project` can rebuild compiler project references and change
the selected producer. Recheck compiler, runtime, grammar, and source hashes
after execution. A changed producer starts a new verification epoch; never
combine cases from different compiler hashes into one current proof.

For UTF-8 grammar inputs, keep mapped `SourceText` owners alive and use the
shared `source_decoding.utf8Text` borrowed view before parsing or hashing.
Grammar source hashing normalizes the line endings specified in `SPEC.md`;
it does not widen the line parser's separators. Preserve vertical tab and
other payload bytes. Reuse `scripts/verify-native-grammar-build.ps1` and its
frozen source normalization contract with a fresh owned output directory.

Language-server positions count UTF-16 units over logical `CR`, `LF`, and
`CRLF` lines. Keep an original CRLF pair inside a formatting replacement
instead of preserving its LF as a suffix. Verify both the reported range and
the result of applying the edit to the original text; matching response shapes
alone does not prove a valid edit.
For language-server syntax messages, reuse `diagnostics.formatForFile` with
an empty path. Keep the zero-based range separate from the shared message.
Do not reconstruct selected diagnostic codes in another CLI-specific branch:
raw strings, committed syntax errors, and supplementary invalid characters
must retain the same reason as the canonical lexer/parser and CLI formatter.

Semantic contract diagnostics retain the canonical invocation AST, source span,
and active module. Generic rejection uses the actual call site. Await IR points
at its input, so resolve its invocation through the shared flow-target index
before formatting. Task contract errors use the common semantic prefix so the
CLI can relay and remove diagnostic-only stages without broadening its handling
of unknown failures.

Expanded numeric elements retain their selector source span and indexed computed
value separately. Bounds checks consume the computed value. Preserve the owning
range or `each` diagnostic position during expansion; diagnostics must not recover
that position by scanning selector text or treat its spelling as a numeric literal.

For the direct `EmitContext` invariant fixtures, run
`python scripts/generate-context-fixture-suite.py --check` before compilation.
It verifies the source import closure and every qualified struct initializer,
including nested diagnostic and generic-body records, against current source
declarations. Preserve each original case body and expected output when adding
required fields. Use `scripts/run-context-fixture-pairs.ps1 -Check` to validate
the current managed suite proof, compiler hashes, source count, and native build
inputs, then its planned four-case suite execution. Its declared build limit
belongs to this compiler-source workload; the small-fixture runner's limit does
not establish a compiler failure for these fixtures.

For a private fixture, use `python scripts/verify-context-fixture-initializers.py
<fixture> --source-manifest <repository-owned manifest>` to check the same
initializer rules. The manifest must include the fixture and its declaration
sources. Declare its compiler-source build budget before execution and keep it
separate from the small-fixture batch; preserve any earlier timeout as an
incomplete result.

1. authoritative format and source-style notes (`N001`/`N002`) through
   `scripts/format-authoritative-slg.ps1 -Check -Source <changed-files>` for a
   focused change (omit `-Source` for the final full source inventory); do not substitute an ad-hoc
   Debug/Release compiler invocation whose formatter binary may differ from the
   repository gate;
2. smallest parse and semantic fixture;
3. ownership/effect diagnostic and actionable repair fixture;
4. managed exact compile/run;
5. self-host differential for the affected feature;
6. LLVM direct-call closure and structural assertions;
7. `llvm-as`, link, exact native execution, and exact expected warnings/notes
   (zero for compiler-owned source without deliberate diagnostic fixtures);
8. same-input performance and allocation comparison for a hot path;
9. Stage2/Stage3 fixed point only when compiler-owned source changed or the
   focused evidence exposes a compiler defect;
10. affected Windows, Linux, and browser target closure.

For an LLVM emission or call ABI repair, verify the C# behavior and compare the
sources first. Then execute a checked production SLG emitter fixture with the
managed compiler before rebuilding the native self-host compiler. Pass the
current assembly, link, and execution record through
`scripts/build-focused-selfhost-compiler.ps1 -SlgEmissionProofRecord`.
The build validates its canonical source manifest, executed LLVM hash, and
every pinned input before allocating build output. Native paired verification
still follows the successful build; an emitter fixture does not replace it.
Diagnostic rejection fixtures must call the checked semantic entrypoint, such
as `emitChecked`, and compare its diagnostic and returned failure count. Raw
`emit` output alone does not establish semantic acceptance or rejection.

A generated checked package must preserve its validated standard-library source
prefix. Use `emitCheckedFilesWithStandardLibrarySources` for the file-loading
path or `emitCheckedWithPaths` for borrowed source views, supplying the exact
validated prefix count. `emitCheckedFiles` remains a user-only entrypoint with
zero standard-library authority. Never infer authority from a `sys` namespace
or extend the prefix to include the user program.

Managed/self-host differential output is the last observation, not the first
place to define semantics. When both compilers implement the same expression
family differently, keep a schema-validated mapping from managed syntax types
to self-host AST kinds and make entry and ordinary self-host lowering consume
shared base, contextual, and control-shape materialization policies. Pre-IR
semantic facts decide nested unary result types from the already decided
operand, before Typed IR or LLVM emission chooses an instruction. Inventory
extraction must stop at each declaration boundary so a non-expression helper
record cannot replace a real expression subtype while preserving the same
count. Syntax shape decides that a value node exists; provisional type readiness
only fills its type. Add a pre-LLVM coverage invariant so a missing value
producer fails before a costly native or Stage run. When grammar lowering keeps
consecutive binary wrappers with identical source spans, select the deepest
canonical binary descendant for that owner; never require a Typed IR node for
a transparent wrapper or treat a genuine smaller nested binary expression as
that wrapper. A comparison grammar envelope must not claim angles inside an
exact `TypeAnnotation` span or the balanced outer `<...>` clause of a nested
type application, but it must preserve real comparison operators inside the
following call arguments. After excluding only those generic delimiters, omit
an envelope that owns no comparison operator instead of carrying a numeric
binary kind into Typed IR policy.

Syntax-owned value producers need the same early coverage even when they are not
resolved calls. For memory mapping, preserve one kind-49 AST to kind-9 Typed IR
producer with its read/write opcode, exact mapped builtin type, path operand,
and only the present `at`/`for`/`size` operands in grammar order. Validate the
clause bitmask and exact binding edge before LLVM; never let the path `Text`
child stand in for a missing mapped owner. Keep mapped `flush` on runtime alias
`-114` only when its receiver is `MutableMappedBytes`, after lexical resolution
has had the opportunity to select a user function named `flush`.

Do not duplicate value materialization by emission context. In particular, a
sequential named branch inside `when` has the same `call -> arm value -> labeled
product` contract as the same branch in entry or an ordinary function. Route
all three through the shared branch materializer and keep a nested-control
fixture in the focused differential set. Parallel branch arms belong to their
compute callback path; a broad kind-39 workaround must not emit them as
sequential values. The kind-38 runtime materialization itself must likewise
use one shared helper in entry, ordinary-function, and nested-control paths;
do not copy the capture environment and compute-group sequence per context.
Apply the same rule to range values: kind-31 inclusive/exclusive normalization
and product construction belong to one shared materializer used by all three
emission contexts.

Nested control-region streams must delegate terminal and callback emission to
the same scheduled stream body used by entry and ordinary functions. Keep the
source in the enclosing region, suppress already-fused stage calls from outer
region emission, and allocate mutable function slots only once. A callback body
must never be emitted linearly in the outer function or repaired later from
malformed LLVM.

For a blockless stream `take` or `skip`, classify the synthetic nested flow
node by its AST parent and retain the stream-stage opcode in both entry and
ordinary-function Typed IR. Keep the same-named array or dictionary `take` on
the writable-owner collection path. Verify both boundaries with a stream
execution fixture and a readonly collection diagnostic.

For terminal `each`, preserve the terminal binder's role identity. A role use
whose Typed IR type is deferred still receives an SSA definition from the
current staged stream value with that value's LLVM type. Do not reject it by
comparing an unresolved type symbol to a concrete stage type, or hide a
known distinct type symbol behind a fallback. Verify the terminal body with
`llvm-as`, SSA-closure checking, and exact execution.

Diagnostic lowering and production lowering are separate observations. A
`typed-ir-nodes` result alone does not prove function-parallel production
identity because checked native builds enable the compute-pool lowering mode
and emitter invariants. Use the paired `typed-ir-nodes` and
`typed-ir-nodes-parallel` commands on the same ordered sources and require
exact node-inventory equality before attributing a failure to parallel result
generation or merge.

Finish integrating compiler and fixture changes before starting full suites.
Run the full Windows managed reference suite through
`scripts/verify-managed-reference.ps1` with an empty output directory under
`artifacts/`. This wrapper preserves live logs and requires unchanged compiler,
runner, source, expectation, and tool inputs before publishing success. An
interrupted run is partial evidence; changed inputs require fresh verification.

For a focused comparison of user-program behavior, invoke the verified current
C# and SLG compiler binaries on the same program inputs. Reuse the existing
checked-emission producer for its declared source-proof purpose; compiling the
entire compiler library with the SLG compiler is a separate self-compilation
verification and is not required for every program comparison. Preserve that
requirement when self-compilation itself is the requested verification.

Managed focused positive cases require an empty build diagnostic stream before
execution. Negative cases declare `expectedBuildExit: 1` in their input contract;
the verifier pins that contract in `inputHashes` so artifact cleanup can verify
the expected rejection independently of the result row. Missing negative exit
metadata is rejected before compilation.

Fixtures that load additional files at runtime declare those paths, one per
line, in `expected/<fixture>.runtime-inputs.txt`. These dependencies are pinned
before execution without being added to the compiler's source arguments.
Missing runtime inputs must fail before compilation. When exact stdout differs,
preserve both complete outputs as files and report the first difference with
bounded context instead of printing entire LLVM modules to the console.

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

Use explicit `--jobs <positive Int>` when a compiler build needs bounded
workers. The C# Windows linker retains small LLVM partitions while limiting
concurrent optimization processes. Record the selected worker count with the
build inputs; keep the program, optimization level, and verification timeout
fixed when comparing behavior. `build-focused-selfhost-compiler.ps1 -Jobs`
forwards the same explicit setting to both C# and SLG seeds.

For a long-running focused step, use the common `VerificationExecution` runner
with an explicit `SlowStepDiagnostics` plan. Set the stage, soft time limit,
unchanged hard timeout, sampling interval, and sample budget before launching.
Choose the soft limit from an observed comparable run or an explicitly declared
stage budget; do not present an unmeasured budget as a performance baseline.
The focused numeric runner accepts `--diagnostics-plan` with
`scripts/contracts/focused-step-diagnostics-plan.json`. Its 30-second soft limit
is a declared investigation budget, not a measured baseline; its 180-second
hard timeout preserves that runner's existing contract. It is not the plan for
a native fixture whose declared timeout is 1,200 seconds. Reject a plan whose
hard timeout differs from the actual runner before starting a child.
Preserve the first and latest observations, elapsed time, log-size changes,
owned process identities, measured CPU scope, sampling gaps, and dropped samples
in the durable diagnostic record. Missing CPU remains unknown. A slow step with
CPU or log activity differs from a quiet observation; neither proves a root
cause. Use the recorded stage and input identity to select a small source
comparison or focused reproduction. Never automatically repeat the whole build,
start profiling, relax its timeout, or treat a diagnostic as compiler acceptance.
Diagnostics are opt-in: the focused numeric runner activates them only when
`--diagnostics-plan` is supplied. Pass that same explicit plan on each authorized
follow-up invocation; a previous result does not enable future sampling.
For any long step using this common runner with an explicit plan, crossing the
soft limit automatically sets `investigation.required` in its durable result.
`investigation` records candidate-only CPU activity, output
activity, a measured quiet interval, or insufficient evidence, with the exact
CPU scope, process identities, interval and log deltas. Retained samples preserve
their own candidate classifications even when a final observation changes scope.
CPU absence, scope changes, counter resets and sampling gaps never establish
that a process stopped or that unchanged output means deadlock. Read `nextSteps`
to inspect existing logs, process measurements and stage source first.
CPU scope identity and observation errors (`cpuIdentity`,
`cpuObservationFailure`) belong to the enclosing execution JSON process row;
the standalone diagnostic JSON contains the samples and investigation routes.
A proposed wait investigation is plan-only and requires a separate explicit execution
budget; the record itself authorizes no retry, profiling or timeout extension.
Timeout and cancellation must terminate the owned process group and preserve
logs and failed output. Parent exit alone does not prove descendant shutdown.

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
| scalar and text values | numeric and character-literal context, `Bool`, `Unit`, `CodePoint`, UTF-8 `Text`, interpolation |
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
