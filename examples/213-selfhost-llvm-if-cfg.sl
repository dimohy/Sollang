import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        choose positive: Bool -> Int {
            positive -> if {
                7
            } else {
                9
            }
        }

        report positive: Bool -> Unit {
            positive -> if {
                "then" -> println
            } else {
                "else" -> println
            }
        }

        main {
            report(false)
            true -> if {
                "main-then" -> println
            } else {
                "main-else" -> println
            }
            choose(false) => value
            "value=$value" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
