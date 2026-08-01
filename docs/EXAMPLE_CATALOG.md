# Example and test catalog

Sollang keeps learning-oriented examples separate from exhaustive regression
fixtures.

## User examples

`examples/user/` contains 10 focused examples, one for each syntax direction
adopted in the 2026-07 grammar alignment:

1. `->` flow and `=>` binding/body/arm separation
2. value-first binding and indexed assignment
3. flow-only `each`
4. explicit zero-input calls and property-like computed members
5. value-first stream state
6. arbitrary generic parameters
7. trailing and multiple generic constraints
8. inclusive `..` and half-open `..<` ranges
9. interleaved top-level declarations
10. growable array forms

Each user example has a byte-identical regression counterpart.

## Regression inventory

| Kind | Location | Count |
| --- | --- | ---: |
| User examples | `examples/user/` | 10 |
| Regression cases | `examples/regression/expected/*.stdout.txt` | 770 |
| Diagnostic cases | test runner | 231 |
| Complete logical catalog | test runner | 1,001 |
| Windows x64 selected suite | test runner | 1,001 |
| Linux x64 applicable suite | test runner | 1,000 |
| Browser playground catalog | `app/samples.ts` | 34 |

The catalog counts logical test cases, not every supporting file. Source lists,
LLVM assertions, expected diagnostics, module fragments, projects, and other
supporting files may belong to one logical case. Linux excludes the one
Windows-only COM execution case while still structurally validating its LLVM;
therefore the Linux-applicable selected suite has 1,000 cases.

The test runner also checks that every file under `examples/user/` is backed by
an identical regression fixture, preventing documentation examples from
drifting away from tested syntax.

The exhaustive catalog additionally keeps compiler-internal combinations out
of the user tutorial set. For example,
`711-selfhost-llvm-subject-when.slg` verifies all six subject comparison arms,
inclusive and half-open ranges, `else`, value-producing function returns,
LLVM assembly, native linking, and exact runtime output in one retained
self-host regression.
