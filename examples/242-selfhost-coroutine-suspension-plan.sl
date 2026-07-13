import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        child value: Int -> async Int {
            value + 1
        }

        parent value: Int -> async Int {
            value * 2 => base
            [1, 2, 3, ~] => values!
            value -> child => firstTask
            firstTask -> await => first
            first -> child => secondTask
            secondTask -> await => second
            base + second + (values! -> len)
        }

        main { }
        """,
        ~
    ] => sources!

    sources! -> typedIr.suspensions => points!
    sources! -> typedIr.frameSlots => slots!
    "suspensions=$(points! -> len),states=$(points![0].state)/$(points![1].state),slots=$(slots! -> len),ownedFlags=$(slots![1].flags)/$(slots![3].flags)" -> println
}
