import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        namespace app.main
        import stage2.answer as answer
        main {
            answer.value -> println
        }
        """,
        """
        namespace stage2.answer
        public value: -> Int => 42
        """,
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    ir! -> each node {
        (node.sourceModule == 0 and node.kind == 6) -> if {
            "call=$(node.symbol),module=$(node.targetModule),arg=$(node.operand0)" -> println
        }
    }
}
