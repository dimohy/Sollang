import smalllang.compiler.semantic.calls as calls
import smalllang.compiler.semantic.type_check as typeCheck

main {
    [
        """
        fixedLength<N: Int, T> values: [T; N] -> UIntSize {
            values -> len
        }

        first<N: Int, T> values: [T; N] -> T {
            values[0]
        }

        main {
            ["lexer", "parser", "llvm"] => stages
            [10, 20] => points
            stages -> fixedLength<3> => stageCount
            points -> fixedLength<2> => pointCount
            stages -> first<3> => firstStage
            points -> first<2> => firstPoint
            stages -> fixedLength<4> => rejectedCount
        }
        """,
        ~
    ] => sources!
    sources![0] -> calls.resolve => resolvedCalls!
    sources! -> typeCheck.analyze => errors!
    0 => resolvedCount!
    resolvedCalls! -> each call {
        call.status == 0 -> if {
            resolvedCount! + 1 => resolvedCount!
        }
    }
    "fixed-array generic calls = $(resolvedCount!)" -> println
    "fixed-array length rejections = $(errors! -> len)" -> println
}
