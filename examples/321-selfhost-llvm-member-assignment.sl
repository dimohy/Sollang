import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        struct Node {
            operand0: Int
        }

        select: -> Int {
            Node { operand0: -1 } => node!
            true -> if {
                3 => node!.operand0
            }
            node!.operand0
        }

        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
