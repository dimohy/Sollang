import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        ping: -> Int => 0
        main {
            ping
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
