# Managed generic borrowed-wrapper context

State: open. The accumulated updated-compiler integration is pending.

The existing managed DLL rejects the two minimal probes with unknown type T
while generic inference falls through to ParseType without a binding context.
The retained interactive observation (tool output chunk 215265, before this
evidence directory was created) reports the readonly failure at 8:27 and the
explicit-reference failure at 7:29. The observed stack is ParseType(inner T)
through ParseType(wrapper), InferGenericArgumentsFromTypeTemplate,
InferGenericArgument and ResolveGenericFlowSpecialization. This paragraph is an
observation excerpt, not a reconstructed raw CLI log or a new compiler run.

The durable focused-run.log independently verifies the underlying baseline
failures against the same real DLL: baseline-readonly-loses-T and
baseline-reference-loses-T both require its unknown-type-T diagnostic. These
are expected rejection assertions, so the encompassing probe exits zero.

The current extracted production wrapper/specialization methods, existing real
type parser and reference-place validator pass 21/21 assertions. The existing
selfhost candidate supplies 2/2 valid generic wrapper shapes. Its structural
specializeManyInto recursion already supports those shapes; this is not an
executed end-to-end generic call or evidence of fresh compiler integration.

Named owners in fixtures 1719/1720 are positive borrowed calls. The literal in
generic-explicit-reference.slg remains a negative reference-place case: after
generic resolution it must be rejected as non-addressable, not accepted.

The production fix restores readonly/ref element inference in both consumers
and routes specialization through the existing generic-environment-aware
ParseAssociatedType/ParseType authority. No duplicated type parser is added.
Expected native outputs 2/2 and 42/text have not yet been executed using the
updated compiler. Stage2/Stage3 remain deferred until accumulated final checks.
