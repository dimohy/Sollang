import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        increment value: Int -> Int {
            value + 1
        }

        main {
            [1, 2, 3, 4, ~] -> parallel value {
                value -> increment
            } => values!
            "entry role binding done" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
