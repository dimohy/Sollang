import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        succeed value: Int -> Result<Int, Text> => Result<Int, Text>.Ok(value + 5)

        main {
            true -> if {
                [1, 2, ~] -> tryParallel value {
                    value -> succeed
                } => result
                result -> when {
                    Ok(values) => values[0] + values[1] == 13 -> if { "region" } else { "unexpected" }
                    Err(error) => error
                } -> println
            }
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
