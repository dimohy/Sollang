import smalllang.compiler.semantic.ownership_check as ownershipCheck

main {
    [
        """
        main {
            10 => offset!
            [1, 2, 3, ~] => values!
            values! -> parallel value {
                value + offset!
            } => shifted!
        }
        """,
        """
        inspect memory: Arena -> [Int; ~] {
            [1, 2, 3, ~] => values!
            values! -> parallel value {
                value + Int(memory -> used)
            } => shifted!
            shifted!
        }

        main {
        }
        """,
        """
        main {
            10 => offset
            [1, 2, 3, ~] => values!
            values! -> parallel value {
                value + offset
            } => shifted!
        }
        """,
        ~
    ] => sources!

    sources! -> each source {
        [source, ~] => unit!
        unit! -> ownershipCheck.analyze => errors!
        errors! -> each error {
            (error.code == 18 or error.code == 19) -> if {
                "parallel capture error=$(error.code)" -> println
            }
        }
    }
}
