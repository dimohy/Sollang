# Owned resource branch results

`scripts/contracts/owned-resource-branch-result.json` checks the C# compiler and,
after a source-aligned compiler build, paired native acceptance. Each fixture
imports the real `std.net.socket.CompletionReactor`. The tested functions are
checked even though `main` only prints `1`; no native resource is constructed.

The cases distinguish a consuming call versus a bare owner block result, two
consuming calls, a statement-only move versus a continuing retained path, and a
terminating moved arm. Only the third case must be rejected.

`source-checked.slg` and `source-helper.slg` run the same fixture text through
the SLG preparation and ownership analyzer. To isolate this unit from unrelated
stdlib diagnostics, the helper supplies only the canonical reactor declaration
and its scalar `UInt64` field. Its four code-33 decisions verify the branch
analysis; they do not prove complete stdlib validation or paired native behavior.
Runtime-read fixture hashes must match the retained C# proof when accepting this
source comparison.
