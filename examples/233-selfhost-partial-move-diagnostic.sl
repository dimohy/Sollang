import smalllang.compiler.semantic.ownership_check as ownershipCheck

main {
    [
        """
        struct Pair {
            left: [Int; ~]
            right: [Int; ~]
        }

        invalid flag: Bool -> Int {
            Pair {
                left: [1, ~]
                right: [2, ~]
            } => pair!
            pair!.left => left!
            pair!.right => right!
            pair! => whole
            0
        }

        main {
        }
        """,
        ~
    ] => sources!
    sources! -> ownershipCheck.analyze => errors!
    errors! -> each error {
        error.code == 17 -> if {
            "partial move error = $(error.code),$(error.span.fileId),$(error.span.length)" -> println
        }
    }
}
