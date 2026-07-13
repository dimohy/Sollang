import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        report value: Int -> Unit {
            value + 1 => next
            "$value->$next->$value" -> println
        }

        main {
            report(-7)
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
