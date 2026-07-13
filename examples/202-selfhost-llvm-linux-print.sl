import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        main {
            "hello" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emitLinux
}
