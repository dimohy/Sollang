# Nested type delimiters

State: open. This is separate from C395's missing generic binding context.

Before production edits, cases.json froze 21 intended accepted types, nine
negative semantic/arity cases, and eight delimiter positions. SHA256:
2E39AF41FE249AEC741D191E63A24D777ADA89D7BA960F386E56E0D048F00B5A.

The existing managed DLL rejects eight of those 21 intended accepted types.
Result's success product is cut at its inner comma; a nested product's field
label is cut at an inner colon; a readonly product view is classified as a fixed
or bounded array using its field's semicolon. The duplicated product/signature
scanners also count the bounded-capacity <= operator as a generic opening angle.
The durable type-delimiters.log records real old-parser outcomes before any
candidate type aliases are added to its table.

One production scanner now handles (), [], {}, and <> depth, with <= excluded
from generic depth. Existing comma/colon and product/signature split consumers,
array/dictionary ParseType and declaration prepass classification, fixed-array
template extraction, and generic borrowed-view detection use that authority.
The readonly/fixed/bounded direct nested-container restrictions and size
diagnostics remain unchanged.

The current selected ParseType branches and ParseProductType are extracted
verbatim, with recursive ParseType references renamed only to select the probe
entry. Real type-table construction, visibility and nested-container predicates
run in the existing DLL. The unrelated dyn/numeric collection dispatch is not
included. Definition fixed/bounded array guards are separately extracted up to
ResolveDefinitionType; full declaration resolution/layout is not executed.

The core matrix plus generic nested-wrapper and two definition-guard assertions
passes 41/41. The existing generic suite passes 21/21 and selfhost generic shapes
pass 2/2. No whole compiler was rebuilt, no fresh compiled SLG output was claimed,
and the final accumulated compiler/Stage2/Stage3 integration remains pending.
Three minimal source probes pass the existing formatter/parser. Initial
standalone-function spelling was corrected before that check passed; it is not
part of the semantic baseline or an expected language behavior change.
