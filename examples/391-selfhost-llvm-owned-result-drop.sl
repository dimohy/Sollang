import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        main {
            Result<[Int; ~], Text>.Ok([1, 2, 3, ~]) => result!
            Result<[Int; ~], Text>.Err("inactive payload") => failed!
            "owned result constructed" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
