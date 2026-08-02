# Sollang AI Agent Coding Guide

Status: canonical agent onboarding and coding guide
Updated: 2026-08-02

This is the single maintained entry point for an AI Agent that must read,
write, review, or change Sollang code. Do not infer Sollang syntax from another
language, from an old release, or from one isolated fixture. Read the sources of
truth below and verify generated code with the real compiler.

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
use `=>`, while statement bodies use `{ ... }`. Call a zero-input function with
`()`. Enum members and computed self properties remain member-like, for example
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
```

Ranges are inclusive with `..` and half-open with `..<`. Block functions keep
the current value on the left, such as `1..9 -> each value { ... }`.

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
{"one": 1, "two": 2} => lookup
```

Ordinary product fields are `_0`, `_1`, and so on. Labeled product fields use
their labels. Products do not implicitly expand into function arguments.
Structs and enums are nominal; products are structural. Arrays, dictionaries,
generic types, `Option`, `Result`, traits, `impl`, associated types, and owned
`dyn<Trait>` values are described in `SPEC.md` and demonstrated by retained
fixtures.

### Ownership, references, and effects

Sollang checks affine owners, partial moves, readonly and mutable borrows,
captured values, async frames, and drops. Do not insert cloning or heap
materialization to silence an ownership error. Use the ownership form required
by the callee or flow arm and let the compiler reject illegal reuse.

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
5. Keep the C# bootstrap and the Sollang self-host implementation semantically
   aligned.
6. Update user examples, regression expectations, browser samples, formatter,
   language server, and standard library wherever the public surface requires.
7. Run focused probes, complete Windows/Linux suites, applicable browser gates,
   and required Stage 2/Stage 3 fixed-point verification.
8. If compiler or standard-library artifacts changed, synchronize and verify
   the installed compiler at `P:\\Utils\\sollang`.
9. Update this guide when the preferred syntax, semantics, CLI, target boundary,
   standard library, examples, or required verification workflow changed.
10. Commit and push only after `git diff --check`, a clean test result, and a
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
`CLAUDE.md`, `.github/copilot-instructions.md`, the website's
`/ai/AI_AGENT_GUIDE.md`, and `/llms.txt` are discovery entry points; they must
refer to this file instead of copying its full contents.

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
