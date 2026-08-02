# User examples

The directory contains two deliberately small learning tracks. Start with
`663-arbitrary-generic-parameters.slg`, then read through `672-...` for the
general syntax direction:

1. arbitrary generic parameters;
2. distinct flow (`->`) and definition (`=>`) arrows;
3. value-first binding and indexed mutation;
4. flow-only `each`;
5. explicit zero-input calls and member-like properties;
6. value-first stream state;
7. trailing multiple constraints;
8. inclusive and half-open ranges;
9. interleaved top-level declarations;
10. seeded and typed-empty growable arrays.

Then read `790-sequential-named-branch.slg` through
`802-readonly-parallel-branch.slg` for the ten Flow Junctions examples:

1. scalar sequential `branch`;
2. multi-stage named branch arms and source order;
3. value-preserving `tap` blocks;
4. labeled product binding and field access;
5. ordinary product values;
6. exclusive first-match `partition`;
7. shortest-input `zip`;
8. availability-ordered `merge`;
9. ordered `concat` and state-updating `latest`;
10. readonly ownership with explicit `parallel branch`.

All 20 files are intentionally small. Their byte-identical counterparts under
`../regression/` are executed by the full test suite. Exhaustive combinations,
negative diagnostics, buffering, cancellation, LLVM, and bootstrap coverage
remain only in `../regression/` so the learning track stays readable.
