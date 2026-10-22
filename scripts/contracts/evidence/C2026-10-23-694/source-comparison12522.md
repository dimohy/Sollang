# C693 / C694 source comparison checkpoint

This checkpoint changes no compiler implementation and claims no candidate fix.
The original failing native programs were not executed again.

## C693: finite fused range iteration

The unchanged three-program managed cohort passed before SLG changes. The
native ordinary range control passed; the maximum-inclusive map case compiled
successfully and exceeded its original 3000 ms runtime budget. Its execution
record confirms process shutdown. The original native cohort result sealed two
cases before the timeout exception escaped. That original result remains failed
and is not rewritten into a completed three-case result.

`LlvmEmitter.Statements.cs:1702` (`EmitRangeEachBlockFunctionCall`) compares the
current item with the endpoint at continuation, before selecting the next loop
iteration. Although its next-value calculation uses i32, the wrapped value is
never selected after the final endpoint. The actual managed probe LLVM confirms
this path: `each_done12 = icmp sge i32 %item8, %range_end5` branches to the exit.
Thus width alone is not the C# invariant and a wider cursor is not assumed to be
the required repair.

`LlvmEmitter.RuntimeHelpers.cs:91` independently marks a range producer finished
after yielding its last item, before taking the increment path. Both paths
implement the finite inclusive-end rule in `docs/SPEC.md:1122`.

`entry_expressions.slg:1067` checks the loaded outer cursor against the endpoint.
Its continuation near 3779/3785 stores the incremented i32 value and returns to
that header without a last-item termination decision. The flatMap inner path
near 1150/3759 has the analogous pattern. Full inner/outer effect ordering,
exclusive bounds, take/skip and beforeEach/afterEach must be compared before
implementing a shared endpoint decision. No synthetic input restriction or
shorter range replaces the original failing source.

## C694: unsigned integer display

`LlvmEmitter.Expressions.Core.cs:218` (`EmitWriteIntegerValue`) extends integers
below 64 bits using their signedness, and selects the signed or unsigned writer.
Direct display and interpolation both reach this operation through
`EmitWriteValue`. UInt32 maximum therefore remains 4294967295 in both forms.

`entry_expressions.slg:2577` only extends nonliteral integers narrower than 32
bits, then selects the signed i32 print entry point for width32. The actual
native probe consequently prints -1 directly and 4294967295 in interpolation.
`ownership.slg:3282` classifies UInt32 as width32 and unsigned; that classification
does not justify signed output. `control_region_expressions.slg:2353` contains
the analogous numeric print selection and needs corresponding controls before
repair. The function expression emitter contains no direct print_i32/i64 call;
its actual dispatch path still needs bounded source tracing.

## Next bounded work

Reuse the passed original C# cohort with its unchanged compiler/stdlib/input
hashes. Add ordinary C# controls for exclusive bounds, flatMap inner endpoints,
and UInt32 display in function/control/reference contexts. Finish corresponding
source comparison, then repair SLG and run the original sources plus related
controls. Preserve diagnostics, expected outputs, budgets and final gates.

No security setting, guardrail or required verification is disabled. The visible
account warning alone does not establish which operation triggered it, and this
checkpoint does not claim that a later warning is impossible.
