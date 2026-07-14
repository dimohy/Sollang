import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.semantic.context as semanticContext
import smalllang.compiler.semantic.ownership_check as ownershipCheck
import smalllang.compiler.semantic.type_diagnostics as typeDiagnostics

main {
    [
        """
        struct Pair {
            left: [Int; ~]
            right: [Int; ~]
        }

        invalid flag: Bool -> Int {
            Pair {
                left: [1, ~]
                right: [2, ~]
            } => pair!
            pair!.left => left!
            pair!.right => right!
            pair! => whole
            0
        }

        child value: Int -> async Int {
            value + 1
        }

        parent value: Int -> async Int {
            value * 2 => base
            [1, 2, 3, ~] => values!
            value -> child => firstTask
            value -> child => secondTask
            firstTask -> await => first
            secondTask -> await => second
            base + first + second + (values! -> len)
        }

        main { }
        """,
        ~
    ] => sources!

    sources! -> semanticContext.prepare => prepared
    prepared -> typeDiagnostics.analyzeContext => typeErrors!
    prepared -> ownershipCheck.analyzeContext => ownershipErrors!
    prepared -> typedIr.coroutinePlanContext => plan
    "types=$(typeErrors! -> len), ownership=$(ownershipErrors! -> len), points=$(plan.points -> len), slots=$(plan.slots -> len), destroys=$(plan.destroys -> len)" -> println
}
