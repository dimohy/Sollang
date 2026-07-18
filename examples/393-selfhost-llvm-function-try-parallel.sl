import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        succeed value: Int -> Result<Int, Text> => Result<Int, Text>.Ok(value * 3)

        transform values: [Int; ~] -> Result<[Int; ~], Text> {
            values -> tryParallel value {
                value -> succeed
            }
        }

        main {
            [1, 2, ~] -> transform => result
            result -> when {
                Ok(values) => values[0] + values[1] == 9 -> if { "function" } else { "unexpected" }
                Err(error) => error
            } -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
