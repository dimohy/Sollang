# User examples

Start with `663-arbitrary-generic-parameters.slg`, then read through `672-...`.
Together the ten files demonstrate the current syntax direction:

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

These files are intentionally small. Their identical counterparts under
`../regression/` are executed by the full test suite.
