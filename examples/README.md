# Sollang examples

- `user/`: ten concise, readable examples for learning the current language.
- `regression/`: executable compiler fixtures, expected output, diagnostics,
  platform variants, and self-host coverage.

Every user example has a byte-identical regression counterpart. The test runner
checks that relationship before running the executable and diagnostic suites.
