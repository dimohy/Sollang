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
| Expected-output regression cases | `examples/regression/expected/*.stdout.txt` | 655 |
| Diagnostic input cases | `examples/regression/diagnostics/` | 231 |
| Cataloged regression cases | test runner | 886 |
| Fast executable regression suite | test runner | 724 |
| Browser playground catalog | `app/samples.ts` | 31 |

The catalog counts logical test cases, not every supporting file. Source lists,
LLVM assertions, expected diagnostics, module fragments, projects, and other
supporting files may belong to one logical case. The catalog is intentionally
larger than the fast suite because the fast selector omits expensive or
platform-specific groups.

The test runner also checks that every file under `examples/user/` is backed by
an identical regression fixture, preventing documentation examples from
drifting away from tested syntax.
