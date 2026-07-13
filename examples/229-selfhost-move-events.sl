import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        consume values: move [Int; ~] -> Int {
            values[0]
        }

        choose flag: Bool -> Int {
            flag -> if {
                [41, ~] => values
                values -> consume => result
                result -> return
            }
            0
        }

        main {
        }
        """,
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    sources! -> typedIr.moves => events!
    events! -> len => count
    "move events = $(count)" -> println
    events![0] => event
    "move region kind = $(ir![event.regionIr].kind)" -> println
}
