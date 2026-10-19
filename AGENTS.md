# Sollang repository instructions for AI Agents

Before reading or changing Sollang code, read `docs/AI_SLG_BEST_PRACTICES.md`
and follow its source-of-truth order, syntax rules, root-cause-only policy, and
verification ladder.

`docs/AI_SLG_BEST_PRACTICES.md` is the single AI syntax and beautiful-code guide.
`docs/AI_AGENT_GUIDE.md` is only a compatibility pointer. The single guide links to
`docs/SPEC.md`, the authoritative living specification. Update the relevant
specification and affected grammar/examples/contracts when behavior changes.
Update the relevant guide section when syntax, usage, target boundaries, or
SLG beauty criteria change. Never append progress, defect histories, or build results.
Update `docs/SESSION_HANDOFF.md` only on an explicit user handoff request.
Do not duplicate the guide or specification here.

Completed verification output follows `scripts/contracts/artifact-lifecycle.json`.
After a successful, input-stable verification and process shutdown, use
`scripts/ArtifactLifecycle.ps1` to remove owned generated binaries, LLVM
intermediates and private caches. Preserve source fixtures, expected output,
hashes, result JSON and diagnostics. Keep at most three explicitly reusable
compiler products; protect active consumers and never delete unverified,
failed, cancelled or changed outputs as if they were completed. A successful
compiler build is not permission to delete a product needed by its pending
tests. Its partition temporary files can be removed after build verification;
the caller closes the rest of the output after its tests finish.

Compiler changes follow a strict implementation order. Implement each feature or
fix in the C# compiler first and verify its focused C# behavior. Then compare
the corresponding C# and SLG source structure, branches, logic, and diagnostic
decisions before changing the separate SLG compiler. Make the SLG implementation
match those decisions, then compile and run focused paired cases and related
controls. Only after all units are resolved, run one exhaustive C# versus SLG
comparison and the Stage2/Stage3 gates. A reproduced mismatch or a rule name
alone does not authorize starting the self-host build before source comparison.

During an ongoing Sollang goal, every intermediate status update must include
separate measured `completed/total (percent)` values for compiler stabilization,
the current focused gate, Stage2/Stage3, and the frozen stdlib/runtime backlog.
Keep failures, running work, and completed work distinct; never omit these axes
merely because an earlier update already showed them.

After Slogs LLM Wiki connects, search user-wide Korean software terminology and
reporting preferences separately from Sollang project memory, then read and
apply both sets before the first progress update. A successful connection or a
project-only search does not establish preference coverage. Recheck the relevant
preference when the user corrects wording during a running task. Review Korean
status text with the `korean-software-terminology` skill's deterministic text
guard before sending it; preserve code identifiers and quoted external output.
