# Sollang examples

Read `user/` first. Those twenty files are the preferred surface syntax for
humans and AI Agents. `regression/` is the exhaustive compiler catalog, not
the learning path.

- `user/`: twenty concise examples: ten general syntax examples and ten Flow
  Junctions examples.
- `regression/`: executable compiler fixtures, expected output, diagnostics,
  platform variants, and self-host coverage.

Every user example has a byte-identical regression counterpart. The test runner
checks that relationship before running the executable and diagnostic suites.
