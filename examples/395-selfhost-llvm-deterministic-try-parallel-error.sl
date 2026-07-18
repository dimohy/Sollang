import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        attempt value: Int -> Result<Int, Text> uses Console {
            "$value" -> println
            value == 3 -> if {
                Result<Int, Text>.Err("three")
            } else {
                value == 6 -> if {
                    Result<Int, Text>.Err("six")
                } else {
                    Result<Int, Text>.Ok(value * 10)
                }
            }
        }

        main {
            [1, 2, 3, 4, 5, 6, 7, 8, ~] -> tryParallel value {
                value -> attempt
            } => result
            result -> when {
                Ok(values) => "unexpected"
                Err(error) => error
            } -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
