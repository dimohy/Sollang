import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        main {
            "a\b" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
