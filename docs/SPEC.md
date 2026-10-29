# Sollang Language Specification

Status: implemented living specification
Updated: 2026-09-03

This document is the living specification for Sollang. Normative language
rules follow the current compiler and executable examples; historical design
rationale is retained where it still explains the accepted syntax.

This is the authoritative specification for AI consumers as well as human
readers. `AI_SLG_BEST_PRACTICES.md` is the single AI syntax and coding-style
guide and points here for detailed contracts. When language, ownership, effects, API, CLI,
or target behavior changes, update the relevant section here and the affected
grammar, examples, and verification contracts in the same change. Keep run
results, completion percentages, defect histories, and session notes outside
the specification. Describe target implementation limits explicitly.

## Current Boundary

The implemented language includes:

- expression-first bindings, fluent calls, functions, local functions,
  structured control flow, block roles, compile-time ranges, and interpolation;
- fixed-width and target-sized numerics, contextual Unicode-scalar character
  literals, strict UTF-8 `Text`, raw strings,
  nominal structs/enums/traits, associated types, type/value generics, `box`,
  static trait dispatch, and explicit owned `dyn<Trait>` dispatch;
- generic fixed/growable arrays and Swiss-table dictionaries, checked places,
  readonly references with inferred origins, mutable borrows, move paths,
  deterministic recursive drop, and structured async/parallel ownership;
- multi-file namespaces/imports, visibility, deterministic projects/products,
  packages/workspaces, path/Git/registry dependencies, and reproducible locks;
- canonical scalar and affine async/random-access file I/O, portable paths and
  directory snapshots, child processes, memory maps, and explicit user-value
  serialization through `sys.file.BinarySerializable`;
- a parser-backed formatter, language server, VS Code integration, and native
  `sollang test` harness generation; and
- a Sollang-written compiler pipeline from lexer/parser/CST/AST through
  semantics, typed IR, ownership, LLVM emission, and Windows/Linux native
  toolchain orchestration.

Self-hosting verification requirements are documented in `STAGE3_COMPILER.md`;
completion must be established from current-source verification evidence.
Browser WebAssembly remains a supported output target with a deliberately
narrower host-capability surface. Publishing/signing services, broader codecs,
and richer editor features are product extensions, not implicit language rules.

## Core Goals

- Provide a beautiful, simple, and powerful source language.
- Parse and tokenize source code very effectively.
- Compile through LLVM into highly optimized native executables.
- Keep the compiler pipeline efficient from source text to final executable.
- Support cross-platform native output from the beginning.
- Prefer clear compile-time errors over silent fallback behavior.
- Use the latest .NET and latest C# Preview features for the compiler
  implementation unless a later constraint requires otherwise.

## Non-Goals

- No tracing garbage collector, implicit reference counting, or hidden owner
  duplication in the safe language surface.
- No class inheritance, implicit null, or implicit runtime dispatch.
- No silent target fallback, target-dependent ABI serialization, or unchecked
  safe indexing.
- No private grammar embedded inside block roles or package manifests.
- No requirement that bootstrap-maintenance tooling be written in Sollang when
  the Sollang compiler can already consume the canonical generated product.

## Compilation Model

The intended compilation pipeline is:

```text
source text
-> lexer
-> parser
-> AST
-> semantic model
-> typed IR
-> LLVM IR
-> optimized object code
-> linked native executable
```

The pipeline must avoid unnecessary intermediate forms. Each stage should exist
because it makes diagnostics, semantic analysis, optimization, or LLVM lowering
meaningfully better.

For a native build, the requested output path and its optional LLVM sidecar
`<output>.ll` are final publication targets. The compiler claims both target
paths before emitting LLVM, writes LLVM and the linked executable to unique
same-directory stages, and publishes the complete executable only after
emission and linking succeed. `--keep-temps` publishes the complete LLVM stage;
without that flag, the LLVM stage is discarded. Emission or linking failure
preserves pre-existing final artifacts. Each final file is replaced as a complete file;
the executable and LLVM sidecar are two separate publications, not one atomic
pair. Output-path claims and stages are owned by the invocation and released
when it finishes.

Structured control flow is retained through typed IR. An `if` owns ordered
`then` and optional `else` regions plus its Bool condition. LLVM lowering then
creates explicit basic blocks and branches; it creates a merge `phi` only when
the conditional is value-producing. This keeps branch-local type, ownership,
and lifetime analysis independent of target-specific CFG text emission.
Independent effectful calls and control regions retain source order even when
their value dependencies would otherwise allow topological reordering.
Nested value conditionals compose by using the innermost result-producing merge
block as the predecessor of an enclosing `phi` input.

Self-hosted mutable scalar loops use an explicit memory form before LLVM
optimization: one non-escaping entry-block `alloca` represents each mutable
binding chain, rebinds are ordered stores, and reads are ordered loads. A
`while` condition tree is regenerated in the header so every iteration observes
the latest stored value. Logical `and` and `or` lower to short-circuit branches
rather than eager bitwise evaluation; `not` exchanges the continuation targets,
and a call-valued leaf executes only when its path is reached. An enum, boolean,
or subject `when` leaf is evaluated through the same selected
block and merge its result before the enclosing logical continuation. Its
subject and selected arm are evaluated on that path, and its existing payload
ownership and cleanup rules still apply. LLVM may then
promote the slot to SSA and synthesize
the loop-carried `phi`; the language semantics do not require a heap allocation
or expose this intermediate representation.

## First Program

The first valid Sollang program is:

```sollang
main {
    "dimohy" => name
    print("Hello, $name")
}
```

Expected stdout bytes:

```text
Hello, dimohy
```

`print` does not append a newline. `println` is the current newline-producing
convenience.

Global function aliases resolve to the actual canonical declarations: the
three `sys.io` input/output functions, `sys.random.seed` and `sys.random.below` (as
`seedRandom` and `randomBelow`), the six integer-file functions in `sys.file`,
and the parallel execution and worker-query functions in `sys.runtime`.
An alias retains its target's visibility, effects, source identity, and body.
A missing target is an unresolved declaration, never an implicit runtime call.
A full program requires every canonical alias target even when its main body
does not call that alias. A global function whose name conflicts with an alias
is rejected. Declaration signature, reserved-name, effect-name, and trait
implementation errors precede alias admission; alias admission precedes
function-body validation and LLVM emission. Partial semantic analysis APIs
remain usable without loading the complete standard library.

The canonical `sys.io.print` and `sys.io.println` declarations use the display
printer rules for supported scalar values. Canonical `println()` also accepts
no value and emits only a newline. These rules apply equally to qualified calls
and global aliases; an ordinary function named `println` keeps its own declared
parameters, result, and body.

The current extended example is:

```sollang
getName: -> Text {
    "dimohy"
}

square: Int -> Int {
    it * it
}

main {
    getName() => name
    7 -> square => num
    "Hello, $name. square = $num" -> print
}
```

Expected stdout bytes:

```text
Hello, dimohy. square = 49
```

The one-input function can also name its input explicitly:

```sollang
square n: Int -> Int {
    n * n
}
```

The current cumulative input and loop example is:

```sollang
main {
    "n = ? " -> readInt => n

    1..9 -> each i {
        n * i => value
        "$n x $i = $value" -> println
    }
}
```

With stdin `9`, the expected stdout bytes are:

```text
n = ? 9
9 x 1 = 9
9 x 2 = 18
9 x 3 = 27
9 x 4 = 36
9 x 5 = 45
9 x 6 = 54
9 x 7 = 63
9 x 8 = 72
9 x 9 = 81
```

The same loop can omit the item name and use the default binding `it`:

```sollang
main {
    "n = ? " -> readInt => n

    1..9 -> each {
        n * it => value
        "$n x $it = $value" -> println
    }
}
```

The executable `main` wrapper can be omitted. These top-level statements are
compiled as the main body:

```sollang
getName() => name
7 -> square => num
"Hello, $name. square = $num" -> sys.io.print
```

The input and output functions can also be addressed by their canonical module
path:

```sollang
"n = ? " -> sys.io.readInt => n

1..9 -> each i {
    n * i => value
    "$n x $i = $value" -> sys.io.println
}
```

The current conditional form keeps the condition as the value flowing into a
block function-like control expression:

```sollang
"n = ? " -> readInt => n

n < 1 or n > 9 -> if {
    "n must be 1..9" -> println
} else {
    1..9 -> each i {
        n * i => value
        "$n x $i = $value" -> println
    }
}
```

For multi-branch value selection, `when` is an expression:

```sollang
grade score: Int -> Text {
    when {
        score >= 90 { "A" }
        score >= 80 { "B" }
        score >= 70 { "C" }
        else { "F" }
    }
}
```

When every arm compares the same value, the value can flow into `when` once:

```sollang
grade score: Int -> Text {
    score -> when {
        >= 90 { "A" }
        >= 80 { "B" }
        >= 70 { "C" }
        else { "F" }
    }
}
```

## Initial Syntax Direction

Sollang starts with an explicit `main` block instead of a fully general function
declaration. Local bindings do not use `let`, `var`, or a declaration keyword:

```sollang
getName: -> Text {
    "dimohy"
}

square: Int -> Int {
    it * it
}

main {
    getName() => name
    7 -> square => num
    "Hello, $name. square = $num" -> print
}
```

For short executable scripts, the `main` wrapper may be omitted:

```sollang
getName() => name
7 -> square => num
"Hello, $name. square = $num" -> print
```

Rationale:

- `main { ... }` is shorter than `fn main() { ... }`.
- `value => name` keeps local binding aligned with the language's expression-first
  direction.
- `"Hello, $name"` keeps string interpolation direct and familiar.
- `it * it` introduces the smallest one-input numeric function without deciding the
  final numeric tower.
- `getName: -> Text { ... }`, `square: Int -> Int { ... }`, and
  `square n: Int -> Int { ... }` introduce the smallest zero-input and one-input
  function declaration shapes.
- `getName() => name` and `7 -> square => num` make returned values bindable
  without hiding the flow behind assignment syntax. A bare function name is not
  an invocation.
- `"..." -> print` makes the primary data flow visible at the call site.
- The executable entry point can be explicit with `main { ... }` or implicit
  when top-level executable statements are present.
- The parser can recognize the first complete program with a tiny grammar.
- The syntax leaves room for full functions, modules, and effects later.
- Braces avoid indentation-sensitive block parsing.

## Initial Grammar

The initial grammar is deliberately small:

```ebnf
source_file  := trivia* namespace_declaration? import_declaration* function_declaration* (main_block | statement*) trivia* eof
namespace_declaration := "namespace" path statement_end
import_declaration := "import" path ("as" identifier)? statement_end
function_declaration := path identifier? ":" function_signature (block_function_body | function_body)
function_signature := "->" type_annotation? | type_annotation? "->" type_annotation?
block_function_body := "block" identifier ":" type_name "{" statement* "}"
function_body := "{" function_declaration* statement* expression "}" | "=>" expression | "->" expression | "=" "intrinsic"
main_block   := "main" block
block        := "{" statement* "}"
statement    := guard_loop_control_statement | loop_control_statement | each_statement | binding_statement | index_assignment_statement | field_assignment_statement | expression_statement | block_function_call
block_function_call := range_or_logical_expression "->" path identifier? block
each_statement := "each" identifier "in" range_expression block
binding_statement := identifier "=" expression statement_end | expression newline* "=>" identifier "!"? statement_end
index_assignment_statement := expression newline* "=>" identifier "!"? "[" expression "]" statement_end
field_assignment_statement := expression newline* "=>" identifier "!"? "." identifier statement_end
expression_statement := expression statement_end
loop_control_statement := ("break" | "continue") statement_end
guard_loop_control_statement := range_or_logical_expression "->" "if" ("break" | "continue") statement_end
statement_end := newline+ | "}" lookahead
range_expression := logical_or_expression ".." logical_or_expression
expression   := flow_expression
flow_expression := range_or_logical_expression ("->" (if_flow_target | while_flow_target | when_flow_target | fold_flow_target | standard_generic_enum_flow_target | path flow_target_call?))*
standard_generic_enum_flow_target := ("Option" "<" type ">" | "Result" "<" type "," type ">") "." identifier flow_target_call?
flow_target_call := "(" argument_list? ")"
range_or_logical_expression := range_expression | logical_or_expression
if_flow_target := "if" block_body ("else" block_body)?
while_flow_target := "while" block_body
when_flow_target := "when" "{" subject_when_arm+ "else" when_arm_body "}"
fold_flow_target := "fold" expression (identifier "," identifier)? block_body
when_expression := "when" "{" when_arm+ "else" when_arm_body "}"
when_arm := when_condition when_arm_body
when_condition := subject_when_condition | logical_or_expression
subject_when_arm := subject_when_condition when_arm_body
subject_when_condition := subject_comparison expression | range_expression
subject_comparison := "==" | "!=" | "<" | "<=" | ">" | ">="
when_arm_body := "=>" expression | "->" expression | block_body
block_body := "{" statement* expression? "}"
logical_or_expression := logical_and_expression ("or" logical_and_expression)*
logical_and_expression := value_flow_comparison_expression ("and" value_flow_comparison_expression)*
equality_expression := comparison_expression (("==" | "!=") comparison_expression)*
comparison_expression := additive_expression (("<" | "<=" | ">" | ">=") additive_expression)*
value_flow_comparison_expression := value_flow_expression (("==" | "!=" | "<" | "<=" | ">" | ">=") additive_expression)*
value_flow_expression := equality_expression ("->" ordinary_value_flow_target)* "?"*
additive_expression := multiplicative_expression (("+" | "-") multiplicative_expression)*
multiplicative_expression := unary_expression (("*" | "/" | "%") unary_expression)*
unary_expression := "not" unary_expression | "box" unary_expression | "-" unary_expression | primary
call         := path "(" argument_list? ")"
argument_list := expression ("," expression)*
path         := identifier ("." identifier)*
type_name    := identifier
type_annotation := type_name | "[" type_name ";" "~" "]" | "{" type_name ":" type_name "}"
primary      := atom postfix_suffix*
postfix_suffix := ("!"? "[" expression "]") | ("." identifier) | "?"
atom         := when_expression | bool_literal | call | array_literal | dictionary_literal | "(" expression ")" | string_literal | character_literal | number_literal | identifier
array_literal := "[" type_name ";" ("~" | number_literal "~") "]" | "[" expression ("," expression)* ","? ";" "~" "]" | "[" expression ("," expression)* "]" | "[" expression ";" number_literal "]"
dictionary_literal := "{" type_annotation ":" type_annotation (";" (number_literal "~" | "<=" number_literal | dictionary_entries (";" "<=" number_literal)?))? "}" | "{" dictionary_entries (";" "<=" number_literal)? "}"
dictionary_entries := dictionary_entry (("," newline* | newline+) dictionary_entry)* ","?
dictionary_entry := expression ":" expression
bool_literal := "true" | "false"
character_literal := "'" (unicode_scalar | "\\" ("0" | "b" | "f" | "n" | "r" | "t" | "\\" | "'" | "\"")) "'"
number_literal := decimal_digit+
string_literal := "\"" string_part* "\"" | "\"\"\"" raw_string_text* "\"\"\""
string_part  := string_text | interpolation
interpolation := "$" identifier | "$(" expression ")"
```

Notes:

- The atom's final `identifier` alternative excludes the bare expression
  keywords `not`, `box`, `when`, `map`, `true`, and `false`. Their dedicated
  expression forms commit before a name expression; the same spellings remain
  valid binding names after `=>`. In particular, `true()` and `false()` do not
  become calls because boolean literals are classified before call parsing.
- `raw_string_text` is always literal text. `$name` and `$(expression)` are
  interpolation only inside an ordinary quoted string; raw strings preserve
  those bytes unchanged and never perform binding or expression resolution.
- For a raw string expression whose content starts with `LF` or `CRLF`, the
  closing delimiter must begin on a new line after only spaces or tabs. That
  indentation has the same width as the opening delimiter's UTF-16 column
  minus one. Each nonblank content line must have that exact indentation
  prefix; remove it, normalize `CRLF` to `LF`, and join the content lines with
  `LF`. Whitespace-only content lines become empty lines. The opening newline
  and the newline immediately before the closing indentation are excluded.
  Inline raw strings, including content beginning with a lone `CR`, keep their
  content unchanged. These expression rules do not normalize raw string tokens
  consumed as native-library or COM metadata.
- An ordinary quoted string ends with its closing quote on the same source
  line; an unescaped `CR`, `LF`, or `CRLF` before that quote is an unterminated
  string lexical error. Raw strings may contain source newlines. A raw string
  without its matching quote run reports an unterminated raw string lexical
  error, distinct from an ordinary unterminated string.
- Identifier and bare `$name` scanning use the same UTF-16 BMP character
  categories: an underscore or letter starts a name; underscores, letters, and
  decimal digits continue it. Other characters end the name, and a `$`
  followed by a nonletter such as an emoji or symbol remains literal text.
  Supplementary scalars do not form identifier characters in this contract.
- Numeric literal digits are ASCII `0` through `9`; Unicode decimal digits
  may continue identifiers where the identifier category permits them, but do
  not start or continue a numeric literal.
- Literal punctuation tokens in both compiler implementations come from
  `syntax/sollang.lexer`. The SLG lexer uses the generated literal text,
  rule-index, and token-ID tables and selects the longest matching literal;
  source-level punctuation lookup tables are not separate authorities.
- Outside a literal, a valid UTF-8 scalar that cannot start a token is one
  invalid token spanning its complete byte sequence. Diagnostics for an invalid
  or supplementary scalar must not slice through a UTF-8 sequence.
- `build` and `format` use the same syntax diagnostic formatter. Lexical and
  parse failures report their one-based source line and UTF-16 column on stderr
  and stop before native code generation. File-backed `build` parse errors
  include the source path before `parse error`; lexical errors do not. Diagnostic
  paths use the normalized absolute caller path, independently of cache state.
  Physical canonical paths used for source de-duplication and cache identity do
  not replace these labels; an explicitly supplied extended path remains explicit.
  When a
  statement is followed by another token without `CR`, `LF`, `CRLF`, `}`, or
  end of input, both compilers report `expected end of statement` at that
  token. The SLG parser reports this from a failed generated `StatementEnd`
  rule at the final diagnostic token. When a required expression is missing
  after an arithmetic operator or an argument delimiter, both compilers report
  `expected expression`; an unfinished block still reports `expected RightBrace`
  and a call missing only its close reports `expected RightParen`. In expression
  position, bare `when` requires `LeftBrace`, bare `map` requires an Identifier
  mode, and an unsupported map mode reports `map expects 'read' or 'write'`.
  When a build
  includes multiple invalid source files, it reports only the first
  syntax failure in the selected source order. Malformed UTF-8 source bytes
  produce a lexical error at the first invalid byte's one-based line and
  UTF-16 column, in both `build` and `format`, without replacement decoding.
  For that location, `CR`, `LF`, and `CRLF` each advance one source line;
  `CRLF` is one newline even when it precedes the invalid byte.
  A UTF-8 BOM at the start of a source file or formatter stdin is an encoding
  marker and is removed before lexing, formatting, and source diagnostics.
  Other encoding markers, including UTF-16 BOMs, do not change the required
  UTF-8 source encoding and fail at the first invalid UTF-8 byte.
- `grammar build` removes an initial UTF-8 BOM from each lexer and grammar
  input before parsing and source hashing. Its generated source SHA-256 hashes
  the UTF-8 lexer text, `\n---grammar---\n`, and grammar text after normalizing
  `CRLF`, `CR`, `LF`, form feed, NEL, line separator, and paragraph separator
  to `LF`. Vertical tab is preserved in this hash. Specification lines are
  still separated by `CR`, `LF`, or `CRLF`; hash normalization does not split
  a comment at a Unicode separator.
- Language-server diagnostic and formatting positions are zero-based UTF-16
  positions. `CR`, `LF`, and `CRLF` each advance one logical line. A formatting
  edit never splits an original `CRLF` pair merely because its `LF` is a common
  suffix of the original and formatted text; applying the returned edit must
  reproduce the formatter's complete output, including normalized line endings.
- A single-quoted character literal contains exactly one Unicode scalar or one
  supported escape. It is a contextual integer literal: it defaults to `Int`
  and adopts an integer destination such as `UInt8` or `CodePoint` when its
  scalar value fits. An explicit numeric conversion checks the decoded scalar;
  range diagnostics show its decimal value. Empty, multi-scalar, malformed UTF-8,
  surrogate, and unsupported-escape forms are lexical errors. Character errors
  retain the opening quote location. Empty or multiple scalars report
  `character literal must contain one Unicode scalar`; unsupported escapes report
  their offending escape before a missing closing quote is considered. A missing
  scalar or closing quote at a newline or EOF reports `unterminated character literal`.
  CLI and language-server messages use the same classification.
- `CR`, `LF`, and `CRLF` each form one newline token and can separate
  statements. A line comment ends before any of those newline forms.
  Newline is a statement separator, not an indentation rule.
- Parenthesized call arguments may start on the following line and continue as
  comma-separated lines; newlines inside the parentheses do not end the call.
- Array literals may place their opening item, comma-separated items, `; ~`,
  and closing bracket on separate lines. This keeps raw multiline strings and
  other structured values readable without changing their element order.
  Ordinary fixed array literals allow a final comma, including a single
  element such as `[value,]`; the comma does not create another element.
- An empty static literal may use `[]` when its element type is supplied by a
  return, argument, field, or other array context. `[T; ~]` remains the explicit
  empty growable owner; contextual `[]` never implies growable storage.
- Call-argument context is ordinal and covers the complete declaration. The
  first parameter and the declaration's second-and-later parameter chain are
  one logical sequence, so `[]` in any argument position inherits the exact
  corresponding slice, fixed-array, or growable-array ABI before codegen.
- A one-element growable value array requires the explicit trailing comma
  `[value,; ~]`; `[T; ~]` remains the typed-empty form. The comma removes the
  value/type ambiguity in the same way a trailing comma distinguishes a
  one-element tuple in languages that provide tuple literals.
- Semicolons are not statement separators. The array surface uses `;` for
  repeated fixed arrays such as `[0; 8]`, growable seeds such as `[1, 2; ~]`,
  and typed-empty growable arrays such as `[Int; ~]`.
- The parser gives `[value; N]` and `[value; Count]` fixed-repeat syntax priority
  over the general comma-separated item alternative. Reference and self-host
  parsers must accept the same form.
- The repeated value in `[value; N]` may be any inline copyable value. Its
  element type is inferred from `value`; owned and nested-container values are
  rejected because repetition would duplicate ownership.
- Checked file compilation performs syntax validation before semantic,
  typed-IR, ownership, or LLVM preparation. A rejected parse may retain
  recovery nodes for diagnostics, but those partial nodes cannot enter later
  compiler phases.
- A fixed value literal retains its concrete element count through an immutable
  or mutable binding. `[10, 20]` and `[10; 2]` are `[Int; 2]`;
  `["one", "two"]` is `[Text; 2]`. Binding does not erase the count to an
  unspecified `N` or change the storage shape.
- A function's fixed-array argument must match the declared concrete length.
  When both lengths are known, a mismatch is rejected before LLVM emission.
  The rule applies to the primary input and every additional input.
- A concrete type annotation `[T; N]` carries an exact nonnegative length.
  Struct initialization accepts a compatible owned array only after proving a
  literal count or emitting a runtime equality check before ownership transfer.
  `[T; N]` does not expose growable operations.
- `mut [T; N]` borrows the fixed payload for indexed replacement without
  transferring ownership. Because the length is invariant, this borrow uses
  the fixed-array slice ABI and cannot resize or replace its storage.
- Braces are the only block delimiters.
- Field, index, mutable-index-view, and propagation suffixes form one repeated
  postfix chain and associate from left to right. Dot and index suffixes may be
  freely interleaved, so `symbols![1].payload![0]` means
  `((symbols![1]).payload)![0]` without requiring grouping parentheses.
  The same receiver chain applies inside `$(expression)` interpolation; each
  field or index reads the result of the preceding suffix.
  Grouping parentheses preserve the enclosed place, so
  `(symbols[1].payload)[0]` reads an element of the selected payload.
- Expression operands are evaluated recursively from inner to outer, and
  sibling operands and call inputs are evaluated from left to right as written.
  Typed IR consumers must reference the concrete value-producing node rather
  than a transparent syntax wrapper; generated LLVM definitions therefore
  dominate every use without changing source evaluation order.
- If `main { ... }` is omitted, remaining top-level statements after function
  declarations are treated as the executable main body.
- A function whose body is a single expression uses `=> expression` instead of
  an outer body block. `->` is reserved for value flow.
- A statement-level expression followed by `=> name` introduces a local binding
  in the current block.
- `source -> path item? { ... }` introduces a block-function call. Built-in
  `each`, `repeat`, and `fold`, user-defined result roles, and the standard
  `parallel`/`tryParallel` roles use this surface. The following brace block is
  the call marker, so empty parentheses are omitted.
- `condition -> if { ... } else { ... }` introduces the current conditional
  expression form. The value flowing into `if` must be `Bool`.
- `condition -> unless { ... }` is the statement-only inverse guard. It runs
  the block only when the Bool condition is false and is the canonical form for
  validation failures; an empty `if` success branch followed by `else` is
  redundant.
- A newline may precede `and` or `or`. The line-leading operator continues the
  preceding boolean expression, so a long condition can end with a separately
  visible `-> if` continuation without changing precedence or evaluation order.
- `when { condition => value else => fallback }` is the preferred multi-branch
  expression form. Block arms remain valid for multi-statement bodies.
- `value -> when { >= limit => value else => fallback }` is the subject-value
  shorthand for ordered comparisons against one value. The subject value is
  evaluated once.
  A readonly integer reference is read as its integer value; relational and
  range arms retain that value's width and signedness.
- `value -> when { start..end => value else => fallback }` checks inclusive
  integer ranges against the subject value. Half-open `..<` uses the same
  subject-arm shape.
- In a one-input function using the default input binding `it`, a subject-style
  `when` without an explicit subject uses `it` as the subject. Explicitly named
  inputs should still use `input -> when { ... }`.
- `range -> fold initial acc, item { nextAcc }` returns the final integer
  accumulator value after direct loop lowering.
- `+`, `-`, `*`, and `/` require matching numeric types; `%` is integer-only.
  Inside interpolation, a numeric literal on the right takes the validated
  left operand type when that context permits it. Entry expressions, function
  arguments, and nested control blocks apply the same operand type and width.
- Unary `-` accepts a signed numeric operand.
- A numeric conversion checks its argument count, operand type, and literal
  range before its result type is checked for string interpolation display.
- Parentheses group expressions.
- `#` starts a line comment outside string literals.
- numeric comparison operators require compatible numeric operands and return
  `Bool`. Floating-point comparisons use ordered predicates at the operand's
  `Float32` or `Float64` width, including inside interpolation in entry code,
  function arguments, and nested control blocks. A bare integer-shaped literal
  in a floating comparison or arithmetic context is emitted as a floating
  operand of that width. `Text == Text` and
  `Text != Text` compare UTF-8 contents, not the
  backing pointer/length aggregate identity. Text equality is allocation-free,
  rejects mixed operand types, and does not imply lexical ordering; use an
  explicit text comparison API when ordering is required. The same content
  comparison applies inside interpolation in entry code, function arguments,
  and nested control blocks.
  Interpolated operands compare their rendered contents. Each operand's holes
  are evaluated once, in source order, before the next operand is evaluated.
  A transient operand uses stack storage and introduces no heap owner.
- `and` and `or` short-circuit and require `Bool` operands. Aggregate literals
  passed to calls within an operand evaluate their field initializers in source
  order on that operand's selected branch, before the call. The same storage
  copying and ownership-transfer rules apply as in ordinary calls. If both operands
  are invalid, report the left operand first and stop after that error.
  When an invalid operand is itself a binary expression, report the operand's
  operator token position, including inside parentheses and interpolation.
  Inside an interpolation expression, validate an inner binary operator before
  the enclosing operator. Among independent operand errors, report the left
  expression first.
- `not` requires a `Bool` operand.
- `value -> function` is parsed as a fluent flow expression with `value` as the
  source. The value on the left remains the function input.
- `value -> function()` remains accepted as compatibility syntax, but empty
  parentheses are no longer preferred for receiver-only flow calls.
- Standard generic enum variants are flow targets. Prefer
  `value -> Result<T, E>.Ok` and `value -> Option<T>.Some` when the flowing value
  is the payload; these are equivalent to the direct constructor forms.
- A payload-free enum variant is already a value, not a callable constructor.
  Resolution and reachability must not synthesize a function call for it merely
  because the variant has a name token; only a variant with a declared payload
  type may participate in constructor-call resolution.
- A match arm returning an explicit payload-free variant does not transfer its
  subject's bound payload into that result. Only the result constructor's own
  payload expression supplies runtime payload storage and ownership transfer.
- A specialized generic enum variant whose payload type is `Unit` may be constructed without
  a payload argument and matched without a payload binding. A non-`Unit`
  payload still requires its pattern binding; this exception does not discard
  an owned or reference-bearing payload.
- A payload-bearing nominal enum constructor applies its declared payload type
  through transparent call wrappers. Bare integer literals retain the full
  declared width, and `[]` can initialize a declared zero-length fixed array.
- `->` never creates a binding. Bind results with `=>`: `7 -> square => num`.
- `1..9 -> each i { ... }` iterates an inclusive integer range and introduces
  `i` only inside the loop body.
- `1..9 -> each { ... }` uses `it` as the default loop item binding.
- Runtime `each` completes as `Unit`, including at a function or branch tail.
  Its array receiver and callback operands do not supply the enclosing branch's
  result. Collection comprehensions and ordinary user-defined block functions
  retain their declared value contracts.
- Array `each` borrows its element. A non-copyable element that owns storage
  cannot be transferred into another owning container through that binding or
  an owned field projection. Extract an owner with `take` before transferring
  it; copyable fixed-storage values keep their ordinary value-copy behavior.
- The complete expression immediately before `-> each` determines the role's
  element type. In `receiver -> make(argument) -> each item { ... }`, `item`
  has the element type of `make`'s result; neither the receiver nor an
  additional argument may replace that source because of AST traversal order.
- Function declarations are currently expression bodies with either no input or
  one primary input plus explicitly typed additional inputs. A one-input
  function uses `it` when no input name is supplied, and uses the supplied name
  in `square n: Int -> Int { ... }`.
- An impl declaration with a typed primary input and no `self` is an associated
  function whose primary value is `it`; only an explicit `self` declaration
  defines an instance method. The typed-primary form has default ownership;
  `move` or `mut` requires `self`.
- A local function may omit its primary input type, return type, or both by
  leaving the corresponding signature slot empty: `map value: -> Int`,
  `map value: Int ->`, or `map value: ->`. A non-public top-level function may
  do the same only when exactly one function or `main` scope consumes it.
  Public, generic, impl, multiply-consumed, conflicting, and underconstrained
  signatures remain explicit.
- Path-qualified function declarations remain valid, such as
  `sys.io.print value: Text -> Unit { ... }`, but standard library source now
  prefers file-level `namespace` declarations.
- `= intrinsic` declarations are reserved for the standard library's lower
  runtime boundary.
  A resolved runtime intrinsic retains its intrinsic identity for both direct
  and flow calls. In particular, canonical `sys.file.borrowText` constructs a
  borrowed `SourceText` from the input pointer and length, with no owned mapping;
  it never requires a separately emitted ordinary function. An unrelated
  user function with the same leaf name remains an ordinary resolved call.
- Function declarations may appear at the start of another function body. These
  local functions are scoped to the containing function and nested functions
  below it; they are not visible from `main` or unrelated functions.
- A source file may declare one namespace before imports and function
  declarations. Top-level single-segment function declarations in that file are
  qualified by the namespace.
  The program entry keeps the namespace of its unique executable source when
  sources are combined. A source-level library alias and its imported native
  functions retain that importing module identity and remain internal; equal
  aliases in different modules do not share declaration identities.
  If an ordinary module import and a library import use the same alias in one
  source file, qualified references resolve through the ordinary module import
  first. Native export lookup must not capture those module references.
- Several explicitly supplied source files may declare the same namespace. They
  form one logical module: private top-level declarations and nominal types are
  visible across its files, while imports remain file-local. `Type.Variant`
  references and payload constructor calls resolve an enum declared in any
  fragment of that module. A lexical value with the owner's name retains its
  projection, and `alias.Type.Variant` follows the explicit import rather than
  a same-named local enum. An inherent
  `impl Type` may live in a different fragment from `Type`; its implicit
  `self`, field access, and direct method calls use the same canonical nominal
  type and ABI. Input paths are normalized and ordered deterministically;
  duplicate declarations across fragments remain compile errors.
  Namespace identity follows the parsed path segments, so permitted whitespace
  and comments around path separators do not create a different logical module.
- Method dispatch on a field projection uses the projected field's canonical
  receiver type, including reference unwrapping. A structural or array field
  does not inherit its containing nominal type's method owner. For example,
  `self.values -> push(value)` inside `Queue.push` selects the array operation
  when `values` is an array without an explicit matching implementation; a
  nominal field retains dispatch through its own declared type.
  A constructed receiver belongs to its constructed type; fields read inside
  its initializer do not become the receiver. Once the complete receiver type
  is committed, method lookup does not project the earlier lexical root again.
  An impl-method candidate found by an earlier name search must still match the
  actual receiver before it can override a collection operation.
  The same rule applies inside interpolation: resolve an instance method for
  the canonical receiver first, then a visible declared user/native function,
  then a spelling-based collection intrinsic. A selected method's visibility,
  ambiguity, or argument error does not permit fallback to a same-named free
  function. Commit the selected declaration before result and argument type
  inference, ownership checking, and emission; all consumers retain that same
  declaration and canonical receiver identity.
- Imports use the path's final segment as their default alias, so
  `import sollang.compiler.lexer` is equivalent to
  `import sollang.compiler.lexer as lexer`. An explicit `as` may select a
  different alias, such as `import sys.runtime as rt`. Default and explicit
  aliases share the same duplicate-alias diagnostic.
- A `sollang.project` manifest declares a required canonical SemVer 2.0.0
  `version`. Validation consumes the complete version value; trailing line
  breaks or whitespace are invalid. The manifest names the project and either
  one `root` source
  or a nonempty `products` map. The forms are mutually exclusive. Product roots
  are confined existing `.slg` files. `sollang build` searches ancestors;
  `--project` selects a manifest and `--product` selects among multiple products.
- A manifest may contain a `dependencies` map from an import-safe project name
  to an exact relative local directory or manifest path. The key must equal the
  referenced project's name, and that project must expose a same-named product.
  Graph traversal is ordinal and rejects cycles and one-name/multiple-path
  collisions. One source path cannot belong to different packages. A package
  may import only direct dependencies; transitive packages remain visible only
  to the package that declared them.
- A `sollang.workspace` manifest contains one nonempty `members` array of
  relative project directories or manifest paths. Member paths are confined to
  the workspace directory. Project names remain authoritative in each
  `sollang.project`; duplicate member paths or names are rejected. After loading
  and validating each project, canonical absolute manifest paths are compared
  with ordinal case-insensitive identity before package names are compared with
  ordinal case-sensitive identity. Members and the available-package lists in
  selection diagnostics are ordered by ordinal package name. The selected
  package's complete local dependency closure must consist only of declared
  workspace members. Build graph traversal starts with the selected package,
  then visits every remaining member in ordinal package-name order through the
  same canonical-path visited state. Dependency edges require the referenced
  package's same-named product. An independent member uses its same-named
  product when present, otherwise its first product in ordinal name order.
  The graph has no fixed package-count limit.
- `--workspace` selects a workspace and `--package` selects one member. A
  workspace with one member may omit `--package`; a multi-member workspace must
  not choose implicitly. A source-free build inside a declared member discovers
  the enclosing workspace and selects that member.
- Local modules resolve relative to the selected product root. The dependency
  name is its first module-path segment; a one-segment import selects its root
  product and deeper paths resolve beneath that product's source directory.
- Workspace package metadata includes every member, but compilation starts
  from only the selected product's root source and recursively loads its
  imports. Unimported member sources are not parsed and do not supply program
  entry points. Every loaded source retains its package identity and resolves
  imports through that package's own direct dependencies. A dependency root
  must declare the imported namespace and contain no executable top-level
  statements. Module import cycles are rejected.
  Source diagnostics preserve the lexical/parser boundary: lexical failures
  report their line and column without a file prefix, while parser failures
  include the loaded source path. A colon requiring a type reports Identifier
  when the type name is missing; a later missing array or block delimiter
  retains its own expected delimiter.
  Metadata input admission distinguishes an empty file from an open or read
  failure before mapping. An empty file reaches the JSON reader as the exact
  empty byte sequence and produces its missing-token diagnostic; it must not
  trigger the nonempty mapped-region trap. Workspace source loading and direct
  library catalog loading share this admission path. Catalog source owners
  retain original metadata bytes separately from owned decoded strings.
  Source library imports are checked after parsing and before namespace or
  dependency entry validation. Unsupported Wasm library imports are rejected
  before interface lookup; supported native targets report a missing interface
  at the library declaration location.
  Each library declaration consumes its statement terminator, so consecutive
  declarations are parsed independently. Native library imports are validated
  in declaration order: a repeated alias is rejected before that declaration's
  interface lookup, and an invalid earlier interface stops processing before
  a later missing interface. Semantic interface diagnostics retain the failing
  export and parameter identity independently of the JSON decoding cursor.
  Missing or null interface strings, export/parameter arrays, and their object
  entries are rejected as invalid interface data before ABI semantic checks.
  The diagnostic identifies the declaration location, interface path, and
  member path; malformed input must not surface as an unexpected null-reference
  failure.
  JSON field conversion and unmapped-property checks follow property order
  before required-shape and ABI validation. A missing schema value defaults
  to zero and is rejected by the ABI version check; a null root document is
  rejected as empty. Conversion diagnostics retain the complete JSON member
  path and zero-based source byte line/column.
  Typed field checks occur while the JSON reader consumes the value, before
  scanning later properties: a later incomplete document cannot replace an
  earlier conversion or unmapped-member error. Syntax diagnostics retain the
  active export/parameter path, invalid string control byte, and trailing-root
  data location.
- Default standard-library discovery walks ancestors of the selected source
  directory, then the current directory, then the compiler directory. The
  nearest directory containing both a `Sollang.slnx` file and a `stdlib`
  directory wins; incomplete marker pairs are skipped. Native build and test
  paths share this resolver and check a supplied standard-library directory
  before claiming generated build stages. Failure remains explicit.
- A manifest build without `-o` writes to `build/<product>` with the target's
  `.exe` or `.wasm` suffix where applicable. Explicit CLI options override only
  build settings, not manifest identity or root ownership.
- `--jobs <n>` accepts a positive `Int` decimal value and bounds compiler
  workers. Zero, signs, non-digits, missing values, and values above
  `2147483647` are rejected before generation. The C# Windows linker bounds
  concurrent optimization processes while retaining its small LLVM partitions;
  explicit CLI configuration takes precedence over `SOLLANG_NATIVE_JOBS`.
- A workspace build without `-o` writes to
  `build/<target>/<package>/<product>` under the workspace root, with the same
  target suffix rules. The workspace manifest is part of incremental input
  identity; deleting its disposable cache never changes source state.
- A manifest build keeps `sollang.lock` beside its project manifest; a workspace
  build keeps it at the workspace root. Path-package source locations are
  relative to that lock directory. With `--locked`, a missing lock is rejected
  before dependency traversal; after traversal, its contents must match the
  complete graph. Comparison normalizes CRLF to LF and leaves a matching file
  unchanged. Workspace builds and `resolve` create a missing lock. Without
  `--locked`, an outdated lock is replaced. Lock writes use UTF-8 without a BOM
  and a sibling temporary file followed by atomic replacement.
- Before claiming stages, the self-host native CLI checks that its final
  LLVM/executable paths and any derived semantic
  cache destination satisfy the file publication contract (1..259 UTF-8 bytes,
  without embedded NUL). Unsupported paths fail before frontend or link work.
  It exclusively claims two short sibling staging paths
  for LLVM and the linked executable. A later build skips an occupied pair
  left by a crashed process rather than deleting paths it does not own; after
  256 occupied pairs it fails explicitly. A failed frontend or link removes its
  claimed stages before returning and does not publish a new final product.
  Successful stages are published with `sys.file.atomicReplace`; publication
  is per file, not an atomic transaction across the LLVM and executable pair.
  A staging claim, cleanup, or publication failure is reported explicitly.
  Known lexical, parse, and semantic frontend failures use the emitter's
  diagnostic-only stdout stage. The native CLI relays those diagnostics once
  to stderr, removes its claimed stages, and omits a retained-stage message.
  An empty stage or an arbitrary nonzero child exit does not establish a known
  frontend diagnostic; unexpected emission failures retain their diagnostic
  evidence. Standalone syntax diagnostic APIs continue to write to stderr.
- A native build claims exclusive sibling lock files for both final resources:
  the executable path and its `.ll` path. It claims them before staging and
  holds them through publication, so builds targeting the same output or a
  cross-output pair such as `foo` and `foo.ll` cannot publish concurrently.
  A conflicting claim fails with a diagnostic before staging. The build removes
  only locks it claimed; a lock left by a crashed process fails closed until
  that stale lock is reviewed and removed.
- Before claiming those stages on Windows, the self-host native CLI checks both
  final output paths. It rejects drive-relative paths, empty names, trailing
  dots or spaces, the reserved staging-lock suffix, aliases of differently
  named existing files, and existing directories or other non-file objects.
  An unresolved path is accepted as absent only after its parent directory can
  be inspected and the requested name is not present; an unresolved short-name
  pattern is rejected. These checks precede the first staging file effect.

## Bindings

The preferred binding syntax is:

```sollang
"dimohy" => name
n * i => value
```

There is no `let`, `var`, or declaration keyword.

Initial binding rules:

- `expression => name` introduces an immutable binding.
- `expression => name!` introduces a local mutable owner binding. The `!`
  suffix is part of that local binding and its rooted accesses; it is not added
  to an input parameter declared with the `mut` ownership mode.
- An immutable binding initialized from a mutable binding read adopts the
  mutable slot's final contextually inferred type. It cannot retain an earlier
  provisional numeric-literal type after the slot has converged.
- Name-first `name = expression` is not part of Sollang; every binding uses
  `expression => name`.
- A binding is visible after its declaration statement.
- A binding statement does not supply a block result. An empty block or a block
  ending in a binding without a final value expression has type `Unit`; the
  binding itself retains its inferred or declared storage type. This also applies
  to `when` and `if` arms used for mutable rebinding.
- Referencing a binding before declaration is a compile-time error.
- Reusing the same name in the same scope is a compile-time error for now.
  A transfer that consumes the complete old binding may reuse its name for the
  returned owner. Dependent receiver calls must finish semantic refinement before
  this decision: selected callees, argument bindings, and ownership facts refer
  to the same completed call context. Moving one owned field leaves its source binding live for
  sibling-field access and cleanup; the moved field cannot replace that binding
  under the same name.
  Transferring an owned field into an array or dictionary checks live borrowed
  views and readonly references against that exact field place. A live loan
  from a disjoint sibling field does not prevent the transfer.
  Constant integer index places are identified by numeric value, not literal
  spelling: `0`, `00`, `0_0`, and `-0` identify the same element. A live loan
  from that element prevents its mutation or transfer through any such spelling.
- Mutating container operations require a mutable owner binding with a `!`
  suffix.
- A mutably borrowing call remains in that same ownership context when its
  result becomes the source of a following `->` pipeline target.
- Type inference determines the binding's type from the initializer.

The compiler also reports style diagnostics where inference proves a narrower
source form without changing semantics:

- S001: a numeric constructor repeats the type already supplied by context;
  in a numeric binary expression, an independently typed operand establishes
  the type for a literal conversion on the other side. Two explicit literal
  conversions keep the left as the type anchor and report only the redundant
  right conversion. A bare numeric literal is contextual and does not make the
  opposite explicit conversion redundant. A declared numeric call parameter
  supplies context to a bare numeric literal, including literal-valued `if`
  branches. The same range check applies to ordinary and instance calls:
  integer and character literals must fit the declared parameter type, and an
  out-of-range literal reports its value and destination bounds. Negative zero
  fits an unsigned destination because its value is zero. An explicit literal
  conversion to that same parameter type reports
  S001; a conversion to a different numeric type is a parameter type error.
  Warnings in interpolation fragments use positions relative to the fragment's
  expression source;
- S002: a `name!` binding is never mutated and should be immutable. Operations
  that require a mutable owner, including a mapped-view `flush`, count as
  writable uses even when they leave the view's bytes unchanged;
- S003: straight-line construction gives a growable array one exact final
  length, so a fixed array value should be used. A `push` reached through an
  `if`, `unless`, `when`, or loop does not establish an exact final length. The
  warning is also suppressed when a downstream parameter requires the
  growable-array type, because the proposed fixed-array rewrite would not
  satisfy that contract.
  The same rule applies when a named owner is transferred into an indexed
  array or dictionary element whose declared value type requires a growable
  array. The stored value must still satisfy that exact element type.
  A declared growable function or method result likewise suppresses the
  warning for its returned owner, including an explicit return. Synthetic
  input and `self` symbols do not replace the enclosing declaration's result
  contract when they share its AST node.
  Selected owning `append` and `updated` intrinsics also require the source
  array's growable type and suppress this warning for that declaration.
  Intrinsic `capacity` observation and `reserve` likewise require growable
  storage, including when the operation occurs inside interpolation. A declared
  function with the same spelling follows its selected parameter contract.
  Each fresh declaration has its own construction state. Reusing a name after
  transferring its former owner does not carry the old owner's length or
  downstream growable-type requirement into the new owner, and does not erase
  a warning belonging to the earlier declaration.
  Only a selected container intrinsic changes the construction length. A
  declared function with the same name retains its own type and effects.
- S004: an `if` has an empty success branch and only performs work in `else`;
  use `condition -> unless { ... }`.
- S005: a never-mutated `name!` binding cannot become immutable by merely
  removing `!` because the resulting name is reserved; rename it to a
  non-reserved immutable binding.

S006 is a blocking compiler-integrity diagnostic rather than a style warning.
It reports that a value-producing typed-IR node reached LLVM allocation, load,
or store selection without a canonical storage type. In particular, every
non-empty array literal must be classified as fixed, growable, or bounded
before LLVM emission. S006 must be fixed in semantic typing or typed-IR
projection, never silenced by changing valid Sollang source to a wider type.

S007 is also a blocking compiler-integrity diagnostic. It reports that a
non-empty array's canonical element type disagrees with the type of its first
lowered direct operand. Nested literals inside an element flow do not determine
the array type. Header-layout compatibility is not sufficient: element
identity must remain consistent for indexed access, ownership, drop behavior,
and ABI selection. S007 must be fixed in semantic typing or Typed-IR lowering.

S008 is a blocking compiler-integrity diagnostic for integer arithmetic whose
semantic result width differs from the physical width selected from its lowered
operands. A bare literal paired with an independently typed integer operand
inherits that operand's exact type; for example, `UInt16(value) / 16` is an
i16 operation. Runtime printing widens UInt8 and UInt16 values to the i32 print
ABI explicitly. S008 must be fixed at contextual typing or Typed-IR lowering,
not hidden with a source constructor or backend signature mismatch.

S009 is a blocking compiler-integrity diagnostic for a scalar binding whose
initializer is an unresolved name that is neither a local binding nor a
parameter of the owning function. Function parameters use signature-owned ABI
names (`%arg`, `%arg1`, ...), so immutable aliases of parameters are emitted
through the shared parameter-reference path rather than an invented `%v` SSA
producer. S009 must be fixed in name resolution or ABI-aware value lowering.

S010 is a blocking compiler-integrity diagnostic when an inverse guard's AST
operator identity and Typed-IR opcode disagree. LLVM branch polarity is shared
by entry, named-function, and nested control-region emitters for both direct
and short-circuit conditions. An `unless` body executes only on the false
condition edge in every scope.

Enum `when` completeness is a semantic decision made from the resolved subject
type and source patterns before Typed IR lowering. Without an `else` arm, a
missing variant is reported at the `when` token with its qualified enum and
variant name. Multiple missing variants follow declaration order. Nominal enums,
`Option<T>`, and `Result<T, E>` share this rule; generated arm counts do not
establish coverage.
Pattern payload inference and coverage share the same source subject and arm
ownership. A retained subject-condition wrapper between an explicit enum
pattern and its arm does not change either identity.

S011 is a blocking compiler-integrity diagnostic when a true enum subject
pattern does not lower to an enum-constructor operand. The validator identifies
an enum pattern by the explicit `EnumPattern` AST child, not merely by the
shared subject-condition wrapper; numeric and relational subject conditions
must remain ordinary binary operations.

S012 is a blocking compiler-integrity diagnostic when a subject `when` control
has no canonical subject operand. Final Typed-IR projection recovers the
nearest preceding canonical integer sibling in the same block when recursive
lowering placed that subject outside a nested control slice, then attaches it to every
relational arm. A block result link only forwards a value when the block itself
is consumed; arm-to-body and unused block-tail links are control structure.

S013 is a blocking compiler-integrity diagnostic when a relational subject arm
has no canonical left operand. Final Typed-IR projection repairs each arm from
its explicit arm-to-control parentage rather than assuming every arm remains
reachable from a sibling chain. The kind-59 AST child keeps enum patterns out
of this binary normalization.

Numeric subject range conditions accept expression bounds, including names,
member reads, and calls, without additional grouping. A complete range
condition takes precedence over an enum-pattern prefix. The subject is read
once before arm selection. Each reached range arm evaluates its lower bound
then its upper bound once before combining both comparisons; a false lower
comparison does not suppress upper-bound effects. Reference-backed scalar
subjects and bounds use their canonical scalar reads without changing the
reference storage ABI.

S014 is a blocking compiler-integrity diagnostic when a member-read node has no
canonical base operand. A resolved field type alone is insufficient: ownership,
addressing, and emitted loads require the exact parameter, local, or enum
pattern payload origin. When recursive lowering omits a payload name node, the
member reconnects to the unique kind-29 pattern binding owned by its enclosing
enum arm; spelling and type compatibility are not used as substitutes.

S015 is a blocking compiler-integrity diagnostic when an ordinary binary node
has no canonical right operand. Both operands must be present and ordered by
their source AST before LLVM selects comparison or arithmetic instructions.
Nested-call recovery may use only an exact same-parent predecessor or direct
continuation edge; it must not guess an operand from a compatible nearby type.

Expression materialization follows one cross-implementation contract:
syntax shape determines that an expression or control value exists before its
concrete type is available. Every concrete managed `Expression` subtype has
exactly one schema-validated mapping to its self-host AST kinds, expected Typed
IR roles, and materialization policy. The managed compiler preserves the
corresponding expression object through semantic inference and emission; the
self-host entry and ordinary-function paths consume the same centralized base,
contextual, and control-shape policies and seal types and operands in later
passes. They must not use provisional type-table membership to decide whether
to create a value or independently maintain AST-to-Typed-IR kind tables.
S059 is a blocking compiler-integrity diagnostic when a binding has a binary
initializer AST but no corresponding binary Typed IR producer. Consecutive
binary AST nodes are transparent wrappers only when their source spans are
identical: the deepest same-span binary descendant is the canonical producer
and the first different-span or non-binary ancestor is its owner. This coverage
rule applies only to nodes that own an operator token. Angle brackets inside an
exact `TypeAnnotation` span, including the type prefix of a generic enum
constructor, and the balanced outer clause of a `TypeApplicationExpression` or
pipeline `FlowGenericArgument` are generic delimiters, not comparison operators.
The call-argument span begins after that outer clause, so comparison operators
inside arguments retain ownership.
Any surrounding comparison grammar envelope with no remaining operator is
omitted from the self-host AST. The coverage check runs before
LLVM generation and uses
source-global linear indexes rather than rescanning the complete AST for each
binding.

A sequential named branch lowers to a labeled product whose fields are the
final values of its arms. The flat self-host Typed IR represents each arm with
a kind-39 value node whose `operand1` is its final stage, followed by the
kind-37 product node. Entry bodies, ordinary functions, and nested control
regions must all materialize those two steps through the same emitter
authority. A context-specific copy may not omit the arm SSA definition or
substitute the wrapper index for its final value. Parallel branch arms remain
owned by the compute callback path and are not materialized by this sequential
authority.

A following flow target consumes the completed branch product. A transparent
flow wrapper preserves that product's canonical type and value identity; it
does not substitute the branch's original source value.

A parallel named branch lowers its kind-38 node through one shared runtime
materializer after its callback has been prepared. That materializer owns the
capture environment, compute-group execution, and result-product load for
entry bodies, ordinary functions, and nested control regions alike. Those
contexts may not carry independent copies of the compute-group sequence.

Range values use the same kind-31 materializer in entry bodies, ordinary
functions, and nested control regions. The shared operation owns inclusive and
exclusive-end normalization and the two-field product construction; an
emission context may not reconstruct that value independently.
All `Int` endpoints are valid. A half-open range ending at the minimum `Int`
is empty. Its inclusive predecessor cannot fit in `Int`, so its first-class
two-field value uses the canonical empty bounds `start = 0`,
`endInclusive = -1`. Other endpoint normalization is unchanged. Inclusive
`each` and `fold`, including an `each` body that suspends, visit the maximum
`Int` endpoint once and then terminate; an internal cursor must not wrap back
into the range. The same finite cursor rule applies to a positive `Int`
`repeat` count; zero repeats execute no body.

A stream pipeline nested inside a control region uses the same scheduled stream
body as a top-level entry or ordinary function. The enclosing region emits the
pipeline source first, then delegates the terminal and deferred callbacks in
their regional order. Fused stage-call nodes belong to that pipeline and may
not be emitted again by the outer region. Function mutable slots are allocated
once by the owning body schedule; nested delegation must not allocate them a
second time.

Within a stream pipeline, blockless `take(count)` and `skip(count)` calls retain
stream-stage Typed IR identities (`-275` and `-276`) even when the AST places a
synthetic flow node beneath the enclosing call. Entry and ordinary-function
lowering must classify that nested form consistently and link its operands
before stream planning. An array or dictionary `take` remains a collection
mutation (`-213`) and still requires canonical writable owner storage.
The managed compiler normalizes blockless stream stages from the source of
every block call, including calls after an earlier map or filter block. It
retains parsed call identities and publishes the normalized consumer to LLVM
emission; semantic validation alone must not discard those stages at emission.

The terminal `each` callback role may remain type-deferred in Typed IR even
after the preceding stream stage has a concrete value type. LLVM emission
matches that role by its terminal binder identity, materializes its SSA value
from the current stream value, and uses the current value's canonical LLVM
type. A deferred role type must not suppress the definition; a known distinct
role type symbol must not be silently coerced.

Sequential diagnostic Typed IR and production function-parallel Typed IR must
preserve contiguous function ownership after late await materialization. A
synthesized await remains in the function containing its parent and producer;
appending it to the joined arena must not transfer its effect to the final
entry function. Reordering uses one permutation for `parent`, `operand0`,
`operand1`, and `nextOperand`. Generic call and function indexes use that same
permutation before function bindings are published; interpolation indexes and
semantic type indexes retain their own identities. Repeating this ordering
step leaves the arena unchanged.

Late direct-await materialization updates every consuming value edge, including
the terminal result edge of a function body. These consumers share one joined
value; a function returning `T` must never select the pre-await `Task<T>` producer
as its result merely because that producer retains the payload type metadata.

Sequential diagnostic Typed IR and production function-parallel Typed IR must
have identical ordered node inventories for the same prepared source set.
Compiler verification compares both modes directly; the presence of an
emitter-only invariant diagnostic is not by itself evidence that parallel
lowering lost a node.

S016 is a blocking compiler-integrity diagnostic when a conditional node has
then/else structure but no canonical condition operand. LLVM lowering must not
silently omit such a conditional. A pipeline condition may be restored only
from its exact same-parent continuation predecessor, never a nearby value.
S017 is a blocking compiler-integrity diagnostic when a member base's canonical
nominal owner cannot be mapped to a source range. Member projection resolves
the recursive semantic `typeId` first and never indexes source tables from
stale legacy module metadata. Missing or non-nominal canonical base identity is
the same S017 failure; legacy type fields are not an accepted substitute.

S018 is a blocking compiler-integrity diagnostic when an enum `when` match does
not retain a canonical `Option`, `Result`, or nominal enum subject. LLVM enum
lowering must never extract a tag or payload from a container, struct, stale
wrapper, missing operand, or untyped value even when shallow execution happens
not to expose the mismatch.
An exact unique `(origin, module, symbol)` nominal match may canonicalize a
legacy binding into `typeId`; ambiguity is never resolved by first-match order.

S019 is a blocking compiler-integrity diagnostic when a value-producing enum
match has an arm without a canonical result value. The compiler rejects this
Typed IR before value-use analysis or LLVM emission can reference an undefined
match SSA value.

S020 is a blocking compiler-integrity diagnostic when an enum match subject is
a name with neither a same-module parameter ABI identity nor a concrete
producer link. Symbol ordinals are module-local, so a coincidentally equal
ordinal from another module cannot justify emitting an undefined `%vN`.

S021 is a blocking compiler-integrity diagnostic when an enum match subject is
a transparent flow wrapper, return, declaration, control-transfer, or region
node. Those nodes never
materialize an LLVM value; stale contextual enum typing cannot make them valid
subjects. When a value producer shares their AST position, the producer is the
canonical subject.

S022 is a blocking compiler-integrity diagnostic when a value-producing enum
match arm result type differs from the match result type. The match slot uses
the declared function or enclosing value context, and an arm pipeline retains
its final constructor or transformation rather than its initial payload.

S023 is a blocking compiler-integrity diagnostic when a value-producing enum
match arm retains a transparent, non-SSA parser wrapper rather than its
concrete producer. An existing canonical arm result, including a logical
short-circuit join, is authoritative. Standard generic enum flow targets such
as `value -> Result<T, E>.Ok` are semantically rewritten to constructors in
both the surface and CST-backed compiler paths.

S024 is a blocking compiler-integrity diagnostic when a value-producing `if`
has a then or else region without a concrete result value. This is rejected
before LLVM result-slot lowering can index an absent IR node.

S025 is the mandatory result-store boundary diagnostic for every
value-producing control. It reports an invalid concrete source index with its
control and branch identity rather than permitting an emitter bounds crash.

S026 is a blocking compiler-integrity diagnostic when an enum payload binding
type differs from its matched variant's canonical payload type. Repair and
validation apply to stale non-negative ids as well as missing ids.

S027 requires direct fixed or bounded array return literals to inherit the
function's canonical array identity. S028 requires array-valued nominal struct
field initializers to match the declaration's exact dynamic, fixed, or bounded
shape before ABI lowering.

S029 requires a fixed repeat literal `[value; N]` to carry static length `N`,
not the count of lowered seed operands. S030 rejects a terminal `?` binding
that retains the enclosing `Result` instead of its success payload. S031
rejects an unresolved dotted member type once its nominal, field-bearing base
is canonical.

S032 is the mandatory index-assignment boundary diagnostic when an array
target has no canonical element type. Fixed arrays participate in the same
element query as dynamic and bounded arrays. A fixed repeat literal allocates,
stores, and reports its static repeat length rather than its single seed-operand
count, including when the literal is emitted inside a `while`, `if`, or `when`
region.
An expression-bodied enum-match arm computes its result from the final direct
arm expression after pattern and payload binding whose canonical type equals
the arm result type. The payload binding is only the arm input; it is not an
implicit replacement for transformations such as `Err(error) => -error`, and
an unrelated nested enum producer cannot replace an enclosing scalar result.
Struct literal ABI selection uses the literal's canonical nominal owner id.
Legacy nominal coordinates are consulted only when that id is absent.
S033 rejects a nominal struct literal whose id has no fields while a
coordinate-equivalent canonical identity owns the declaration field table.
S034 guards the final struct emitter when a field position cannot resolve by
the declaration's explicit ordinal.
S035 guards the equivalent control-region emitter boundary. Struct literals
inside control arms use the canonical owner id, explicit field ordinal, and
the same fixed-array pointer-and-length field ABI as function-body literals.
Fixed-array fields store a `{ptr, i64}` value; their element backing is
separate from the containing aggregate. On the supported native64 and wasm32
targets, this descriptor occupies 16 bytes with 8-byte alignment, including
wasm32 padding before the 64-bit length. Struct field offsets, enum payload
storage and boxed aggregate allocation sizes use this descriptor layout;
element backing sizes remain separate. Collection element alignment follows
the element's ABI alignment, independently of its byte size. A three-byte
aggregate of `UInt8` fields aligns to one byte; a twelve-byte aggregate of
`Int` fields aligns to four bytes. Arrays and dictionary entries use the same
canonical rule for element loads, stores, offsets, and strides.
A fixed literal nested in a struct or
product owns heap backing, and copying a fixed-storage aggregate creates
independent backing for each fixed field. Member projection reads the field
carrier with the canonical static length. S036 rejects that projection when
element or length metadata is not canonical.
Binding a copyable fixed scalar array or fixed-storage struct from a named
value or a named field projection creates independent backing, including a
projection through a borrowed struct reference. The copy decision uses the
projected field type even when its containing struct also owns noncopyable storage;
unrelated owned fields retain their existing borrow and transfer rules.
The copy owns its cleanup; the source retains its
original lifetime. Function bodies and nested control regions apply the same
copy decision and read the resulting copied value.
Placing a copyable fixed-storage name or field projection in a struct or
product initializer does not record a move of its source. Storage/drop
responsibility and the field's value-copy decision remain separate. Explicit
move parameters and owning enum or collection payload transfers keep their
transfer semantics; fixed arrays with owned enum elements are not scalar copies.
An enum match whose every arm returns terminates its enclosing region. S037
guards the match-result boundary against re-emitting a constructor already
defined in a nested arm, which would duplicate an LLVM SSA name.
Fixed-array success payloads extracted by `?` follow the same storage/value
boundary as struct fields: the payload is inline in the enum, while the bound
expression is `{ptr, staticLength}`. S038 rejects missing canonical metadata.
Empty contextual slice views emit `{null, 0}` even though they have no
element operands. A fresh literal used as a borrowed call argument instead
owns temporary backing for the duration of the call, including when empty:
it allocates at least one element's storage, keeps its logical length zero,
and the caller releases that backing after the call. Function, entry, and
control-region emission use the same temporary ownership contract. S039
rejects an empty literal whose array ABI remains unknown at the emitter boundary.
Subject-style `when` controls cannot be their own comparison subject. Late
Typed IR canonicalization repairs either a missing or self-referential subject
from the exact preceding integer producer in the same region. S040 guards that
invariant at the LLVM boundary before an undefined `%vN` can be referenced.
Every non-enum subject arm is then synchronized to that canonical subject even
when both operands are already populated. S013 rejects a stale left operand,
not only a missing one.
Binding/control aliases and arithmetic values must preserve one canonical LLVM
storage class through final Typed IR. S041 rejects stale aggregate projections;
S042 and S044 reject scalar receivers for `len` and `capacity`; S043 rejects a
dotted member whose base crosses its structural source span or becomes scalar.
S045 rejects a partition route product unless every field preserves the exact
canonical `Stream<T>` or `EventStream<T>` wrapper of the partition source.
N001 is a source-style note, not a warning: a control condition whose source
spelling is 45 or more characters and still shares a line with `if`, `unless`, `while`, a
standalone `when` arm, a `partition` predicate, or `if break`/`if continue`
should move the condition to its own line and keep `->` with the control
keyword. Short `and`/`or` conditions stay inline. User sources may keep the
note; repository sources wrap those lines. Qualified semantic names do not
inflate the source-style length. `sollang format` wraps inline `if`, `unless`,
and `while` conditions using the same lexical boundary.
Formatting treats ordinary and raw string contents as literal data. Control
arrows inside those literals do not select code-layout rewrites; formatting
must preserve the literal value.
Trailing spaces and tabs on nonblank raw-string content lines are part of
that value; indentation adjustment must not trim those suffixes.
Indentation shifts leave empty raw-string lines empty. When reducing indentation,
remove at most the shift width from the leading Unicode whitespace, counting
UTF-16 characters rather than UTF-8 bytes.
N002 is a source-style note for redundant parentheses around an entire
single- or multi-line `if`, `unless`, or `while` condition. Write
`ready and active -> if {` rather than `(ready and active) -> if {`.
Parentheses that group only part of a condition remain significant and are
not reported. `sollang format` removes only the redundant whole-condition
pair even when its opening and closing tokens are on different lines.
Diagnostic module names come from the source's top-level namespace declaration.
Comments, string contents, and declarations inside a body do not establish a
module name. LF, CRLF, and CR line endings preserve the same namespace identity,
and trivia between dotted path segments does not appear in the diagnostic name.
Regular value transformations bind as logical and comparison operands, while
control-flow targets consume the completed condition. Therefore
`ready and text -> predicate -> if { ... }` means
`ready and (text -> predicate)`, and `text -> len < limit` means
`(text -> len) < limit`, without redundant grouping parentheses. Control and
junction targets such as `if`, `while`, `when`, `branch`, and `partition`
remain at the outer flow precedence.
Fixed-point inference treats a preceding `Range` or other provisional type as
unresolved and updates an already-recorded partition expression when the
canonical product becomes available.
Flow intrinsics are recognized only from top-level identifiers after `->`.
Therefore a local named `capacity` is an ordinary binding, and numeric slice
bounds are written as literals rather than referenced as nonexistent SSA values.
LLVM integer constants never preserve source digit separators. All scalar,
container, index, capacity, interpolation, and control-region literal paths use
the shared canonical integer writer; booleans use `1` and `0`.

E20 partial-move joins track only bindings live across the branch join or loop
back-edge. Later reads include the enclosing block result and arguments or
operands evaluated after the branch in the same value-flow expression. Returning
an owned field as a branch value does not consume live sibling fields or erase
the owner before these reads. A binding introduced inside an arm/body is dead at region exit and
does not require artificial field reinitialization.
The same scope boundary applies to borrowed-view liveness at an owner move:
an earlier use of a loop-local view does not keep that view live across the
next iteration. Actual later uses and loans retained outside the loop still
prevent the conflicting move.
Function scopes can own cleanup and participate in complete-move analysis, but
they are not control regions. A termination query applies only to a nested
control region; it must not climb through a function owner's `-1` parent as if
that parent were another function boundary.
Ordinary explicit numeric generic applications include the normalized integer
value in concrete body identity, independently of the runtime input type.
Digit separators and leading zeros do not create distinct value identities.
Different explicit values remain distinct when their concrete types coincide.
The call target owns its generic clause; comparisons in ordinary arguments
or preceding flow inputs do not supply value-generic arguments.
A value parameter constrained by `where N: Int` has type `Int` in body
expressions, including conditional results, before IR specialization.
An explicit integer value argument belongs to the concrete function's
compile-time binding environment. Specialization substitutes that constant
for resolved body names and symbolic fixed-array extents, including array
repeat counts and names inside interpolation or control expressions.
Value parameters do not occupy runtime signature slots, and callers do not
append their numeric generic arguments to the runtime argument list.
Calls inside interpolation use the same target-owned value identity and
body specialization as ordinary calls.
The mutable-container ABI carrier is declared from
actual mutable-parameter use independently of dynamic-array use, because fixed
arrays have no capacity field and therefore pass their canonical two-field
value by pointer; growable and bounded carriers use the three-address form.

Fixed-array type annotations accept a numeric or generic length: `[T; N]` and
`[T; Length]`. Bounded inline storage remains the distinct `[T; <= N]` form.
The generated grammar must retain the numeric alternative even though array
expressions have their own repeat and bounded-storage alternatives.

Numeric separators are source syntax and are removed when an integer literal
is printed into LLVM text. An underscore is valid only between two decimal
digits; an empty spelling and a leading, trailing, or consecutive underscore
are rejected before LLVM emission. Resolved integer call arguments are converted to the
declared parameter width before the call with signedness-aware extension or
truncation. Integer return literals have no SSA producer; the emitter prints
them directly using the declared return type instead of creating a conversion
from an undefined `%v` value.

Warning locations retain their originating module and survive exact frontend
and semantic incremental-cache reuse. Dedicated regression fixtures may assert
a warning; ordinary standard-library and release builds are expected to have
none. Mutable-use tracking is declaration- and lexical-scope-aware: mutations
in a function's final expression belong to declarations in its preceding
statement body, while a same-named declaration in another scope remains
independent.

Semantic body reuse restores module-scoped `Option` and `Result` constructor
type spellings as well as canonical binding shapes and resolved function calls.
This includes payload-free variants. Changing the executable call graph must
not make an unchanged, previously checked constructor unresolved when its body
is lowered for the first time after reuse.

This keeps the smallest program easy to read while avoiding hidden mutation
semantics before the memory and value model are decided.

## Function Inputs

The first function input is the fluent subject. Additional runtime inputs are
declared after it and supplied positionally in parentheses:

```sollang
square: Int -> Int {
    it * it
}

square n: Int -> Int {
    n * n
}

weighted value: Int, scale: Int, offset: Int -> Int {
    value * scale + offset
}

7 -> weighted(3, 2) => flowed
weighted(7, 3, 2) => direct
```

When the input name is omitted, the function body receives the value as `it`.
When the input name is supplied after the function name, the body receives the
value through that binding. This mirrors `start..end -> each { ... }` and
`start..end -> each item { ... }`. In a direct call every runtime input appears
inside the parentheses. In a fluent call the value on the left supplies the
first declared input, and the parenthesized arguments supply the remaining
inputs in declaration order.

Each input independently accepts the existing readonly, `mut`, or `move`
ownership mode. Compile-time generic parameters remain in angle brackets and
are not counted as runtime inputs. Additional runtime arguments are statically
checked for count, type, ownership, and duplicate parameter names.
For a type containing owned storage, a readonly or `mut` input borrows the
caller's owner; its name does not authorize an ownership transfer. Passing that
borrow to a `move` input is a blocking error for fluent calls, direct calls,
and additional runtime arguments. An explicit `move` input or a local owned
binding can transfer ownership, subject to the existing affine checks.

`mut` is an input ownership mode, not an identifier suffix. Inside the callee,
a named mutable-borrow input is spelled with its bare declared name, and
`mut self` is spelled `self`. The `!` suffix remains on the caller's local
mutable owner expression supplied to that input. Thus an input declared
`values: mut [T; ~]` uses `values -> exchange(...)` in its body, while its call
site passes `values!`.

An ownership, lifetime, scope, or affine violation that can be proven from the
program is a blocking compile error. Diagnostics identify the offending owner
and give a source-level repair: transfer through `move`, retain a borrow, use a
consuming operation such as `take`, use the returned replacement owner, or make
an explicit copy when the type supports one. Reusing a value after a consuming
call never falls through to generated code where it could become a double drop,
use-after-free, or heap corruption. Conversely, malformed LLVM or invalid drop
state produced from valid ownership-correct source is a compiler-integrity
error, not a user-source error.
For every statically provable source error in this safety class, the compiler
diagnostic states both the violated contract and at least one concrete Sollang
repair form. A compiler-integrity error does not invent source advice: checked
emission stops and identifies the compiler boundary that failed.
Checked self-host emission applies blocking diagnostic S051 to every mutating
collection intrinsic whose receiver has no canonical writable owner. It guides
readonly source toward `name: mut Type`, `mut self`, or `=> name!`. If a
writable projected intrinsic has no implemented canonical member-storage path,
verification failure V002 stops emission without inventing source advice. This
separates a repairable source ownership error from a compiler-integrity defect
before invalid field storage or heap corruption.
Builtin console effects are ordered effects even when Typed IR materializes the
call as an expression. Checked emission accepts only the canonical ordinary or
materialized forms. Verification failure V003 stops before LLVM when a builtin
console symbol has any unsupported representation and directs compiler
maintainers to update the shared predicate plus entry-point, named-function,
and nested control-region consumers; valid user source is not rewritten to
compensate for an incomplete emitter.
Verification failure V004 runs after LLVM text generation but before `llvm-as`.
It lists direct `sollang_m*_s*` calls that have neither a definition nor a
declaration. This is an internal emitter reachability or closure defect; valid
user source is not rewritten to hide it.

A value-producing enum `when` arm may itself be a value-producing `if` or
`when`. The arm result is the nested control's merge value. Selecting a value
defined in only one branch is invalid lowering because it does not dominate the
arm result store; valid source is not required to rewrite the expression into a
temporary binding to compensate.

An indexed value passed to a readonly reference parameter preserves its
canonical addressable place from reference-argument preparation through call
writing. Re-canonicalizing the argument and selecting its loaded value is
invalid lowering because the call would no longer name the emitted indexed
place.

An invalid readonly reference argument reports a semantic error at the
argument expression's diagnostic location, with its source module and called
function name. Field and index expressions use the dot and opening bracket
locations respectively. A backend diagnostic comment or a raw byte offset
does not replace the source diagnostic.
A move or mutation that conflicts with a live readonly reference reports the
originating owner place and the live reference name at the mutation target or
consuming argument. Assignment diagnostics point to the destination owner name.

## Structured Async Functions

`async` is a function effect written immediately before the result type. Calling
an async function starts a child task and returns an affine `Task<T>` owner;
flowing that owner to `await` consumes it exactly once and produces `T`:

```sollang
square value: Int -> async Int {
    value * value
}

main {
    20 -> square => first
    22 -> square => second
    first -> await => a
    second -> await => b
}
```

When no concurrency is needed, the temporary task can be awaited directly in
the same left-to-right flow:

```sollang
6 -> square -> await => squared
```

Naming multiple task-producing calls starts concurrent children. Flowing a
call immediately into `await` expresses sequential suspension without an
otherwise unnecessary task binding.

Tasks are structured resources, not detached handles. Every task must finish
before its lexical scope exits. An explicit `await` chooses where its result is
needed; otherwise scope cleanup joins the task and discards the result. A task
cannot be awaited twice or used after `await`. `main` is the implicit root async
scope, while other functions must declare `async` before using `await`.
Consumption applies to the complete flow, so `pending -> await -> decode`
releases `pending` exactly once even though a later target transforms the
awaited value. Lexical cleanup must not join or release that task again.
A borrowed source used to create a later Task remains owned by its original
scope: awaiting that derived Task does not consume the earlier source.
Linear and tail awaits preserve the same per-suspension input and local-owner
state as awaits inside control flow, for both resume and cancellation.
Explicit `return` statements inside an `async` function are currently rejected
before their values are lowered; use the supported final-value or tail-await
form for its result.

The Windows x64 and Linux x64 runtimes represent every task with the same
two-pointer value while an owned task-control record stores its context,
resume/destroy entries, ready-queue link, lifecycle status, and resume state.
The heap context stores input and result slots specialized for their exact
types. Scalar values, immutable `Text`, and value-only structs/enums are
structurally sendable and need no annotation. Heap-owning arrays, dictionaries,
structs, enums, and boxes cross into an async worker only through a `move` input;
the task becomes their sole owner. Mutable borrows and borrowed views are rejected
because the caller could otherwise access the same storage while the worker runs.

The ordinary task-control record also stores the result address and completion
callback needed when a task's originating worker is no longer statically known.
On the native x64 targets its LLVM record occupies 160 bytes and the runtime
reserves 168 bytes for that control allocation. These are separate bounds.
When diagnostics are enabled, a typed view of the ordinary record and its
reserved eight-byte tail retains the producer's diagnostic-header pointer.
Copies, result payload projections, and coroutine spills preserve this pointer
through the Task owner; consumers must not reconstruct the header location
from a statically guessed worker, input type, or additional parameter layout.
Diagnostic tracking uses the same ordinary control layout; disabling diagnostics
emits no diagnostic session storage, calls, or allocations. The exact baseline
layout, reservation, and allocation audit are retained in
`scripts/contracts/async-task-observability.json`.

A Task owns its control and context even when its result is `Unit` or another
scalar. The compiler-owned `DiagnosticSession.track<T>` intrinsic requires
`T` to be a Task, consumes that exact owner, and returns the same Task type in
both the success and failure payloads. Scalars and owned containers are not
accepted as tracked tasks; rejected calls do not consume their input.
Invalid `await`, `cancel`, and `track` contracts report the operation's source
position and active module. A generic `track` rejection identifies the caller,
not the intrinsic's declaration. Checked CLI failures relay the complete
semantic diagnostic and remove diagnostic-only staging files before returning.

`Unit`, numeric,
`Bool`, `Text`, dynamic array/dictionary, struct, enum, and `box` results cross
the task boundary without erasing their type. Owned results transfer to the
awaiting scope; if a task leaves scope unawaited, cleanup joins it and drops the
result before freeing the context. If native worker creation fails, a moved input
is dropped before its context is released. The LLVM emitter calls the common
`sollang_task_start`, `sollang_task_join`, and `sollang_task_release`
runtime boundary. Both native targets now use one cooperative FIFO ready queue;
`await` pumps ready work until its affine target completes, and release invokes
the context destroy entry exactly once. There is no OS thread per task and Linux
does not require pthread linkage. Resume entries return `false` while pending
and `true` when complete. Tail await, sequential direct await bindings,
bindings nested in `if` or `when` branches, and bindings inside `while` bodies
lower to real state machines. The
parent stores its child task, transfers active path values into an exactly laid
out state-specific spill frame, returns to the scheduler, and reloads those
values on resume. Each recorded await or yield remains an observable scheduling
boundary. Reads of restored frame bindings, including immutable aggregate field
receivers, must execute in their consuming continuation; an immutable alias
shortcut cannot reuse a pre-suspension SSA load on a resume edge.
A function-entry state switch may target a resume label inside
the original structured branch CFG; branch joins use value or storage-pointer
phi nodes, so immutable values, mutable scalars, mutable owners, and other live
Tasks retain one coherent post-join representation. Straight-line planning
spills only later-referenced values; the first CFG implementation conservatively
spills all active branch bindings. Numeric/Boolean values and scalar-only
structs/enums can cross multiple state 0/1/2/... awaits; ordinary control flow
may execute after the final resume. The self-hosted grammar and IR recognize the
same nested sites, assign stable one-based states per async function, and export
typed `CoroutineFrameSlot` records for live binding symbols. A suspending
`while` creates explicit header phis for every loop-carried value or mutable
storage pointer. Its back-edge can therefore revisit the same numbered await
state on every iteration without replaying earlier iterations. Iterations may
also branch around an await; both the initial and resumed paths converge on the
same back-edge representation.
For sequential direct awaits, heap-owning and mutable values are now supported:
the spill frame temporarily becomes their unique owner, the source local is
removed before cleanup, and resume reconstructs one owner (plus a fresh mutable
slot when needed). Async containers are never stack-promoted because their
buffers must outlive a native resume invocation. The current state number
selects the exact active frame layout and cancel path; the pending-frame destroy
entry cancels the active child and drops initialized owners. The spill frame
also preserves which owned struct fields were moved before
suspension. Resume and cancellation drop only the remaining fields, while the
transferred fields keep their separate owners. `break`,
`continue`, and their compact guarded forms work inside suspending loops. Each
early edge drops body-local owners first, captures the surviving loop-carried
representation, and joins either the continue or exit phi. Consuming a required
outer owner on only one edge is rejected as inconsistent ownership.

A bare `yield` statement remains an explicit, effectful control-flow operation
through lowering. It cannot be discarded as an unresolved value expression or
reordered across other effects. It is an async-only cooperative suspension point. It
spills the same typed live state as `await`, records its numbered resume state,
returns pending, and lets the FIFO executor append the current Task behind
other ready work. It has no child Task. Cancellation while it is queued invokes
the state-specific destroy path, so CPU loops become cancelable exactly where
the programmer places `yield`. In contrast, `value -> yield` remains the
existing block-function value transfer. Bare `yield` is rejected in `main` and
ordinary synchronous functions because neither has a resumable Task frame.
For a `move` input, each suspension state records whether the original input
owner is still live; cancellation drops either that context owner or the owner
to which it was transferred, never both.

Time suspension uses the public non-negative `Duration` value type and the
affine `sleep: Duration -> async Unit` intrinsic. `milliseconds`, `seconds`,
`minutes`, and `hours` are fallible construction boundaries that reject a
negative input and unit-scaling overflow without losing the unit at the call
site:

```sollang
250 -> milliseconds -> sleep -> await
```

Integer literals are contextually checked as the constructor's `Long` input,
so the concise spelling keeps the full 64-bit range without an explicit cast.
Duration state is observed and transformed through instance methods.
`checkedAdd`, `checkedSub`, `checkedMultiply(UInt32)`, and
`checkedDivide(UInt32)` return typed errors for overflow, a negative result, or
a zero divisor; `absoluteDifference` always returns a non-negative value.
`MonotonicInstant` and `UtcInstant` likewise accept durations only through
checked instance addition/subtraction, and compute elapsed durations through
`later -> durationSince(earlier)`.

`UtcInstant.formatRfc3339(output: mut [UInt8; ~]) -> Result<Int, Error>`
writes exactly 24 UTF-8 bytes, `YYYY-MM-DDTHH:mm:ss.SSSZ`, to caller-owned
storage. It returns 24 without changing the buffer length or capacity. The
calendar is proleptic Gregorian with years 0001 through 9999; instants outside
Unix milliseconds -62135596800000 through 253402300799999 produce
`CalendarOutOfRange`. A buffer shorter than 24 bytes produces
`InsufficientOutput`. Validation precedes all writes, so either error preserves
the complete buffer. Bytes after the 24-byte result are untouched. Formatting
is pure: it does not allocate, read clocks, query locale/timezone settings, or
serialize monotonic readings. Negative epoch values retain floor-based day and
millisecond decomposition.

Every `MonotonicInstant` carries its source identity. The system
`MonotonicClock` uses the reserved source zero; `manualClock(source,
ticksMillis)` requires a nonzero caller-selected identity. `durationSince`,
`Deadline.remaining`, and `Deadline.isDue` return `DifferentClock` before
comparing readings from distinct sources. `MonotonicClock.deadlineAfter` and
`ManualClock.deadlineAfter` bind a checked target instant to the same source;
remaining time reaches zero when due instead of becoming negative.

`FixedClock` is a pure injected UTC source. `OffsetClock` applies an explicit
signed millisecond offset to the system wall clock and reports `Overflow`
rather than wrapping. Neither value is a monotonic elapsed-time source. Clock
capabilities expose whole-millisecond `resolution`, bounded `maximumDelay`, and
a typed `SuspendPolicy`. The compiled Windows monotonic clock reports
`IncludesSystemSuspend`, Linux reports `ExcludesSystemSuspend`, and browser
builds report `Unspecified` instead of inventing host timing guarantees. Affine
periodic `Timer` values own an explicit cancellation token. `wait(move self)`
moves that owner into a real asynchronous Task and returns the next owner in a
`TimerTick`; no mutable borrow crosses suspension. `Burst` preserves overdue
ticks, `Skip` advances to the next aligned tick, and `Delay` schedules from the
observed wake time. `cancel(move self)` and `close(move self)` explicitly end an
idle schedule, while cancellation of an in-flight wait consumes its Task.
Browser targets reject this async surface rather than blocking. The
current-source self-host candidate executes `Duration.sleep`/`await` through an
affine Task and scheduler-owned timer queue. An ordinary async wrapper stores
its result at context offset zero and stores every primary and additional input
in later aligned slots; its worker reloads those values in source order before
calling the async body. Scalar inputs and an affine Dictionary input pass the
focused normal-completion contract. A standalone Windows or Linux native async
module emits the complete Task scheduler even when its source root contains no
stdlib runtime module. Captures, direct chained await with an affine additional
input, cancellation before the body first executes, general state-machine
parity, and network/process deadline consumers remain unfinished slices.
The direct scalar form `asyncCall() -> await -> println` consumes the awaited
result after joining and releasing its Task, with the same single-consumer
semantics as `asyncCall() -> await => result`.
A standalone `asyncCall() -> await` retains the await effect even when the
result is `Unit` and no binding consumes it. Its Task is joined and released
once before the next statement executes.

`sleep` registers its Task in the executor's deadline-ordered timer queue. It
does not allocate an OS thread and does not remain in the runnable queue. When
there is no ready work, the executor waits only until the nearest monotonic
deadline, then moves every due timer to the FIFO ready tail. A zero duration
completes immediately; a negative duration cannot be constructed. Canceling a sleeping Task unlinks it from the
timer queue and destroys its context exactly once. File-descriptor readiness,
task groups, closure-capture analysis, and failure propagation follow.

Postfix `?` inside an `async Result<T, E>` function completes the affine Task
with the fully constructed `Err(E)`. The internal readiness worker stores that
Result in the Task context and returns `true`; it never returns the enum through
the worker's Boolean readiness ABI. The managed Windows/Linux backend implements
this complete contract; the browser target rejects async functions. The
self-host LLVM candidate currently implements the canonical
`Duration.sleep`/`await` Task boundary plus aligned primary and additional
parameter transfer for ordinary async functions. Focused native execution
includes distinct scalar Tasks and affine Dictionary normal completion, and the
standalone scheduler executes on Windows and Linux. Captures, direct chained
await with an affine additional input, multiple suspension states, typed spills
and resume, fallible completion, cancellation ownership, and accumulated
Stage2/Stage3 remain required before claiming self-host parity. Synchronous
output equivalence alone is never async evidence.

## Local Functions

Functions may declare local helper functions before their final body expression:

```sollang
scale n: Int -> Int {
    double value: -> {
        value * 2
    }

    addBase value: Int -> {
        value + n
    }

    n -> double -> addBase
}
```

Local functions cannot be declared `public`.
Local functions use the same input naming rule as top-level functions. Their
names are visible only inside the containing function and functions nested below
it. They can read bindings from the containing function, such as `n` above.
Omitted primary input types are constrained by all calls in that lexical scope;
omitted return types are constrained by tail expressions and explicit returns.
All constraints must agree. Local functions lower to private LLVM functions
with stable local symbols and explicit capture parameters.
Stored field reads constrain an omitted signature through the receiver's
canonical declared field type, including nested fields and readonly receivers.
A method that calls an inferred private function is a consuming function scope;
it participates in the same unique-consumer rule as an ordinary function.

Ordinary array literals constrain an omitted input by their source-level array
contract, independently of their physical storage length. `[1]` and `[2, 3]`
both constrain the input to `[Int]`; `["text"]` instead supplies `[Text]` and
conflicts with that input. The inferred parameter contract must preserve this
distinction from the argument's fixed literal storage. Explicitly declared
fixed-array contracts retain their declared lengths.

An omitted result type follows the same source-level contract: an ordinary
array literal infers a readonly slice, not an implicit owning return type.
Inference cannot extend the lifetime of function-local backing storage.
Returning a runtime array literal, local array, or owned array call result as
a readonly slice is rejected during semantic analysis, including explicit
returns. Declare the owning array result, such as `[Int; 1]`, to transfer the
value. This adds no hidden allocation or ownership change. Ordinary integer
literal arrays whose elements are compile-time numeric literals may retain
immutable static backing; tail and explicit returns use the same rule.

A binding carries the type contract of its complete initializer. If that
initializer is not yet resolved, a nested element cannot provisionally supply
the binding's type or constrain an omitted parameter that reads the binding.
Canonical wrappers with the same complete source span preserve that value's
identity; genuinely nested expressions remain separate values.

When a `parallel` or `tryParallel` callback calls a local helper, every capture
reachable through that helper's transitive local call graph is part of the
callback capture set. A mutable binding is rejected even when the helper only
reads it, because the submitting scope still names mutable storage that worker
invocations could share. Immutable structurally sendable values remain legal
read-only captures. Recursive helper graphs terminate through a compiler
visited set and one unsafe binding produces one diagnostic per callback.
An ordinary nonlocal callee's own parameters and bindings are not captures of
the submitting callback. Storage created inside that callee belongs to that
worker invocation, including storage read by the callee's nested local helpers.

## Block Functions

Sollang models executable blocks as values passed to block functions at the
semantic layer:

```sollang
1..9 -> each i {
    n * i => value
    "$n x $i = $value" -> println
}
```

`each`, `repeat`, and `fold` are built-in block-function targets. User-defined
block functions and typed result roles use the same grammar and ownership
rules. For `each`, the range expression flows into `each`, the optional
identifier names the block input for each invocation, and the brace body is the
executable block argument. For `repeat`, an integer count flows into `repeat` and
the block receives repeat numbers from `1` through that count:

```sollang
3 -> repeat turn {
    "repeat turn $turn" -> println
}
```

Because the code block is the argument, these forms are written
`-> each i { ... }` and `-> repeat turn { ... }`, not `-> each() { ... }` or
`-> repeat() { ... }`.

A result-producing block call can continue through ordinary flow targets and
subsequent block calls. Each stage consumes the preceding stage once, in source
order. A trailing `=> name` binds the final stage result in the enclosing lexical
scope; it does not name an earlier callback result. Ordinary terminal calls use
the same binding, assignment, ownership and diagnostic rules as other flows.
A transient callback result can flow directly into an immediate sink. Storing
deferred interpolation still requires explicit arena materialization.

Users can define block functions with a typed `block` parameter. Its type is a
full `TypeAnnotation`, so generic and composite capabilities such as `[T; ~]`
are legal. The block-function body calls the passed executable block with
`value -> yield`:

```sollang
runTimes count: Int -> Unit block turn: Int {
    1..count -> each turn {
        turn -> yield
    }
}

main {
    3 -> runTimes step {
        "custom block step $step" -> println
    }
}
```

`value -> yield` evaluates its inputs in the producer scope before binding the
callback's roles in the caller scope and executing its body in source order.
Source positions in the producer and caller files cannot reorder these phases.

The compiler is not required to lower this as a runtime closure. For built-in
block functions such as `each`, the backend may specialize the call at compile
time. The current LLVM backends lower `each` directly to basic blocks with an
SSA phi value for the item binding, with no heap allocation, function pointer,
closure object, or dynamic block dispatch.

An intrinsic `parallel` or `tryParallel` call evaluates its source once before
entering the callback. Its input role has the source element type and denotes
the current element even when referenced only inside interpolation. Nested
callbacks preserve the lexical owner of each role. Ordinary user declarations
with the same spelling retain their declared input and callback contracts.
Binding the canonical intrinsic declaration does not turn its callback into
an ordinary value argument: later call normalization preserves the separate
source and callback operands, including inside conditional regions.

A result-producing `parallel` or `tryParallel` call derives its result element
from the concrete terminal producer in the callback body. A direct resolved
call is a producer even when it is the only direct child of the callback. The
callback body wrapper and a value-control owner are transparent regions; their
provisional type must not create an additional array or `Result` specialization.

When one `tryParallel` branch fails, the runtime still cancels and joins the
remaining work before destroying results. Every initialized result payload that
completed but was not selected is destroyed exactly once according to the
payload's actual ownership representation. In particular, a `SourceText`
payload with borrowed storage performs no terminal cleanup, heap storage is
freed, and mapped storage is unmapped through the target runtime. Lowering must
delegate the intact `SourceText` aggregate to that representation-aware cleanup;
extracting its owner pointer and treating every non-array payload as heap
storage is invalid.

`SourceText` is admitted as a direct payload of the top-level `Result` returned by
a `tryParallel` callback. The callback moves its intact representation into the
joined result slot; no worker or submitting scope may retain a second owner.
Collection occurs only after the structured join and follows the
representation-aware rule above. Plain `parallel` results and nested carriers
such as arrays, `Option`, or another `Result` remain rejected until their
recursive worker-side cleanup is implemented.

Normal drop lowering may elide `SourceText` cleanup only when the complete value
is proven to come directly from a borrowing intrinsic, possibly through
immutable binding/read aliases that preserve the same representation. Mutable
storage, control merges, tap values, parameters, aggregate fields, opaque calls,
and owned producers retain representation-aware runtime cleanup. This proof is
fail-closed: an unknown or cyclic provenance path is never treated as borrowed.

## Static Trait Method Contracts

A trait method declares `self`, optionally preceded by `mut` or `move`, then
zero or more comma-separated named inputs before its result type:

```sollang
trait Reader {
    readInto: mut self, output: mut [UInt8; ~] -> Int
}
```

Each implementation must provide the declared method with the same receiver
ownership, additional-input count, positional input ownership and types, and
result type. The receiver is separate from the additional-input sequence.
Signature mismatches are semantic errors, including for implementations that
have not been called; they must not reach LLVM call or wrapper emission.
An implementation cannot add a method absent from its trait. Concrete methods
are validated in source order before missing required methods are reported.
An unknown method or signature mismatch points to the implementation method;
a missing method points to the trait declaration. Completeness is checked for
the canonical trait and receiver pair across its implementation blocks.

A qualified call `receiver -> Reader.readInto(output)` supplies the receiver
once and the remaining inputs in declaration order. Generic functions may
preserve mutable receiver and buffer borrows with the same explicit signature:

```sollang
read<T> reader: mut T, output: mut [UInt8; ~] -> Int where T: Reader {
    reader -> Reader.readInto(output)
}
```

Associated type bindings participate in signature comparison inside composite
input and result annotations. With `type Item = Int`, `[Item; ~]`, `[Item; 2]`,
and `{Text: Item}` resolve to `[Int; ~]`, `[Int; 2]`, and `{Text: Int}`.
Substitution preserves the container kind and fixed length. A differing element
type or fixed/growable shape is not a matching implementation signature.
The same substitution applies to an associated type inside the result storage.
A generic constraint such as `C: Comparison, C.Item == T` ties the method's
associated item type to the caller's type argument.

Static dispatch identifies the requested trait by its declaring module and
symbol, including an explicit import alias. A same-named trait in another
module does not supply a matching implementation. The Windows native path
supports the additional-input, generic mutable-buffer, imported trait identity,
and composite associated-type forms described here. This target boundary does
not imply Linux/WASM closure or support for every recursive generic type shape.

## Dynamic Trait Objects

Static trait dispatch remains the default. Runtime polymorphism is explicit:

```sollang
Cat { value: 1 } -> dyn<Speak> => speaker!
speaker! -> Speak.sound => value
```

`dyn<Trait>` is an affine two-pointer value containing an erased data pointer
and a vtable pointer. Slot 0 is the erased drop function. Subsequent slots are
trait methods in declaration order. Conversion allocates storage for the
concrete value and selects its concrete implementation table; dispatch loads
the requested slot and calls it indirectly. Scope cleanup calls slot 0 exactly
once.

The implemented dyn-compatible subset requires a trait without associated
types and synchronous, capture-free methods with readonly `self`, no additional
arguments, and an `Int` result. Concrete values with nested owned storage are
rejected until conversion has an explicit recursive move-transfer contract.
These restrictions are diagnostics, not implicit fallback to static dispatch.
In particular, a valid static implementation does not make an additional-input
trait dyn-compatible. Trait conversion checks the declared additional inputs,
receiver ownership, result type, and associated type declarations before
emitting an erased wrapper or vtable.

## Standard Library Imports And Aliases

The current standard library implements the `sys.io` module in Sollang:

```sollang
namespace sys.io

import sys.runtime as rt

public print value: Text -> Unit {
    value -> rt.print
}

public println value: Text -> Unit {
    value -> rt.println
}

public readInt prompt: Text -> Int {
    prompt -> rt.readInt
}
```

The lower `sys.runtime` functions are intrinsic declarations owned by the
standard library:

```sollang
namespace sys.runtime

public print value: Text -> Unit = intrinsic
public println value: Text -> Unit = intrinsic
public readInt prompt: Text -> Int = intrinsic
public eprint value: Text -> Unit = intrinsic
public eprintln value: Text -> Unit = intrinsic
```

`eprint` writes the supplied Text bytes to standard error without a trailing
newline. `eprintln` appends the platform line ending. Both require Text and the
Console effect; neither changes the selected output stream or line policy as a
fallback.

The compiler loads the standard library before user code and globally imports
the public `sys.io` functions:

```text
sys.io.print
sys.io.println
sys.io.readInt
```

The short names are aliases:

```text
print   -> sys.io.print
println -> sys.io.println
readInt -> sys.io.readInt
```

### TCP, UDP, and QUIC

`std.net.socket` is the portable public socket module for `windows-x64` and
`linux-x64`. It defines affine `TcpListener`, `TcpStream`, and `UdpSocket`
values, consumes the allocation-free `std.net.Endpoint.V4`/`.V6` enum, structured
`SocketError { kind, code }`, TCP `listen`/`connect`/`accept`/`send`/`receive`
and `shutdown`, and UDP `bind`/`sendTo`/`receiveFrom`/`receiveFromInto`.
`localPort` is available
on every socket owner, including a TCP listener bound to port zero. Stateful operations are
inherent methods on their owning value and are normally called with Sollang's
pipeline syntax. Every operation
that can access the network declares `uses Network` and returns `Result`.

`TcpStream.shutdown(direction)` keeps the stream owner alive and disables only
`ShutdownDirection.Receive`, `.Send`, or `.Both`; call `close: move self` to
release it. The three direction tags map directly to the portable native
shutdown ABI, so selecting a direction adds no allocation or wrapper dispatch.

`TcpStream.setNoDelay(enabled)` changes `TCP_NODELAY` on the live connection and
`TcpStream.noDelay` observes the kernel value. Both keep the affine owner alive,
return `Result`, and lower directly to one native socket-option call. The public
API intentionally exposes the portable policy name rather than native option
levels or numbers, and it does not allocate or cache a second copy of the state.

`TcpStream.setReadTimeout(timeout)` and `setWriteTimeout(timeout)` configure
synchronous relative I/O timeouts on the live stream. Their argument is
`Option<std.time.Duration>`: `Some(duration)` requires a positive duration and
`None` clears the option. `readTimeout` and `writeTimeout` return
`Result<Option<std.time.Duration>, SocketError>`, where `None` means blocking
behavior. A queried value can be rounded upward to the target kernel's timer
granularity. These operations are non-consuming, allocate no wrapper, and map
directly to `SO_RCVTIMEO`/`SO_SNDTIMEO`; they do not define asynchronous or
absolute-deadline semantics.

`TcpStream.setKeepAlive(enabled)` and `keepAlive` configure and observe the live
kernel keep-alive switch. `TcpStream.setLinger(timeout)` accepts
`Option<std.time.Duration>`: `None` disables linger and `Some(duration)` requires
a positive value rounded upward to the target kernel's whole-second unit.
`linger` returns the effective `Option<Duration>`. All four are non-consuming
instance methods with direct native lowering and no wrapper allocation, cached
state, or function-name-based code generation.

`TcpStream.receive(maxBytes)` allocates and returns an owned byte array for
convenience. `TcpStream.receiveInto(buffer!)` is the reusable-buffer path:
`buffer` is a mutable growable `[UInt8; ~]`, its current capacity bounds the
single native receive, and success replaces its logical length with the number
of bytes received. The operation writes directly into existing storage and
returns that same count. Failure leaves the prior logical length unchanged.
Intrinsic lowering loads the buffer pointer and capacity from the mutable-owner
ABI and calls the platform receive primitive without a wrapper, allocation, or
payload copy.

`TcpStream.peekInto(buffer!)` uses the same caller-owned buffer contract without
consuming queued stream bytes. Each successful call replaces the buffer length
with the observed count; failure preserves its prior length. It is a distinct
typed intrinsic that lowers directly to the platform receive primitive with the
peek flag, without allocation, copying, a wrapper call, or function-name-based
code generation. Multiple peeks before `receiveInto` observe the same queued
bytes; the following `receiveInto` consumes them.

`UdpSocket.receiveFrom(maxBytes)` allocates and returns an owned `Datagram` for
convenience. `UdpSocket.receiveFromInto(buffer!)` receives directly into the
capacity of a mutable growable byte buffer and returns
`DatagramReceipt { source, count }`; payload ownership remains with the caller.
Success replaces the buffer's logical length with `count`, while failure leaves
the prior length unchanged. Lowering calls `recvfrom` through the same fixed
stack endpoint descriptor as the allocating path, with no payload allocation,
copy, wrapper call, text conversion, or DNS lookup.

The completion-reactor foundation separates reusable operation ownership from
the existing synchronous readiness `Reactor`. `CompletionReactorOptions`
fixes registration, pending-operation, and completion-batch capacities before
any network effect or native allocation; each value is in `1..1024`, with
`completionBatch <= pendingOperations <= registrations`. Its `validate` method
returns `InvalidArgument` without changing external state. `operationSlot`
consumes a caller-owned growable byte buffer into an affine `OperationSlot` in
the `Vacant` state. The slot exposes its application key, direction, state,
exact byte length, optional terminal transfer count, and optional error through
instance methods, so an absent result is distinct from a real zero-byte completion;
consuming `intoBytes` returns the original buffer without a payload copy.
Native identity and state-transition fields remain private. The public
`completionReactor` constructor creates one affine reactor with bounded,
preallocated registration, pending-operation, and completion storage.
`CompletionReactor.registerStream` consumes both the reactor and `TcpStream`;
success retains the exact stream owner in the reactor, while duplicate,
capacity, or native-table validation failure returns the exact reactor and stream owners in
`SocketRegistrationFailure`. Registration itself only updates the bounded
owner table. It deliberately postpones IOCP association on Windows and
nonblocking plus epoll registration on Linux until the first submission, so an
unsubmitted registration can be removed and returned as an independently
usable `TcpStream`. Once submitted or associated, `removeStream` rejects the
transition and retains reactor authority. Linux epoll payloads use tagged native
registration identities rather than reserving any user `UInt64` key; the key is
resolved from the owner table. `submit` returns either an immediate completion
or a pending reactor owner. `dequeue` and `dequeueTerminal` move that owner into
an affine Task which parks without polling until the platform completion source
wakes it. The final selected intrinsic declaration determines its Task-producing
identity, including after cross-fragment receiver or generic call resolution.
Both await/cancel validation and runtime emission use that same identity; an
earlier provisional call opcode cannot override the selected declaration. On Linux, one dedicated waiter owns the blocking `epoll_wait`; a
direction-specific `EPOLLONESHOT` registration retries every eligible retained
operation for that registration. Multiple operations may share a registration.
After the bounded scan, the registration rearms the union of directions still
pending; `EAGAIN` leaves that operation pending and does not prevent later
operations from progressing. A reactor-local mutex serializes table changes and
terminal publication, but is never held across `epoll_wait`, Task waiting, or
waiter joining. Per-call nonblocking socket operations keep those critical
sections bounded. Each operation publishes one terminal record before scheduling
the parked Task. A native rearm failure after pending publication completes the
retained operations with that native error and preserves their buffer ownership
until dequeue or shutdown. Error and hangup readiness also retry the operation to obtain
its native error or EOF. A peer write failure returns `SocketError` without
terminating the process. The dequeue transfers the exact retained buffer back into the
slot without copying. Canceling a parked completion Task consumes the Task, requests native
cancellation for every active operation, and leaves the task control and retained
owners alive until one terminal completion wins. The completion drain then joins
the waiter and releases each retained slot, stream, descriptor, context, and
reactor allocation exactly once. The existing `Reactor.waitInto` remains the
separate bounded `WSAPoll`/`poll` readiness operation.

The managed completion-reactor acceptance matrix covers 22 contract cases with
24 probes across Windows, Linux, browser rejection, and cross-target ownership,
allocation, copy, cancellation, and shutdown invariants. Passing that focused
matrix does not by itself authorize replacing the readiness reactor: formal
self-host Stage2/Stage3 execution and the throughput/peak-memory comparison
remain separate promotion requirements.

Programs flatten sequential failure with postfix `?`:

```sollang
sendPing endpoint: net.Endpoint, timeout: time.Duration -> Result<Bool, socket.SocketError> uses Network {
    endpoint -> connect? => connection
    connection -> sendText("ping")? => count
    connection -> setNoDelay(true)?
    connection -> noDelay? => lowLatency
    connection -> setReadTimeout(Option<time.Duration>.Some(timeout))?
    connection -> readTimeout? => observedTimeout
    observedTimeout -> when {
        Option<time.Duration>.Some(_) { true }
        Option<time.Duration>.None { false }
    } => hasTimeout
    connection -> shutdown(socket.ShutdownDirection.Both)?
    connection -> close
    Result<Bool, socket.SocketError>.Ok(count == UIntSize(4) and lowLatency and hasTimeout)
}
```

This is the standard alternative to nesting a `when` for every operation. A
`when` remains appropriate at a boundary that renders, retries, translates, or
otherwise recovers from the final error.

`std.net.quic` provides affine `Identity`, `Endpoint`, `Connection`, and `BiStream`
values; generated identities, explicit peer-certificate pinning, bidirectional
streams, and unreliable datagrams; and the same flat `Result`/`?` contract.
Its peer representation is the shared `std.net.Endpoint`. User code normally
constructs loopback and wildcard values with `quic.loopback(port)` and
`quic.anyAddress(port)`. Arbitrary numeric IPv4 text uses the strict,
DNS-free parser `quic.ipv4(address, port) -> Result<Endpoint, QuicError>`:

```sollang
quic.loopback(44_434) => local
quic.ipv4("192.0.2.42", 44_434)? => peer
quic.generateIdentity()? => identity
quic.bind(local)? => endpoint!
endpoint! -> listen(identity)? => listener!
```

`std.net` also defines allocation-free numeric IPv6 values. `Ipv6Address`
stores eight 16-bit groups, while `Ipv6Endpoint` keeps `port`, `flowInfo`, and
`scopeId` explicit. `std.net.Endpoint` is the common `V4`/`V6` value enum.
`std.net.ipv6(text, port)` and `ipv6Scoped(text, port, scopeId)` are pure,
fallible parsers: they accept hexadecimal groups and one `::` compression but
perform no DNS lookup. URI brackets are not address bytes, and interface zones
are endpoint scope metadata rather than part of `Ipv6Address`. Native socket
listen, connect, UDP bind, and UDP send lower the common enum to a fixed 32-byte
stack descriptor and support both address families without text conversion.
UDP receive publishes `Datagram.source: Endpoint` through the inverse fixed
descriptor path, with no address string or second heap allocation. The public
QUIC bind/connect and connection peer state preserve the same enum. The signed
P2P peer-record encoding remains IPv4-specific and is not a dual-stack
discovery contract.

`std.net.dns.Resolver` is the explicit system-name-resolution boundary. A
resolver value carries `AddressFamily`, `maxResults`, and `maxHostBytes`; its
`resolver -> lookup(host, port)` method declares `uses Network` and returns an
owned ordered `[std.net.Endpoint; ~]`. The runtime preserves system resolver
order, removes exact duplicate numeric endpoints without reordering, attaches
the requested numeric port, and returns `ResultLimitExceeded` instead of
silently truncating. The foundation accepts ASCII DNS presentation names only,
rejects numeric literals so callers use the pure IPv4/IPv6 parsers, and does
not silently apply IDNA, service-name lookup, timeout, retry, or address-family
preference policy. It may block in the system resolver. `wasm32-browser`
requires an explicit host-provided resolver and fails compilation otherwise.

Direct `{ a, b, c, d, port }` literals expose the storage representation and
are not the preferred application surface. Empty components, non-decimal
components, and octets above 255 are rejected before network access.
`quic.bind(local)` creates the affine transport owner. One `Endpoint` owns one
UDP socket, the connection-ID route table, and a bounded pending-datagram queue.
`endpoint! -> listen(identity)` transfers the server identity into a reusable
`Listener`; `listener! -> accept(endpoint!)` returns an independent affine
`Connection` and may be called repeatedly. Closing the Listener stops only
future accepts. Accepted Connections remain usable until each is explicitly
closed, and closing a Connection unregisters only its route. Closing Endpoint
finally releases the shared transport.

`ConnectionOptions` is an inline pre-construction policy value. Its
`maxInboundBidirectionalStreams` is the initial cumulative RFC 9000 stream
credit. `pendingInboundBidirectionalStreams`, `pendingApplicationFrames`, and
`pendingApplicationBytes` independently bound local decoded state awaiting the
application. Nested `ReceiveWindowSizes` carries the connection-wide and the
locally/remotely initiated bidirectional stream receive credits. Explicit
server policy uses `endpoint! -> listenWith(identity, options)`; explicit client
policy uses `endpoint! -> connectWith(peer, certificate, options)`. The shorter
`listen` and `connect` forms apply reviewed defaults. All limits are validated
before listener mutation, random generation, or network access, and are stored
as direct scalar fields without a wrapper or dynamic dispatch. Receive windows
may be any QUIC variable-length integer through `2^62 - 1`; they do not inherit
MsQuic's power-of-two restriction.

Local pending-queue exhaustion returns `QueueLimitExceeded` with the exact
active limit. It is distinct from a peer's `FLOW_CONTROL_ERROR`,
`STREAM_LIMIT_ERROR`, or malformed transport parameter. STREAM admission checks
frame and byte capacity, computes the next connection-flow state, and validates
the peer identity before committing any identity, flow, queue, or byte-count
mutation. A rejected frame therefore leaves all prior queued streams intact.

Connection and stream operations receive `mut Endpoint` explicitly so the hot
path uses direct static calls without an implicit parent object, wrapper
allocation, or hidden copy. Routing uses fixed eight-byte connection IDs folded
into scalar keys, queues a datagram addressed to another live Connection, and
fails explicitly when the bounded queue is full. A long header is rejected
before reading its CID unless at least fourteen bytes are available; a short
header requires at least nine. Protocol state, TLS 1.3, packet protection, loss
recovery, flow control, streams, and datagrams are pure reachable Sollang
standard-library modules. The completed native path does not require a Rust
crate, `sollang_quic.dll`, or `libsollang_quic.so`; the obsolete adapter and its
packaging/linker paths have been removed. Browser WASM does not silently emulate
native networking capabilities.

Public library APIs follow an instance-first rule. If an operation has a
natural state, owner, or domain-value receiver, it is declared in `impl` and
called as `value -> method(arguments)`. Dot calls remain equivalent syntax.
Module functions are reserved for construction, parsing before a receiver
exists, and genuinely process-global boundaries. This is a zero-cost rule:
intrinsic methods lower directly to the same runtime primitive, and ordinary
method migration may not add an O0 wrapper frame, allocation, branch, or copy.
Consuming `close: move self` ends an affine resource immediately; otherwise
scope exit performs the same exactly-once drop.

The reviewed top-level `stdlib/std` exceptions are a machine-checked contract.
Every exception is classified as a factory, receiver-less parser, generic flow
adapter, pure constant, or explicit migration debt. Adding an unclassified
global or retaining a stale exception after an instance migration fails
`scripts/verify-stdlib-instance-policy.ps1`.
The same gate permits only the `sys.path.fromText` factory and
`sys.path.nativeStyle` raw boundary as public globals. Path operations are
instance methods; new migration-debt globals are not permitted. Fixed-width
crypto bit operations are qualified `UInt32` or `UInt64` instance methods, and
QUIC packet-threshold and congestion-window arithmetic are qualified `UInt64`
instance methods. Their scalar receivers add no owner, allocation, copy, or
compatibility wrapper.
QUIC scalar wire values likewise own packet-number restoration/truncation,
varint and typed framing encoders, reserved-version classification, transport
parameter emission, stream-identity validation, and Initial/Handshake header
construction as qualified instance methods. These migrations retain their
existing result, ownership, and wire-byte contracts without adapter functions.
An inherent method on a built-in receiver retains its declaring module in its
semantic identity. Thus separate modules may define the same member name on
`UInt64`; a qualified flow such as `value -> varint.encode` selects the method
from that module, while a bare member name selects only the current module's
extension. The compiler must reject neither pair as a global duplicate and must
not choose one through an unrelated lexical fallback.

Concrete array storage types are also valid inherent owners. `impl [UInt8]`
defines a readonly byte-view receiver without introducing a nominal wrapper;
matching fixed, growable, and bounded byte arrays borrow that view with no copy
or allocation. An exact storage owner such as `[UInt8; 32]` is considered before
the compatible `[UInt8]` view. Array method identity includes the declaring
module and canonical storage spelling, so imported qualified calls resolve the
same way as module-qualified primitive methods.

The library layering contract is `std -> sys`. `std` owns portable public APIs,
domain values, and pure algorithms; `sys` owns only irreducible target and OS
primitives. `sys` must not import `std`, and a public feature must not remain in
both namespaces after its replacement path is verified. Existing protocol code
under `std.net.quic` is migrated incrementally into `std.net.quic`; this transition
does not authorize new portable APIs to accumulate under `sys`.

The canonical portable path vocabulary is migrating from `sys.path.Path` to
`std.path.Path`. Lexical style, components, joining, comparison, and confined
normalization are pure instance operations. Filesystem metadata and canonical
resolution are explicit `uses File` operations backed by raw `sys` primitives;
lexical normalization does not claim to resolve symbolic links. The migration
must not introduce a reverse `sys -> std` dependency or leave two public path
types after the replacement is verified.

`std.path.components(text, style, limits)` creates a bounded lexical
`Components` iterator over borrowed UTF-8 input. It reuses the existing
`sys.path.Style` identity; it neither introduces a second owned `Path` nor
performs filesystem access. `Limits` explicitly bounds input bytes, component
count, and bytes per component. All limits are nonnegative, and zero is a real
ceiling. Construction rejects an overlong input, its first NUL byte, and
unsupported or malformed prefixes before exposing any component.

`Components.next(mut self)` returns `Result<Option<Component>, Error>`.
Each component contains only its `Kind`, original byte offset, and byte length.
The iterator retains a private source loan; component metadata does not retain
that loan. Count and size checks precede cursor mutation, so a failed call
preserves the iterator and repeated calls report the same error. Roots and
prefixes count toward both limits. `offset` points immediately after the last
returned span; end-of-input consumes remaining separators once and stays stable.

The lexical profile preserves dots, dot-dots, byte spelling, case, whitespace,
and Unicode. POSIX style splits only on slash and represents a leading slash
sequence with one root component; it does not interpret the special resolution
meaning an implementation may assign to exactly two leading slashes. Windows
style accepts slash and backslash separators. Drive prefixes preserve their
two bytes, with a separate root component when followed by a separator, so
drive-relative and rooted paths remain distinguishable. A UNC root includes
its server and share; empty or dot/dot-dot server/share, missing shares, and
three or more leading separators are malformed. Device and extended namespace
prefixes are explicitly unsupported. These namespace distinctions follow the
[Windows path naming model](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file),
but this API is not a Windows filename validator or an OS path resolver.
Ordinary colons after byte offset one remain component data. Repeated
separators and a trailing separator produce no empty or phantom component.
The precise prefix, error precedence, and byte-span contract is
`scripts/contracts/path-components.json`; this API performs no normalization,
confinement, symlink lookup, allocation, source copy, or asynchronous work.

`std.text.glob.pattern(text, limits)` creates an immutable bounded matcher that
borrows validated UTF-8 input. `Pattern.matches(input)` performs a
case-sensitive whole-text match without filesystem access or normalization.
`*` matches zero or more Unicode scalar values, `?` matches exactly one scalar,
and only `\*`, `\?`, and `\\` are escapes. Separators, leading dots, newlines,
NUL, brackets, and braces otherwise remain ordinary text; this is not a POSIX
or shell expansion API.

All glob limits are nonnegative and zero is a real ceiling. Construction checks
`InvalidLimits`, pattern bytes, then escape validity. Matching checks input bytes
before spending work and consumes one bounded step per state transition,
including its terminal decision. Work exhaustion reports the byte offsets of
the next transition it could not perform without mutating either input. The
iterative last-star algorithm uses constant auxiliary storage; it does not build
an AST, enumerate paths, or allocate hidden match state. The exact profile,
precedence, cases, and offsets are fixed by `scripts/contracts/text-glob.json`.

`std.text.regex.pattern(text, limits)` creates an immutable bounded matcher
that borrows its validated UTF-8 pattern source. The supported profile is
literal scalars, `.`, concatenation, ASCII classes and non-reversed ranges,
negated ASCII classes, `?`, `*`, `+`, an initial `^`, and a terminal `$`.
Matching is case-sensitive and uses absolute-input anchors; dot excludes LF,
while NUL and CR remain ordinary input. Groups, alternation, bounded or lazy
repetition, lookaround, backreferences, named classes, and Unicode properties
are rejected rather than silently interpreted as literals.

`Pattern.scratchCells()` reports the exact caller-owned `[UIntSize; ~]`
workspace required by `find(input, scratch!)`. `find` uses two state banks,
returns the earliest byte start and then the longest byte span for that start,
and retains neither its input nor its scratch. Pattern, atom, input-byte, and
work limits are explicit; input and scratch preflight failures preserve all
scratch bytes, while work exhaustion may alter only the required prefix and a
retry reinitializes that prefix. The implementation performs no recursion,
backtracking, hidden allocation, source copy, normalization, or locale lookup.
The exact syntax, error precedence, UTF-8 byte offsets, work accounting,
ownership, and independent leftmost-longest cases are fixed by
`scripts/contracts/text-regex.json`.

`std.io.Reader` and `std.io.Writer` are public static protocols over one
caller-buffer partial-transfer primitive. Both operations return exact `Int`
progress and preserve an associated failure type without a wrapper object,
payload allocation, error erasure, or dynamic dispatch. The memory
implementations bind that failure to `std.io.Error`; effectful implementations
retain their domain error. `Reader.readInto` borrows a mutable growable-byte
destination. `Writer.writeRange` borrows a read-only growable-byte owner
and receives an exact offset and length so a generic caller can retry a partial
write without copying or removing the written prefix. Implementations validate
the range before mutation and may not retain either caller buffer. `MemoryReader` and
`MemoryWriter` implement these protocols while preserving their existing
inherent methods. A concrete `MemoryWriter` therefore keeps its source-compatible
partial `write` returning `Int`, while `writeRange` returns the same exact
progress as `Result<Int, Error>`. `std.net.socket.TcpStream` implements both
protocols by forwarding directly to `receiveInto` and `sendRange`; its methods
retain `uses Network` and `SocketError`, and add no wrapper owner or payload copy.
`std.io.file.ByteReader` and `ByteWriter` are affine adapters that consume a
`sys.file.File` or `FileWriter`, retain an explicit `UInt64` position, and
implement the same protocols with `uses File` and `Text` failure. Their
operations call position-independent `readIntoAt` and `writeRangeAt`, advance
only by successful progress, and can be consumed to recover the exact native
owner. A read fills only the caller buffer's visible length and treats native
end-of-file as successful zero progress. A write validates its complete source
range before any platform effect. Windows uses overlapped offsets, Linux uses
`pread`/`pwrite`, and browser targets return an explicit unavailable result.

`TransferPolicy` is an immutable instance owning a maximum transfer count and a
positive reusable-buffer size. Its generic `copy` method statically dispatches
consumer-defined `Reader` and `Writer` implementations, retries partial writes
from the exact unwritten range, and reports successful zero progress as
`WriteZero`. `CopyOutcome` distinguishes an observed source end from reaching
the policy limit. The copier never consumes a probe byte beyond that limit.
This slice proves imported cross-module generic protocol specialization without
a trait object or runtime dispatch.

`MemoryReader.readExactInto` remains transactional: it validates the configured
limit and complete source range before changing its cursor or the destination.
This guarantee does not extend automatically to an effectful stream.
`ReplayBuffer` supplies the explicit bounded alternative. Its generic
`readExactFrom` validates the complete request before source access, reads only
the still-required byte count into reusable adapter-owned scratch, and publishes
to the caller destination only after the entire request is present. A failed
short read retains its prefix for the next logical read. The adapter advances a
logical published cursor and never claims that the underlying file or socket
cursor moved backward. Checkpoint-capable sources may provide a separate exact
path later. `TransferPolicy.readAll` composes that replay owner with the
policy's explicit maximum and reusable chunk size. It publishes an owned
aggregate only after observing end, retains one over-limit probe for a lossless
larger-limit retry, and rejects replay capacity that cannot hold `maxBytes + 1`
before source access. Reactor protocol implementations and async buffering
remain unpublished; no unbounded aggregate helper or implicit buffer is part
of the portable protocol. This synchronous protocol
must not hide a blocking operation behind an async-looking API; future
task-returning adapters expose real suspension separately.

`std.uuid.Codec` is an immutable RFC 9562 policy value. Its pure `v4` method
accepts exactly sixteen caller-owned entropy octets; pure `v7` accepts a
`UtcInstant` plus exactly ten entropy octets. Both validate lengths before any
index and set the RFC version/variant bits. `std.uuid.Generator` separately owns
the explicit `WallClock` and `SecureRandom` instances used by effectful `v4`
and `v7`; deterministic construction never reads ambient clock or randomness.

`std.encoding.hex` and `std.encoding.base64` are pure, instance-first byte
codecs. A `Codec` creates a bounded `Encoder` or `Decoder`; repeated `write`
calls mutate that instance and `finish` consumes it. One-shot `encode` and
`decode` remain methods on the immutable codec value. Every operation accepts
an explicit maximum output size or inherits the bound fixed when the stateful
instance was created. Validation and output-length planning complete before
reserving or committing mutable state, so an error leaves the codec state and
caller-owned output unchanged.

Hex reports an exact invalid-byte offset and rejects an unfinished half-byte at
`finish`. Base64 implements strict RFC 4648 Basic and URL-safe alphabets in
padded and raw forms. It rejects whitespace, mixed alphabets, misplaced or
missing padding, non-zero padding bits, and trailing data after a padded
quantum; MIME line folding is not silently accepted. These modules perform no
native call, hidden allocation beyond the caller's requested result buffer,
ambient I/O, or target-specific fallback.

`std.encoding.binary.ByteOrder` is an immutable explicit big- or little-endian
policy. It creates a `Reader` owning only an input cursor or a bounded `Writer`
owning only output-limit and produced-count state. The caller supplies every
input slice and mutable output buffer. UInt16/UInt32/UInt64 and canonical
unsigned base-128 varints therefore add no native-byte-order dependency or
hidden buffer copy. Failed fixed-width reads and writes are transactional;
varints use at most ten bytes, reject overflow and longer-than-minimal forms,
and report the exact failing byte offset.

`std.hash.crc32.Polynomial` selects the reflected IEEE or Castagnoli polynomial
and creates a mutable scalar `Hasher`. `write`, `checksum`, and `reset` are
inherent methods; there is no process-global checksum state. The fixed-input
instance path is allocation- and copy-free at O0. GZIP keeps its existing
private CRC until shared-code throughput and all compression gates establish
that consolidation does not regress performance.

`std.compress.gzip` is a pure, instance-first GZIP codec. A `Limits` value
constructs a `Codec` with mandatory maximum output bytes and maximum expansion
ratio. `codec -> planCompress`, `compress`, `planCompressFixed`,
`compressFixed`, `planDecompress`, and `decompress`
validate complete bounds before producing a result. The current writer emits a
deterministic RFC 1952 header and RFC 1951 stored blocks (compression level 0);
`compressFixed` emits a fixed-Huffman block using a bounded 4,096-slot
latest-match table after `planCompressFixed` proves its worst-case output bound;
the reader accepts stored, fixed-Huffman, and dynamic-Huffman blocks, validates
canonical code trees and LZ77 distances, supports overlapping back-reference
copies across block history, and validates LEN/NLEN, optional header fields and
header CRC when present, CRC32, ISIZE, exact stream termination, output size,
and expansion ratio. Reserved block types and malformed codes fail explicitly.
`codec -> encoder()` constructs a stored-block streaming `Encoder`. Its
`write(input, output)` method emits non-final blocks immediately into the
caller-owned output while retaining only incremental CRC32, modulo ISIZE, and
bounded output accounting. It reserves the final empty block and trailer in
its limit check before mutating output; `finish: move self` emits that block,
CRC32, and ISIZE. `codec -> decoder(DecoderLimits)` creates an affine,
chunk-fed transactional decoder. `write` advances the GZIP header, DEFLATE bit
reservoir, active Huffman tables, LZ history, CRC32, ISIZE, and member state;
consumed compressed bytes are not retained or reparsed. The decoder accepts at
most `maxMembers`, keeps unverified member output private, and `finish: move
self` appends the verified aggregate only when every final block, CRC32, ISIZE,
output limit, and expansion ratio is valid. Any failure leaves caller output
unchanged. `decompressMembers` retains a complete-input bulk decoder while
fixture 1214 requires semantic parity with the incremental path. A direct route
through the byte-resumable decoder was rejected after the same-input runtime
median regressed by 24.7%; future consolidation must use a measured shared core
without that abstraction cost. Dynamic-Huffman writing, ZIP, and Brotli are
separate follow-up gates.

`std.compress.zstd` is the pure Sollang RFC 8878 foundation. Its `Limits` value
independently bounds encoded bytes, decoded bytes, frame window bytes, data
frame count, and each skippable-frame payload. `Limits.codec` creates an
immutable `Codec`; `Codec.encoder(expectedInputBytes)` and `Codec.decoder`
create affine state instances, while `compress` and `decompress` are one-shot
instance conveniences over the same public lifecycle. The deterministic writer
emits an independent single-segment frame with raw blocks no larger than 128
KiB. Encoder writes publish raw blocks directly to caller-owned output without
retaining input, and consuming `finish` checks the declared content size before
emitting the final block. The incremental decoder accepts raw and RLE blocks,
bounded skippable frames, and concatenated independent frames one byte at a
time. It does not retain encoded input and appends private decoded output to the
caller only when consuming `finish` at a validated frame boundary. Invalid
magic, header, block, size, truncation, and every limit fail explicitly.
Entropy-compressed blocks, dictionaries, and content checksums are not yet
implemented and return distinct unsupported errors rather than a fallback.

`std.archive.zip` provides bounded stored-method ZIP reading and writing without
ambient file access. `Codec.writer(WriterLimits)` creates an affine `Writer`;
`beginStored` emits one deterministic local header, `write` streams caller-owned
payload bytes without retaining them, `finishEntry` validates the declared size
and CRC32, and consuming `finish` publishes the retained bounded central
directory and EOCD. Limits independently bound encoded bytes, entry bytes and
count, name, extra, comment, central-directory storage, and work. Every failing
call leaves its supplied output unchanged. Capacity checks use subtraction-first
arithmetic, and the 65,536th entry is rejected before mutation even when the
configured entry limit is larger. Names used as textual bytes are written with
character literals; wire signatures, lengths, and binary payload octets remain
numeric. The focused contract requires deterministic two-entry agreement with
Python `zipfile`, exact Windows and Linux O0/O2 execution, LLVM assembly and
direct-call closure, affine/privacy rejection, and exact execution of the
produced wasm artifact through the repository browser harness. DEFLATE method 8,
data descriptors, ZIP64, encryption, and fixed-point promotion remain separate
gates.

Brotli follows as a separate bounded codec/encoder/decoder contract over
caller-owned buffers or portable `std.io` streams; neither format adds ambient
file APIs or unbounded allocating globals.

`std.log` provides explicit structured logging policy without an ambient
mutable logger, global sink, implicit formatter, or hidden destination effect.
`logger(minimumLevel)` creates an immutable `Logger`. `Logger.record` applies
the level filter and returns `None` before the caller constructs structured
fields or invokes a sink; an accepted message returns `Some(Record)` containing
only its typed level and message. The caller then constructs caller-owned
`[Field]` input and invokes a concrete implementation of `Sink.write` through
static trait dispatch. A sink owns serialization and destination effects and
returns `Result<Unit, std.log.Error>`, so failures remain typed and are never
replaced by a fallback destination. This split keeps disabled logging free of
field construction and sink calls while leaving allocation, I/O, buffering,
retry, and backpressure policy explicit in the selected sink.

`std.uri.parse(text, maxInputBytes)` parses an RFC 3986 URI-reference without
performing DNS, IDNA conversion, file access, or scheme-specific network I/O.
The result retains raw percent-encoded component spans over one `SourceText`
and distinguishes an absent query or fragment from a present empty component.
`Reference` exposes component text and classification as instance methods.
Authority hosts are either a registered-name span, a numeric IPv4 value, or a
bracketed numeric IPv6 value; an unbracketed colon is reserved for the decimal
port, whose accepted range is 0 through 65535. Numeric-looking dotted hosts
must parse as IPv4 and are not silently reclassified as registered names.
The parser retains the original authority span privately for serialization;
obtain authority values through `parse` rather than constructing them externally.

`std.uri.percent` provides immutable component-specific `Codec` values for
unreserved, user-info, registered-name, path-segment, path, query, and fragment
rules. Planning and encode/decode are instance operations with a required
maximum output size. Percent triplets are strict hexadecimal byte encodings,
errors retain the exact input offset, encoding uses uppercase hex, and decode
does not reinterpret `+` as space.

`Reference.normalizeBytes(policy, maxOutputBytes)` returns owned UTF-8 bytes.
`NormalizationPolicy` independently selects scheme and registered-name case
folding, unreserved percent decoding, percent-hex uppercasing, and dot-segment
removal; `canonicalNormalization()` enables all five. Reserved encoded bytes
remain encoded. The output bound also bounds intermediate path storage, so
an oversized intermediate path fails even if dot removal would shorten it.
`Reference.resolveBytes(reference, policy, maxOutputBytes)` uses the receiver
as the explicit base, inherits absent components, and merges relative paths.
A reference with its own scheme does not need an absolute base; other
references require a base scheme. Both operations return typed limit errors
and perform no DNS or file effects. Form encoding, IDNA, DNS, default-port
elision, and scheme-specific behavior remain separate contracts.

`std.text.json` provides strict, bounded RFC 8259 token reading and generation. A
`Reader` owns one retained `SourceText` view and yields ordered `Token` values;
string and number tokens retain raw spans so decoding and numeric precision are
explicit caller decisions. `decodeString` validates escapes, UTF-8, Unicode
scalar values, and its output bound. Reader limits independently bound input
bytes, nesting depth, token count, and decoded string bytes. Comments, trailing
commas, invalid UTF-8, lone surrogates, `NaN`, and infinities are rejected.
Repeated object names remain ordered tokens and are never silently collapsed.

`Reader.document()` produces an owned index-addressed value tree. Every `Value`
retains `sourceStart` and exclusive `sourceEnd` byte offsets in the reader's
original source. String spans include their quotes and escaped source bytes;
array/object spans include both delimiters. Decoded names and values remain
owned UTF-8 bytes, so diagnostic offsets do not depend on decoded string length.

`Reader.int64(token)` and `uint64(token)` validate the token kind, source span,
JSON number grammar, and integer range without advancing the reader. Only the
integer lexical form is accepted: a decimal point or exponent produces
`NonIntegerNumber`, even when the mathematical value is integral. Overflow
produces `NumberOutOfRange`; unsigned conversion also rejects every negative
form, including `-0`. Signed conversion accepts the exact `Int64` minimum.
`Reader.boolean(token)` and `nullValue(token)` likewise leave the cursor and
structural state unchanged. They validate the kind, source bounds, and actual
`true`, `false`, or `null` source bytes rather than trusting a public token tag.

`Reader.nameSeparator(token)` accepts a `NameTokenKind` token only after
checking its bounds and complete quoted-string span against the original
source. It skips JSON whitespace after that span and requires a colon,
returning `ExpectedColon` if absent. This read-only check leaves the reader
cursor, token count, and container state unchanged.

`Reader.skipValue()` consumes exactly the next scalar, array, or object through
the same bounded token state machine. After an object name has been read, it
can discard that member's value while preserving the following member; within
an array it preserves the following element. Nested values are validated but
are not decoded into strings, arrays, or an intermediate value tree. Input,
depth, token, and string limits remain active, including inside skipped values.
A next token that cannot begin a value yields `WrongTokenKind`. As with token
reading, parse failure retains consumed progress and does not promise rollback.

A `Writer` instance owns its structural state and growable byte buffer.
`beginArray`, `endArray`, `beginObject`, `endObject`, `name`, `nullValue`,
`boolean`, `number`, and `string` mutate that instance. Construction fixes
maximum output bytes and nesting depth. Each operation validates its complete
input and planned byte count before changing state or output, so an error is
transactional. `number` accepts an exact already-formatted JSON number rather
than choosing floating-point precision or formatting policy. `int64` and
`uint64` produce exact base-ten integer forms through the same transactional
number-writing path, including both 64-bit range boundaries. `intoBytes: move
self` requires one complete document and transfers the existing output buffer
without copying it. Parsing and generation perform no ambient file, network,
locale, reflection, or hidden serialization work.

`std.text.csv` provides a bounded UTF-8 field stream over borrowed `Text`.
`standard()` creates a `Format` with CRLF record delimiters and unconstrained
column count; call `format -> reader(text, limits)` to create a reader, then
`reader! -> next(output!)` with caller-owned growable byte storage. The result
is `Option<Field>` metadata: zero-based record and field indices, decoded byte
length, and whether the field ends its record. No row array, decoded string,
output resize, or file operation is implicit. The input backing storage must
outlive the reader and cannot be mutably aliased by the output.

The quoting model follows [RFC 4180 section 2](https://www.rfc-editor.org/rfc/rfc4180.html#section-2):
commas and line breaks inside quoted fields are data, and doubled quotes decode
to one quote. The explicit profile accepts UTF-8, treats a trailing comma as an
empty final field, treats an empty document as zero records, and does not
infer headers, trim whitespace, strip a BOM, or add a phantom record after a
terminal newline. A blank record has one empty field. This is not an
unqualified strict-RFC conformance claim. `CrLf` accepts only CRLF delimiters,
`Lf` only LF, and `Either` accepts either independently, including mixed input.
Bare CR is rejected outside quotes; CR and LF inside quotes are preserved.
Other ASCII control bytes and DEL are rejected.

`Limits` separately bounds input bytes, records, fields per record, and decoded
field bytes. Negative limits or column counts are invalid; zero limits permit
an empty document. A positive expected column count may not exceed the field
limit. `Reader.next` validates one complete field before writing its decoded
prefix or advancing its private state. Every failure preserves the cursor and
the entire output buffer; `OutputTooSmall` reports the required byte count and
allows retry with another buffer. Success preserves output length, capacity,
and the unused tail. Transactionality is per field, not per record: a later
syntax, column-count, or limit failure does not retract earlier returned
fields. Extra fixed columns fail before scanning the first extra field; too
few columns fail before publishing the final field. Errors report the relevant
source byte offset, and `Reader.offset` observes the committed cursor.

`format -> writer(writerLimits)` creates a `Writer` with private cumulative
byte and record counters. `WriterLimits` bounds total encoded output bytes,
records, fields per record, and each field's decoded UTF-8 bytes. Limits must
be nonnegative and a positive `expectedColumns` must fit the field limit.
Writers require explicit `CrLf` or `Lf`; `Either` is an input policy and is
rejected with `InvalidOptions`, not silently converted to an output style.

`writer! -> writeRecord(fields, output!)` borrows a readonly `[Text]` and emits
one complete record, including its final line ending, into caller-owned byte
storage. It returns the exact encoded prefix length. Empty fields are quoted;
nonempty fields are quoted only when they contain comma, quote, CR, or LF.
Quotes are doubled, UTF-8 and spaces are preserved, and other ASCII controls
or DEL are rejected. Zero fields is `InvalidRecord`, not a blank record.

The writer checks the complete row before modifying any output byte. Size
arithmetic is bounded by the remaining encoded-byte budget, including commas,
quotes, escaping and line endings. `OutputLimit` denotes that cumulative
budget; `OutputTooSmall` reports the exact complete-record size and permits
retry with another buffer. Every failure preserves the entire output and both
counters. Success changes only the output prefix, preserving length, capacity
and tail, then advances `bytesWritten` and `recordsWritten`. Writer error
offsets are the committed byte count; `requiredBytes` is zero except for
`OutputTooSmall`. Input fields may not borrow the mutable output. No row plan,
payload allocation, output resize, filesystem access, or asynchronous work is
implicit in this pure formatter.

`std.net.http` provides a pure, bounded HTTP/1.0 and HTTP/1.1 message-head parser.
Create a `Parser` from explicit limits, then call `parser -> parseRequest(text)`
or `parser -> parseResponse(text)`. A parsed head owns one retained
`SourceText`; start-line components and fields are spans over that source.
Fields preserve input order and duplicates, and case-insensitive lookup is an
instance operation rather than an implicit dictionary collapse.

The parser requires CRLF, rejects bare CR or LF, obsolete line folding,
whitespace before a field-name colon, invalid token bytes, and invalid field
value bytes. Limits independently bound the complete head, start line, field
count, field-name bytes, and field-value bytes. Parsing stops at the empty line
and reports `bodyStart`; it does not choose message-body framing, open a socket,
resolve a host, negotiate TLS or QUIC, follow redirects, retry, decompress, or
invent timeout and cancellation policy. Those remain explicit higher layers.

`std.net.http.response` provides the matching pure, bounded HTTP/1.x response-
head writer. `ResponseLimits.policy` fixes the complete head, field count,
field-name, and field-value bounds. `ResponsePolicy.response` validates the
request method, version, RFC 9110 status range, reason phrase, explicit body
length, and connection mode before creating a mutable `ResponseWriter`.
`ResponseWriter.field` preserves ordered duplicates but rejects invalid token
names, invalid values, and caller-supplied `Content-Length`,
`Transfer-Encoding`, `Connection`, or `Trailer`; framing fields have one owner.
Consuming `finish` appends the bounded automatic framing and yields a
`ResponseHead`. Its head byte buffer transfers through consuming `intoBytes`
without copying, while the body remains in caller-owned storage. HEAD and 304
suppress body transmission while retaining representation length;
informational and 204 responses omit Content-Length, and successful CONNECT is
a tunnel. This layer does not send bytes or own a socket, timeout, server loop,
content decoder, TLS session, QUIC connection, or protocol upgrade.

`std.net.http.request` provides the matching pure, bounded HTTP/1.x request-
head writer. A `RequestTarget` explicitly selects origin, absolute, authority,
or asterisk form. `RequestPolicy.request` validates the method-dependent form,
version, authority, explicit body length, connection mode, and independent
head limits before returning a mutable `RequestWriter`. Ordered application
fields are appended with `field`; Host, Content-Length, Transfer-Encoding,
Connection, and Trailer remain reserved to the framing owner. Consuming
`finish` emits exactly one Host, the required Content-Length and connection
field, and yields a `RequestHead` whose existing bytes transfer without a
copy. CONNECT requires authority-form with an explicit port, asterisk-form is
OPTIONS-only, and fragments, user-info, controls, whitespace, and invalid
schemes are rejected. The body remains caller-owned. This layer performs no
network, DNS, TLS, redirect, decompression, timeout, cancellation, or protocol
downgrade work.

`std.net.quic.initial_engine` integrates the v1/v2 long-header parser, Initial key
derivation, header protection, AEAD, packet-number restoration, CRYPTO frame,
and ClientHello/ServerHello framing. A client Initial is padded to at least
1200 bytes. The server derives client Initial keys from the original
destination connection ID, accepts one offset-zero CRYPTO frame followed only
by PADDING, and replies with the server Initial key direction. Fixtures 929 and
933 prove the in-memory and real UDP roundtrips on Windows and Linux; these are
foundational self-interoperability checks, not yet independent QUIC endpoint
interoperability.

`std.net.quic.handshake_engine` applies the negotiated TLS handshake traffic
secret to v1/v2 Handshake long-header packets. `std.net.quic.application_engine`
applies the application traffic secret to 1-RTT short-header packets, validates
the destination connection ID and reserved bits, carries STREAM and DATAGRAM
frames, and advances the receive key phase only after authentication succeeds
with the next `traffic upd` secret. CONNECTION_CLOSE transport/application
forms and HANDSHAKE_DONE have their RFC wire values and strict length checks.
MAX_DATA, MAX_STREAM_DATA, MAX_STREAMS, DATA_BLOCKED, STREAM_DATA_BLOCKED, and
STREAMS_BLOCKED share the same varint codec and preserve the bidirectional or
unidirectional stream-limit bit in their nominal values.
Stream IDs are connection-local 62-bit QUIC varints. Their two low bits encode
initiator and direction, leaving a 60-bit per-family sequence; stream-count
limits and local allocation reject values beyond that family range before ID
multiplication so overflow cannot alias an earlier stream.
`frame.encodeAll` and `frame.decodeAll` preserve ordered frame sequences, and
the 1-RTT application engine seals and opens that sequence as one authenticated
packet rather than requiring one frame per packet.
These engines are pure Sollang protocol slices. Their Windows/Linux
self-roundtrips are required evidence, but do not replace an independent QUIC
endpoint interoperability test or the connection-level ACK, recovery, flow
control, coalescing, and handshake-confirmation state machine.

The pure TLS layer emits and strictly decodes TLS 1.3 ClientHello,
ServerHello, and EncryptedExtensions for AES-128-GCM-SHA256 and X25519. The
ClientHello carries SNI, ALPN, supported versions, signature algorithms, key
share, and QUIC transport parameters; the encrypted extensions carry the
selected ALPN and peer transport parameters. Certificate, CertificateVerify,
and Finished framing is likewise length-checked, CertificateVerify input uses
the RFC 9846 64-space context construction, and Finished comparison consumes
all 32 bytes. The TLS state machines do not advance authentication messages on
framing alone: exact-DER pinned-certificate mode first compares the complete
certificate, parses its RFC 5280 TBSCertificate structure, accepts only an
RFC 8410 Ed25519 SubjectPublicKeyInfo whose algorithm parameters are absent,
and requires the requested server name to match a subjectAltName dNSName
exactly under ASCII case folding.
CertificateVerify then uses only that extracted key over the transcript hash
before the message; the server creates the message from the same transcript
point, and received Finished messages must match the expected verify_data.
Authentication failure moves the state to `Failed`. Exact certificate pinning
plus exact DNS SAN matching is not general X.509 path, validity, revocation,
wildcard, IP-address, or IDNA service-identity validation; those remain separate
authentication gates for a general-purpose Internet-facing QUIC endpoint.

`std.net.quic.p2p` builds an authenticated direct-peer session on that QUIC
transport. `PeerId` is the SHA-256 digest of an Ed25519 public key. A signed,
expiring `PeerRecord` binds that identity to an IPv4 endpoint and the exact
QUIC certificate used for transport pinning. `dial` verifies the record before
network access, and `dial`/`accept` then perform a nonce-based mutual Ed25519
proof over a domain-separated transcript. Neither peer trusts the rendezvous
service that delivered the record.

After authentication, `openProtocol`/`acceptProtocol` negotiate an exact
application protocol byte string. `sendMessage` and `receiveMessage` use
length-prefixed messages on the authenticated channel, `finish` closes the
application direction, and `close` closes the QUIC connection. The present
connection implementation exposes one bidirectional stream, so authentication,
protocol negotiation, and messages currently reuse stream zero. This is a
bounded P2P-channel implementation limit, not permission for repeated
`Connection.openBi`/`acceptBi` calls to manufacture separate owners with the
same wire ID. Connection-local non-reusing stream identities are required
before multiplexed or unidirectional public APIs. Protocol names are limited
to 1,024 bytes and messages to 60,000 bytes.

This is direct P2P for peers whose advertised UDP endpoint is reachable, such
as a LAN peer or a public/forwarded address. A `PeerRecord` is suitable for a
future rendezvous or out-of-band exchange, but the module does not claim ICE,
STUN address discovery, relay, NAT hole punching, simultaneous connect, or
NAT keepalive support. Those require concurrent endpoint driving and explicit
rendezvous/relay contracts and must remain separate layers instead of being
simulated by a direct-connect fallback.

General algorithms live in `std.algorithm` and require an explicit import.
An `Ordering { direction: Ascending | Descending }` value owns the ordering
policy; its `sort`, `binarySearch`, `min`, `max`, and `clamp` methods accept a
`Comparison` implementation whose associated `Item` matches the element type.
`Comparison.compare` borrows both inputs and returns a negative, zero, or positive
`Int`. It must define a pure, deterministic strict weak ordering. Only the sign
is significant: descending order reverses the sign test, never the integer
itself, so an `Int.min` comparison result remains valid.

`Ordering.sort` mutably borrows a caller-owned growable array and performs
unstable heapsort with worst-case O(n log n) comparisons and O(1) additional
storage. It preserves the owner, length, capacity, and element multiset without
allocating a collection or copying the whole storage. The current permutation
operations require inline-copyable elements; ordinary ownership checking rejects
owned element types instead of cloning or silently materializing them.
`binarySearch` borrows an existing growable array already sorted by the same
direction and comparator. In O(log n) comparisons it returns a `SearchResult`
containing the first equal index and `found: true`, or the insertion index and
`found: false` when absent. It does not sort or copy the input.

`min` and `max` return copyable values and preserve the first input on an
equivalent comparison. `clamp` interprets its lower and upper bounds using the
same direction and comparator, accepts equal bounds, and returns
`Error.ReversedBounds` for reversed bounds rather than swapping them. These
library operations do not allocate storage; their cost excludes work explicitly
performed by a user-supplied comparator.

General-purpose sequence operations live in `std.sequence` and require an
explicit import. `range(start, endInclusive)` returns a first-class `Range`
that stores only its two `Int` bounds. `each` consumes that value as a direct
inclusive loop, so no element array is allocated. `map<R>` is declared with
`-> stream R`: when followed by `each`, every emitted value is sent directly to
that consumer without a mapped result array. Streaming stages may be chained;
the final stage is `each` or a `Unit` block function.

```sollang
public map<R> values: Range -> stream R block item: Int -> R {
    values -> each item {
        item -> yield -> emit
    }
}
```

The growable-array counterpart is named `mapArray<T, R>` because the current
language does not overload public functions by source type. One module import
provides the complete sequence vocabulary without an ambiguous `map`:

```sollang
import std.sequence
```

The Range mapper declares `R` only in its callback result and stream element:

```sollang
public map<R> values: Range -> stream R block item: Int -> R
```

For a generic block function whose source and callback input are concrete, the
callback's final expression may infer an otherwise output-only type parameter.
This keeps `Range` lazy while allowing the projected type to be any valid
Sollang value. `filter<T>` conditionally emits its input, and `tap<T>` invokes
an effectful callback before emitting the unchanged value. `take<T>` and
`skip<T>` are ordinary library stream functions, not compiler intrinsics.
Generic parameters may also be inferred from additional arguments, allowing
`scan<T, S>` to derive `S` directly from its initial accumulator.
Ordinary generic calls and user-block calls share recursive inference for
`Option<T>`, `Result<T, E>`, dictionary key/value types, growable arrays, and
readonly references. Each argument contributes to the same inference environment;
conflicting occurrences of a parameter are rejected in argument order. A
user-block source passed to `ref T` must have an addressable owner or reference,
and code generation preserves that borrow rather than passing the value as `T`.
An explicit user-block result binding has the function's declared result type.
The source input, callback input, callback result, and function result retain
their separate contracts, including when the result is used only in interpolation.
User-block runtime argument inference visits the source value and then the
explicit arguments in source order. The callee path, callback role names, and
callback body are excluded from those argument slots.
Braces inside parameter or result type annotations belong to those types;
they do not begin a function body or end its caller-supplied block signature.

A stream function can declare pipeline-lifetime mutable state with
`value => state name!`. The initializer runs once when that stage is created;
ordinary statements run once per incoming item. `stop` requests upstream
cancellation after the current item finishes downstream processing. Every
enclosing source loop observes the same signal, including loops nested by
`flatMap`.

```sollang
public take<T> value: T, count: Int -> stream T {
    0 => state taken!
    taken! < count -> if {
        taken! + 1 => taken!
        taken! >= count -> if { stop }
        value -> emit
    } else {
        stop
    }
}
```

`scan<T, S>` combines callback execution and pipeline-lifetime state. For every
incoming `T`, the callback receives the current `S` and the item, and its result
becomes both the next state and the emitted value:

```sollang
public scan<T, S> value: T, initial: S -> stream S block accumulated: S, item: T -> S {
    initial => state current!
    current! -> yield(value) => current!
    current! -> emit
}
```

`yield` invokes the caller-supplied block and returns its result. `emit` forwards
that result to the downstream consumer. Streaming is therefore a declared
property of any user block function, not a compiler rule attached to `map`.
For a bound call such as `current! -> yield(value) => current!`, the flow result
and its binding have the block result type `S`; the receiver has type `S` and
the additional argument retains type `T`. This also applies when `T` and `S`
are different nominal types.

```sollang
values
    -> map item { item * 10 }
    -> each mapped {
        "$mapped" -> println
    }
```

The downstream `each` owns the mapped value for one iteration. Its `break` and
`continue` control the original source loop, so mapping stops as soon as the
consumer stops. `beforeEach` runs immediately before an outer range item enters
the downstream chain. `afterEach` first emits the item and runs its callback
only after downstream processing returns. This expresses scoped preprocessing
and postprocessing without testing the first or last inner index:

```sollang
2..9
    -> beforeEach dan { "$(dan)단" -> println }
    -> afterEach dan { println() }
    -> flatMap(1..9) dan, multiplier {
        "$dan × $multiplier = $(dan * multiplier)"
    }
    -> each line {
        line -> println
    }
```

`Stream<T>` is the affine, first-class form of a deferred producer. It is a
three-word ABI value containing an opaque context, a typed `next` function, and
a `drop` function. The value may be bound to a name, moved through a library
function, returned, and then consumed by `each`. It never owns a materialized
element collection. A second terminal use is an ownership error.
The terminal consumer makes the producer's name unavailable. A later read is
diagnosed as an unknown binding, with the same rule for `Stream<T>` and
`EventStream<T>`. The error points to the later read and names its source
module. The self-host compiler determines that visibility from the
canonical ownership moves, reachability, and reinitialization after Typed IR
lowering and blocks output before LLVM generation. This semantic ownership
result is distinct from an unnamed affine producer reuse diagnostic.

`std.sequence.defer` converts a `Range` into `Stream<Int>` by allocating only
the small producer context that stores the current and inclusive end values.
Local block pipelines continue to use fused loop lowering and allocate no
producer object at all. The public ABI is used only when the stream must become
a runtime value across a function or library boundary.

`EventStream<T>` uses the same affine producer shape but represents a hot
source whose `next` may wait for external input. Dropping it performs structured
cancellation: signal cancellation, wake or interrupt the producer, join its
worker, restore platform state, and release its fixed storage.
Every producer's third ABI word is a lifecycle callback
`void(context, destroy)`: `destroy=false` signals cancellation and wakes blocked
readers without reclaiming their context, while `destroy=true` completes
structured destruction. Cold `Stream` producers use the same callback signature;
cancellation alone leaves their deferred context intact. The callback contract
also remains consistent for joins backed entirely by cold inputs that produce
an `EventStream`.
An event join first cancels its inputs, joins every worker that can still enter
or execute an input's `next`, and only then destroys the input contexts. Nested
joins propagate cancellation without reclaiming storage still borrowed by an
outer worker. A source's worker and reader resources remain live until these
borrows have ended; an in-callback reader counter alone cannot cover a worker
that has registered a pull but has not yet entered the callback.

A local `partition` registers one consumer for every route before dispatching
its source. Dispatch begins at the final consumer registration, regardless of
registration order. Root initializers and effects between registrations run
before dispatch; predicates and callbacks retain their order inside the shared
loop. Producer and predicate function calls retain their resolved module identity.

Stream joins accept a product of `Stream<T>` and `EventStream<T>` inputs.
`merge` and `latest` always produce `EventStream`; `concat` and `zip` produce
`EventStream` when any input is an event stream, otherwise `Stream`. Merge
and concat require identical input element types. Zip and latest preserve
input order and labels in a product element type. Latest requires copyable
elements because each update emits the current product again.

`sys.input.mouse.source(capacity, overflow)` validates the first concrete hot
input source plan. `capacity` must be in `2..65536`; invalid dynamic values are
typed `Error` results and invalid literals are rejected during compilation.
`Source.events: move self -> EventStream<Event>` starts the subscription without
a public wrapper, consumes the plan exactly once, and owns cancellation until
the stream is dropped. Its ring buffer never grows, and `OverflowPolicy` is one
of:

- `DropNewest`: retain queued events and discard the incoming event.
- `DropOldest`: discard the oldest queued event and retain the incoming event.
- `CoalesceMotion`: replace the newest pending motion event when possible;
  button and wheel transitions otherwise use oldest-drop behavior.

Windows reads `MOUSE_EVENT_RECORD` values with `ReadConsoleInputW`. Linux
enables SGR 1003/1006 reporting and parses terminal input. Browser WebAssembly
rejects this blocking pull adapter with a target capability diagnostic. DOM
events require a future host-driven callback lowering because synchronous Wasm
execution on the browser main thread cannot wait for an event without blocking
its delivery.

The compiler composes these callbacks as synchronous continuations and lowers
the whole chain into the source loops. No intermediate array, iterator object,
virtual dispatch, or callback allocation is introduced. Interpolated Text is
kept as an ordered formatting plan whose holes are evaluated exactly once when
the value is produced. A following print consumer writes those evaluated
segments into the platform's buffered output sink without first allocating an
owned Text buffer. This is a general stream-value rule rather than a special
case for `flatMap` or `println`.

Importing a module exposes each direct public symbol both through the module
alias and as an unqualified name. Therefore `import std.sequence` permits both
`sequence.flatMap` and `flatMap`. An import path may also end at one public
symbol when a source wants to import only that name or assign an explicit
alias:

```sollang
import std.sequence

2..9
    -> beforeEach outer { "$outer단" -> println }
    -> afterEach outer { println() }
    -> flatMap(1..9) outer, inner {
        "$outer × $inner"
    }
    -> each line {
        line -> println
    }
```

Local declarations and explicit import aliases take precedence over names
opened by a module import. If multiple imported modules expose the same short
name, using that short name is a compile-time ambiguity. The diagnostic lists
the candidates and directs the caller to a qualified spelling such as
`sequence.flatMap` or to an alias for the module. Qualified module access
remains valid regardless of short-name collisions.

User-block callback inputs borrow the values supplied by the producer's
`yield`; naming an input does not create another owner. A callback may read
owned storage through that role, but cannot pass the role to a `move` input.
The producer retains ownership and cleanup responsibility. This rule applies
to every callback input and while inferring generic callback result types.

Self-host lowering preserves callback input names in declaration order for
single-stage calls and longer pipelines alike. Each input resolves its own
declared type and corresponding yielded value; a later role type cannot become
the callback result type. In the compact AST, a signature type retains its
introducing colon or arrow in `operatorKind`, so symbol collection distinguishes
role inputs from the optional callback result without assuming an input count.

Block functions may declare multiple callback inputs after `block`, separated
by commas. Calls provide the same number of item names. Inside the block
function implementation, the flowed value supplies the first callback input
and `yield` arguments supply the rest:

```sollang
pair source: Source -> Unit block outer: Int, inner: Text {
    source.outer -> yield(source.inner)
}
```

Source code can use either spelling:

```sollang
"Hello" -> print
"Hello" -> sys.io.print
"n = ? " -> readInt => n
"n = ? " -> sys.io.readInt => n
```

These functions are resolved through the same function table as user functions.
They are not parsed as keywords or statement-specific built-ins. Their only
current privilege is the global alias layer. The backend inlines the Sollang
`sys.io` wrappers and lowers the `sys.runtime` intrinsic boundary to the
selected platform I/O implementation.

The global aliases `limitParallelWorkers`, `parallelWorkers`, and
`parallelPeakWorkers` resolve to the actual declarations with those names in
`sys.runtime`. Bare and qualified calls retain the same declaration identity,
visibility, source authority, and return type. An absent or inaccessible
declaration cannot be replaced by an implicit runtime operation. A non-intrinsic
function with the same name remains an ordinary function.

On targets supporting the compute pool, `limitParallelWorkers` bounds the
requested worker count to 1 through 64 and starts the pool. Once the pool has
started, another limit request returns the existing worker count.
`parallelWorkers` starts the pool if necessary and returns its worker count.
`parallelPeakWorkers` reads the recorded peak without starting the pool.

`std.crypto.sha256.create()` constructs a `Hasher` with bounded 64-byte block
storage. Its inherent `update(mut self, source: [UInt8])` processes a borrowed
byte slice without retaining it; consuming `finish(move self)` returns the
complete `[UInt8; 32]` digest. Empty input requires no update. One-shot and
incremental hashing use this same instance contract; there is no public
`sha256.digest` convenience wrapper.

`std.crypto.hmac_sha256.create(key: [UInt8])` constructs an owned `Hasher`.
The key is borrowed only during construction. Its inherent
`update(mut self, source: [UInt8])` borrows each message segment without
retaining it; `finish(move self)` consumes the instance and returns the
complete `[UInt8; 32]` MAC. Empty updates do not change the result, and
segment boundaries do not change the MAC. One-shot input uses the same
instance contract; there is no public `hmac_sha256.digest` wrapper.

The current purpose-oriented file and random libraries follow the same wrapper
pattern:

```sollang
seedRandom value: Int -> Unit
randomBelow maxExclusive: Int -> Int
std.crypto.random.bytes count: UIntSize
    -> Result<[UInt8; ~], std.crypto.random.Error> uses Random

openIntWriter path: Text -> Unit
writeInt value: Int -> Unit
closeIntWriter: -> Unit

openIntReader path: Text -> Unit
closestInt target: Int -> Int
closeIntReader: -> Unit
```

`seedRandom` and `randomBelow` are deterministic workflow primitives and are
not cryptographic. `std.crypto.random.bytes` allocates an independently owned
byte array and fills it from the operating-system cryptographic source:
`BCryptGenRandom` with `BCRYPT_USE_SYSTEM_PREFERRED_RNG` on Windows and
`getrandom` on Linux. Failure is returned as `Error.Unavailable`; it never
falls back to the deterministic generator. The declaration, runtime helper,
and Windows `bcrypt.dll` import are emitted when the intrinsic symbol has a
lowered function or call result type in the emitted source set. This matches
the current whole-package function emission model: a runtime definition must
not be restricted to the entry-point reachability closure while non-root
function bodies are still emitted. `wasm32-browser` rejects the capability
until a host cryptographic random source is explicitly provided.

The legacy sorted-`Int` file format is binary, little-endian, signed 64-bit records.
`writeInt` appends to the current writer through an internal buffer. `closestInt`
expects the current reader file to be sorted ascending and performs a binary
search over fixed-width records. General affine sync/async file handles,
position-based reads/writes, canonical scalar I/O, mapping, and explicit
user-value serialization are specified in the later file sections. Broader
text/binary codecs remain format-specific library work.

The 100,000,000-record generator avoids a separate sort by dividing
`1..1,000,000,000` into 100,000,000 10-wide buckets and choosing one
pseudo-random value from each bucket in increasing bucket order:

```sollang
main {
    "artifacts/random-sorted-100m.i64" -> openIntWriter
    20260708 -> seedRandom

    1..100000000 -> each bucket {
        bucket - 1 => zeroBased
        zeroBased * 10 => base
        10 -> randomBelow => offset
        base + offset + 1 => value
        value -> writeInt
    }

    closeIntWriter
}
```

This produces sorted unique values with one pseudo-random choice per bucket. It
is not a uniform sample over all possible 100,000,000-element subsets of
`1..1,000,000,000`.

## HTTP Message Body Framing

`std.net.http.body` is the pure RFC 9112 message-body boundary over an already
parsed head. Construct `BodyPolicy` from explicit encoded, decoded, chunk-line,
trailer-byte, and trailer-field limits. Use `policy -> request(head)` or
`policy -> responseContext(method) -> plan(head)`, then create an affine
`BodyDecoder`. Feed a complete caller-owned view through
`decoder! -> write(input, output!)`. When a receive buffer also contains a
header prefix or pipelined suffix, use
`decoder! -> writeRange(input, offset, length, output!)`; it validates the
range before decoder/output mutation and reports `BodyProgress.consumed`
relative to that range without copying input. Advance the caller's cursor by
`offset + consumed` and retain the remaining bytes because consumption stops
before the next pipelined message. Consuming
`finish` completes close-delimited response bodies and rejects incomplete
fixed-length or chunked bodies. Preserve RFC precedence: reject simultaneous
Transfer-Encoding and Content-Length, reject duplicate Content-Length under
the strict security policy, require final `chunked` for framed requests, give
HEAD/1xx/204/304 no body, and expose successful CONNECT as a tunnel. The
decoder validates chunk CRLF and trailers incrementally without retaining the
complete encoded input. It still performs no socket I/O, content decoding,
client pooling, server orchestration, timeout, redirect, retry, or cancellation.
`BodyDecoder.completion()` performs the same terminal-framing check without
consuming the decoder. Use it only when an affine aggregate such as
`RequestBody` must validate one projected field and then move the complete
aggregate exactly once; ordinary standalone decoder callers should keep using
consuming `finish()`.

## Numeric Expressions

Numeric expressions use stable, fixed-width primitives:

```sollang
Int8(20) + Int8(22) => small
Float32(1.5) * Float32(2.0) => scaled
```

Numeric rules:

- Decimal integer literals default to `Int`, which is always `Int32`.
- When a destination integer type is known from an argument, return, `when`
  arm, struct initializer, indexed element assignment, or direct/projected field assignment, an integer
  literal is checked and lowered as that exact destination type. This is
  contextual typing, not implicit widening or narrowing of a typed value.
- Fractional or exponent literals default to `Float`, which is always
  IEEE-754 `Float32`.
  Unary negation preserves that floating width and IEEE-754 signed zero,
  including in function arguments, control conditions, and interpolation.
- Explicit widths are `Int8/16/32/64`, `UInt8/16/32/64`, and `Float32/64`.
- Constructor-like conversions such as `Int8(value)` and `Float32(value)` are
  explicit. Literal range failures are compile errors and runtime integer
  narrowing performs a bounds check.
- Binary arithmetic requires equal numeric operand types; Sollang does not
  silently widen, narrow, or change signedness. `%` is integer-only and unary
  `-` rejects unsigned values. `CodePoint` requires an explicit conversion to
  `UInt32` before binary arithmetic. Both operands are inferred before checking
  the left operand's arithmetic domain, then the right operand's type equality.
  An invalid left domain is diagnosed at that operand's expression location.
  For a direct or additional argument with a known declared integer input type,
  arithmetic operands instead receive that expected type recursively. Numeric
  literals adopt it; independently typed operands retain their own type. An
  incompatible operand reports the expected type at that operand. An operand
  inference or literal-range failure precedes validation of its enclosing
  arithmetic operation. A primary flow source is inferred before call argument
  validation. A generic argument uses only context known before its inference.
- `*`, `/`, and `%` bind tighter than `+` and `-`; operators are
  left-associative.
- Integer bindings can be interpolated using invariant decimal display.
- `Long` aliases `Int64` and `Double` aliases `Float64`; the exact-width names
  remain available when representation should be explicit. Semantic type
  diagnostics display these types as `Long` and `Double`, and display
  `Float32` as `Float`, regardless of which accepted spelling appears in source.
- `Size` and `UIntSize` use the target pointer width: 64 bits on the current
  Windows/Linux x64 targets and 32 bits on wasm32. `Size` is signed for offsets
  and differences; `UIntSize` is unsigned for byte counts and capacities.
  Literal range checks, explicit conversions, aggregate layout, and LLVM
  function ABI all use that target width. Ordinary `Int` remains `Int32` on
  every target.

## Struct Field Visibility And Nested Structs

Struct fields are private to their declaring logical module unless the field
itself is marked `public`:

```sollang
public struct StreamCount {
    raw: UInt64
}

public struct Point {
    public x: Int
    public y: Int
}
```

The nominal type and its public functions or inherent methods remain visible
through imports. All source fragments with the same namespace belong to one
logical module, so a factory and an `impl` may directly access private fields
from different files. Outside that module, a struct literal is valid only when
every field needed to construct the value is public. Reading or writing a field
requires that exact field to be public. Private-field misuse is rejected before
LLVM, and the diagnostic directs the caller to a public factory or public
instance method. The check follows the resolved nominal owner through inferred
member chains, so `wrapper.inner.secret` cannot bypass a private `secret` field
merely because the caller did not spell `Inner`.

Field visibility has no runtime representation. Private and public fields use
the same inline layout, calling convention, ownership, and direct projection.
Visibility must not introduce a heap wrapper, object header, dynamic dispatch,
hidden copy, or retained validation result. Fixture 1391 fixes same-module and
public-field access plus the one-`UInt64` case as one LLVM aggregate with direct
`insertvalue` and `extractvalue`; fixtures 1392, 1393, and the historical
`opaque-struct-*` diagnostic identifiers fix the self-host and private-field
boundary. The obsolete `opaque` struct modifier is rejected by the grammar.

Struct declarations may contain helper struct declarations:

```sollang
struct Parser {
    struct Cursor {
        offset: Int
    }

    cursor: Cursor
}
```

The nested type is nominally `Parser.Cursor` but `Parser` fields and
`impl Parser` bodies resolve the short name `Cursor`. A nested struct is private
to its declaring struct by default. Prefixing the nested declaration with
`public` exposes the qualified name to other code. Layout, initialization,
ownership, recursive drop, and value-cycle checks are identical to top-level
structs.

## Generic Delimiters And Result Propagation

Generic type and compile-time value parameters use `<...>`:

```sollang
Option<Int>
Result<Int, Text>
identity<T> value: T -> T => value
values -> fixedLength<3>
```

`[]` is reserved for arrays, indexing, and collection expansion. The former
generic square-bracket spelling is not accepted.

Generic call inference uses one environment across the primary and additional
arguments. That complete environment specializes the input, additional-input,
and return types before the call result is bound or read by a later expression.
An explicit flow type argument seeds the environment before the primary input.
When preceding inputs determine an additional parameter's concrete numeric
type, its numeric literal or value-if branch literals use that context before
further inference and range checking. Return typing uses this same context.
A conflicting actual type reports the declared type parameter and its first
and conflicting actual types at the conflicting argument. The failed call has
no valid result from which to report additional consumer errors.

Inherent methods may declare method-scoped generic parameters after the method
name and before the colon: `identity<T>: self, value: T -> T => value` inside
an `impl` block. A trailing `where` clause supplies constraints. Infer these
parameters from the matching inputs, preserving the receiver's owner type and
keeping different instantiations separate. Managed compilation supports this
surface. Native direct calls publish separate concrete function bodies and
call signatures for ordinary functions and inherent methods, preserving
receiver ownership and method scope. Direct trait-constraint calls in a concrete
body resolve against both the requested trait and receiver type. Managed nested
generic helper calls preserve distinct type instantiations. Native nested helper
calls and recursive calls preserve concrete integer and Text specializations
and reuse identical instantiations. Other recursive type shapes
require further target verification.
Parsing alone does not establish target support.

An inherent method may also declare a typed block role. Unqualified block-call
syntax resolves the exact nominal type of the flowed receiver before considering
a top-level block function with the same name. An explicit qualified owner must
match that receiver and never falls back by stripping the qualifier. `self`
selects the method only; it does not infer a method type parameter or replace
the declared callback role. For `block item: ref T`, infer `T` from the matching
explicit method arguments and borrow the yielded element as `ref T`.

Flow-call method lookup uses the exact nominal type of the immediate receiver,
including the result of a preceding call in the same chain. An imported
inherent method is eligible only when its `impl` header names that receiver
type. Qualified types mentioned inside method parameters or results do not
change the `impl` owner and cannot override an otherwise valid lexical function.
For a qualified struct literal used directly as a flow receiver, its leading
type path selects the owner. Qualified paths inside field initializers cannot
replace that receiver or its method result type.

Postfix `?` applies only to `Result<T, E>`. On `Ok`, its expression value is the
success payload. On `Err`, it returns `Result<U, E>.Err(error)` from the nearest
enclosing Result-returning function after deterministic local cleanup. Error
types must match exactly. An owned Result may be propagated when the operand is
a fresh temporary or the function's explicit `move Result<T, E>` input. A named
non-move owned Result is rejected instead of being copied.
A readonly `ref Result<T, E>` reads the same success and error types. Propagation
may copy its payload only when it contains no owned storage; borrowing the
Result does not authorize transferring its backing or resource ownership.
The postfix applies to a complete value-flow expression as well as to its
source, so `owner -> fallibleTransform?` propagates the target Result without
an intermediate binding. If the target consumes an owned source, both the
success and propagated-error paths transfer that source exactly once.
Inside interpolation, a field access after `?` uses the `Ok` payload type only
after the Result and enclosing function error types are validated. If `?` is
invalid, report its propagation error before field display eligibility.
For a semantically resolved propagation, the successful payload type also
participates in interpolation displayability and enclosing unary, binary or
conversion inference before Typed IR lowering. Invalid propagation does not
supply a successful payload type to those consumers.

An enum-pattern payload containing owned storage is a borrow unless the match
subject itself is a named owner or a fresh owned temporary. Re-wrapping a
borrowed payload in an owned aggregate, or passing it to a `move` input, is a
semantic error rather than an implicit pointer copy.
The transferable case also permits `Ok(payload) { payload => owner!; ... }`:
this creates a new mutable owner by one explicit move, not a copy or a wholesale
replacement of an existing mutable container. The old payload and consumed
subject cannot subsequently be reused. A borrowed subject grants no such
transfer authority, including through a nested match or shadowed binding.
When an arm terminates, an owned payload extracted from a fresh or consumed
subject participates in that terminating cleanup even though continuing arms
treat the binding as a borrow until an explicit transfer. A genuinely borrowed
subject remains excluded from payload cleanup and is released only by its owner.
When an owned payload becomes the subject of a nested match, its exact cleanup
obligation grants the nested match transfer authority. An actual inner transfer
discharges the outer obligation and transfers cleanup to the inner owner once;
the outer arm must not release the transferred backing again. A borrowed local
view alone does not grant this authority.
Binding a directly named owned payload to a new local transfers its cleanup
obligation to that local. A fixed-storage value copy preserves the source
obligation instead. Both compilers record this distinction before arm cleanup.

The same transfer rule applies when an aggregate containing a borrowed owned
value enters owned container storage through `push`, `put`, heap insertion, or
set insertion. Fixed arrays count as owned storage in the current ABI. The
compiler must reject the borrowed form with an actionable move-or-copy repair
before LLVM emission. An owning enum constructor applies this check to its
payload before recording the successful constructor or consuming its source.
An explicit reference is a borrow of its element storage, not ownership of
that storage. A borrowed fixed payload may be copied only when its elements
and owned fields satisfy the fixed-storage copy contract; noncopyable owned
elements must be rejected. A match payload with transfer authority remains
eligible for ownership transfer. A `move` parameter has exactly one cleanup path. When a
`move self` method consumes one projected owned field, cleanup drops only the
remaining live sibling fields and never invokes the full owner drop afterward.
The semantic ownership check tracks the complete projected place. After an
owned field is moved, a later read or transfer of that field, its ancestor, or
its descendant is rejected before LLVM generation with the overlapping owned
field path. Independent sibling fields remain usable. Repeated moves within
one call follow the same place-overlap rule. Diagnostic place spelling follows
the parsed tokens, so source spacing around projection punctuation does not
change the named place.
At a branch or loop join, a moved-field state that differs between continuing
paths is a branch ownership error. The diagnostic names the affected field and
its binding; this join error takes precedence over a later overlapping-field
read derived from the same move site. All moved fields from one binding at the
same join are reported once, with duplicate names removed and names in ordinal
lexical order. If a field is moved twice inside one branch, the second move is
rejected as an overlapping field access before the branch-state comparison.

Result constructors
consume named owned payloads and transfer their single drop obligation into the
new enum value.

## Containers

Constant ranges and compile-time `each` expressions can construct collections:

```sollang
[1..10]
[1..10 -> each { it + 1 }]
{1..3 -> each { it: it * 10 }}
```

Ranges are inclusive. When their bounds and selector arithmetic are constant
integers, the compiler expands these forms into ordinary array elements or
dictionary entries before semantic analysis. An explicit item name may replace
`it`, as in `[1..3 -> each item { item * item }]`. Nonconstant expressions are
diagnosed; compile-time expansion currently has a 100,000-element limit.
Outside a collection literal, `source -> each item { ... }` is a runtime block
statement. It may be the last statement of a `Unit` function or branch; its
position does not turn it into a compile-time collection expansion.

Container storage is explicit in the type. Implementations must not silently
switch an inline owner to heap storage.

Static arrays:

```sollang
[1, 2, 3] => numbers
[0; 8] => zeros
numbers[0] => first
numbers -> len => count
```

For nominal struct elements, name the element type once and initialize each
record by field name:

```sollang
struct Point {
    x: Int
    y: Int
}

[Point; { x: 10, y: 20 }, { x: 30, y: 40 }] => points
```

This form has the exact fixed type `[Point; 2]`. Each record must initialize
every declared field exactly once. Unknown names, duplicate or missing fields,
and incompatible field types are compile-time errors. Field identity is its
name, independent of initializer order; aggregate storage follows declaration
order. Effectful initializer expressions retain source order. A numeric literal
inherits the declared integer field type only when its value fits that type;
a typed variable does not gain an implicit narrowing conversion.
An incompatible nominal field value reports the value expression's location,
the field name, and the canonical expected and actual type names. An import
alias changes the source spelling, not the declaring module's type identity.
Integer-literal diagnostics use the parsed decimal value with digit separators
removed. A `CodePoint` literal outside `0..1114111` reports the range; a value
inside the Unicode surrogate interval `55296..57343` reports the surrogate
restriction separately. The same distinction applies to enum payload literals
and explicit numeric conversions of literals. Computed conversions retain
runtime range checks. On Windows and the browser target, a failed computed
integer conversion reports its source function declaration identity (or `main`)
and `numeric_conversion_lower`, `numeric_conversion_upper`, or
`numeric_conversion_surrogate` before trapping. The diagnostic code does not
depend on generated LLVM block names. An integer-shaped literal in an explicit integer
conversion is checked and emitted at the destination width, even when it
exceeds the default `Int` range. A computed same-width integer conversion
checks its destination range and then preserves the original value.
A numeric literal in an explicit floating-point conversion is encoded directly
at the destination `Float32` or `Float64` precision, including decimal,
exponent, and negated literals. Converting a computed floating-point value
preserves the precision already committed to that operand before widening or
narrowing it. These rules also apply inside interpolation expressions.
An explicit numeric conversion accepts exactly one
numeric operand. A nonnumeric operand is a semantic error, including when the
conversion appears inside text interpolation; code generation does not decide
whether the operand is numeric. Its target must be a numeric type: integer
types, `CodePoint`, `Float`/`Float32`, or `Float64`/`Double`. `Bool` is not a
numeric conversion target. Converting a floating-point value to `CodePoint`
is a semantic error even when the value would be an integral Unicode scalar.
Inside interpolation, an arity error points to the conversion call; a
nonnumeric operand or floating-point `CodePoint` operand error points to that
operand. These locations use the parsed interpolation expression's coordinates.
An intrinsic flow call inside an interpolation expression contributes its
result type to the surrounding expression. For example, `Text.slice` yields
`Text`, so a numeric conversion of that result fails during semantic analysis
before LLVM emission.
An instance method flow call contributes its declared return type in the same
way. A numeric conversion of a method returning `Text` reports the nonnumeric
operand during semantic analysis before LLVM emission.
When an instance method has the same name as an intrinsic flow operation, its
declared return type governs nested interpolation expressions. For example,
a nominal `len` method returning `Int` is `Int` in arithmetic, rather than the
receiver-dependent intrinsic length type.
The same declared result type applies to ordinary instance methods inside
interpolation arithmetic, including numeric operand validation.
A floating-point conversion may appear inside an interpolation expression
when the final result has a supported display type; floating-point values
are not directly interpolatable. Binary `+`, `-`, `*`, and `/` retain their
validated floating-point operand type inside interpolation and use floating
point arithmetic at that width. `%` requires integer operands. Converting a
floating-point arithmetic result to an integer emits a numeric conversion even
when the source and target have the same bit width; the integer result selects
the interpolation writer in entry code, function arguments, and control blocks.
Nested field, indexed, and call-result member interpolation resolves each
receiver before its member or index use. The final result's type determines
display eligibility; inaccessible intermediate fields report their access
error before any display-type error. An instance method result supplies its
declared return type only after method visibility and additional argument
count are validated; a method error takes precedence over the field's display
type error. Indexing a field of an instance method result resolves the method
return, accessible field, valid index, and element type in that order. The
element type determines interpolation display eligibility. An invalid index
reports only its index error for that expression, before a potential element
display-type error.
A direct nominal struct value and a direct floating literal are not
interpolatable. Their known types determine display eligibility during semantic
analysis before Typed IR. A struct initializer error takes precedence over the
outer display-type error.
A valid unary expression inside interpolation uses its inferred result type
for display eligibility during semantic analysis. An invalid unary operand
reports its own error before any outer display-type error.
For a direct binary interpolation with known operand types, arithmetic keeps
its validated numeric type, while comparison and logical expressions produce
Bool. Operand errors take precedence over the outer display-type check.
Nested binary interpolation composes each validated child result before its
parent's type and final display check. An invalid inner operator reports its
operand error first.
Nested numeric conversions and binary expressions likewise resolve each child
before its parent, including conversions used as binary operands and binary
expressions used as conversion arguments. A failed child conversion or operand
check takes precedence over the enclosing interpolation display check.
Unary `-` and `not` around those nested expressions validate the computed child
type before producing their result and before the final display check.
A same-width integer conversion of an interpolation expression preserves its
computed operand value in each of those positions.
Names bound by stream callbacks retain their callback input type inside
interpolation, including when used as numeric conversion operands. Arithmetic
between a callback role and another numeric value applies the same matching
operand-type rule during semantic analysis, before LLVM emission. Comparisons
use that callback input type and reject mixed numeric types at the right operand.
Unary `not` checks that callback input type against `Bool` during semantic
analysis and reports a non-Boolean operand before LLVM emission.
When several interpolation fragments contain semantic errors, compilation
reports the first failing fragment in source order. A later fragment does not
add another diagnostic after that first failure.
Semantic errors inside a parsed interpolation expression report one-based line
and UTF-16 column relative to that expression. An error in `main` uses the
namespace of its unique executable source, preserved when sources are combined;
`<main>` is used when that source has no namespace. An error in a named function
uses that function's module name. The failed build writes the semantic
diagnostic to stderr without LLVM comments or worker-count notes. Compiler
diagnostic streams use UTF-8 without a byte-order mark, including on Windows.
For a missing field after a nominal constructor, the diagnostic points to the
member access and names only the missing field. A qualified constructor type
path, enclosing parentheses, or trivia around the member access do not become
part of the field name.
The same trivia rule applies when the member resolves to a readonly computed
member; lookup uses the identifier itself.
A plain identifier-only dotted path reports a missing member at its first
identifier. A postfix member after a call, index, `!`, or parenthesized expression
reports the parsed dot position. This is distinct from the identifier span used
for member lookup.
An enum variant after a spaced dot resolves by its identifier; a valid enum
value is then checked against the ordinary interpolation display types.
An uninvoked zero-input associated function after a spaced dot reports the
canonical `Owner.member()` call spelling in its diagnostic.
For a flow call inside `$(expression)`, semantic resolution checks a visible
instance method on the receiver before a free function of the same name.
Public methods of imported receiver types follow that same rule. An unknown
target is a semantic error at the target name's position in the interpolation
expression; LLVM generation does not choose whether the call exists.
A matching private method in an imported module reports that the qualified
function is internal to its declaring module at the same target position.
For a floating-point target, a numeric literal is first parsed as a finite
`Float64`; a `Float32` target also requires its magnitude to fit `Float32`.
An integer-shaped literal in this conversion uses that floating-point value
directly, even when its digits exceed the default `Int` range.
The diagnostic names the target spelling used in the source call.
An integer target rejects a literal with a decimal point or exponent as
`not an integer`, before integer range checking.

An array repeat with a concrete count has that exact fixed-array type. In a
declared array context its repeated value inherits the element type, so
`zeros: -> [UInt8; 32] => [0; 32]` requires neither a `UInt8(0)` constructor nor
a growable intermediate. A value-generic fixed array may be mutably borrowed;
its specialized length name is a compile-time integer in ordinary expressions
as well as in array type and repeat positions. Returning a fixed array from a
function preserves this concrete type and length across the call boundary; the
lowered pointer/length representation does not weaken `[T; N]` into `[T]`.
Copying a named fixed-array result into a returned aggregate creates independent
backing for the destination; an inline callee still drops the named source
backing at its own scope exit rather than classifying that copy as a move.
When a branch produces a copyable fixed-array value from an outer binding,
the branch result receives independent backing and the outer binding remains
available after the join. The same rule applies to copyable fixed-storage
struct results.
When an owned enum match binds a fixed-array payload, the bound payload owns
its backing independently of whether its elements need cleanup. A continuing
arm releases that backing at scope exit unless it transfers the payload.
A borrowed enum subject retains its original cleanup responsibility.
Returning a copyable fixed payload from a match arm copies its backing before
the arm exits. The result owns that copy; the original payload retains its
cleanup responsibility. This is a value copy rather than an ownership transfer.
An owning enum constructor can instead take a named heap-backed fixed local
as its payload. The enum receives that backing and its cleanup responsibility;
the enclosing arm must not release the transferred local backing again.
Heap-backed fixed literals also retain this cleanup responsibility in entry
and nested control regions, independent of scalar element cleanup traits.
Reading a fixed-array struct field in a loop condition borrows its pointer
and length descriptor, whether the struct base is a value or a reference.
Result propagation with `?` extracts that same descriptor for fixed-array
payloads. Its success binding owns the backing until transfer or scope exit;
copying the binding into a struct initializer preserves its original cleanup.
Direct named assignment to an existing owned fixed-array field instead
transfers the backing, releases the previous field value, and clears the
pattern binding's runtime ownership flag only on the path that stores it.
An arm that does not perform that assignment still releases its payload.
An owning enum constructor can also transfer an owned fixed pattern payload;
its completed store clears that pattern's cleanup flag. A payload borrowed
from a reference subject or readonly fixed input instead receives independent
backing in the new enum, and the original owner retains its cleanup.

Dynamic arrays:

```sollang
[10, 20; ~] => values!
values! -> push(30)
values![2] => third
values! -> capacity => capacity

99 => values![1]
```

`capacity` accepts growable arrays, bounded arrays, dictionaries, and `Arena`.
The same receiver contract applies inside interpolation, including readonly
owners and projected fields. Fixed arrays, slices, and `Text` have no capacity
operation and are rejected before LLVM emission. Interpolated calls preserve
source order and evaluate each expression once.
`len` and `capacity` take no arguments. Their argument-count diagnostic is
reported at the flow target before receiver eligibility or user-method lookup,
including when the receiver does not support the intrinsic. With no arguments,
an unsupported receiver continues through ordinary method and function lookup.
Collection `capacity` has an `Int` result; `Arena` and mapped-byte capacities
have a `UIntSize` result. Interpolation preserves that result width for both
printing and expressions that compare it with an ordinary bound value. An
`Int` capacity query checks that the backing capacity is at most `2147483647`
before narrowing; a larger capacity traps instead of wrapping to zero or a
negative result. This check does not restrict valid source capacity hints.

Bounded inline arrays and dictionaries:

```sollang
[Int; <=8] => recent!
recent! -> push(10)
recent! -> capacity => eight

{Int: Int; <=8} => scores!
scores! -> put(7, 70)
```

`[T; <=N]` and `{K: V; <=N}` store their initialized length and all storage
inside the owner value. `N` is a positive integer and part of type identity.
They never allocate, reallocate, free, or spill. An initializer larger than
`N` is rejected before semantic lowering. Runtime insertion past `N` traps
before mutation. Moving or returning the value copies its complete LLVM value
representation, so no pointer may outlive a callee stack frame.

A storage suffix belongs only to the collection whose outer delimiters contain
it. In `{Int: [Int; <=4]}`, the dictionary is growable and its array value has
capacity 4. In `{Int: [Int; <=4]; <=8}`, the dictionary capacity is 8 and the
array-value capacity remains 4. An `Option<T>` wrapper preserves these storage
identities; nested type arguments do not supply their parent's capacity.

Extended collection constructors keep their representation visible:

```sollang
Set<Int>(16) => seen!
Deque<Int>(16) => queue!
BinaryHeap<Int>(16) => priorities!
BitSet<128>() => flags!
```

The first three are nominal heap owners with an explicit initial capacity.
Heap-backed dictionary and Set storage allocation traps on failure before
initializing controls or accessing entries. This also applies to insertion
growth and same-capacity rebuilding; allocation failure is not an empty or
missing-key result.
`Set<T>(N)` requires a positive `Int` literal. Its bucket capacity is the next
power of two at least `max(ceil(8 * N / 7), 16)`. Normalize the request and
round the bucket count in 64-bit arithmetic, before any multiplication;
`N = 2147483647` therefore produces `4294967296` buckets. This does not narrow
the valid source hint range. Querying a capacity that exceeds `Int.MaxValue`
uses the ordinary checked `capacity` conversion and traps.
`BitSet<N>` is a nominal fixed inline owner. Set storage contains no dummy
value, deque indexing uses a power-of-two ring, heap mutation preserves the
heap invariant, and bit-set words use fixed-width `UInt64` storage.
`BitSet<N> -> count` accepts no arguments and returns `Int` by counting set
bits across every inline word. Unused bits in the final word do not contribute
to the count. It has the same result and diagnostic behavior
inside text interpolation; other receiver types may resolve a user `count`
method through ordinary value-flow lookup.
`BitSet<N> -> contains(index)` takes exactly one `Int` bit index and returns
`Bool`. The index is checked against `0 <= index < N` at runtime; an invalid
index traps. These type, arity, result, and bounds rules also apply inside
text interpolation, including a readonly `ref BitSet<N>` receiver.

Concrete `Set<T>`, `Deque<T>`, `BinaryHeap<T>`, and `BitSet<N>` owners are valid
`mut` function inputs. Set, Deque, and BinaryHeap preserve their dictionary or
growable-array storage contract. BitSet passes the address of its fixed inline
words, so mutations update the caller storage without an allocation or copy.
The same address contract applies to additional inputs, forwarding, and
mutable BitSet fields.

`Set<T>.insert(value)` and `Set<T>.remove(value)` return `Bool` to report whether
membership changed. Their result can continue to another value-flow target;
mutation still requires writable owner storage and the canonical element type.
`contains(value)` is readonly, takes exactly one value of
the canonical element type `T`, and returns `Bool`. The same argument and result
rules apply inside text interpolation, which uses the Set's ordinary hash and
equality lookup. An invalid argument is diagnosed before a surrounding `?`.
Set insertion transfers owned storage from its argument, including when an equal
key already exists and the incoming key is dropped. A transferred named owner
is unavailable to subsequent source expressions. `contains` and `remove` borrow
the query value; removal drops only the stored key.
A set entry occupies exactly
the aligned key stride. Removal writes a tombstone so later probe-chain members
remain reachable. At the exact one-eighth-live transition, the bootstrap
implementation performs one same-capacity rehash to bound accumulated
tombstones. `Deque<T>` exposes readonly `front`/`back` and mutable
`pushFront`, `pushBack`, `popFront`, and `popBack`. It deliberately exposes no
indexing or ordinary array `take`, because those operations would leak its
physical ring representation. Empty `front`, `back`, or pop traps before a load.

[10, 20; ~] => values
values -> append(30) => values
values -> updated(0, 99) => values
```

Dictionaries:

```sollang
{ 1: 100, 2: 200 } => scores!
scores! -> put(3, 300)
scores! -> putIfAbsent(3, 999) => inserted
scores![3] => score
scores! -> len => count

{ 1: 100, 2: 200 } => frozenScores
frozenScores -> updated(2, 250) => frozenScores
```

Container rules:

- A bare empty fixed-array literal `[]` defaults to `[Int; 0]` when no
  contextual element type is supplied. A contextual element type takes
  precedence over that default; typed-empty storage forms retain their
  explicit element type and storage shape.
- A concrete fixed-array type length is a decimal integer in `0..2147483647`;
  a bounded-array type capacity is a decimal integer in `1..2147483647`.
  Fractional and out-of-range tokens are syntax errors at the numeric token.
  The parser checks that token before expecting the closing bracket or body,
  so a later syntax error does not replace the invalid extent diagnostic.
  CLI and language-server messages use the same fixed-length or bounded-capacity
  reason. Compile-time value parameters in fixed-array types retain their
  separate generic contract.
- Numeric digit separators are removed before checking array extents, capacity
  hints, and repeat counts; `4_096` has the same value as `4096`.
  A typed empty-array capacity hint and a numeric repeat count must be in
  `0..2147483647`, including zero. A capacity hint reserves backing without
  adding elements: `[T; N~]` starts with length zero and capacity `N`.
  A repeat count creates elements. The capacity hint is checked before its
  trailing `~` and closing bracket. A repeat count is checked after the closing
  bracket, so a missing `]` takes priority over an invalid repeat count.
  Leading `[` expressions use array-literal parsing; an abandoned speculative
  enum-constructor type annotation cannot replace their diagnostics.
- A bounded dictionary type capacity and a `BitSet<N>` size are positive decimal
  integers in `1..2147483647`, with digit separators allowed. Zero, fractions,
  and overflow are rejected at the numeric token before the closing `}` or `>`.
  CLI and language-server diagnostics share the same respective reason.
- Dictionary literals check numeric capacities before the closing brace. A typed
  empty dictionary capacity hint is a nonnegative decimal `Int32`; a bounded
  capacity is positive. A populated dictionary's bounded capacity must also be
  at least its parsed initializer count. Nested dictionary entries belong to
  their own literal and do not increase the enclosing initializer count. Digit
  separators do not affect the value. CLI and language-server diagnostics retain
  the numeric token's location and the same owning capacity reason.
- A dictionary literal uses its own final storage suffix. A typed initializer
  separator and nested storage suffixes do not determine the enclosing capacity.
  Inferred key and value types are resolved recursively; a nested dictionary
  retains its dictionary type and capacity as the enclosing value type. Explicit
  key/value annotations and contextual nominal record types remain authoritative.
- A contextual nominal record checks construction visibility before field names
  and duplicate labels. It then checks required fields in declaration order,
  inferring each present value before checking a later missing field; extra
  fields are rejected afterward without inferring their values. Labels identify
  fields and never read same-named local bindings. Bare numeric literals inherit
  the declared field type with target-sized range checking. Integer arithmetic
  carries that field context recursively to bare operands; each operand subtree
  is inferred before its parent checks both operand types. Floating values retain
  their type in an integer field. An already typed value retains its type.
  Integer-valued `if` and `when` fields pass context to continuing arms' terminal
  numeric literals and nested selections. Conditions, subjects, and earlier
  block statements keep independent types. Array literal fields retain their
  declared storage shape and give elements the declared element type. Element
  inference and its diagnostics precede fixed-length and bounded-capacity checks.
  Repeated array fields apply the same element and storage context; their logical
  length is the source repeat count, independent of inline capacity or the single
  repeated value node. These rules also apply to dictionary index keys,
  index assignment, `put`, and `putIfAbsent`, including mutable parameters.
  Report the selected field inference or construction error once, before later
  generic initializer diagnostics.
- A typed empty dictionary header ends at its closing brace (allowing intervening
  newlines). A comma after a `Name: Name` pair keeps it on the entry-literal path;
  a typed empty header cannot consume a prefix of a populated record.
- Static arrays are owned fixed-size `[T; N]` values stored inline in the owner.
- Dynamic arrays own `ptr`, `len`, and `capacity` metadata plus their payload
  storage. The normal payload placement is heap storage.
- A nonempty dynamic-array literal bound to an immutable local may instead use
  inline stack payload storage when the compiler proves every remaining use is
  readonly and the owner does not escape. This optimization does not change the
  source type or syntax.
- Dictionaries infer homogeneous key/value types and own Swiss-style control
  bytes plus type-aligned key-value entries. `Int` and `Text` currently provide
  the required built-in hash/equality operations; local/imported nominal keys
  use explicit static `Hash`/`Eq` implementations. Values may be scalar, `Text`,
  or inline/owned user values; owned entries receive recursive destruction.
  `{Key: Value; N~}` creates an empty typed dictionary with a capacity hint.
  A populated growable literal starts with a bucket capacity equal to the
  next power of two at least `max(2 * entryCount, 4)`. An explicit empty
  capacity hint uses the same rule with `N` in place of `entryCount`, including
  `N = 0`; an empty dictionary without a hint retains zero capacity and null
  storage. Capacity normalization and backing byte arithmetic use 64-bit
  values: the valid `Int32` hint `2147483647` normalizes to `4294967296`
  buckets, without wrapping or narrowing the source hint range. Initial
  entries use the dictionary's hash and probing rules to
  choose buckets, so spare capacity does not change lookup or insertion.
  `{Key: Value; keyExpression: valueExpression, ...}` gives nonempty entries
  an explicit type context. Key and value annotations accept imported qualified
  paths and the same recursive type syntax as function signatures.
  Controls have a 16-byte mirrored tail followed by an aligned entry region.
  An `Int` key/value entry contains two 32-bit fields with an 8-byte stride;
  heap and inline payload sizing use that same entry layout.
  Lookup compares one LLVM `<16 x i8>` group at a time, extracts H2 and empty
  masks, checks only matching-key candidates, and advances by 16 buckets.
  Mirroring makes a group crossing the final bucket contiguous without a wrap
  branch. Primary and mirrored control bytes are updated together.
  Indexed reads check all matching-key candidates in a control group before
  an empty control byte ends the search, including after tombstone reuse.
  A bounded dictionary `{K: V; <=N}` has a fixed entry limit `N` and owns
  its table storage inline as a value: the value contains its length and
  aligned control/entry bytes, not a pointer to a heap table. Its bucket
  count is a separate power-of-two probing capacity with at most 7/8 load.
  Calls and returns carry the whole bounded value; a receiver derives table
  addresses from its current owner after the transfer, not from a pointer
  retained by the callee. Dropping a bounded owner destroys occupied owned
  keys and values once but never frees the inline table. A readonly bounded
  parameter does not acquire ownership of, or free, the caller's storage.
  Bounded arrays and dictionaries contribute owned-storage responsibility only
  through their element, key, or value types. A nominal record containing only
  scalar bounded storage remains copyable. Fixed and growable array backing
  retains its storage responsibility even when the elements are scalar. Semantic
  indexed-read eligibility and subsequent ownership checks use the same rule.
  Dictionary intrinsics `put(key, value)` and `putIfAbsent(key, value)` require
  exactly two arguments whose resolved types match the dictionary's declared
  key and value types. A mismatched type or argument count is a semantic error
  before LLVM emission; a user-defined method with the same name is not a
  dictionary intrinsic.
  `putIfAbsent(key, value)` performs the grouped lookup once and inserts only
  on a vacant entry. It returns whether insertion occurred. For owned
  arguments, the call is a transfer on both paths: a duplicate keeps the
  resident key/value and destroys the incoming equal key and unused value
  exactly once. No entry pointer escapes across a possible rehash.
  Heap arrays, heaps, deques, dictionaries, and sets accept
  `owner! -> reserve(nonnegativeCount)`. Arrays and heaps reserve exact element
  slots; deques round upward to a power of two; dictionaries and sets compute
  enough power-of-two buckets to keep the requested entry count at or below
  7/8 load. A request no larger than current capacity is a no-op. Bounded
  inline collections reject `reserve` because their capacity is part of their
  type and cannot change.
  Growing an ordinary heap array with `reserve` traps on allocation failure
  before copying old elements, releasing their backing, or committing a new
  pointer and capacity.
  Ordinary heap arrays accept `owner! -> pushAll(fixedArray)` when the element
  type is copyable and exactly matches. The source expression is evaluated once;
  lowering checks addition overflow, reserves the combined length at most once,
  copies its contiguous fixed storage, and updates logical length after the copy.
  Dynamic-array sources are excluded to prevent source/receiver alias
  invalidation. `BinaryHeap`, `Deque`, bounded arrays, and owned elements do not
  expose this operation; invariant-preserving or move-explicit bulk APIs are
  separate language surfaces.
  The legacy `{Int: Int}` layout also supports readonly stack promotion; other
  specializations currently use heap payload storage.
- Typed empty arrays and dictionaries without capacity hints begin with a null
  pointer and zero capacity. Their first mutation allocates initial storage;
  readonly use of the empty value performs no heap allocation.
- `[T; N~]` is a typed empty growable array with `len == 0` and
  `capacity == N`; its payload allocation is performed once at construction.
- Indexing is checked. Out-of-bounds array access and missing dictionary keys
  trap in the current runtime slice.
- A mutable growable-array owner exposes the canonical atomic operation
  `values! -> exchange(left, right)`, where both indices are `Int`. The
  receiver, left index, and right index are evaluated exactly once in that
  order. Both bounds are validated before either element is loaded or stored;
  an out-of-bounds index traps without beginning the exchange. Equal valid
  indices are a no-op. Distinct valid indices exchange the complete element
  representations without copying, allocating, dropping, changing length or
  capacity, or exposing a partially initialized place. The operation returns
  `Unit`, must be the final flow target, and is not available on fixed arrays,
  bounded arrays, `BinaryHeap`, or `Deque`.
- Dictionary `owner! -> take(key)` traps for a missing key and transfers the
  removed value to its result binding without dropping that value. It drops an
  owning removed key. A growable dictionary allocates replacement storage at
  the same capacity, rehashes the remaining entries, and releases its old
  storage once. A bounded inline dictionary marks the removed slot as a
  tombstone in place and does not allocate replacement backing.
  Both storage forms produce the declared value type as the semantic result
  of `take`; subsequent projections use that value type.
- An indexed element that recursively owns storage is a place, not a copied
  value. Field and nested-index projections preserve that place identity, so
  `symbols![key].payload -> inspect` and `symbols![key].payload![0] -> inspect`
  may be passed directly to a default readonly function input. That borrow
  lasts only for the call expression. Binding, returning, storing, or mutating
  through the indexed result or one of its projections is rejected. Use
  `owner! -> take(indexOrKey) => value!` to transfer ownership out explicitly.
  Passing an owned indexed result to a mutable input reports the rejected
  index read at its bracket before checking the root binding's mutability.
  A readonly call through one or more field/index projections rooted in a named
  owner never schedules the indexed element for independent cleanup; the root
  owner remains live and performs the one final recursive drop. When the same
  projection is rooted in a fresh anonymous factory result, the complete
  factory owner instead remains alive through the call and is dropped exactly
  once afterward. Scalar sibling projections do not change either rule.
- A `move` input consumes the complete named owner, including an instance
  receiver declared `move self`. A later reachable read of that name is an
  unknown binding unless a new owner has been bound or the mutable place has
  been reinitialized. This applies to user structs as well as built-in affine
  values; the moved argument's position in a call does not change the rule.
  Every declared `move` parameter, including additional call arguments, takes
  a named owner, a direct field of a `move` input in the current function, or
  a fresh owner-producing expression. A nested field path, indexed place, or
  field of a local owner must be extracted into a named owner before passing it.
  Direct and flowed calls enforce this rule during semantic analysis, before
  LLVM generation.
  Collection insertion transfers the completed argument value. Reading an
  owner to compute a scalar argument does not transfer that owner. Reachability
  follows completed control flow: when every continuation after a move returns
  from the function, a later read on a non-moving path remains valid. A branch
  that can continue with the owner moved instead fails at the ownership join.
  This join uses the resolved callee and every declared `move` parameter for
  direct calls as well as flowed calls. In `receiver.method(arguments)`, the
  receiver is the primary input and the explicit arguments are the additional
  inputs; an argument cannot be mistaken for the receiver.
  A `when` or enum-match subject is evaluated before its arms. A move in that
  subject remains a move on every continuing arm; returning arms contribute no
  ownership state to the continuation. Mixed ownership is diagnosed during
  semantic analysis at the containing control expression.
- Storing a value in an array element, struct field, or collection consumes the
  source binding only when its canonical type recursively owns storage or a
  unique resource. An imported struct containing only copyable fields remains
  copyable after storage, just like a local struct with the same fields. The
  expression's origin or the module in which the struct was declared is not
  evidence of ownership transfer.
- Extracting a stored field whose type reaches heap-backed storage partially
  deinitializes that exact move path. Sibling fields remain usable, while the
  whole owner, the same path, and descendants of that path are unavailable
  until the field is reinitialized. A scalar-only nominal field is a copyable
  value and does not partially move its parent. If the moving control-flow path
  returns before a later use, that use is reachable only from a non-moving path
  and remains valid. The checked self-host compiler reports reachable explicit
  extraction/call/assignment violations as E17 before printing an LLVM target
  header. Implicit owned projections nested inside readonly request literals
  retain drop-tracking metadata but are not classified as explicit E17 moves.
  A local affine aggregate or a `move` input may transfer one of these exact
  paths directly; a readonly receiver, readonly parameter, or captured outer
  owner may not. Extracting an owned path through a mutable binding or mutable
  borrow is valid only when the immediately following statement infallibly
  reinitializes that same path. No call, branch, fallible expression, or access
  to another path may intervene, because the mutable owner must never be
  observable or returned in a partially initialized state.
  In the current slice, field assignment accepts only a direct field target.
  Therefore an owned nested field cannot be extracted through a mutable
  binding or mutable borrow: there is no supported nested assignment with
  which to restore that path. Transfer the containing owner through a `move`
  input, or borrow the nested field for a readonly call. This restriction does
  not prevent an affine local or a `move` input from transferring a nested
  owned field while retaining independent sibling fields.
- A function may return `Text` produced by `slice` from one or more
  default-borrowed `sys.file.SourceText` inputs. The compiler infers the union
  of every possible input origin; no lifetime parameter is written in the
  common case. Return-origin inference for readonly references and borrowed
  `Text` reaches a fixed point across callees before caller mutation or escape
  checks; declaration order cannot freeze a partially known origin union.
  In a multi-stage flow, a returned reference maps to the actual value entering
  the final stage, including the origins selected or replaced by earlier calls.
  Parenthesizing an intermediate flow does not change its return origins.
  The same origin union is inferred recursively when borrowed
  `Text` values are stored in a returned struct, fixed or growable array, or
  dictionary, including explicit early-return paths. Passing such an aggregate
  through a `Text`-containing function parameter transfers its existing origin
  union without treating an aggregate made only from static or owned `Text` as
  borrowed. Field and index projections inherit the aggregate's origins.
  Moving, replacing, or mutating any origin while a derived value is live is a
  compile-time error. A call checks the exact consumed argument place for each
  `move` parameter, including additional parameters; moving an unrelated
  argument does not invalidate a readonly receiver's borrowed origin.
  CFG last-use analysis ends the borrow after the final
  reachable aggregate or projection use, so the origin may be moved later.
  Reading an independent non-Text field of an ordinary struct does not keep a
  sibling borrowed Text field live; this also applies inside interpolation.
  References inside string interpolation are uses of the borrowed view. A
  reachable future interpolation or loop backedge keeps its origin live; an
  interpolation confined to an exclusive branch does not extend that loan
  into the other branch.
  Origin metadata is compile-time-only and does not alter struct or container
  ABI. Borrow conflicts are compared by canonical place path. The whole owner
  overlaps every projection, equal paths overlap, and a path overlaps each of
  its descendants. Different stored struct fields and unequal compile-time
  numeric array indices are disjoint at their first difference. A runtime
  index, or projections whose disjointness cannot otherwise be proven, remain
  conservatively overlapping.

Borrow-origin flow state distinguishes an unknown place from a value that is
known to have no borrowed storage origin. Bindings and flow bindings whose
`Text`-carrying value is owned or backed only by static storage retain an
explicit empty-origin state. Mutable rebinds and control-flow joins propagate
that state together with nonempty origin sets. Consequently, aliasing and
returning a mutable value selected only from static string literals is valid,
while any reachable rebind from local `SourceText` storage keeps its concrete
owner origin and is rejected if it escapes the function.
A complete ownership transfer ends the consumed binding. A later binding with
the same name creates a fresh owner rather than replacing live owned storage.
Moving only a field does not end its containing owner, and a transfer on only
one continuing control-flow path does not establish a consumed owner at the join.
A binding's borrowed-view or readonly-reference loan cannot invalidate a move
or mutation evaluated before that binding in source order. Lowered binding-shell
ordinals alone do not establish that the loan is already active. Existing loop
and reaching-version rules continue to govern loans carried from prior iterations.
An owned `SourceText` has no upstream borrowed origin, but a `Text` slice
returned from a call that reads it borrows the `SourceText` owner place. An
empty carrier entry for that owner cannot erase the origin of the new slice.

- A user struct field may have type `ref T`. The reference remains a plain
  pointer in the runtime layout, while the compiler attaches its inferred
  origin to the containing value. Indexing an array-valued reference field
  reads the referenced array without transferring ownership of its storage.
  A function may return such a struct only
  when every possible stored reference originates from a reference-bearing
  input; returning a reference to callee-owned storage is E22. Aliasing a
  reference-bearing struct or receiving it from a function preserves its
  reference origins, including nested and structural-product field paths.
  Moving, rebinding, or mutating an overlapping owner while a stored reference has a
  reachable later use is E23. Liveness is field-sensitive: using a scalar
  sibling after the stored reference's final use does not keep the reference
  live. Each stored reference field retains its own origin and reachable last
  use; using a different reference field does not extend that field's loan.
  E23 identifies the same complete field path used by the lifetime check.
  No lifetime or origin parameters appear in source syntax. Reference
  fields in enum payloads and array/dictionary element storage remain outside
  this implemented struct vertical.
- Indexed assignment validates the element value before the index, before LLVM
  generation. Array indexes have type `Int`; dictionary indexes have the exact
  declared key type; `MutableMappedBytes` indexes have type `UIntSize` and values
  have type `UInt8`. Already typed numeric values require explicit conversion
  when their type differs from the destination element or index type.
  A named readonly reference used as the value or index reads one reference
  layer before this type check, as in other ordinary name reads. This does not
  convert a different nominal or numeric type to the destination type.
- `push`, `put`, and indexed assignment require a named mutable owner binding
  created with `=> name!`.
- `array -> each item { ... }` binds `item` to the concrete element type for
  fixed and dynamic arrays. Owned elements are readonly borrows for one block
  invocation and are never dropped separately from their array owner.
- `dictionary -> eachKey key { ... }` and `dictionary -> eachValue value {
  ... }` scan occupied Swiss-table slots and bind the concrete K or V type.
  Iteration order is unspecified. Owned items are readonly per-slot borrows.
- `Int` and `Text` have built-in dictionary hash/equality. A local or imported
  nominal key, including one that recursively owns storage, must implement
  `Hash.hash: self -> Int` and `Eq.eq: self -> Int`.
  `Eq.eq` returns the canonical equality-class integer, and equal keys must
  return the same hash. Dispatch is statically specialized with no vtable.
- When dictionary K is a struct, `dictionary[{ field: value, ... }]` is a
  contextual K literal equivalent to `dictionary[K { field: value, ... }]`.
  All fields remain required and type checked; elsewhere braces retain their
  dictionary-literal meaning. The same contextual key rule applies inside a
  text interpolation. Its field labels are names and its values follow the
  declared field types; `true` and `false` in value position are Bool literals.
- A dictionary literal whose declared V is a struct likewise interprets a
  nested `{ field: value, ... }` entry value as a contextual V literal. Field
  names must be identifiers, every declared field is required exactly once,
  values retain their declared types and ownership, and source field order does
  not change the struct layout.
- `append` and `updated` consume a named source owner and return the moved owner.
  After the transform, the source binding is no longer live. The target may
  reuse the same name because the old owner is consumed before the new owner is
  bound.
- `append` reuses the existing dynamic-array buffer when capacity remains and
  grows/free-replaces only when capacity is full. Dynamic-array `updated` writes
  into the moved buffer after a bounds check. Dictionary `updated` reuses the
  `put` path, which performs expected O(1) hash-table lookup/update/insert and
  grows/rehashes at the load threshold.
- Move-consuming owner-returning operations must be final flow targets and must
  be bound directly with `=>`, so the compiler has a drop point for the moved
  heap owner.
  When a preceding function in the same flow returns an owned container, the
  final operation consumes that returned owner. It does not read the original
  binding again after a `move` call has consumed it.
- Heap-owning container creation must happen directly at a binding site or as
  a fresh block/function result transferred to a caller binding, so the compiler
  can insert deterministic cleanup. A generic constructor such as `Set<T>(N)`
  or `Deque<T>(N)` is a fresh creation expression at that result boundary.
- Heap-owning containers may be created inside nested blocks. The compiler drops
  block-local owners at the end of that block unless the final block expression
  moves the owner out as the block result.
- A block result may move a block-local growable array or dictionary owner out
  to the surrounding binding. Moving an outer owner out through an inner block
  result is rejected, except when every return branch transfers the current
  function's own `move` input to the function result.
- User functions may return concrete `[T; ~]` and `{K: V}` owners. The returned
  owner must be bound directly by the caller so the caller owns the drop point.
  Calling such a function as an anonymous flow source is rejected.
- User functions may accept generic `[T]` readonly views. A static, fixed, or
  growable `T` array can be passed to `[T]` without transferring ownership.
  The callee can read with indexing, `len`, and `each`, and can use `fold` on
  an `[Int]` view, but cannot
  mutate or store the view beyond the call. A field or index projection rooted
  in a named owner may be borrowed directly for that call; it does not need a
  temporary owned binding and the root owner remains live.
- A readonly `[T]` view uses the `{ ptr, i64 }` data/length descriptor: 16
  bytes with 8-byte alignment. A `ref [T]` argument addresses that descriptor,
  independent of the element type. Taking this reference does not transfer
  ownership or extend the view beyond its permitted call lifetime.
- User functions may accept any supported concrete `{K: V}` as a readonly
  dictionary view. The
  callee receives `ptr`, `len`, and `capacity` metadata by value and may use
  indexing, `len`, and `capacity`. `put`, indexed assignment, `updated`, return,
  and storage beyond the call are rejected. The caller remains the owner.
- User functions may accept mutable struct and container borrows such as
  `mut State`, `mut [T; ~]`, and `mut {K: V}`. The caller passes either a named
  mutable owner such as `state!`/`values!` or a field or index place rooted in
  that owner, such as `state!.transcript`. Projected mutable borrows address the
  original field storage rather than a copied aggregate. The callee can use
  existing mutable operations such as `push`, `put`, and indexed assignment,
  and the caller keeps ownership after the call.
  Declaration admission uses the outer storage shape for both the primary and
  additional inputs of a generic function. A generic element type does not
  make a slice or enum mutable storage: `mut [T]` and `mut Option<T>` are
  rejected even when the function is unused. A bare `mut T` defers this check
  until specialization; `mut [T; ~]`, `mut [T; N]`, and mutable dictionaries
  retain their declared container shape.
- User functions may accept `move [T; ~]` and `move {K: V}` owners.
  Passing such a value moves ownership into the callee. The caller binding is
  no longer live after the call. The callee drops the parameter at function
  exit or returns it directly or after move-consuming transforms. A returned
  owner must be bound directly by the caller, which receives the drop duty.
  Conditional returns must transfer the input on every branch or on none.
- Native Windows and Linux targets emit platform allocation/free primitives and
  drop dynamic arrays and dictionaries at scope exit.
- Browser WebAssembly rejects heap-placed containers until the target has a
  linear-memory allocator. Stack-promoted readonly dynamic arrays and
  dictionaries require no allocator and are accepted.
- Fixed-array generic contracts, type-preserving collection iterators, and
  user-defined local/imported dictionary `Hash`/`Eq` key dispatch are
  implemented. Compile-time `Int` value parameters specialize fixed repeat
  counts and `[T; N]` input contracts; a fixed array must match the specialized
  compile-time length.

## Lexical Design

The lexer must be single-pass and allocation-conscious.

Initial token categories:

- keywords represented by identifier text in the current lexer: `main`, `each`,
  `in`
- identifiers
- string literals, including interpolation markers inside string mode
- decimal integer literals
- punctuation: `{`, `}`, `[`, `]`, `(`, `)`, `..`, `~`, `.`, `,`, `;`, `+`,
  `-`, `*`, `/`, `%`, `->`, `=>`, `:`, `!`, `=`
- newlines
- trivia: spaces, tabs, comments when comments are specified
- end of file

Lexing principles:

- Source text is UTF-8.
- Tokenization should be deterministic and mostly context-free.
- String literal contents should be represented as source slices where possible.
- String interpolation should be tokenized in string mode without allocating
  concatenated strings.
- Diagnostics must preserve byte offset, line, and column information.
- The compiler must not normalize source text before tokenization.

`Text` stores validated UTF-8 bytes and `text -> each scalar { ... }` decodes
them into `CodePoint` values. `CodePoint` is a distinct unsigned 32-bit Unicode
scalar type: its valid values are `U+0000..U+D7FF` and `U+E000..U+10FFFF`.
Iteration advances by one UTF-8 sequence, not one byte or one user-perceived
grapheme cluster. Malformed, truncated, overlong, surrogate, and out-of-range
sequences trap at the safe runtime boundary. Explicit `CodePoint(integer)`
conversion performs the same range and surrogate checks; a floating-point
source is rejected. Arithmetic is not
defined directly on `CodePoint`; convert to `UInt32` first when numeric work is
intentional. This restriction also applies when a declared function input
supplies `CodePoint` as the expected type of an arithmetic argument.
Equality and ordering comparisons remain available for lexer
classification.

`Text` also exposes explicit UTF-8 byte operations for lexer and source-map
work. `text -> len` returns `UIntSize` byte length, `text -> byte(index)` returns
a bounds-checked `UInt8`, and `text -> slice(start, length)` returns a borrowed
`Text` view. A computed byte index, slice start, or slice length must be
`UIntSize`; an integer literal is checked in that argument context. Nested
conversions such as `slice(UIntSize(1), UIntSize(2))` keep their own argument
lists, so the two conversions each receive one argument. `byte` requires
exactly one argument and `slice` exactly two; arity is checked before argument
types. Slice offsets are byte offsets and both ends must lie on UTF-8
scalar boundaries; splitting a continuation sequence traps. Thus byte scanning
is explicit while every value that retains the `Text` type remains valid UTF-8.

On Windows and the browser target, a failed `Text.slice` check reports the
enclosing function identity followed by one of `text_slice_start_bounds`,
`text_slice_length_bounds`, `text_slice_start_utf8_boundary`, or
`text_slice_end_utf8_boundary` before trapping. This diagnostic identity does
not include LLVM basic-block names or ordinals: those are private backend
details and can differ between the bootstrap and self-host compilers. Windows
writes the diagnostic to standard error without a trailing newline. Bounds
checks identify the source function declaration, retaining its namespace and
method owner; generic specialization does not add backend type numbers to this
identity. Bounds
checks precede UTF-8 boundary checks; the start boundary precedes the end
boundary. A checked heap-allocation guard uses the same source function
identity followed by `allocation_failed`. It checks the nullable allocation
before initializing or publishing its payload; private LLVM block names and
ordinals do not participate in this diagnostic. Other trap diagnostics retain
their existing contracts.

The self-hosting syntax substrate defines `SourceSpan { fileId, start, length }`
with `UIntSize` byte offsets and `SyntaxToken { kind, span }`. Byte offsets are
shared across tokens, CST nodes, diagnostics, and source maps so Unicode column
rendering can be derived without destabilizing stored spans.

A nonempty CST recovery range retains its first consumed token, including a
skipped error range that precedes any matched token. Later matches do not replace
that origin. Its token range must remain inside the lexed token array, and skipped
tokens are counted once. Diagnostic tree traversal retains these bounds without
changing a rejected parse into an accepted compilation.

## Arena Storage

`Arena(initialCapacity)` creates a unique owned byte arena. It is a three-word
handle containing a backing pointer, used byte count, and capacity. `box T`
remains different and always means an individually owned heap allocation;
ordinary structs remain inline values.
Arena growth, including growth triggered by `materialize`, traps on allocation
failure before copying used bytes, releasing old backing, or changing the
arena's pointer and capacity.
Boxed values use the same canonical size and alignment as inline values of
their element type, after declared collection shapes have been registered.
Aggregate alignment follows its fields independently of its total byte size.
Declared enum payload sizes and collection element layouts use that same
canonical calculation in dependency order. Descriptor identities are registered
before their element metadata; declared by-value cycles remain invalid.
Declaration order does not affect payload word counts or nested aggregate padding.
For built-in types, `box` accepts `Int`, `Bool`, and `Text`. Other
built-in types, including `Int8` and `UIntSize`, are rejected at the
`box` expression. Eligible declared struct and enum types can also be boxed;
the compiler's type registry decides their eligibility. Arrays and dictionaries
and `BitSet<N>` are not boxable, including fixed, dynamic, and bounded storage forms.
Instantiated built-in generic types such as `Option<T>`, `Result<T, E>`, and
`Set<T>` are likewise absent from the registered box types.
In a generic function, a readonly `box T` input infers `T` from the boxed
element. A `box T` return is resolved after specialization against the same
registered box types; a generic signature does not make an otherwise ineligible
element boxable. A function can construct and return a fresh box for an eligible
specialized element. This does not add support for generic `move` inputs.
The boxed element contract also applies through supported enclosing wrappers,
including `Option<box T>` and `ref box T`. Inference preserves the declared box
layer and does not insert a heap allocation for an unboxed argument.
The standard runtime identities excluded from boxing are
`sys.file.{File, FileWriter, SourceText, AtomicReplaceRequest}`,
`sys.process.Command`, `sys.path.{Path, Style}`,
`sys.directory.{Raw, Entry, RawResult, ReadResult}`,
`sys.directory.kind.Kind`, and
`sys.input.mouse.{Event, Kind, OverflowPolicy}`.

```sollang
Arena(4096) => syntax!
syntax! -> alloc(24, 8) => nodeOffset
syntax! -> store(nodeOffset, UInt8(1))
syntax! -> load(nodeOffset) => tag
syntax! -> used => bytesUsed
syntax! -> reset
```

- `alloc(bytes, alignment)` requires a mutable arena, accepts `Int` or
  `UIntSize`, validates non-negative sizes and a nonzero power-of-two alignment,
  and returns an aligned `UIntSize` offset.
- Offsets stay stable when the arena grows because they are relative to the
  backing block rather than raw addresses.
- Growth selects at least `max(capacity * 2, requiredEnd)`, copies only used
  bytes, and immediately frees the previous block.
- `store(UIntSize, UInt8)` and `load(UIntSize)` perform bounds checks against
  used bytes. Raw pointers are not exposed in safe Sollang.
- `reset` retains capacity and sets used bytes to zero. Existing offsets become
  logically invalid; subsequent checked access is relative to the new contents.
- `Arena` is affine: readonly borrowing, `mut Arena`, and `move Arena` follow the
  ordinary ownership rules. Final drop frees the current backing block exactly
  once. Individual arena allocations are never freed separately.
- `deferredText -> materialize(arena!)` formats into one contiguous arena
  allocation and returns an ordinary non-owning `Text` view. Interpolation
  holes have already been evaluated once in source order; materialization only
  formats their retained values.
- A materialized `Text` borrows its arena owner. While that view is live,
  `alloc`, `store`, `reset`, move, and drop of the conflicting arena are
  rejected. Passing the owner to any `mut Arena` parameter is likewise rejected
  because that callee may grow or rewrite the backing block. The loan ends at
  the view's last reachable use and propagates through functions that return
  the view on both the bootstrap and self-host ownership paths.
- Immediate sinks consume deferred interpolation directly and do not
  materialize. The explicit boundary is for storage, return, indexing, or code
  that intentionally fixes allocation timing and lifetime.
- Named bindings are storage boundaries, including a user-defined block's
  result and a producer-local binding of its yielded callback result. Inlining
  a block does not turn deferred interpolation into an ordinary `Text` view.
  Materialize in an explicit arena before crossing those boundaries. A block
  that never invokes its callback and returns ordinary `Text` does not inherit
  the unused callback expression's deferred representation.
- Storage includes array elements, product and struct fields, dictionary keys
  and values, and collection insertion or assignment. An unmaterialized
  interpolation in those positions is a semantic error before LLVM emission;
  the compiler must not allocate hidden backing storage. Materialize once into
  an explicitly owned arena, then store the resulting borrowed `Text` view.
- The native targets currently support arenas. Browser wasm remains blocked by
  its existing no-heap runtime boundary.

## Memory-Mapped Bytes

Native Sollang programs can map a file directly as an owned byte view:

```sollang
map read "huge.dat" at 4_000_000_000 for 64_000_000 => data
map write "index.dat" size 10_000_000 => output!
42 => output![0]
output! -> flush
```

- `map read` produces immutable `MappedBytes`; `map write` produces
  `MutableMappedBytes` and therefore requires a mutable owner binding such as
  `=> data!`. A write map bound to an immutable name is rejected at that name.
  The same binding rule applies when a call is typed as `MutableMappedBytes`.
  A function may return either mapped type. The returned map retains its
  aggregate value and can be used by the caller; a mutable result still
  requires a mutable binding at the call site.
  An indexed mapped byte used inside text interpolation has type `UInt8`;
  its load checks the mapped length before reading the byte. A non-literal
  mapped index must be `UIntSize`, including inside text interpolation.
  An invalid unary operand in an index expression is diagnosed before the
  index type; for example, `-UIntSize(1)` fails the signed-numeric operand rule.
  In interpolation expressions, unary `-` accepts signed `Size` values.
  Nested numeric conversions used by unary or binary expressions retain their
  target width in both entry and function bodies.
- The path expression must have type `Text`. The compiler checks this at the
  path expression before forming the mapped value producer; a non-`Text` path
  reports `map path must be Text` at the path's source location.
- The `at` and `size` contexts infer integer literals as `UInt64`; `for` and
  mapped indices infer literals as target-sized `UIntSize`. Explicit constructors
  remain valid, and `_` may separate decimal digits. Non-literal `at` and
  `size` values must be `UInt64`; non-literal `for` values must be `UIntSize`.
  The compiler reports a mismatch at the clause value before lowering the map
  producer.
- `at ... for ...` maps a view without loading the whole file. The runtime
  aligns the operating-system view down to its required granularity while the
  language-visible view begins at the exact requested byte offset.
- Indexing and assignment are bounds checked and yield/accept `UInt8`.
  `len` returns `UIntSize`, `each` iterates bytes, and mutable `flush` requests
  synchronous writeback.
- A mapped view is affine. Leaving its owning scope unmaps the underlying view
  exactly once; copying a mapped owner is not allowed.
- The compiler represents a map expression as one value producer whose path is
  the first operand. Present clauses follow it in source order. `at ... for ...`
  is an inseparable pair; `size` is accepted only by `map write`. A
  `map read ... size ...` expression is rejected at the `size` keyword during
  parsing. A map binding must retain that exact producer and its `MappedBytes`
  or `MutableMappedBytes` identity. An enclosing function body can share the
  map expression's AST index
  but does not count as another producer. Compiler validation rejects a missing
  producer, a path value used as the owner, a mismatched clause chain, or a
  mismatched mapped type before LLVM
  emission. Mapped `flush` retains its runtime identity only for a
  `MutableMappedBytes` receiver; a lexically declared function named `flush`
  remains an ordinary user function.
- Windows x64 and Linux x64 use their native mapping APIs. Browser wasm rejects
  `map` because it has no corresponding host-file mapping primitive.

## Process Arguments

Native entry points expose their launch arguments through the standard-library
property `sys.process.arguments`:

```sollang
import sys.process as process

process.arguments => args
args -> len => count
args[1] => sourcePath
args -> each argument {
    "argument = $argument" -> println
}
```

A block function with a non-`Unit` result may appear before another block stage.
The previous result becomes the next source directly; no source-visible
temporary binding is introduced:

```sollang
5
    -> map { it * 3 }
    -> tap { "mapped=$it" -> println }
    -> filter { it > 10 }
    => result
```

Every stage uses ordinary function lookup and the declared source, callback,
and result types. `map`, `tap`, and `filter` are examples of user-defined names,
not keywords or compiler intrinsics. An intermediate `Unit` block is rejected
because it has no value to feed into the following stage.

Generic block types are specialized from the ordinary input before either the
function's `yield` sites or the caller body are checked. For example,
`block items: [T; ~]` becomes `[Int; ~]` when an `Int` source fixes `T = Int`.
The caller body cannot feed constraints back into that choice.

`Arguments` is a copyable, process-lifetime, read-only view rather than an owned
`[Text; ~]`. Its `len` and index use `UIntSize`; indexing returns borrowed
`Text`; `each` binds `Text`. The first item is the executable name supplied by
the host and must not be treated as a canonical or security-checked path.
The same index type and borrowed `Text` result apply inside `$(...)` string
interpolation; invalid index types are rejected before LLVM emission.

Passing, returning, capturing, or storing an `Arguments` value copies the view,
not its argument strings. It can be used as a primary or additional function
input, a generic value, an aggregate field, or a branch result without `move`.
On Windows, the managed and self-host call ABI represents this view with an
`i64` count snapshot; element storage remains owned by the process runtime.
Forwarding the view adds no allocation or cleanup obligation.

On Windows, Sollang uses the operating system's Unicode command-line parser and
converts each UTF-16 item to validated UTF-8 storage retained until program
exit. That storage is released exactly once by the runtime. On Linux, the
native `argc`/`argv` entry ABI supplies stable byte spans directly. Browser wasm
does not currently define host process arguments and rejects the property.

Argument setup and its allocation helpers are emitted only when the program
actually references `sys.process.arguments`, preserving allocation-free LLVM
for programs that do not use this host capability.

Environment lookup uses the same module and returns an option so a present
empty value is distinct from a missing name:

```sollang
process.environment("LLVM_ROOT") -> when {
    Option<Text>.None => "LLVM_ROOT is not set"
    Option<Text>.Some(path) => path
} => llvmRoot
```

The input name must be valid UTF-8 without an embedded zero byte. The returned
`Text` is a borrowed process-lifetime view. Linux borrows the stable `getenv`
storage because safe Sollang currently has no environment mutation API. Windows
queries the Unicode environment, converts a present value to UTF-8, retains it
in a runtime-owned allocation list, and releases the list at process exit.
Repeated Windows lookups may retain duplicate converted values until exit; a
future cache may deduplicate them without changing source semantics.

Lookup allocation or encoding failure traps rather than being reported as
`None`; `None` means only that the variable is absent. Browser wasm rejects
environment lookup until a host capability is explicitly supplied.

## Structured Child Processes

An owned `sys.process.Command` executes one program directly without invoking a
shell. `spawn` consumes its configuration and returns the running affine
`Child`; `wait` consumes and reaps that child:

```sollang
import sys.process as process

process.command("clang") => command!
command! -> arg("module.ll")
command! -> arg("-o")
command! -> arg("module.exe")
command! -> workingDirectory("build")
command! -> spawn -> when {
    Result<process.Child, Text>.Ok(child) => child -> wait
    Result<process.Child, Text>.Err(error) => Result<process.ExitStatus, Text>.Err(error)
} => result
```

The primary signatures are
`move Command -> Result<Child, Text>` and
`move Child -> Result<ExitStatus, Text>`. The command's first
owned argv item is the program path or search name and every remaining item is one literal argv entry;
spaces, Unicode, quotes, and backslashes are not reparsed as shell syntax.
`Ok(status)` represents normal termination; `status.succeeded` and
`status.exitCode` expose intent without treating an unlabelled integer as a
process object. A successfully spawned child also contains a `ProcessId` domain
value. `child -> id` observes it without consuming the affine child, and
`processId -> asUInt64` exposes its positive numeric representation. Both are
pure field projections: they perform no host call, allocation, resource copy,
or dynamic dispatch. The native ownership token remains distinct from this
identifier; on Windows it is a process handle and the PID is captured once with
`GetProcessId`, while Linux uses the spawned PID as both native token and
identifier. `ProcessId` is observational data rather than an ownership or
signalling capability, and its number may be reused by the host after the child
is reaped. An unconsumed `Child` remains attached to its lexical owner;
scope exit kills and reaps it before releasing the platform handle or PID.
`child! -> kill` mutably borrows that owner and requests forced termination
without waiting, reaping, closing, clearing, or copying its native token.
Windows uses `TerminateProcess`; Linux sends `SIGKILL`. Success means that the
host accepted the termination request, not that terminal state has already been
observed. `tryWaitTermination(mut)` or `wait(move)` remains the single reap
authority. `tryWaitTermination` returns `Ok(None)` while the process is live,
`Ok(Some(TerminationStatus.Exited(ExitStatus)))` for ordinary exit, and
`Ok(Some(TerminationStatus.Signaled(SignalStatus)))` for POSIX signal exit.
`SignalStatus.signalNumber` preserves the exact host signal; observing it clears
the native token and caches both the terminal kind and number so repeated polls
never reap twice. The older `tryWait(mut)` is a compatibility projection over
that same observation and maps `Signaled` to `Err("signal")`; it does not issue a
second host poll. A terminal state already cached by either poll makes a later `kill` an idempotent
success without another host call. An invalid token or rejected request returns
`Err("kill")` and leaves the owner available for a later wait or lexical cleanup.
After `wait(move)`, a second use is a compile-time ownership error with guidance
to retain a returned owner, borrow before moving, or create a new owner.
`Err("spawn")`, `Err("kill")`, and `Err("wait")` distinguish host launch and
process-operation failures. `Err("signal")` remains only on the compatibility
`tryWait`/`wait` surface; typed nonblocking consumers use `Signaled`. The argv owner remains valid and is dropped normally after
the runtime call; the `Command` itself is consumed. `statusToFile` has the same
result contract while directing standard output to an explicit path. The raw
`run` and `runToFile` intrinsics are compatibility boundaries for the current
self-host compiler and are not the preferred user vocabulary.
On Windows, `statusToFile` and `Input.File`/`Output.File` require a nonempty
UTF-8 path without embedded NUL, convert it to UTF-16, and open the selected
file with `CreateFileW`. An invalid path fails the process operation before
launch. The `Null` stream uses the ASCII `NUL` device name.

`workingDirectory(path)` mutates only that `Command` instance and configures
the child's initial directory. It does not change the parent process directory
and does not reinterpret the command program as relative to the child
directory. Independent commands may therefore be prepared and spawned without
a process-global directory race. Windows supplies the directory directly to
`CreateProcessW`; Linux supplies it through the `posix_spawn` file-action set.

`stdin(Input)`, `stdout(Output)`, and `stderr(Output)` also mutate only that
`Command` instance. `Input` and `Output` are distinct directional types; their
current variants are `Inherit`, `File(Text)`, and `Null`. The inherited defaults use the
ordinary allocation-free stdio path. A file variant opens a temporary parent
handle, supplies it only to the selected child descriptor, and closes the
parent copy immediately after spawn. Windows selects the three handles passed
to `STARTUPINFO`; Linux attaches guarded `posix_spawn` `dup2` and close actions
for descriptors 0, 1, and 2. Neither platform temporarily replaces a parent
descriptor. `Null` uses `NUL` on Windows and `/dev/null` on Linux without
changing a parent stream. `Pipe` is intentionally absent until `Child` exposes
typed live endpoints; bounded synchronous capture is a separate operation.
On Windows, selecting process execution also selects the configured stdio
runtime body, so its `CreateFileA` declaration is required even when the current
command uses only inherited streams. This is compile-time capability closure;
it does not open a file on the inherited fast path.
`statusToFile(path)` is the compatibility spelling for an explicit stdout file
override. It retains the configured stdin and stderr policies; only the
Command's stdout policy is replaced by the supplied path.

`collect(CaptureLimits)` consumes a `Command` and returns
`Result<CapturedOutput, Text>`. `CaptureLimits.standardOutputBytes` and
`standardErrorBytes` are mandatory independent byte limits. Collection retains
the command's configured stdin policy and replaces stdout and stderr with
private child-only pipes. Both pipes are drained concurrently while the child
runs. Bytes beyond a limit are still drained and discarded;
`standardOutputTruncated` or `standardErrorTruncated` records that loss. The
retained `standardOutput` and `standardError` values are raw growable byte
arrays, so text decoding and malformed-byte policy remain explicit at the call
site. `status` records the same `ExitStatus` domain value as `wait` and
`Command.status`. Pipe creation, reader threads, and capture allocation are
capability-selected and absent from commands that use the ordinary
spawn/status path. There is no unbounded convenience overload. Example 1182
writes a pipe-filling stderr sequence before stdout and verifies concurrent
draining and truncation on managed and self-host Windows/Linux targets.
Capability selection follows the resolved process intrinsic rather than the
spelling `collect`; an unrelated instance method with that name does not emit
pipe or reader-thread runtime.

`setEnvironment(name, value)`, `removeEnvironment(name)`, and
`clearEnvironment` mutate only the `Command` instance. Edits are ordered and
the last edit for a platform-equivalent key wins. Clearing removes prior edits,
disables parent inheritance, and allows later sets to construct a minimal child
environment. The parent environment is never modified. With inheritance and no
edits, Windows passes a null environment pointer and Linux reuses `environ`, so
the common path performs no environment copy or allocation. A customized
Windows launch uses case-insensitive key matching, a
`CompareStringOrdinal`-sorted UTF-16 double-NUL block, and
`CREATE_UNICODE_ENVIRONMENT`; Linux supplies a merged zero-terminated
`char **` to `posix_spawnp`.

Windows strictly converts UTF-8 entries to UTF-16, applies the Microsoft argv
quoting rules, retains one process handle, and validates both wait and exit-code
reads before closing it. Linux creates temporary zero-terminated argv storage,
calls `posix_spawnp`, and retries interrupted `waitpid`; an unrecoverable wait
failure kills and reaps before returning `Err("wait")`. Browser wasm rejects
the capability until a host process interface is supplied. Examples 87 and
1132-1133 verify synchronous compatibility, positive identifier observation,
explicit wait, missing-executable spawn failure, and scope-drop cleanup on
Windows and Linux. Example 1160 additionally executes the same binary as a
child and proves that a relative file becomes visible through the configured
child directory.

## Owned Portable Paths

`sys.path.Path` owns its UTF-8 byte storage rather than borrowing a `Text`.
The representation carries an explicit `Style.Posix` or `Style.Windows`, so a
cross-compiler applies the target's lexical path rules instead of silently
using the host operating system:

```sollang
import sys.path as path

"src//compiler/./../main.slg" -> path.fromText(path.Style.Posix) => source!
source! -> path.normalizeConfined => normalized!
normalized! -> when {
    Ok(value) => value -> path.equalsText("src/main.slg")
    Err(error) => false
}
```

`normalizeConfined(move Path)` is purely lexical and performs no filesystem
access. It removes repeated separators and `.` components, resolves `..`, and
returns `Err("path escapes root")` rather than allowing a parent component to
cross the starting root. Windows drive roots and UNC server/share roots are
preserved; an incomplete UNC prefix is rejected. `join(move Path, Text)` accepts
only a relative child and rejects an absolute child instead of discarding the
base path. `byteCount`, `equalsText`, and `isAbsolute` borrow the Path.

Path bytes use a dedicated canonical `[UInt8; ~]` type identity. `Path`,
`Style`, and their byte-buffer identity are reserved standard-library IDs, so
adding the module cannot renumber unrelated user nominal or parametric types.

`path.nativeStyle()` is a zero-argument target constant, not a host query. It yields
`Style.Windows` for a `windows-x64` compilation and `Style.Posix` for Linux and
wasm targets, even when the compiler itself runs on another operating system.
It is valid in ordinary functions and requires no `File` capability. Arguments
are rejected before code generation. Only the intrinsic declaration in
`sys.path` has this behavior; a user function named `nativeStyle` retains its
declared return type and body.
`sys.file.mapPath(Path)` borrows the Path bytes and returns the same affine
`SourceText` mapping as `mapText(Text)`, but first requires the carried style to
match the compilation target:

```sollang
import sys.path as path
import sys.file as file

"src/main.slg" -> path.fromText(path.nativeStyle()) => sourcePath
sourcePath -> file.mapPath => source
source -> len -> println
```

The Path owner remains valid and is dropped independently; the returned
`SourceText` owns only its native mapping. A style mismatch traps at the
intrinsic boundary instead of interpreting target syntax with host rules. This
provides the ownership-safe bridge needed for deterministic directory discovery
to feed compiler source loading without rebuilding every entry name as Text.
On Windows, `mapText` and mapped-byte file opens validate UTF-8, reject an
embedded NUL, convert to UTF-16, and use `CreateFileW`. Their bounded native
path buffer holds at most 259 UTF-16 code units plus the terminator; conversion
or length failure occurs before any file effect. This limit is separate from
the owned-file Text path limit of 259 UTF-8 bytes.

## Deterministic Directory Snapshots

Directory enumeration and creation require the `File` effect. This includes
`sys.directory.readRaw`, `readRawSnapshot`, `read`, and `create`; an ordinary
function calling any of them must declare `uses File`. Main retains its
implicit authority, and pure path transformations do not acquire this effect.

`sys.directory.read(Path)` returns an owned `ReadResult`. A successful snapshot
contains independently owned `Entry` values with an owned basename `Path` and a
`Kind` of `File`, `Directory`, `Symlink`, or `Other`:

```sollang
import sys.path as path
import sys.directory as directory

"src" -> path.fromText(path.Style.Posix) -> directory.read -> when {
    Ok(entries) => entries -> each entry { entry.name -> path.byteCount }
    Err(error) => error -> println
}
```

The native runtime excludes `.` and `..`, orders names lexicographically by raw
UTF-8 bytes, closes the operating-system directory handle before returning, and
serializes the result once into an owned snapshot. The standard-library layer
then gives each entry its own byte buffer, so neither entries nor paths borrow a
native enumeration buffer. Ordering is therefore reproducible even though the
operating system does not promise enumeration order. Windows and Linux support
the operation; browser wasm rejects it until a host filesystem capability is
provided. The supplied `Path.Style` must match the target path syntax.

`sys.path.query` adds target-native canonical resolution, file/directory kind,
byte length, and nanosecond modification time. Lexical normalization remains a
separate operation and does not claim to resolve symlinks by itself.

## Generic Binary Scalar I/O

`sys.file` provides a generic writer alongside the legacy sorted-Int64 demo
API:

```sollang
import sys.file as file

"values.bin" -> file.openWriter
UInt8(65) -> file.write
UInt16(258) -> file.write
Float32(1.5) -> file.write
file.closeWriter
```

`write<T>` is monomorphized for `Bool`, `CodePoint`, the fixed-width signed and
unsigned integers, `Float32`/`Float64`, and target-sized `Size`/`UIntSize`.
Unsupported values such as `Text`, arrays, dictionaries, boxes, and arbitrary
structs are rejected rather than dumping pointer-bearing in-memory layouts.

The current native targets are little-endian, and scalar files use the exact
little-endian bit representation and byte width of the specialized type. A
generic write flushes the legacy Int64 record buffer first so mixing old and new
calls cannot reorder bytes. I/O failure follows the existing fail-fast runtime
status path.
On native targets, a fail-fast writer error terminates with process status `1`
without executing subsequent source statements. This behavior is independent
of the enclosing function's return type; typed reads retain their `Result`
errors.

The reader uses explicit zero-input type application and call syntax:

```sollang
"values.bin" -> file.openReader
file.read<UInt16>() => value
file.closeReader()
```

Its type is `read<T>: -> Result<Option<T>, Text>`. `Ok(Some(value))` is a full
scalar, `Ok(None)` is clean EOF, and `Err("truncated")`, `Err("invalid")`, or
`Err("io")` distinguish partial data, invalid `Bool`/`CodePoint` encodings, and
host failures. The supported specializations and exact native byte layouts are
the same as `write<T>`. Empty parentheses are required for zero-input calls.
Arbitrary structs still require an explicit
serialization contract rather than implicit ABI dumping.

## Explicit User-Value Serialization

`sys.file.BinarySerializable` is the standard opt-in contract for converting a
user-defined value into canonical binary data:

```sollang
import sys.file as file

struct Packet {
    first: UInt8
    second: UInt8
}

impl file.BinarySerializable for Packet {
    serialize: self -> [UInt8; ~] {
        [UInt8; ~] => bytes!
        bytes! -> push(self.first)
        bytes! -> push(self.second)
        bytes!
    }
}

Packet { first: 65, second: 90 }
    -> file.BinarySerializable.serialize => bytes!
```

An integer literal in a struct initializer inherits the declared integer type
of its field. This removes a conversion that repeats information already visible
in the declaration. The rule is literal-only: `first: 65` is context-typed as
`UInt8`, but an `Int` variable or arithmetic expression is not silently narrowed.
The compiler checks the literal at compile time, so `first: 256` is rejected as
outside `UInt8`'s `0..255` range. Explicit conversions remain available when a
runtime value intentionally crosses numeric types.
An out-of-range field literal reports its spelling, declared field type, and
that type's bounds rather than a generic field-type mismatch. A typed
nonliteral value that cannot match the field retains the field-type diagnostic.

The required signature is `serialize: self -> [UInt8; ~]`. The result owns its
storage. The implementation defines field order, framing, integer byte order,
version tags, and any validation metadata required by its format. The compiler
does not reflect over fields or copy a struct's target-dependent ABI layout.
Pointer-bearing values therefore cannot leak addresses or padding through an
implicit fallback. Callers explicitly write or otherwise consume the returned
bytes; decoding remains a separate format-specific contract.

Qualified calls to imported traits use static dispatch when the receiver has a
known concrete type. Both bootstrap and self-host compilers resolve the actual
implementation, including a trait imported through a module alias, and transfer
the owned byte result to the caller.

The asynchronous counterpart is a zero-input generic property as well:

```sollang
file.readAsync<UInt16> => pending
pending -> await => value
```

Its declared type is
`readAsync<T>: -> async Result<Option<T>, Text>`. It preserves the same EOF,
encoding, truncation, and I/O result model as `read<T>`, but the blocking host
file call runs on one shared native file worker. The Task leaves the ready
queue while its request is pending; completion returns it to the FIFO ready
tail. One worker serves all file Tasks, so the runtime never creates one OS
thread per read. Windows uses auto-reset request/completion events and Linux
uses `eventfd` plus `poll`; both feed the same target-neutral completion queue.

Cancellation consumes the Task immediately. A request already owned by the
worker keeps its control record until completion, then destroys its context
exactly once without waking a former waiter. Runtime shutdown drains canceled
requests, stops and joins the shared worker, and releases its native event
resources. Synchronous reads and reader open/close wait for already-submitted
asynchronous work before touching the shared cursor.

The compatibility reader still has one process-wide cursor, but new code can
use an affine native file owner and position-independent reads:

```sollang
file.openReadAsync("values.bin") => opening
opening -> await => opened
opened -> when {
    Ok(reader) {
        reader -> readAt<UInt16>(0) => header
        reader -> readAtAsync<UInt16>(128) => pending
        pending -> await => record
    }
    Err(error) => error
}
```

`openReadAsync(Text)` returns `Task<Result<File, Text>>`; `openWriteAsync(Text)`
returns the corresponding writer Task. The Task owns a copy of the path until
the worker completes. A successful `await` transfers the new native handle
into the Result, while failure and cancellation retain no handle.

`File` is non-copyable and closes deterministically at owner-scope exit.
`readAt<T>(UInt64)` and `readAtAsync<T>(UInt64)` never advance a shared cursor.
The asynchronous form duplicates the native handle into the Task, so the Task
and original File have independent, exactly-once close obligations. Windows
uses an overlapped offset and Linux uses `pread`; high-bit offsets unsupported
by the signed host APIs return `Err("io")`.

Writes use a separate affine capability so a read-only handle cannot be used as
a writer:

```sollang
file.openWrite("values.bin") => opened
opened -> when {
    Ok(writer) {
        writer -> writeAt(UInt16(513), 0) => inferred
        writer -> writeAt<UInt16>(1027, 3) => contextual
        writer -> writeAtAsync(UInt16(2049), 8) => pending
        pending -> await => asynchronous
        writer -> syncAsync => syncing
        syncing -> await => durable
    }
    Err(error) => error
}
```

`openWrite` creates or truncates the file. `writeAt(value, UInt64)` infers the
scalar type from `value`; the optional type argument gives an untyped literal a
context. The operation returns `Result<Unit, Text>` and succeeds only after the
entire scalar is written. It never advances a cursor and extends the file when
the offset lies beyond its end. Windows uses an overlapped offset and Linux
uses `pwrite` without append mode.
The synchronous operation also accepts a readonly `ref FileWriter` receiver.
It reads that receiver's handle without transferring ownership; explicit scalar
context applies to integer literals, while typed values and offsets retain their
own types and must match the selected scalar type and `UInt64`, respectively.

`writeAtAsync` has the same inference and explicit-context forms and returns
`Task<Result<Unit, Text>>`. Submission copies the scalar bytes and duplicates
the writer's native handle into the affine Task; it never borrows caller stack
storage or the original writer. Completion and cancellation therefore retain
independent exactly-once close obligations. The shared file worker dispatches
both reads and writes.

For `readAtAsync` and `writeAtAsync`, evaluate the receiver and all arguments
once in source order before submitting the new Task. An argument may await
another Task and run the scheduler; the new file Task must remain unpublished
until its argument values are available.

`syncAsync: -> async Result<Unit, Text>` is a durability barrier. It waits for
file data and metadata to reach the filesystem through `FlushFileBuffers` on
Windows and `fsync` on Linux. The operation owns a duplicate writer handle and
shares the same FIFO worker, so earlier submitted writes complete before the
barrier. Sollang deliberately calls this `sync`, not `flush`: random-access writers
have no hidden language buffer to empty. Deterministic scope drop closes the
original handle immediately and does not await Tasks because every pending
operation owns its own duplicate. A future IOCP/io_uring completion backend
remains before the general file-I/O gate is complete.

Compiler and cache code may use the synchronous `writer -> file.sync` barrier.
After the affine writer's scope closes, `file.AtomicReplaceRequest` passed to
`file.atomicReplace` publishes the staged path over the destination atomically.
Windows uses `MoveFileExW` with replace-existing and write-through flags; Linux
uses `rename` after `fsync`. Wasm reports `false` because it has no host
filesystem. The destination is therefore either the previous complete file or
the new complete file, never a partially written cache entry.

`file.createExclusive(path: Text) -> Int uses File` creates a new empty file
only when the path does not already exist. `file.removePath(path: Text) -> Int
uses File` removes a file without following a missing path into success. Both
return `1` for the requested change, `0` for the expected contention or
already-missing case, and `-1` for another failure. They reject an embedded NUL
or a UTF-8 path longer than 259 bytes before a filesystem effect. Windows
converts accepted UTF-8 file paths to UTF-16 for native create, removal, and
replacement so path queries and those file effects identify the same name.
Linux provides native implementations; Wasm returns `-1` without a host file
operation. A failed close after exclusive creation can return `-1` even though
the new path exists, so a caller using it as a claim must explicitly inspect
and reconcile that ambiguous failure.

Double-quoted UTF-8 literals decode `\n`, `\r`, `\t`, and `\\` in text
segments and support optional identifier and expression interpolation. Unknown
backslash sequences remain literal for backward compatibility:

A parenthesized interpolation must contain a non-whitespace expression and a
matching closing parenthesis. Empty and unterminated interpolation errors are
reported at the opening string token when the parser commits that expression,
before errors from later tokens. Each closed fragment uses the ordinary
expression grammar and must consume its entire input after leading and trailing
newlines. Fragment errors retain their own relative position and are wrapped
with the opening string position and original fragment text. Fragments are
validated in source order, so an invalid earlier expression precedes a later
empty or unterminated fragment. Raw strings do not interpret interpolation.

```sollang
"Hello World"
"Hello, $name"
"next = $(score + 1)"
"object = { name: $name, score: $score }"
"first\nsecond"
```

Interpolation is statically typed. Builtin values use target-neutral writers
selected from the expression result type; they do not first allocate a
temporary Text. `Int` uses decimal output and `Bool` uses the canonical
`true`/`false` spellings. The intended user-defined extension is a statically
dispatched `Display` trait that writes into an interpolation sink. There is no
implicit reflection, debug formatting fallback, or automatic heap promotion.
Formatting adapters/options may be added explicitly without changing the
default `$name` and `$(expression)` syntax.
An `if`, `when`, or enum-match result that flows directly into an immediate
interpolation consumer remains deferred across the control-flow join. Only the
selected arm writes its typed segments; the join does not first allocate or
copy a temporary `Text`. Arms may mix plain `Text` and deferred interpolation,
and nested selections retain the same behavior. Storing or returning deferred
interpolation still requires explicit Arena-backed materialization.
A `Text` block result, including a deferred interpolation's borrowed `Text`
segments, cannot outlive backing storage owned inside that block. Such an
escape is rejected before code generation. Materializing into an Arena owned
by the enclosing scope is valid; scalar values read from local storage remain
ordinary copied values and may be interpolated after the block.
An `each` role keeps the iterable's element type inside interpolation. A known
element type that cannot be displayed is rejected during semantic analysis,
before LLVM emission, with the string literal as the diagnostic location.
Stream callback roles keep the input type declared by the called stage, including
when a role is referenced only inside interpolation. The upstream element type
specializes generic callback inputs; the stream result constrains the output
type and does not replace a callback input type.

When either interpolation form reads a readonly `ref T` binding for a supported
interpolatable `T`, it formats the referenced value, not the reference address.
This value read applies equally in entry code, ordinary functions, nested
control regions, Arena materialization, and transient Text arguments; it does
not change the function's readonly pointer ABI or transfer ownership.
The output-runtime capability scan must select Int/Bool formatter definitions
from that same resolved value type, including the `ref T` value type. A scalar
print call without its matching runtime definition is invalid LLVM lowering.

The complete expression before a flow call remains its receiver inside
interpolation. For example, `$(outer.inner -> read)` statically dispatches
`read` on the type of `outer.inner`; `outer.inner` is not reinterpreted as a
qualified function name. This has the same allocation-free instance-call ABI as
the equivalent expression outside interpolation. Entry, named-function, and
nested-control lowering use the same interpolation call emitter; a deferred
instance call is not filtered out by a consumer-specific node-kind list.
An explicit nominal struct literal also remains a complete receiver inside
interpolation. In `$((Point { x: 5 }).x)`, the named type and field initializer
are checked before the field access, and the field's declared type determines
whether the resulting value can be displayed. The compiler emits the
constructed value before extracting the field.
The interpolation expression uses the surrounding module's namespace and
imports. For example, after `import sample.shapes as shapes`,
`$((shapes.Point { x: 5 }).x)` resolves the complete `shapes.Point` path to
the imported struct declaration. Parentheses around the constructor preserve
that receiver; they do not create an additional field access.
A complete module path such as `$((sample.shapes.Point { x: 5 }).x)` resolves
the same declaration without an import alias when that source is in the
compilation unit.
For an explicit nominal literal, duplicate field names are rejected first;
then each initializer is checked in source order for a declared field and a
compatible value. Required fields are checked after those initializers.
An initializer that is itself an expression is checked using its inferred
result type, including arithmetic results, before the constructed value is
emitted. A field type mismatch is a semantic error at that initializer.
An unknown nominal type is rejected at the literal's type name before LLVM
lowering or field access.
When that receiver is itself a call, its arguments and evaluation order remain
attached to that inner call; subsequent flow-call suffixes add only their own
arguments. Each successive target receives the preceding result and only its
own explicit arguments, including chains with three or more targets. Ordinary
nested argument calls retain their own argument edges. A flattened IR must
discover suffix identity from the complete parent/span relation before assigning
fixed-width operand slots. The callee name belongs to the parsed call target, not to the first
parenthesized expression within its receiver. The resolved flow-call result
type also selects the interpolation writer in entry, named-function, and
nested-control contexts; a negative `Int` result remains signed decimal text
rather than an unsigned bit-pattern rendering. An interpolation flow call with
no target matching its receiver is a semantic error before LLVM emission.
The `len` flow result retains the receiver-dependent type inside interpolation:
arrays, slices, dictionaries, and bit sets return signed `Int`, while `Text`,
`SourceText`, `Arguments`, and mapped bytes return `UIntSize`. Thus negating an
array length is valid and negating a text length is a semantic error.
The same receiver-dependent result applies to `capacity`: growable and bounded
arrays and dictionaries return signed `Int`, while `Arena` returns `UIntSize`.
The result retains its signedness inside interpolation even when LLVM stores
the capacity in a wider field.

Triple-quoted raw literals preserve quotes, backslashes, and `$` markers as
ordinary text. A multiline raw literal removes its opening newline, closing
newline, and the indentation shared with its closing delimiter:

```sollang
"""
JSON and paths need no escaping: C:\data\input.json
$(this remains text)
"""
```

The opening and closing delimiters must have matching indentation. Every
nonblank content line must include that indentation; embedded Sollang source
should then be indented normally relative to the delimiters:

```sollang
main {
    """
    main {
        7 => value
        value![0]
    }
    """ => source
}
```

Inline raw literals such as `"""a "quoted" path"""` are also supported.
The delimiter may contain more than three quotes when the content itself must
contain a shorter quote run; opening and closing delimiter widths must match.

Interpolation rules:

- `$name` inserts the current value of the binding named `name`.
- `$(expr)` inserts the value of a Sollang expression. Parentheses inside a
  single-quoted character literal do not change the hole nesting; escaped
  character delimiters remain part of that literal. The fragment lexer checks
  character scalar count and supported escapes. The outer ordinary-string
  lexical delimiter rules still apply.
- A bare `$name` resolves only a binding visible at that source position. A
  later declaration or a binding in another lexical scope cannot satisfy it.
  When its spelling starts with a shorter visible binding name, the diagnostic
  suggests `$(shorter)remainder` to make the boundary explicit; among visible
  prefixes, the longest one is used. An unresolved `$(expr)` name reports the
  ordinary unknown-binding diagnostic.
- A function name by itself in interpolation is not a function call. A
  function with an input requires call or flow syntax; a zero-input function
  requires parentheses. A local function has this diagnostic only where its
  declaring function's scope makes it visible. A visible binding of the same
  name takes precedence.
- Hole expressions follow ordinary evaluation order and enum payload ownership
  rules. A named owner transferred into an enum constructor is unavailable to
  later operands or arguments in the same hole, later holes, and subsequent
  statements. Reuse reports the ordinary unknown-binding diagnostic during
  semantic analysis, before LLVM generation.
- When an enum constructor copies borrowed fixed storage, the borrowed source
  remains available. A transferable owned-match payload follows the existing
  transfer and cleanup rules instead. Interpolation does not permit a
  move-consuming function call outside the allowed direct consumption forms.
- Interpolating an integer value uses its invariant decimal display form.
- `{` and `}` inside string literals are ordinary text characters.
- The older `{name}` interpolation form is removed from the preferred language
  surface because literal braces are common in JSON-like text, CSS-like text,
  blocks, and future dictionary/set syntax.

## Effect Sets And Capability Boundaries

Every function is pure by default. A function that performs an external effect
declares the required capability set after its return type:

```sollang
announce text: Text -> Unit uses Console {
    text -> println
}

archive path: Text -> Result<file.File, Text> uses File, Clock {
    path -> file.openRead
}
```

The initial closed set is `Console`, `File`, `Clock`, `Random`, `Process`,
`Environment`, and `Network`. Unknown or duplicate names are compile errors. Calling an
effectful function requires the caller to declare every callee effect, so the
set propagates through ordinary, local, generic, block, member, and imported
calls. `map` and mapped-view `flush` require `File` even though they are
language forms rather than ordinary functions. Map capability admission precedes
inference of its path, offset, length, and file size. `main` is the unrestricted root
capability boundary.

`sys.process.exit` requires `Process`, including calls on failure paths.
Its requirement propagates through helper functions like other callee effects.

A mapped-view `flush` has a `Unit` result and requires writable owner storage.
An unrelated type's same-named method does not discard this operation or replace
its receiver, result, or `File` requirement. Ordinary functions named `flush`
retain their own declared parameter, result, and effect contracts.

Bare `nowMillis`, `sleep`, `eprint`, and `eprintln` calls do not introduce
global runtime aliases. Resolve an explicit module-qualified declaration through
its normal visibility and capability checks; an unresolved bare spelling remains
an unknown direct-call or value-flow target.
An ordinary declaration may define `sleep`, `eprint`, `eprintln`, or `flush`.
Bare reserved function names, including `nowMillis`, are rejected during
declaration binding before their effect clauses and bodies. Names qualified by
an explicit path or a top-level namespace retain their full identity; a local
function still owns its bare declared name. Earlier declaration errors precede
later declarations, including local functions, before body diagnostics.
The current runtime aliases for random seeding/sampling and integer-file I/O
retain the internal visibility of their `sys.random` and `sys.file` wrappers.
Check that visibility before caller capabilities or operand expressions. The
root capability boundary in `main` does not grant access to internal functions.

Standard-library source authority comes from the selected standard-library
loader and is preserved through semantic preparation and committed call
resolution. A namespace spelling, import, or directly supplied source file
does not grant that authority.
Windows, Linux, and browser WebAssembly preparation retain the same selected
standard-library source range; target selection does not grant authority to
the user-source suffix or erase authority from the selected library sources.

During function declaration admission, a non-standard-library function whose
resolved name starts with `sys.` is rejected before its body is checked. The
current explicit trait-implementation exemption follows the trait declaration
identity; it does not grant standard-library source authority to that body.
Ordinary top-level names inherit the declaring namespace, explicit qualified
function names retain their complete path, and local names retain their lexical
scope. Thus `sysdemo` and `system` are ordinary namespace prefixes, and an
explicit `system.helper` declaration is not renamed by a surrounding `sys`
namespace. Type declarations alone do not constitute a forbidden function.

This source authority applies throughout a function's lexical body, including
intermediate bindings, assignments, nested control expressions, and generic
specializations. An intermediate statement cannot grant a main-only runtime
call that the function's final expression would reject.
For a committed call, check visibility, declared capabilities, and then the
main-only runtime boundary before diagnosing its operand expressions. Classify
runtime operations by the selected declaration and canonical owner; an ordinary
function with the same unqualified name does not acquire that restriction.
Native test compilation retains the selected standard-library loader's source
authority, excludes those sources from test selection, and leaves the generated
test harness outside the standard-library source range.

The native compiler checks declared closed capabilities against the committed
callee and nearest lexical caller. A missing-effect diagnostic selects the first
missing name in the callee signature and carries that capability to diagnostic
rendering; it must not assume every effectful call requires `Console`.
Canonical `sys.runtime` intrinsics retain their required capability when a
legacy declaration omits `uses`; a same-named ordinary function does not acquire
that capability. Unknown and duplicate closed names are rejected while binding
function signatures, including local signatures, before checking body calls.

`async` is intentionally separate: it describes suspension and scheduling,
not permission to access the clock, filesystem, console, or process state. An
async timer therefore declares both parts, for example
`delayed: -> async Int uses Clock`.

These six names are fixed external capabilities, not user-replaceable
algebraic operations. A normal `handle` role therefore cannot erase them and
make real I/O appear pure. Future handleable effects use separately declared
effect signatures and operations; only those operations may be discharged by
a matching lexical handler. The current implementation checks the closed
capability set and does not silently infer or erase authority.

The accepted user-defined surface keeps operation types inside a module-level
effect declaration and references that effect from `uses`:

```sollang
public effect Failure {
    fail message: Text -> Int
}

parse text: Text -> Int uses Failure {
    text -> fail
}
```

An imported declaration is named through its normal import alias, for example
`uses fx.Failure`. Inside a function, an unqualified operation such as `fail`
is selected only from that function's declared user effects. Ordinary lexical
functions keep precedence. An explicit `Failure.fail` call still requires
`uses Failure`; qualification does not grant an effect capability. Duplicate
operations, unknown effects, inaccessible imported effects, missing `uses`,
and ambiguous operations are compile-time diagnostics.

This surface is currently implemented as a self-host grammar, AST, symbol, and
semantic-analysis product. Reference-compiler parsing, canonical operation
type checking, lexical handler discharge, resumptions, and LLVM lowering are
not implemented yet, so user effect operations are not executable runtime
features at this stage.

## Output Surface Semantics

`sys.io.print` and `sys.io.println` are standard library functions. The compiler
globally aliases them as `print` and `println` before user code is analyzed. The
preferred source form is a value-flow call:

```sollang
"Hello, $name. square = $num" -> print
"Hello, $name. square = $num" -> println
"Hello, $name. square = $num" -> sys.io.print
```

The parenthesized forms remain valid and equivalent:

```sollang
print("Hello, $name. square = $num")
println("Hello, $name. square = $num")
sys.io.print("Hello, $name. square = $num")
```

The explicit zero-argument call `println()` emits one empty line without
requiring an empty string literal:

```sollang
"first section" -> println
println()
"second section" -> println
```

This call form is statement-only. It does not change the declared
`println value: Text -> Unit` function signature and does not apply to `print`.

Semantically, it resolves to:

```text
sys.io.print(utf8_output_expression)
sys.io.println(utf8_output_expression)
```

`print` emits exactly the requested text. `println` emits the requested text
followed by one platform line break; `println()` emits only that line break.

## Input Surface Semantics

`sys.io.readInt` is the first input function implemented through the standard
library and globally aliased as `readInt`. The preferred form mirrors output
value flow:

```sollang
"n = ? " -> readInt => n
"n = ? " -> sys.io.readInt => n
```

The parenthesized form is also valid:

```sollang
n = readInt("n = ? ")
n = sys.io.readInt("n = ? ")
```

Semantically, it resolves to:

```text
sys.io.readInt(prompt_text) -> Int
```

The current runtime accepts a decimal integer line from standard input. Input
failure or a non-integer input must affect the process exit code; it must not
silently fall back to an arbitrary value.

## Range Loops

The first loop form is implemented as the built-in block function `each`. The
preferred explicit item form is:

```sollang
1..9 -> each i {
    n * i => value
    "$n x $i = $value" -> println
}
```

When the item name is omitted, Sollang provides the default binding `it`:

```sollang
1..9 -> each {
    n * it => value
    "$n x $it = $value" -> println
}
```

The older compatibility spelling remains accepted:

```sollang
1..9 -> each i {
    n * i => value
    "$n x $i = $value" -> println
}
```

`break` exits the closest lexically enclosing loop and `continue` transfers to
that loop's next condition/iteration block. Both are statements without a
value. Using either outside a loop is a semantic error. A control transfer
drops every owned local created since the target loop was entered before the
LLVM branch is emitted; nested loops therefore clean up and target their own
innermost scope.

A single conditional transfer may use the guard-flow shorthand:

```sollang
inner! == 2 -> if continue
inner! == 3 -> if break
```

The condition must be `Bool`. This is exactly the braceless form of
`condition -> if { continue }` or `condition -> if { break }`; false continues
with the next statement. Sollang deliberately does not use `?` here because
postfix `?` already means typed `Result` propagation.

The self-hosted LLVM backend represents an early loop transfer as a dedicated
loop-exit IR node; guarded exits additionally carry their Bool condition. A
true guard branches through an explicit cleanup basic block while false reaches
the following statement. Region-local
dynamic arrays release their backing pointer; dictionaries release key and
value stores in reverse declaration order. The normal back-edge invokes the
same scope cleanup so every iteration has identical ownership semantics.

An explicit early return keeps Sollang's left-to-right flow:

```sollang
value -> return
return # Unit functions only
```

The returned owner transfers to the caller. Every other active owned local is
dropped in reverse declaration order before the LLVM `ret` terminator. The
reference compiler supports scalar, aggregate, borrowed-reference, and Unit returns; the
self-hosted LLVM slice proves a scalar return from a structured region while
cleaning an owned array. Local functions may use the same explicit return form;
their local owners are cleaned before either an early or tail return. An owner
wrapped by value-preserving nodes and owning enum constructors is part of the
returned aggregate and is therefore excluded from cleanup on that return edge.
Explicit and tail returns resolve this transfer through the same compiler path.
Borrowed-reference returns preserve the caller's referenced storage while
dropping the callee's active owned locals before returning the reference pointer.
Generic signatures resolve nested type constructors in the declaration's generic
scope. Specialization preserves the declared return shape, including references
to growable arrays, and infers reference origins for the new function and its
nested local functions before validating their returns. Runtime intrinsic
admission validates the abstract signature before concrete calls are available.
General
moved-region paths remain part of the structured early-exit follow-up.

The loop variable is immutable for the iteration and scoped to the loop body.
Bindings introduced inside the loop body are also scoped to that body. The
current range direction is ascending only; if the start is greater than the end,
the loop executes zero times.

`fold` accepts an integer range or an integer array, including a readonly
`[Int]` view, and returns a value:

```sollang
1..100 -> fold 0 sum, i {
    sum + i
} -> total
```

Range inputs may be literals, named values, parameters, or function results.
The source is evaluated once before iteration. All forms consume the same
normalized inclusive pair of `Int` endpoints; a half-open range is normalized
when its value is created. Iteration stops at the final item even when that
endpoint is the maximum `Int`. Other concrete source types are rejected at the source
expression location before code generation.
A readonly range or integer-array reference is read as its canonical value
before folding. Its storage remains borrowed; this introduces no ownership
transfer or implicit collection clone. Direct range `each` likewise reads a
readonly `Range` reference before iteration.

The first expression after `fold` is the initial accumulator value. An empty
array or range returns that initial value without evaluating the body. The first
name is the accumulator binding inside the block and the second name is the
range item binding. The pair may be omitted, in which case the names are `acc`
and `it`. Both names belong only to this fold body. Commas in the initial
expression or body never declare role names. The block must return the next
accumulator value. The
current implementation supports integer accumulators and lowers the built-in
directly to LLVM loop blocks with accumulator and item phi values.

## Conditionals

The current conditional syntax is flow-oriented:

```sollang
condition -> if {
    thenBody
} else {
    elseBody
}
```

The expression on the left must be `Bool`. `if` may be used as a statement when
both branches produce `Unit`; in that form the `else` branch may be omitted. When
`if` is used as a value, `else` is required and both branches must produce the
same type.

For a failure-only guard, keep the positive validity condition and use
`unless`; it is equivalent to `not condition -> if { ... }` without adding a
negation wrapper around a long expression:

```sollang
decoded.nextOffset == UIntSize(bytes -> len) -> unless {
    Result<Message, Error>.Err(error(50)) -> return
}
```

```sollang
n == 9 -> if {
    "nine"
} else {
    "other"
} -> label
```

For multiple ordered conditions, `when` is preferred over chaining nested
`if`/`else` expressions. Sollang does not add a prefix-style `elsif condition`
after the flow-style `condition -> if`, because that would reverse the reading
direction inside one decision:

```sollang
when {
    score >= 90 { "A" }
    score >= 80 { "B" }
    score >= 70 { "C" }
    else { "F" }
} -> grade
```

`when` checks arms in order. Each arm condition must be `Bool`; the `else` block
is required in the current expression form; all branch values must have the same
type. When an integer-valued `if` or `when` appears in a typed context such as a
function argument, struct field, return value, or numeric operand, that expected
integer type is propagated through surrounding arithmetic and into every arm.
The existing type of a mutable rebind and the element/value type of an indexed
assignment are also typed contexts. Nested value-form `if` expressions in a
declared integer return preserve that return type during semantic analysis and
code generation.
Numeric literals therefore stay unannotated instead of requiring a redundant
constructor. Branch-local bindings do not escape their branch body.
A subject-style `when` that is the final value of a declared integer-returning
function inherits that declared result type for every integer-literal arm and
returns the selected arm value, never the subject. A nonterminal `when` cannot
replace a later function-body result.
Nested ordinary and subject-style `when` expressions forward their selected
values through a continuing arm when the enclosing expression needs that value.
Statement-position loop bodies do not consume their terminal expression value.
When every arm of a Boolean-condition or subject-style `when` returns, the
selection has no continuing result or merge edge. This termination also applies
when the selection is nested in another control region; enclosing branches
must not store a result or add a continuation edge for it.
This context includes the `else` arm and unary negative integer literals.
Literal range errors are rejected before IR generation. An independently typed
arm value retains its own type; the declared return context does not coerce it
to match a literal arm, and incompatible continuing arm types are diagnosed.
Only arms that reach the join contribute a terminal result value. A returned
match preserves each call's declared canonical type, including its generic
arguments; an earlier nested call is not the arm result. Result propagation
`?` produces the operand's success type and checks its error type against the
enclosing function, without replacing the operand's success type.
When every arm of a source-final `when` returns explicitly, the function body
terminates without a merge value or implicit return. The emitter identifies
conditional arms and `else` from their AST roles: a conditional arm tests its
body region for termination, while `else` tests the arm region itself. If a
later sibling follows the control, its continuation and fallback remain live.

When every arm compares the same value, the value can flow into `when` once and
each arm can start with a comparison operator:

```sollang
score -> when {
    >= 90 -> "A"
    >= 80 -> "B"
    >= 70 -> "C"
    else -> "F"
} -> grade
```

This form is equivalent to the full-condition form for ordered integer
comparisons, but the subject expression is evaluated once before the branch
chain. Every signed, unsigned, pointer-sized, and code-point integer subject is
supported. Numeric literal arm operands are contextually typed from the
subject; nonliteral operands must have the same integer type. The current
shorthand supports `==`, `!=`, `<`, `<=`, `>`, and `>=`.
It also supports inclusive range arms:

```sollang
score -> when {
    90..100 -> "A"
    80..89 -> "B"
    70..79 -> "C"
    else -> "F"
} -> grade
```

When a one-input function uses the default `it` input, the subject can be
omitted entirely:

```sollang
grade: Int -> Text => when {
    90..100 => "A"
    80..89 => "B"
    70..79 => "C"
    else => "F"
}
```

If the input is explicitly named, pass it explicitly into `when`:

```sollang
grade score: Int -> Text => score -> when {
    >= 90 => "A"
    >= 80 => "B"
    >= 70 => "C"
    else => "F"
}
```

## Value-Flow Calls

Sollang accepts `->` as the preferred direction for function calls where the
input value should be visually explicit:

```sollang
main {
    getName() => name
    7 -> square => num
    "Hello, $name. square = $num" -> print
}
```

The expression on the left flows into the function or callable path on the
right. `->` is a fluent pipeline step, not a binding form. The example above is
semantically equivalent to:

```sollang
print("Hello, $name. square = $num")
```

This makes argument flow and return flow visible without discarding normal
parenthesized calls where they supply arguments. Zero-input functions use
explicit call syntax such as `getName()`; the value-flow form is the preferred
Sollang style for single-primary-input operations.

Return values are bound with `=>`:

```sollang
getName() => name
7 -> square => num
name -> greeting => message
```

Function targets in a value-flow statement should omit empty parentheses:

```sollang
7 -> square => num
"Hello, $name. square = $num" -> print
```

One-input flow targets omit empty parentheses because the flowed value is the
function input. A truly zero-input function uses call syntax (`nowMillis()`).
Flow targets
with additional arguments are supported for receiver-style
operations such as `values! -> push(10)` and `scores! -> put(3, 300)`. When a
function-like target receives a brace code block argument, the block argument is
the call marker: `1..9 -> each { ... }` and `1..9 -> each i { ... }` remain
valid without `each()`.

Sollang has only expression-first binding and assignment:

```sollang
num = square(7)
n * i => value
```

The corresponding function type notation follows the same direction:

```sollang
greeting: Text -> Text
print: Text -> Io<Unit>
stdout.write: Bytes -> Io<Int>
```

The current parser accepts:

```sollang
value -> function
```

as a `FlowExpression`. Since binding is now explicit with `=>`, a bare flow
target is never interpreted as a binding. Semantic analysis resolves each target
as a callable path. The executable lowering for unary calls remains equivalent to:

```sollang
function(value)
```

The callable path after `->` is authoritative independently of syntax in the
source expression. An opening parenthesis in an earlier direct call or enum
constructor does not bound qualified-target lookup. Thus
`frames.Value.Crypto(payload) -> frames.encodeValue?` resolves the qualified frame
codec even when the enclosing function is also named `encode`.

Chained value-flow calls are parsed left-to-right:

```sollang
text -> trim -> lower -> slugify => slug
```

A newline may appear before a continuing `->` or any binding/assignment `=>`,
including indexed and field targets.
Because neither token can begin an independent statement, the continuation is
unambiguous:

```sollang
text
    -> trim
    -> lower
    -> slugify
    => slug
```

Boolean composition may likewise continue with line-leading `and` and `or`:

```sollang
user.isActive
    and user.profile.isVerified
    and request.canWrite
    -> if {
        save
    }
```

The formatter indents continuation arrows and boolean operators one level
beyond the source line. A block opened by a continuation keeps that additional
indentation for its body and closing brace.
Boolean continuation keywords must end at an identifier boundary. A BMP
letter, decimal digit, or `_` immediately after `and` or `or` makes it part
of an identifier, so names such as `and漢字` and `or가` do not gain continuation
indentation.
It preserves the exact left-to-right evaluation order; the vertical form does
not create a different AST or an implicit scope.

Role-local names may be omitted when they are uniquely determined. Function
inputs and block items default to `it`. A fold with no explicit names defaults
its accumulator to `acc` and its item to `it`:

```sollang
1..100 -> fold 0 {
    acc + it
} => total
```

The explicit `fold 0 total, value { ... }` form remains available when domain
names communicate more meaning.

Initial constraints:

- The first supported argument is a displayable scalar expression.
- Plain and interpolated string literals are valid displayable expressions.
- Integer expressions are displayable through invariant decimal formatting.
- The output target is standard output.
- The emitted data is exactly the evaluated string content, with no implicit
  newline.
- Output failure must not be silently ignored.
- The exact user-facing error-handling syntax is still open.

## Cross-Platform Output Binding

Although `print` is simple at the surface, it is a platform-bound I/O primitive
inside the compiler and core library.

The compiler chooses the output backend from the target triple at compile time.
There must be no generic runtime dispatch layer for selecting the OS backend.
Small OS-required runtime checks are allowed inside a selected backend, such as
distinguishing a Windows console handle from redirected stdout.

### POSIX-like Targets

For Linux, initial lowering targets a minimal stdin/stdout path equivalent to:

```text
write(stdout_fd, ptr, len)
read(stdin_fd, ptr, len)
```

Requirements:

- Treat short writes as an output failure in the current runtime slice.
- Preserve buffered stdout flush failures, including the final process flush,
  in the process failure state. A later successful write or empty flush must
  not erase an earlier output failure. Apply this rule on Windows as well.
- Treat read failure, EOF, or invalid integer text as input failure.
- Avoid heap allocation for static string literals.
- Keep the ABI boundary explicit.
- Use `main` as the Linux executable entry point.

### Windows Targets

For Windows native targets, stdout must be Unicode-correct and efficient.

Requirements:

- If stdout is redirected to a pipe or file, write UTF-8 bytes directly.
- If stdout is a console, use a console-correct path such as UTF-16 output.
- For string literals, compile-time generation of UTF-16 companion data is
  preferred over runtime heap conversion.
- Handle partial writes and API failures explicitly.

### WASI Targets

For WASI-style targets, initial lowering should use the target ABI's stdout
write primitive, such as `fd_write`.

Requirements:

- Preserve exact UTF-8 bytes.
- Avoid assuming a host OS console.
- Report unsupported capabilities at compile time where possible.

### Unsupported Targets

Unsupported output targets must fail at compile time with a clear diagnostic.
They must not silently fall back to another backend.

## LLVM Lowering Direction

Runtime helper bodies follow reachable functions and calls, including runtime
operations required by the transitive owned-type drop closure. An unused
standard-library declaration or semantic type alone does not require its
runtime helper bodies. Preserve ABI type definitions referenced by declared
struct layouts even when their operations are unreachable. Runtime declaration
diagnostics remain independent of helper selection, and every emitted call
must retain its matching declaration or definition in the LLVM module.

Internal function symbols must preserve canonical function identity, including
the distinction between namespace separators and identifier underscores.
Replacing both with the same character is not a valid encoding. The managed
emitter retains simple ASCII qualified names and uses a disjoint, complete
UTF-8 hex encoding for other canonical names. Native-library symbol names
remain governed by their explicit foreign-function declarations.

Checked compilation admits syntax and library declarations before semantic
lowering. A rejected function signature stops before call-context resolution
and typed-IR construction: invalid mutable input storage and unused generic
input parameters keep their declaration diagnostic ahead of body errors.
The rejected result retains its source snapshot for the same module name,
source position, and message used by ordinary semantic diagnostics. It does
not construct a partial emitter context. An admitted result carries the full
emitter context and follows the existing semantic, IR-invariant, and target
checks. Diagnostic-only validation returns the semantic count without emitting
LLVM or diagnostic stdout, including when rejection occurs before typed IR.

For the current runtime sample:

```sollang
getName: -> Text {
    "dimohy"
}

square: Int -> Int {
    it * it
}

main {
    getName() => name
    7 -> square => num
    "Hello, $name. square = $num" -> print
}
```

The intended lowering shape is:

```text
static global utf8 bytes: "dimohy"
function getName -> returns text slice
function square -> accepts i64 %it, evaluates %it * %it at runtime, returns i64
runtime decimal conversion helper for integer output
native entry function
-> call getName() as a zero-input invocation and bind name to returned text slice
-> pass 7 to square through flow and bind num to returned integer
-> write string literal segments directly
-> write name as a text slice
-> convert num to decimal bytes at runtime and write them
-> resolve print as global alias for the Sollang function sys.io.print
-> inline sys.io.print to sys.runtime.print
-> lower sys.runtime.print to selected backend output bytes
-> return process exit code
```

Optimization requirements:

- String literals are emitted as immutable globals.
- `(ptr, len)` should be passed without copying.
- Interpolated strings should avoid heap allocation when all parts are known
  static strings.
- Runtime function calls are emitted even when the current implementation could
  theoretically constant-fold the sample.
- Printing segmented string parts directly is preferred over building a
  temporary heap string.
- Platform output calls should be direct and inlinable when practical.
- The final executable should be produced through LLVM's native target pipeline.

## Implemented Language Surface

The current compiler supports:

```sollang
getName: -> Text {
    "dimohy"
}

square: Int -> Int {
    it * it
}

main {
    getName() => name
    7 -> square => num
    "Hello, $name. square = $num" -> print
}
```

and the cumulative input and loop sample shown above.

Current backend:

- targets: Windows x64, Linux x64, and browser WebAssembly
- LLVM toolchain: LLVM 22.1.8, downloaded under `.tools` by `scripts/sollang.ps1`
- lexer: generated from `syntax/sollang.lexer` by a Roslyn incremental source
  generator
- parser: generated from `syntax/sollang.grammar` by a Roslyn incremental source
  generator
- semantics: zero-argument and one-input function declarations, including
  default `it` inputs, explicit input names, local function scopes, standard
  library loading, global aliases for `sys.io`, built-in block-function calls,
  string, integer, and boolean bindings, checked integer `+`, `-`, `*`, `/`,
  `%`, unary `-`, parenthesized expressions, integer comparisons, short-circuit
  logical expressions, scalar interpolation, flow-oriented `if`,
  full-condition `when`, subject-value `when`, range-arm `when`, `fold`, `Int`
  static arrays, `Int` dynamic arrays, `{Int: Int}` dictionaries, checked
  indexing, mutable container bindings, move-consuming owner-returning container
  transforms, nominal inline `struct` values, complete field initialization,
  direct nested field access, readonly `self` methods in `impl` blocks,
  parenthesis-free computed members, payload `enum` values, exhaustive enum
  `when` patterns, nominal traits with explicit implementations, explicit
  affine `dyn<Trait>` conversion and vtable dispatch, checked
  one- and two-type generics with trait bounds, associated-type inference, and
  monomorphization, compile-time
  `Int` value generics with explicit fluent specialization such as
  `value -> fill[4]`, trait associated types with static `impl` bindings and
  trailing constraints such as `where T: Source, T.Item == Item`, receiver-argument
  flow targets, explicit `box T` owners, recursively sized user types through
  boxed fields or enum payloads, readonly owned-value borrows, static recursive
  drop glue, and expression-first bindings are type-checked
- fixed array literals preserve homogeneous element type for `Int` and `Text`;
  `Text` arrays use 16-byte `%sollang.text` elements, checked indexing returns
  `Text`, and their backing storage is deterministically released
- copyable user `struct` and `enum` elements receive an element-specific
  parametric array type and use their exact LLVM aggregate layout; arrays of
  recursively owned elements call static element drop glue for every initialized
  slot before freeing the backing buffer; an owned indexed element can be
  borrowed only as a direct readonly-call argument, while `take` transfers one
  slot without leaving a second owner
- growable arrays preserve `Text` and user-value element layouts, support typed
  empty capacity hints, checked indexing, `len`/`capacity`, type-checked mutable
  `push`, aggregate-aware growth copying, and runtime-length recursive drop
- growable arrays may own growable array elements such as `[[Int; ~]; ~]`;
  each element uses the growable owner's pointer/length/capacity descriptor,
  ownership transfers on insertion, and recursive drop releases inner storage
  before the outer buffer. A readonly borrow of an owned array cannot be copied
  into that owning storage.
- an owning local struct-literal binding applies the same borrowed-source
  check before acquiring cleanup responsibility. A readonly array input cannot
  initialize an owned field in that local aggregate. Move inputs and independent
  fixed-storage value copies retain their existing transfer and copy rules.
- a borrowed parameter that transitively owns storage cannot be embedded in an
  owned function result; ownership must be transferred with `move`, or the API
  must return a borrow or an explicit copy. This is a compile-time error with a
  source-level repair hint in both managed and self-host compilers; checked
  self-host emission stops before LLVM output
- value-flow calls: `value -> function` and compatibility spelling
  `value -> function()` are parsed as a flow AST and lowered by
  semantic/codegen stages according to target position; bare flow targets cannot
  introduce bindings
- input: `sys.io.readInt` and alias `readInt` lower to a selected stdin backend
  primitive and return an integer value
- file/random workflow: `seedRandom` initializes a deterministic LCG state,
  `randomBelow` returns a pseudo-random integer in `0..maxExclusive-1`,
  `openIntWriter`/`writeInt`/`closeIntWriter` write buffered binary `Int`
  records, and `openIntReader`/`closestInt`/`closeIntReader` query sorted binary
  `Int` records
- loops: `start..end -> each i { ... }` and `start..end -> each { ... }` are
  modeled as block-function calls and lower directly to LLVM basic blocks with
  an SSA phi value for the loop variable, without runtime closure allocation or
  dynamic block dispatch
- folds: `start..end -> fold initial acc, item { nextAcc }` lowers directly to
  LLVM basic blocks with SSA phi values for the item and accumulator, and returns
  the final accumulator value without runtime closure allocation or dynamic
  block dispatch
- IR output: immutable UTF-8 literal segments, runtime function calls, runtime
  i64 arithmetic/comparison, i1 boolean values, one-evaluated subject values for
  subject-value `when`, branch/phi conditional lowering, named inline LLVM
  aggregates for user structs, statically dispatched methods, inlined local
  functions, and runtime integer decimal output
- incremental LLVM units: the production emitter writes one target/configuration
  prefix, stable-hash-ordered per-module function units, and one program suffix.
  Unit-local string symbols and function-local SSA numbering make module text
  independent of earlier emission order. `sollang build` may reuse a module only
  when its exact implementation, transitive public interfaces, concrete
  specialization inventory, compiler identity, target, and configuration match.
  The persistent binary generation has bounded lengths, canonical unit order,
  full module identities, the schema-1 per-fragment and envelope checksums, and is
  atomically replaced only after a successful link. A corrupt or incompatible
  generation is reported and rebuilt; cached and clean LLVM bytes must match.
- canonical self-host module interfaces retain the full parsed namespace as
  length-prefixed UTF-8 bytes in the schema-2 interface payload. Whitespace and
  comments do not participate in namespace identity. The namespace hash is a
  lookup accelerator; equality requires the complete canonical word sequence,
  including the namespace and exported signatures. Older interface payloads
  are incompatible and must miss reuse. Record selection must continue through
  a hash collision bucket. Imports resolve by the complete parsed namespace;
  dependency reuse also compares the target's full cached canonical interface.
  An unchanged public interface may preserve consumers after a body-only edit.
- complete typed-IR artifacts retain the exact owning source bytes in a
  bounded, checksummed identity envelope. Canonical module ordinals replace
  namespace hashes inside the structural payload, and decoding maps those
  ordinals back to current source indexes only after exact source comparison.
  Source order does not affect the artifact. A changed or missing source
  invalidates complete-IR restoration because its syntax and symbol ordinals
  are source-local. This exact artifact contract does not authorize skipping
  changed-source semantic validation or replace semantic owner restoration.
  The producer retains the final resolved call context and its inferred type
  table together. Encoding reports an explicit failure and publishes no payload
  when an IR type reference is outside that table or structural type validation
  fails; an invalid reference must never become an absent type. Decoding must
  preserve every typed node, although canonical type IDs may be renumbered.
- exact-input frontend cache: after a successful link, `sollang build` records
  the exact root, manifest, standard-library, and discovered user-source bytes in
  a checksummed snapshot bound to the SHA-256 digest of the matching LLVM-unit
  generation. If compiler, target, configuration, source sets, bytes, snapshot
  checksum, codegen digest, and codegen envelope all match, a warm build skips
  lexing, parsing, semantic analysis, and LLVM emission and links the validated
  units directly. Any source change falls back to the normal frontend and may
  still reuse independently valid LLVM units. Snapshot comparison is streamed;
  publication uses a same-directory write-through temporary file and atomic
  replacement after a successful link.
- exact-product cache: a small checksummed `.product` generation binds the
  validated source snapshot, LLVM-unit generation, and final target artifact by
  SHA-256 together with compiler, target, and configuration identity. If all
  three files still match, an exact warm build also skips the linker. A missing
  or changed final artifact relinks from the already validated LLVM units and
  atomically publishes a repaired product generation without rerunning the
  frontend.
- semantic identity generation: a schema-9 `.semantic` generation stores
  canonical structural identities for bound functions and resolved generic call
  sites, the visible declaration-universe fingerprint, exact per-module source
  digests, and reusable function binding/captured-binding type maps.
  It never persists process-local `TypeId` values or AST object addresses, is
  bound to compiler/target/configuration identity, uses strict UTF-8 and bounded
  canonically ordered records, and protects the complete payload with SHA-256.
  After declarations are rebuilt, a changed-source build may skip body
  validation only when the function's module digest and the complete visible
  declaration fingerprint are unchanged. Persisted structural types are
  re-interned into the fresh type table. A parent and all recursively nested
  local functions are restored as one atomic tree. Stable syntax-call identities
  are assigned before resolution across ordinary calls, type applications,
  fluent targets, and block-function calls. Resolved edges carry either a
  generic template plus structural type/value arguments or the concrete
  signature of a synthesized runtime specialization. Rehydration reconstructs
  the current-session target, verifies its full stable identity, follows nested
  specialization edges, and restores user-specialization bindings. Main uses
  the same process when its executable module is exact. Function and main call
  restoration is transactional; any missing or invalid node, recipe, type, or
  target falls back to normal validation without publishing partial state.
  Publication is write-through and atomic after a successful link.
- self-host module-cache admission: `module_cache.preflight` validates the
  complete cache envelope and record structure before looking up a module or
  reading its source hash. A truncated, corrupt, or incompatible cache returns
  `false` without accessing an unvalidated record. A valid cache still requires
  the requested module identity and exact source hash.
- typed artifact decoding: validate the declared structural type count against
  the available record payload before allocating per-record decoder state.
  A rejected count returns its existing failure status with empty decoded
  tables; it must not allocate storage proportional to that rejected count.
- semantic type-term substitution: replacing a parameter uses the original
  replacement tree without substituting inside that tree again. Identity and
  self-containing replacements remain valid, including canonical aliases.
  Child indices are checked before traversal; invalid indices return status 1,
  while unresolved or cyclic arenas return status 2.
- common emitter: `LlvmEmitter` owns function calls, bindings,
  interpolation, local-function inlining, `each` lowering, integer decimal
  output, containers, and `readInt` parsing. It is split into partial files by
  lowering area so target-independent LLVM emission stays navigable.
- platform runtime layer: `LlvmRuntimePlatform` owns the target triple, native
  entry point name, external OS declarations, stdin/stdout handle setup, and
  byte-level `sollang_write`/`sollang_read_stdin` primitives
- Windows entry point: `sollang_start`
- Windows imports: `GetStdHandle`, `ReadFile`, `WriteFile`
- Windows linker: `lld-link`
- Windows CRT: none
- Linux entry point: `main`
- Linux imports: `read`, `write`
- Linux linker: WSL `cc` after producing an ELF object with Windows LLVM `clang`
- executable size is toolchain, optimization-level, and feature dependent;
  dated measurements belong in `benchmarks/`, not in the normative language
  contract

The current runtime backend keeps source-language lowering shared across
targets. It calls generated user Sollang functions, inlines standard library
`sys.io` wrappers, converts integer output to decimal bytes at runtime, and
parses `readInt` in common LLVM IR. Only target triple selection, native entry
point setup, external OS declarations, byte writes, byte reads, and linker choice
are platform-specific.

## Current Module Layout

The compiler implementation is organized by responsibility:

- `Cli`: command line parsing and build orchestration
- `Lexing`: token model and generated lexer
- `Parsing`: parser helpers; the token-to-AST parser is generated
- `Syntax`: AST node definitions
- `Semantics`: current binding/interpolation/I/O/loop lowering
- `CodeGen`: shared LLVM IR generation plus target runtime platform layers
- `Tooling`: LLVM, Windows linker, and WSL Linux linker integration
- `stdlib/sys`: system-effect modules such as console/standard-stream I/O,
  process, and file, plus runtime ABI fragments under `stdlib/sys/runtime/**`
- `stdlib/std`: portable value and algorithm modules, including in-memory
  Reader/Writer implementations under `std.io`
- `tests/Sollang.ExampleTests`: executable sample expected stdout runner
- `selfhost`: Sollang lexer/parser/CST/AST, semantics, typed IR, ownership,
  incremental cache, LLVM emission, and native compiler driver modules

Lexer rules are expressed in the compact `syntax/sollang.lexer` file. The source
generator reads that file as an MSBuild `AdditionalFiles` input and emits
`TokenKind` plus the deterministic lexer during C# compilation.

Parser rules are expressed in the compact `syntax/sollang.grammar` file. The
source generator emits the C# bootstrap parser, while the generated ordinary
Sollang table drives the self-host lexer/parser/CST/AST pipeline. Byte-for-byte
table determinism prevents the two paths from silently drifting.

## Follow-On Design Extensions

The core syntax, ownership model, target matrix, compiler pipeline, and
self-hosting boundary are implemented. Possible future specifications must be
accepted explicitly and include their own executable evidence. Current
extension areas include richer format-specific serialization/decoding,
publishing/signing services, additional editor refactorings, and wider browser
host capabilities. None of these imply a fallback or weaken the existing
Windows/Linux/native ownership guarantees.
