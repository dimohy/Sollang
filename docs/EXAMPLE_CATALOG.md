# Example and test catalog

Updated: 2026-08-18

Sollang keeps learning-oriented examples separate from exhaustive regression
fixtures. The inventory table below is measured from the current runner
inputs: user examples remain a learning track, while the complete logical
catalog is the 985 executed regressions plus 274 diagnostics.

## User examples

`examples/user/` contains 20 focused examples. Ten cover the syntax direction
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

Ten more cover Flow Junctions: sequential named branch, multi-stage branch,
tap, labeled and ordinary products, partition, zip, merge, concat/latest, and
readonly explicit parallel branch. Each user example has a byte-identical
regression counterpart.

## Regression inventory

| Kind | Location | Count |
| --- | --- | ---: |
| User examples | `examples/user/` | 20 |
| Regression cases | `examples/regression/expected/*.stdout.txt` | 985 |
| Diagnostic cases | test runner | 274 |
| Complete logical catalog | test runner | 1,259 |
| Flow Junctions positive fixtures | `examples/regression/788-844*.slg` | 57 |
| Flow Junctions diagnostic fixtures | `examples/regression/diagnostics/` | 26 |
| Flow Junctions physical fixtures | positive + diagnostic | 83 |
| Flow Junctions independently counted logical cases | coverage matrix | 114 |
| Browser playground catalog | `app/samples.ts` | 43 (42 runnable + 1 target diagnostic) |

The catalog counts logical test cases, not every supporting file. Source lists,
LLVM assertions, expected diagnostics, module fragments, projects, and other
supporting files may belong to one logical case. Platform pass counts are
recorded only after the corresponding complete runner finishes; this inventory
table does not infer a pass count from the number of files.

The test runner also checks that every file under `examples/user/` is backed by
an identical regression fixture, preventing documentation examples from
drifting away from tested syntax.

The exhaustive catalog additionally keeps compiler-internal combinations out
of the user tutorial set. For example,
`711-selfhost-llvm-subject-when.slg` verifies all six subject comparison arms,
inclusive and half-open ranges, `else`, value-producing function returns,
LLVM assembly, native linking, and exact runtime output in one retained
self-host regression.
