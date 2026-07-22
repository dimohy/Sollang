# The Sollang Philosophy

Updated: 2026-07-22

Sollang is shaped by four distinct meanings of `Sol`. They belong together,
but none should disappear into a vague promise of simplicity. Every language
decision should be explainable through one or more of these commitments.

## 1. Sun — Code That Reveals

The sun makes form visible. Sollang should do the same for a program's intent.
Its syntax favors explicit value flow, local reasoning, transparent ownership,
and diagnostics that point toward the real cause. Warmth matters too: clarity
should invite people into the language rather than punish them for learning.

**Design test:** Can a reader see where a value comes from, where it goes, and
who owns it without reconstructing hidden machinery?

## 2. Sol — Code With Rhythm

`Sol` is a note in solfège. Sollang treats code as structured rhythm: expressions
flow, declarations establish motifs, and blocks create readable phrases. This
does not mean decorative syntax. It means related constructs should sound alike
to the eye, irregular noise should be removed, and reading and writing should
feel coherent.

**Design test:** Do similar ideas use harmonious forms, and can a program be read
in a natural sequence without jumping through incidental syntax?

## 3. Solution — Code That Resolves Problems

`Sol` also opens the word *solution*. A language earns its place by helping
people solve real problems. Sollang therefore combines concise expression with
native performance, compile-time evaluation, self-hosting, predictable memory,
cross-target LLVM output, and libraries that remove accidental complexity.

**Design test:** Does this feature make the user's problem simpler, or merely
move complexity into a less visible corner?

## 4. S·O·L — Code for Creators

The letters themselves state the creative principle:

- **S — Simple:** small, learnable forms with clear roles;
- **O — Original:** enough expressive power for a creator's own way of thinking;
- **L — Logical:** rules that compose consistently and remain explainable.

Simplicity without originality becomes restrictive. Originality without logic
becomes chaotic. Logic without simplicity becomes inaccessible. Sollang seeks
the force created when all three remain together: simple expression, original
thought, and logical execution.

**Design test:** Can creators express a distinctive idea without surrendering
either clarity or rigor?

## How the Four Commitments Meet the Syntax

Sollang's preferred `value -> operation => result` form exposes movement like
sunlight, reads with a repeated rhythm, shortens the path from problem to
solution, and gives creators a compact but logical composition tool. The same
standard applies beyond syntax: ownership should be visible, compile-time work
should remove runtime burden, tooling should explain rather than obscure, and
self-hosting should prove that the language can build itself honestly.

When a flow grows, its visual form should preserve that direction rather than
force the reader back into nested calls. A leading `->` continues the value
from the preceding line, and a leading `=>` names its result. Names such as
`it` and fold's `acc` are omitted only where the grammatical role determines
them uniquely; omission must remove noise without hiding ownership or changing
evaluation order.

That proof is now executable rather than aspirational: the Sollang-written
compiler completes the measured 60/60 self-hosting roadmap, emits LLVM, and
builds native Windows and Linux programs while remaining differential-tested
against the C# bootstrap compiler.

The four meanings are not ranked. A design that satisfies only one of them is
unfinished; the goal is code that is bright, harmonious, useful, and distinctly
the creator's own.
