# SmallLang Decision Log

This file records accepted or working decisions so the language design can
evolve without losing context.

## D001 - Specification Before Implementation

Status: accepted
Date: 2026-07-07

SmallLang remains in specification mode until the user explicitly asks for
implementation. No compiler, parser, LLVM backend, runtime, or build
infrastructure should be created before that.

## D002 - Compiler Implementation Stack

Status: accepted
Date: 2026-07-07

When implementation begins, the compiler should use the latest .NET and latest
C# Preview features unless a later constraint requires otherwise. Actual SDK,
C# language, and LLVM versions must be verified against official sources before
implementation starts.

## D003 - Native LLVM Output

Status: accepted
Date: 2026-07-07

SmallLang compiles through LLVM and ultimately produces highly optimized native
executables. The language and compiler pipeline should be designed around
efficient LLVM lowering rather than treating LLVM as an afterthought.

## D004 - First Program Syntax

Status: working decision
Date: 2026-07-07

The first complete SmallLang program is:

```smalllang
main {
    name = "dimohy"
    print("Hello, {name}")
}
```

The `main` block is explicit, short, and parser-friendly. `name = value` is the
initial local binding form. Full function syntax is not decided yet.

## D005 - `print` As Platform-Bound Primitive

Status: working decision
Date: 2026-07-07

`print` appears as a simple prelude call in source code, but resolves internally
to `core.io.print` and lowers to a platform-specific stdout backend selected by
the target triple.

The design must preserve:

- simple source syntax
- cross-platform correctness
- Unicode-correct Windows console behavior
- efficient static string output
- no silent fallback for unsupported targets
- explicit handling of output failure

## D006 - Bindings Without Declaration Keywords

Status: working decision
Date: 2026-07-07

Local variables are introduced with the smallest readable form:

```smalllang
name = "dimohy"
```

There is no `let`, `var`, or declaration keyword in the initial syntax. For now,
the first `name = expression` in a block introduces a binding, and reusing the
same name in the same scope is a compile-time error. Reassignment and mutability
remain open design questions.

## D007 - Minimal String Interpolation

Status: working decision
Date: 2026-07-07

Double-quoted strings support simple binding/path interpolation:

```smalllang
"Hello, {name}"
```

The initial interpolation form accepts names and reserved path syntax only, not
arbitrary expressions. This keeps tokenization, parsing, semantic analysis, and
LLVM lowering simple while still making the first useful program expressive.

## D008 - Local LLVM Bootstrap

Status: accepted
Date: 2026-07-07

LLVM binaries must not be committed to the repository. The build script
downloads LLVM 22.1.8 into `.tools` when missing and uses that local toolchain
for native code generation. `.tools`, `artifacts`, and build outputs are ignored
by Git.

## D009 - First Native Backend

Status: working decision
Date: 2026-07-07

The first native backend targets Windows x64 and links with `lld-link` without
the C runtime. The generated executable imports only `GetStdHandle` and
`WriteFile` from `kernel32.dll` for the first `print` program. The verified
first executable size is 752 bytes.

## D010 - Modular Compiler Source Layout

Status: accepted
Date: 2026-07-07

Even small requests should keep the compiler modular. The compiler source is
split by responsibility into CLI, Lexing, Parsing, Syntax, Semantics, CodeGen,
and Tooling modules. `Program.cs` must stay as a minimal entry point, not a
container for lexer/parser/codegen/linker implementation.

## D011 - Lexer Source Generation From SmallLang Rules

Status: accepted
Date: 2026-07-07

SmallLang lexer rules are expressed in `syntax/smalllang.lexer`. A Roslyn incremental
source generator in `src/SmallLang.Compiler.Generators` reads that rules file and
generates `TokenKind` and `Lexer` during compiler build. This keeps the language
surface concise and regular while producing deterministic C# tokenization code.

## D012 - Parser Source Generation From SmallLang Grammar

Status: accepted
Date: 2026-07-07

SmallLang parser rules are expressed in `syntax/smalllang.grammar`. A Roslyn incremental
source generator reads that grammar file as an MSBuild `AdditionalFiles` input
and emits the current token-to-AST parser during compiler build.

ANTLR, parser combinators, and C# embedded parser generators remain valid future
options, but they are not the best fit for the first SmallLang slice. ANTLR adds a
separate grammar toolchain and C# runtime dependency. Parser combinators and
attribute-based C# parser generators keep grammar inside C# code instead of a
small language-owned syntax file. The current source-generator approach keeps
the repo small, dependency-light, modular, and aligned with the existing lexer
generation model.

The first parser generator intentionally supports only the approved initial
grammar shape. Broader grammar features should be added when the language
surface actually needs them.

## D013 - Value-Flow Calls As Preferred Call Style

Status: implemented, superseded in parser shape by D016
Date: 2026-07-07

SmallLang adopts `value -> function` as the preferred call style when a primary
input value flows into a function:

```smalllang
"Hello, {name}" -> print
```

This form makes data flow visually explicit. The expression on the left is the
first input to the callable path on the right. For the initial unary case, it is
semantically equivalent to:

```smalllang
print("Hello, {name}")
```

Parenthesized calls remain valid as a conventional compatibility syntax and for
cases where the value-flow form is not expressive enough. The preferred SmallLang
style is value-flow first:

```smalllang
result = value -> transform
```

Function type notation should use the same left-to-right direction:

```smalllang
print: Text -> Io<Unit>
```

The first implementation lowered unary value-flow calls to the same call AST
shape used by the existing parenthesized call. D016 keeps value-flow as its own
AST node so a final target can bind the result.

## D014 - Initial Integer Addition And Scalar Interpolation

Status: accepted
Date: 2026-07-07

SmallLang supports decimal integer literals and left-associative integer `+` in the
current compiler slice:

```smalllang
sum = 20 + 22
```

The first numeric model is intentionally narrow. Integer literals evaluate to
signed 64-bit values in the semantic evaluator, and `+` performs checked integer
addition. Mixed string/integer `+`, floating point values, arbitrary precision
numbers, suffixes, and final overflow policy syntax are not decided yet.

String interpolation can display integer bindings:

```smalllang
"Number: {sum}" -> print
```

This first numeric step initially allowed the compiler to fold the whole sample
to output bytes. D015 changes the current sample to exercise runtime function
calls and runtime integer-to-decimal output instead.

## D015 - Runtime Function Sample

Status: implemented, superseded as the current sample by D016
Date: 2026-07-07

The D015 sample should not be represented only as one compile-time output
buffer. It used zero-argument functions so the generated LLVM contained real
runtime calls:

```smalllang
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

The D015 implementation parsed `getName: -> Text { ... }` and
`getNum: -> Int { ... }` as zero-argument expression functions. Semantic
analysis type-checks the function bodies and main bindings. The Windows LLVM
backend emits `@smalllang_fn_getName`, `@smalllang_fn_getNum`, runtime `i64` addition,
segmented `WriteFile` output, and a runtime integer decimal conversion helper
instead of one full static output string. D016 is the current sample and
supersedes the `getNum` naming.

## D016 - Flow Binding And One-Input Square Function

Status: implemented
Date: 2026-07-07

SmallLang adopts statement-level value-flow binding for the current sample:

```smalllang
getName: -> Text {
    "dimohy"
}

square: Int -> Int {
    it * it
}

main {
    getName -> name
    7 -> square -> num
    "Hello, {name}. square = {num}" -> print
}
```

`getName -> name` calls the zero-input function and binds its result to `name`.
`7 -> square -> num` passes `7` into a one-input function, where the implicit
input binding is named `it`, then binds the returned value to `num`.

The parser now preserves value-flow as `FlowExpression` rather than immediately
lowering it to `CallExpression`. Semantic analysis resolves each target as a
known one-input function, `print`, or a final statement-level binding target.
Unknown intermediate targets are compile-time errors, and flow expression
statements must either end in `print` or bind their result.

The current implementation adds the `*` token/operator, parses
`square: Int -> Int { it * it }`, emits `@smalllang_fn_square(i64 %it)`, lowers the
body to `mul nsw i64 %it, %it`, and calls it as `@smalllang_fn_square(i64 7)`.
The verified output at D016 time was `Hello, dimohy. square = 49`; the Windows
x64 executable size at D016 time remained 1,088 bytes.

## D017 - Input Primitive And Inclusive Range Loop

Status: implemented, loop spelling superseded by D019
Date: 2026-07-08

SmallLang samples are cumulative. New samples should be added alongside earlier
samples instead of replacing `examples/hello.sl`.

The next implemented sample reads an integer and prints that multiplication
table:

```smalllang
main {
    "n = ? " -> readInt -> n

    each i in 1..9 {
        n * i -> value
        "{n} x {i} = {value}" -> println
    }
}
```

`readInt` mirrors output value-flow style: a `Text` prompt flows into the input
primitive and the resulting `Int` can flow into a binding target. The
parenthesized form `readInt("n = ? ")` remains valid. Internally, `readInt`
resolves to a selected backend primitive, currently the Windows stdin path using
`ReadFile`; this keeps the source syntax independent from the platform backend
and leaves room for POSIX/WASI input lowering later.

`println` is accepted as the first newline-output convenience. It shares the
same output backend as `print`, then emits one line-feed byte in the current
runtime slice.

The first loop syntax is:

```smalllang
each i in 1..9 {
    ...
}
```

This is an inclusive integer range loop. The loop variable is scoped to the loop
body, and bindings created inside the body do not escape the body. The current
implementation lowers the loop to LLVM basic blocks with an SSA phi value for
the loop variable. Descending ranges are not specified yet; a range whose start
is greater than its end executes zero times.

After adding the input and loop runtime, the verified executable sizes are 1,104
bytes for `examples/hello.sl` and 1,584 bytes for
`examples/gugudan.sl`.

## D018 - Arrow Binding As Preferred Assignment Direction

Status: accepted
Date: 2026-07-08

SmallLang should prefer arrow-oriented binding even for local assignment-like
introductions. New samples should use:

```smalllang
expression -> name
n * i -> value
```

instead of leading with:

```smalllang
name = expression
value = n * i
```

This keeps local binding aligned with the language's value-flow direction:
values are written first, then flow into their binding target. The existing
`name = expression` form remains accepted as a compatibility syntax for now, but
it is no longer the preferred style for examples or documentation. This decision
supersedes D004/D006 as the current surface-language direction while preserving
those entries as historical context.

## D019 - Arrow Range Loop With Optional Item Name

Status: implemented
Date: 2026-07-08

SmallLang's preferred range loop syntax is now flow-oriented:

```smalllang
1..9 -> each i {
    n * i -> value
    "{n} x {i} = {value}" -> println
}
```

The range expression flows into `each`, and the optional identifier after `each`
names the current item. When the identifier is omitted, the loop item is bound as
`it`:

```smalllang
1..9 -> each {
    n * it -> value
    "{n} x {it} = {value}" -> println
}
```

This gives the language two final current forms:

- `start..end -> each { ... }` for the default item binding `it`
- `start..end -> each item { ... }` for an explicit item binding

The older `each item in start..end { ... }` spelling remains accepted as a
compatibility form, but new samples and documentation should prefer the
flow-oriented loop syntax.

## D020 - Optional Function Input Names

Status: implemented
Date: 2026-07-08

SmallLang one-input functions now follow the same naming shape as `each`.

When the input name is omitted, the function body receives the value as `it`:

```smalllang
square: Int -> Int {
    it * it
}
```

When the input name is supplied after the function name, the body receives the
value through that binding:

```smalllang
square n: Int -> Int {
    n * n
}
```

This mirrors the loop forms:

```smalllang
1..9 -> each {
    it
}

1..9 -> each i {
    i
}
```

The older `square: Int -> Int { it * it }` form remains valid and is the default
input-binding form. The explicit form `square n: Int -> Int { n * n }` is
available when naming the input improves readability.

## D021 - Built-In Block Functions And Optimized `each`

Status: implemented
Date: 2026-07-08

`each` should be understood as the first built-in block function rather than as
only a hard-coded loop statement:

```smalllang
1..9 -> each i {
    n * i -> value
    "{n} x {i} = {value}" -> println
}
```

Semantically, the range value flows into the block function `each`, `i` names the
block invocation input, and the brace body is the executable block argument.
The default item form follows the same rule:

```smalllang
1..9 -> each {
    n * it -> value
    "{n} x {it} = {value}" -> println
}
```

The compiler now represents this preferred form as a generic block-function call
AST. The current semantic layer only accepts `each` as a block-function target;
future built-ins or user-defined block functions can build on the same model.

This language model must not force inefficient runtime lowering. The Windows
LLVM backend specializes the built-in `each` block function directly into loop
basic blocks with an SSA phi value for the item binding. It does not allocate a
closure, emit a function pointer, or perform dynamic block dispatch for the
current built-in loop.

The older `each item in start..end { ... }` spelling remains accepted as a
compatibility syntax and is converted into the same internal block-function call
shape before semantic analysis.

## D022 - `sys.io` Is A SmallLang Standard Library Module

Status: implemented
Date: 2026-07-08

`print`, `println`, and `readInt` should not be compiler-owned special functions
under the `sys.io` name. They are ordinary functions provided by the standard
library and imported globally through aliases:

```text
print   -> sys.io.print
println -> sys.io.println
readInt -> sys.io.readInt
```

The actual `sys.io` module is implemented in SmallLang:

```smalllang
sys.io.print value: Text -> Unit {
    value -> sys.runtime.print
}

sys.io.println value: Text -> Unit {
    value -> sys.runtime.println
}

sys.io.readInt prompt: Text -> Int {
    prompt -> sys.runtime.readInt
}
```

The lower runtime boundary is declared separately in the standard library with
`= intrinsic`:

```smalllang
sys.runtime.print value: Text -> Unit = intrinsic
sys.runtime.println value: Text -> Unit = intrinsic
sys.runtime.readInt prompt: Text -> Int = intrinsic
```

This required two syntax additions for the current implementation slice:

- path-qualified function declarations, such as
  `sys.io.print value: Text -> Unit { ... }`
- intrinsic declarations, such as
  `sys.runtime.print value: Text -> Unit = intrinsic`

The compiler loads `stdlib/sys/runtime.sl` and `stdlib/sys/io.sl` before user
source, then adds only alias entries for `print`, `println`, and `readInt`.
The semantic model resolves `sys.io` through the same function table as user
functions. The Windows LLVM backend inlines standard library wrappers and lowers
only the `sys.runtime` intrinsic boundary to direct `ReadFile`/`WriteFile`
runtime code, so verified IR does not emit `sys.io` function calls.
