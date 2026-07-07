# SLang Language Specification Draft

Status: draft
Date: 2026-07-07

This document is the living specification for SLang. It records the language
shape before implementation so design decisions do not get lost.

## Current Boundary

SLang implementation has started for the smallest approved language slice.

The implementation boundary is intentionally narrow:

- one `main` block
- zero-argument expression functions
- local string bindings with `name = value`
- integer bindings with decimal integer literals
- left-associative integer `+`
- simple string interpolation with `{name}`
- value-flow calls with `value -> function`
- parenthesized calls with `function(value)`
- Windows x64 native executable output through LLVM

Anything beyond that remains specification work until explicitly approved.

## Core Goals

- Provide a beautiful, simple, and powerful source language.
- Parse and tokenize source code very effectively.
- Compile through LLVM into highly optimized native executables.
- Keep the compiler pipeline efficient from source text to final executable.
- Support cross-platform native output from the beginning.
- Prefer clear compile-time errors over silent fallback behavior.
- Use the latest .NET and latest C# Preview features for the compiler
  implementation unless a later constraint requires otherwise.

## Non-Goals For The Current Phase

- No implementation.
- No final type system.
- No final memory model.
- No final module/package system.
- No finalized LLVM binding choice.
- No runtime design beyond the minimum needed to specify initial output.

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

## First Program

The first valid SLang program is:

```slang
main {
    name = "dimohy"
    print("Hello, {name}")
}
```

Expected stdout bytes:

```text
Hello, dimohy
```

`print` does not append a newline. A newline-producing convenience such as
`println` is a future surface-language decision.

The current extended example is:

```slang
getName: -> Text {
    "dimohy"
}

getNum: -> Int {
    20 + 22
}

main {
    name = getName()
    num = getNum()
    "Hello, {name}. getNum() = {num}" -> print
}
```

Expected stdout bytes:

```text
Hello, dimohy. getNum() = 42
```

## Initial Syntax Direction

SLang starts with an explicit `main` block instead of a fully general function
declaration. Local bindings do not use `let`, `var`, or a declaration keyword:

```slang
getName: -> Text {
    "dimohy"
}

getNum: -> Int {
    20 + 22
}

main {
    name = getName()
    num = getNum()
    "Hello, {name}. getNum() = {num}" -> print
}
```

Rationale:

- `main { ... }` is shorter than `fn main() { ... }`.
- `name = value` is the smallest readable binding form.
- `"Hello, {name}"` keeps string interpolation direct and familiar.
- `20 + 22` introduces the smallest numeric expression without deciding the
  final numeric tower.
- `getName: -> Text { ... }` and `getNum: -> Int { ... }` introduce the
  smallest function declaration shape.
- `"..." -> print` makes the primary data flow visible at the call site.
- The executable entry point is still explicit.
- The parser can recognize the first complete program with a tiny grammar.
- The syntax leaves room for full functions, modules, and effects later.
- Braces avoid indentation-sensitive block parsing.

## Initial Grammar

The initial grammar is deliberately small:

```ebnf
source_file  := trivia* function_declaration* main_block trivia* eof
function_declaration := identifier ":" "->" type_name "{" expression "}"
main_block   := "main" block
block        := "{" statement* "}"
statement    := binding_statement | expression_statement
binding_statement := identifier "=" expression statement_end
expression_statement := expression statement_end
statement_end := newline+ | "}" lookahead
expression   := flow_expression
flow_expression := additive_expression ("->" path)*
additive_expression := primary ("+" primary)*
call         := path "(" argument_list? ")"
argument_list := expression ("," expression)*
path         := identifier ("." identifier)*
type_name    := identifier
primary      := call | string_literal | number_literal | identifier
number_literal := decimal_digit+
string_literal := "\"" string_part* "\""
string_part  := string_text | interpolation
interpolation := "{" path "}"
```

Notes:

- Newline is a statement separator, not an indentation rule.
- Semicolons are not part of the initial surface syntax.
- Braces are the only block delimiters.
- `identifier = expression` introduces a local binding in the current block.
- `+` is initially defined only for integer addition.
- `value -> function` lowers to a unary call with `value` as the first argument.
- Function declarations are currently zero-argument expression bodies with an
  explicit return type.

## Bindings

The initial binding syntax is:

```slang
name = "dimohy"
```

There is no `let`, `var`, or declaration keyword.

Initial binding rules:

- The first `name = expression` in a block introduces `name`.
- A binding is visible after its declaration statement.
- Referencing a binding before declaration is a compile-time error.
- Reusing the same name in the same scope is a compile-time error for now.
- Reassignment and mutability are not specified yet.
- Type inference determines the binding's type from the initializer.

This keeps the smallest program easy to read while avoiding hidden mutation
semantics before the memory and value model are decided.

## Numeric Expressions

The first numeric expression support is intentionally narrow:

```slang
sum = 20 + 22
```

Initial numeric rules:

- Decimal integer literals are supported.
- Integer values are represented as signed 64-bit values in the current
  semantic evaluator.
- `+` performs checked integer addition.
- `+` is left-associative.
- Mixing strings and integers with `+` is not part of the current language.
- Integer bindings can be interpolated into strings using their invariant
  decimal display form.

This adds arithmetic without deciding floating point, arbitrary precision,
numeric suffixes, overflow policy syntax, or implicit string concatenation.

## Lexical Design

The lexer must be single-pass and allocation-conscious.

Initial token categories:

- keywords: `main`
- identifiers
- string literals, including interpolation markers inside string mode
- decimal integer literals
- punctuation: `{`, `}`, `(`, `)`, `.`, `,`, `+`, `->`, `:`, `=`
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

The exact string escape set is not finalized. The first required string form is
a double-quoted UTF-8 literal with optional identifier/path interpolation:

```slang
"Hello World"
"Hello, {name}"
```

Interpolation rules:

- `{name}` inserts the current value of the binding named `name`.
- Interpolating an integer binding uses its invariant decimal display form.
- `{module.name}` style paths are reserved by the grammar but module semantics
  are not finalized.
- Arbitrary expressions inside interpolation are not part of the initial
  language.
- An unmatched `{` or `}` inside a string is a compile-time lexical error unless
  a later escape rule defines a literal brace form.

## `print` Surface Semantics

`print` is available in the initial prelude. The preferred source form is a
value-flow call:

```slang
"Hello, {name}. getNum() = {num}" -> print
```

The parenthesized form remains valid and equivalent:

```slang
print("Hello, {name}. getNum() = {num}")
```

Semantically, it resolves to:

```text
core.io.print(utf8_output_expression)
```

## Value-Flow Calls

SLang accepts `->` as the preferred direction for function calls where the
input value should be visually explicit:

```slang
main {
    name = getName()
    num = getNum()
    "Hello, {name}. getNum() = {num}" -> print
}
```

The expression on the left flows into the function or callable path on the
right. The example above is semantically equivalent to:

```slang
print("Hello, {name}. getNum() = {num}")
```

This makes argument flow and return flow visible without discarding the familiar
parenthesized call form. Parenthesized calls remain valid as a compatibility and
escape-hatch syntax, but the value-flow form is the preferred SLang style for
single-primary-input operations.

Return values are still bound with `=`:

```slang
message = name -> greeting
bytes = message -> utf8.encode
count = bytes -> stdout.write
```

The corresponding function type notation follows the same direction:

```slang
greeting: Text -> Text
print: Text -> Io<Unit>
stdout.write: Bytes -> Io<Int>
```

The current parser lowers:

```slang
value -> function
```

to the same AST shape as:

```slang
function(value)
```

for unary calls. Chained value-flow calls are parsed left-to-right. Extended
forms such as additional named arguments remain future syntax work.

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

For Linux, macOS, and other POSIX-like targets, initial lowering should target a
minimal stdout write path equivalent to:

```text
write(stdout_fd, ptr, len)
```

Requirements:

- Handle short writes correctly.
- Handle interruptible writes correctly where required by the platform.
- Avoid heap allocation for static string literals.
- Keep the ABI boundary explicit.

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

For the current runtime sample:

```slang
getName: -> Text {
    "dimohy"
}

getNum: -> Int {
    20 + 22
}

main {
    name = getName()
    num = getNum()
    "Hello, {name}. getNum() = {num}" -> print
}
```

The intended lowering shape is:

```text
static global utf8 bytes: "dimohy"
function getName -> returns text slice
function getNum -> evaluates 20 + 22 at runtime and returns i64
runtime decimal conversion helper for integer output
native entry function
-> call getName and bind name to returned text slice
-> call getNum and bind num to returned integer
-> write string literal segments directly
-> write name as a text slice
-> convert num to decimal bytes at runtime and write them
-> lower value-flow print call to selected core.io.print backend with output bytes
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

## Current Implementation Slice

The current compiler supports:

```slang
getName: -> Text {
    "dimohy"
}

getNum: -> Int {
    20 + 22
}

main {
    name = getName()
    num = getNum()
    "Hello, {name}. getNum() = {num}" -> print
}
```

Current backend:

- target: Windows x64
- LLVM toolchain: LLVM 22.1.8, downloaded under `.tools` by `scripts/slang.ps1`
- lexer: generated from `syntax/slang.lexer` by a Roslyn incremental source
  generator
- parser: generated from `syntax/slang.grammar` by a Roslyn incremental source
  generator
- semantics: zero-argument function declarations, string and integer bindings,
  checked integer `+`, and scalar interpolation are type-checked for the current
  slice
- value-flow calls: `value -> function` is parsed and lowered to the existing
  call AST shape
- IR output: immutable UTF-8 literal segments, runtime function calls, runtime
  i64 addition, and runtime integer decimal output
- entry point: `slang_start`
- imports: `GetStdHandle`, `WriteFile`
- linker: `lld-link`
- CRT: none
- current verified executable size: 1,088 bytes

The current runtime backend emits direct `WriteFile` calls for text segments,
calls generated SLang functions, converts integer output to decimal bytes at
runtime, and returns `0` or `1` from the native entry point based on API
success.

## Current Module Layout

The compiler implementation is organized by responsibility:

- `Cli`: command line parsing and build orchestration
- `Lexing`: token model and generated lexer
- `Parsing`: parser helpers; the token-to-AST parser is generated
- `Syntax`: AST node definitions
- `Semantics`: current binding/interpolation/print lowering
- `CodeGen`: LLVM IR generation
- `Tooling`: LLVM and Windows linker integration

Lexer rules are expressed in the compact `syntax/slang.lexer` file. The source
generator reads that file as an MSBuild `AdditionalFiles` input and emits
`TokenKind` plus the deterministic lexer during C# compilation.

Parser rules are expressed in the compact `syntax/slang.grammar` file. The
source generator validates the first approved grammar slice and emits the
recursive descent parser during C# compilation. This keeps the grammar visible
without introducing a separate external parser generation toolchain at this
stage.

## Open Questions

- Should the language include both `print` and `println`?
- What is the exact error model for I/O failure?
- Does `main` return an explicit exit code later?
- What is the final string type: owned string, slice, UTF-8 view, or multiple
  forms?
- What escape sequences are allowed in string literals?
- Should string interpolation later allow full expressions?
- How should literal `{` and `}` be written inside strings?
- What is the mutability/reassignment model for `name = value`?
- What numeric types beyond the initial signed 64-bit integer should exist?
- What comment syntax should be adopted?
- What is the first official target matrix?
- Which LLVM integration strategy will the .NET compiler use?
- How much core library is required before the first executable?
