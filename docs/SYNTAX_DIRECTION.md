# Sollang syntax direction

The current syntax follows one reading direction: values move left-to-right,
while definitions and destinations appear on the right.

| Area | Current form |
| --- | --- |
| Flow | `value -> function` |
| Binding / compact body / compact arm | `expression => name` |
| Indexed mutation | `value => owner![index]` |
| Iteration | `source -> each item { ... }` |
| Zero-input function | `nowMillis()` |
| Payload-free enum / one-input computed member | `State.Ready`, `point.size` |
| Stream state | `initial => state current!` |
| Generic constraints | `where T: Source, T.Item == Item` |
| Range | inclusive `a..b`, half-open `a..<b` |
| Growable array | `[value,; ~]`, `[a, b; ~]`, typed empty `[T; ~]` |

Generic parameter lists are not capped at three parameters. Declarations may be
interleaved after namespace/import declarations. Removed compatibility forms
are covered by negative regression fixtures so they cannot silently return.
The trailing comma in `[value,; ~]` is mandatory: without it, `[T; ~]` would
make a single identifier ambiguous between a value seed and an element type.

The design comparison used official language references: Swift API naming and
clarity guidance, Rust call/generic/range expressions, Kotlin ranges, Elixir's
pipe operator, and Zig's explicit-control-flow principle. The one-element array
comma follows the same ambiguity-removal principle as Rust's required comma for
a [one-element tuple expression](https://doc.rust-lang.org/stable/reference/expressions/tuple-expr.html).
