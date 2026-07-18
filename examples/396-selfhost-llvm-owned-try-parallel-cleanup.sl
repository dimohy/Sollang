import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        makeOwned value: Int -> [Int; ~] => [value, value * 10, ~]

        ownUnlessThree value: Int -> Result<[Int; ~], Text> {
            value == 3 -> if {
                Result<[Int; ~], Text>.Err("owned partials cleaned")
            } else {
                value -> makeOwned => payload!
                Result<[Int; ~], Text>.Ok(payload!)
            }
        }

        main {
            [1, 2, 3, 4, 5, 6, 7, 8, ~] -> tryParallel value {
                value -> ownUnlessThree
            } => result
            result -> when {
                Ok(values) => "unexpected"
                Err(error) => error
            } -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emitLinux
}
