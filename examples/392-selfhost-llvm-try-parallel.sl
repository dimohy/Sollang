import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        succeed value: Int -> Result<Int, Text> {
            "work=$value" -> println
            Result<Int, Text>.Ok(value * 2)
        }

        fail value: Int -> Result<Int, Text> => Result<Int, Text>.Err("bad")

        main {
            [1, 2, ~] -> tryParallel value {
                value -> succeed
            } => succeeded
            succeeded -> when {
                Ok(values) => values[0] + values[1] == 6 -> if { "success" } else { "unexpected" }
                Err(error) => error
            } -> println
            [3, 4, ~] -> tryParallel value {
                value -> fail
            } => failed
            failed -> when {
                Ok(values) => "unexpected"
                Err(error) => error
            } -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
