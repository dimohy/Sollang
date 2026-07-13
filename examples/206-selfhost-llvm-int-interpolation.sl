import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        main {
            -2147483648 => value
            "value = $value!" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
