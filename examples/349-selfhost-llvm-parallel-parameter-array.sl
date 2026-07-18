import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        incrementOne value: Int -> Int {
            value + 1
        }

        increment values: [Int; ~] -> [Int; ~] {
            incrementWithOffset value: Int -> Int {
                value + values![0]
            }
            values -> parallel value {
                value -> incrementWithOffset
            }
        }

        main {
            0 => iteration!
            iteration! < 100 -> while {
                [1, 2, 3, 4, ~] -> increment => values!
                iteration! + 1 => iteration!
            }
            "parallel done" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
