import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        main {
            [1, 2, ~] => values!
            9 => values![0]
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
