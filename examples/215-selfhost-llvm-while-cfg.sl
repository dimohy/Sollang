import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        spin: -> Unit {
            true -> while {
                "tick" -> println
            }
        }

        wait enabled: Bool -> Unit {
            enabled -> while {
                "waiting" -> println
            }
        }

        nested enabled: Bool -> Unit {
            enabled -> if {
                false -> while {
                    "wrong-nested" -> println
                }
            } else {
                "wrong-else" -> println
            }
        }

        main {
            nested(true)
            wait(false)
            false -> while {
                "wrong" -> println
            }
            "done" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
