import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        child value: Int -> async Int {
            value + 1
        }

        accumulate count: Int -> async Int {
            0 => index!
            0 => total!
            index! < count -> while {
                index! -> child => firstTask
                index! + 10 -> child => secondTask
                firstTask -> await => first
                secondTask -> await => second
                total! + first + second => total!
                index! + 1 => index!
            }
            total!
        }

        main { }
        """,
        ~
    ] => sources!

    sources! -> typedIr.suspensions => points!
    sources! -> typedIr.frameSlots => slots!
    0 => stateTotal!
    points! -> each point {
        stateTotal! + point.state => stateTotal!
    }
    "loopSuspensions=$(points! -> len),stateTotal=$(stateTotal!),slots=$(slots! -> len)" -> println
}
