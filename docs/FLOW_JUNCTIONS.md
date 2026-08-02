# Flow Junctions: Branching And Joining
Status: implemented and verified across Windows, Linux, browser, Stage 2, and Stage 3
Updated: 2026-08-02

## Purpose

Sollang reads from left to right. A flow may nevertheless change topology:
one value can feed several computations, several values can become one value,
and streams can split or meet under different ordering policies. These shapes
must preserve the meaning of `->` instead of inventing competing arrows.

This design therefore keeps the existing roles:

- `->` moves, applies, or transforms a value;
- `=>` defines, binds, or resolves a destination; and
- readable flow operators describe the topology and its policy.

No operator in this document may hide ownership, effects, evaluation order,
buffering, backpressure, nondeterminism, or materialization cost.

## Accepted Surface

### Broadcast one value into named branches

`branch` sends the same input to every arm and produces a labeled product in
source order:

```sollang
order
-> branch {
    priced:  -> price
    checked: -> validate
}
-> reconcile
-> persist
```

The result can be bound and inspected:

```sollang
order
-> branch {
    priced:  -> price
    checked: -> validate
}
=> examined

examined.priced -> printPrice
examined.checked -> printCheck
```

An arm may contain a longer left-to-right flow:

```sollang
document
-> branch {
    tokens:   -> tokenize -> normalizeTokens
    metadata: -> inspectMetadata
    checksum: -> checksum
}
-> assembleDocument
```

The result type is a labeled product, not an implicitly expanded argument list.
Its proposed type notation is:

```sollang
reconcile parts: (priced: Price, checked: Check) -> Decision {
    ...
}
```

Unlabeled products remain ordinary tuple values:

```sollang
(price, discount, tax)
-> calculateTotal
=> total

calculateTotal parts: (Money, Money, Money) -> Money {
    ...
}
```

### Route each stream item into one branch

`partition` is distinct from `branch`. `branch` sends an input to every arm;
`partition` sends each stream item to exactly one arm:

```sollang
events
-> partition event {
    errors: when event -> isError
    warnings: when event -> isWarning
    normal: else
}
=> routed

routed.errors -> writeErrorLog
routed.warnings -> writeWarningLog
routed.normal -> process
```

Arms are tested from top to bottom. The first matching arm receives the item.
Exactly one `else` arm is required, must be last, and makes routing exhaustive.
Overlapping predicates are therefore deterministic rather than multicast.

### Keep the original value after a side operation

`tap` performs an explicitly effectful side operation and returns the original
value unchanged:

```sollang
order
-> tap audit
-> persist
```

The block form supports a longer side flow:

```sollang
order
-> tap {
    -> summarize
    -> writeAudit
}
-> persist
```

`tap` is not a borrowing loophole. Its callable receives the input according to
the ordinary parameter mode, and the original value remains available only
when that mode permits it.

## Joining Values And Streams

Several ordinary values first become one explicit tuple or labeled product.
There is no general `join` keyword that silently expands values into function
arguments.

Streams require a named policy because their timing and termination differ:

```sollang
(left, right) -> zip
(left, right) -> merge
(left, right) -> concat
(sensor, threshold) -> latest
```

The policies are normative:

| Operator | Output rule | Ordering | Completion |
| --- | --- | --- | --- |
| `zip` | one tuple from the next item of every input | input tuple order | when any input can no longer form a tuple |
| `merge` | the next item available from any input | arrival order; may be nondeterministic | after every input completes |
| `concat` | all items from each input in tuple order | deterministic | after the last input completes |
| `latest` | one tuple after every input has a value, then on each update | arrival-triggered; may be nondeterministic | after no input can update the tuple |

`zip`, `merge`, `concat`, and `latest` operate lazily. They do not materialize
their input streams. Their implementations must specify bounded buffering and
propagate backpressure; an unbounded hidden queue is forbidden.

## Ownership, Effects, And Evaluation

`branch` describes topology only. Its default execution is sequential in source
order. It does not imply threads, tasks, or parallel evaluation.

For a `Copy` input, every arm receives a copy. For an affine owned input, the
ordinary flow mode is a move, so at most one arm may consume it. The compiler
must reject an attempted implicit duplication:

```sollang
resource!
-> branch {
    first:  -> consumeA
    second: -> consumeB
}
```

Readonly inspection is explicit:

```sollang
resource!
-> branch {
    first:  ref -> inspectA
    second: ref -> inspectB
}
```

At most one arm may receive `mut`, and no other arm may overlap that mutable
borrow. A `move` arm consumes the value at its source-ordered position. Branch
results own their returned fields and drop them in reverse field order.

Effects execute in arm source order. An error or propagation from an earlier
arm prevents later arms from starting, matching ordinary left-to-right
evaluation. Successful earlier results are dropped if a later arm exits the
branch early.

Parallel execution requires the existing explicit parallel vocabulary:

```sollang
value
-> parallel branch {
    first:  ref -> transformA
    second: ref -> transformB
}
```

The parallel form is legal only when ownership and effect rules prove that the
arms may overlap. Its result fields retain declaration order even if completion
order differs. Failure and cancellation follow the existing structured
parallel rules; `branch` must not introduce a second concurrency model.

## Static Model And Lowering

The implementation must represent junctions in the parser, semantic model, and
typed IR. It must not lower them early into unrelated temporary bindings that
lose source spans or ownership relationships.

- A labeled product is a closed product type whose field names and order are
  part of its type.
- `branch` has one input edge, one region per arm, and one labeled result edge.
- `partition` has one stream input edge and one stream field per route.
- Tuple construction is the explicit many-values-to-one-value junction.
- Stream policies are ordinary typed operations over a tuple of compatible
  streams, but retain policy metadata through typed IR for diagnostics and
  lowering.
- Formatter and language-server nodes preserve arm labels, alignment, and
  source spans.
- LLVM lowering may optimize pure branches, but must preserve observable source
  order unless the source explicitly selected `parallel`.

The grammar direction is:

```ebnf
branch_flow_target :=
    "branch" "{" branch_arm+ "}"
  | "parallel" "branch" "{" branch_arm+ "}"

branch_arm := identifier ":" parameter_mode? "->" flow_expression
parameter_mode := "ref" | "mut" | "move"

partition_flow_target :=
    "partition" identifier? "{"
        partition_when_arm+
        partition_else_arm
    "}"

partition_when_arm :=
    identifier ":" "when" expression

partition_else_arm :=
    identifier ":" "else"

tap_flow_target :=
    "tap" path flow_target_call?
  | "tap" block_body

product_expression :=
    "(" expression "," expression ("," expression)* ","? ")"

product_type :=
    "(" product_type_field "," product_type_field
        ("," product_type_field)* ","? ")"

product_type_field := (identifier ":")? type_annotation
```

The real generated grammar, bootstrap parser, self-host parser, semantics,
typed IR, ownership analysis, formatter, LSP, and both LLVM paths must change
together. No compatibility alias or temporary parser fallback is permitted.

## Diagnostics

Diagnostics must name the topology and the offending arm. Required cases
include:

- duplicate branch or partition labels;
- fewer than two arms;
- a missing, duplicate, or non-final `else` route;
- a predicate that is not `Bool`;
- incompatible product or stream element types;
- implicit duplication of an affine owner;
- overlapping `mut` and readonly borrows;
- an illegal effect in `parallel branch`;
- an unbounded-buffer requirement;
- a `zip`/`merge`/`concat`/`latest` input that is not a tuple of streams; and
- field access after the branch product has been moved.

Diagnostics must point to both the conflicting use and the original arm or
owner when two locations establish the error.

## Samples And Exhaustive Verification

Learning examples and exhaustive fixtures remain separate.

Ten Flow Junctions user examples are kept under `examples/user/`:

1. scalar `branch`;
2. multi-stage named branch arms;
3. labeled product binding and access;
4. ordinary tuple value joining;
5. `partition`;
6. `tap`;
7. `zip`;
8. `merge` and its nondeterministic ordering contract;
9. `concat` and `latest`; and
10. readonly ownership plus explicit `parallel branch`.

Each user example has a byte-identical regression counterpart. The exhaustive
track contains 57 positive fixtures (`788` through `844`) and 26 focused
diagnostic fixtures. Those 83 physical fixtures cover the following
114 separately counted logical cases:

| Area | Logical cases |
| --- | ---: |
| Grammar and parser, including rejected forms | 18 |
| Tuple and labeled-product typing | 14 |
| Ownership, borrow, move, and drop | 14 |
| Effects and evaluation order | 12 |
| Stream policy, completion, buffering, and backpressure | 20 |
| Required diagnostics and source spans | 16 |
| Formatter and language server | 8 |
| Bootstrap/self-host differential and LLVM execution | 12 |
| **Total** | **114** |

The 114 logical cases run on Windows x64 and every applicable case runs on
Linux x64. The browser gate runs 20 exact-output runtime cases and 4 exact
diagnostic cases, including 9 Flow Junctions runtime cases and the explicit
parallel-branch target diagnostic. The browser catalog exposes 40 samples.
The complete cumulative suite, Stage 2 differential gate, and Stage 3 fixed
point remain mandatory. Test counts are updated only from measured runner
inventory after the fixtures exist.

The repository-wide runner inventory after adding this track is 20 user
examples, 827 regression cases, and 257 diagnostic cases: 1,084 logical
fixtures in total. Supporting `.sources.txt`, LLVM validation, execution, and
contains files do not add to that count.

## Delivery Order

Implementation was completed in this order after the 0.4 native-only
distribution gate:

1. add tuple and labeled-product grammar, types, ownership, and LLVM layout;
2. implement sequential `branch` and `tap`;
3. implement lazy `partition`;
4. implement `zip`, `merge`, `concat`, and `latest` with bounded buffering;
5. connect `parallel branch` to structured parallel ownership and cancellation;
6. add formatter, LSP, browser, user samples, and the complete verification
   matrix; and
7. update `PHILOSOPHY.md`, `SPEC.md`, `DECISIONS.md`, and the generated grammar
   only when implementation evidence makes the surface normative.

## Rejected Directions

- New arrows such as `->>`, `-<`, or `<+>` are rejected because symbols alone
  do not reveal replication, routing, ordering, or synchronization policy.
- A single stream `join` is rejected because `zip`, `merge`, `concat`, and
  `latest` have observably different semantics.
- Implicit tuple expansion is rejected because it hides the function's real
  input type.
- Implicit parallelism is rejected because it changes effects and ordering.
- Implicit cloning or materialization is rejected because it hides ownership
  and cost.
- A fallback that accepts both provisional and final syntax is rejected.

## Research Basis

- [Apache Pekko stream operators](https://pekko.apache.org/docs/pekko/current/stream/operators/index.html)
  separates fan-out (`Broadcast`, `Partition`, `Unzip`) from policy-specific
  fan-in (`Merge`, `Concat`, `Zip`, `ZipLatest`).
- [Haskell `Control.Arrow`](https://hackage.haskell.org/package/base/docs/Control-Arrow.html)
  distinguishes splitting paired inputs with `***` from sending one input to
  two computations with `&&&`.
- [Apache Beam programming guide](https://beam.apache.org/documentation/programming-guide/)
  models a pipeline as an explicit graph in which outputs may feed several
  transforms and collections are combined by named transforms.
- [F# symbol and operator reference](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/symbol-and-operator-reference/)
  provides tuple pipeline operators, supporting the principle that multiple
  inputs first form an explicit structural value.
- [Elixir `Kernel.tap/2`](https://hexdocs.pm/elixir/Kernel.html#tap/2) performs a
  side operation while returning the original pipeline value.
- [TPL Dataflow](https://learn.microsoft.com/en-us/dotnet/standard/parallel-programming/dataflow-task-parallel-library)
  makes broadcast, grouping, ordering, bounded capacity, scheduling, and
  greedy/non-greedy joining separate observable policies.
