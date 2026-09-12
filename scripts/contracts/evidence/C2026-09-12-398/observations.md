# Fixed Text owner to readonly view

State: open. Source fix, isolated production-method checks and updated managed
compiler fixture1719 are complete; final accumulated Stage2/Stage3 are pending.

Managed compiler SHA256
5AB9600547E2A3C3C4E88D76895C67DEDF212B6B404B49376E45FC8E5948BB71
already resolves C395's generic context and C396's delimiters. Its actual
fixture1719 run nevertheless fails during code generation with
`readonly array view requires an array value`. The fixed Text owner has runtime
representation RuntimeStaticTextArray, absent from CreateRuntimeSlice's switch.
That switch already supports generic inline arrays and views; Int has its own
specialized path. Existing array-phi and fixed-array-call consumers recognize
RuntimeStaticTextArray as Text elements, confirming the missing conversion case.

The fixture's fixed Text array follows the S003 recommendation encountered in
the prior growable version. The Int owner remains growable, preserving both
borrowed input shapes without ignoring warnings or adding a heap workaround.

The repair adds one switch arm that forwards the existing pointer and length
with Text element identity to the existing RuntimeInlineSlice representation.
It does not emit a copy, payload allocation, conversion, or owner mutation.

The current CreateRuntimeSlice and runtime value records are extracted into the
existing generic-context probe project. Slice element queries use the real
loaded compiler type table. Eight assertions preserve pointer/length identity
for heap, stack, empty, generic inline, growable and existing-view inputs, and
retain wrong-element/non-array rejection. The untouched IntSlice branch is
explicitly outside this Text-only extraction rather than simulated as passing.

Separately, actual managed source execution passed 6/6 selected cases in
61ca736994434714a694f9e0bb2fb1d9: fixture1720 prints 42/text, three C396 minimal
signature probes compile/run with output 0, and literal-reference/direct-nested
container negatives fail semantically before LLVM. All four positive outputs
pass LLVM assembly and direct-call closure. Those checks do not close C398.

All preserved run files are exact copies. No compiler rebuild was performed by
this focused task; the root agent owns the combined subsequent compiler build.

## Actual managed integration delta

After the root's combined incremental host build, compiler SHA256
21906EAB6B391472FB88195E35E2675645D09F500FBD197534EE2BB929ADAD9E
passed only the remaining fixture1719: exact stdout 2/2, exit zero, warning-free
LLVM assembly and direct-call closure. Its current-managed-result.json and the
three current logs are preserved separately from the prior 6/6 run. The earlier
six cases were not repeated, and this is not a claim that all seven ran under
the new DLL or that Stage2/Stage3 ran.

The original result's selectedIds contains a trailing null because the verifier
projected .id from the empty negative selection. The actual cases array contains
exactly one entry, 1719, and completed/total is 1/1. The original bytes are kept;
managed-execution-split.json indexes actual case entries rather than treating
that incidental null as a selected or executed case.

## Ordinary direct-call coverage expansion

The initial one-switch repair above did not cover two additional consumers.
CSV Writer's ordinary helper exposed duplicated array classification in
EnsureFunctionArgumentRuntimeType and BuildReadonlySliceArgument. On compiler
493C510EC06ED20F500B81D18D7746E6D1101606E205477B331E0B7C1D324A10,
reachable ordinary first and additional fixed Text array arguments both fail
with `expects Slice<builtin:Text> ... but received FixedArray<builtin:Text,2>`.
The original generic1719 success remains valid but is not direct-call proof.

The root repair replaces all three duplicate classifications with the same
seven-shape TryGetRuntimeArrayView helper. Current production extraction runs
all three consumers and the actual slice serializer, using the existing DLL's
type table and stable type identity. Six Text descriptor cases preserve their
pointer/length through validation, conversion and exactly two LLVM insertvalue
instructions. Wrong-element/non-array rejection is checked at all three
consumers; three Int descriptor checks cover existing specialized shapes.
All eleven checks and the existing generic21 checks pass. Full IntSlice
conversion is deliberately outside this Text-focused test.

direct-call-delta.json preserves the split between actual old-DLL failures and
current source-extraction success. A new host build and exact two-case execution
remain pending; no full compiler build or Stage2/Stage3 ran in this subtask.

## Actual ordinary-call delta

Root-built compiler
0A244A540E13825F42056E25F41C315A644CDBA5FC38CCAA3440E358F280EFDD
passed only the two ordinary-call probes in run
64d97fbf53a04157a18366ef0ca368c2. First and additional arguments print exactly
2 and 5, respectively, with no warning. Both generated modules assemble and
pass direct-call closure. Compiler, source, LLVM and executable hashes are
preserved in direct-call-current-result.json, with per-case logs. The shared
classifier/consumer extraction remains 11/11 and generic checks remain 21/21.

An intervening C076 compiler failed before either code-generation path at a
common std.uri semantic guard; that observation is not a new C398 codegen
failure. After the separate enum-match origin repair, the above actual delta
passes. Initial1719, earlier six-case verification and this two-case delta
remain distinct observations. The defect stays open for final accumulated
Stage2/Stage3 and required-target checks.
