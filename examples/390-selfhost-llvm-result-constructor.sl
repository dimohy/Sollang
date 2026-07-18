import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        succeed value: Int -> Result<Int, Text> => Result<Int, Text>.Ok(value)

        main {
            7 -> succeed => success
            Result<Int, Text>.Err("bad") => failure
            "result constructors" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
