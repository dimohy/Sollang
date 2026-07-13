import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        child value: Int -> async Int {
            value + 1
        }

        parent value: Int -> async Int {
            value -> child => pending
            pending -> await
        }

        main { }
        """,
        ~
    ] => sources!

    sources! -> typedIr.suspensions => points!
    "suspensions=$(points! -> len),state=$(points![0].state)" -> println
}
