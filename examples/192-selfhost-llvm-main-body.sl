import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        identity value: Int -> Int => value
        compute: -> Int {
            1 => value
            value
        }
        main {
            0 => code
            identity(code)
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
