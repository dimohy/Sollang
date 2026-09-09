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

During an ongoing Sollang goal, every intermediate status update must include
separate measured `completed/total (percent)` values for compiler stabilization,
the current focused gate, Stage2/Stage3, and the frozen stdlib/runtime backlog.
Keep failures, running work, and completed work distinct; never omit these axes
merely because an earlier update already showed them.
