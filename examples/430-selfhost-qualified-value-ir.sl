import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        namespace sample.constants
        public answer: -> Int => 42
        """,
        """
        namespace app.main
        import sample.constants as constants
        matches: -> Bool => constants.answer == 42
        main { }
        """,
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    ir! -> each node {
        (node.sourceModule == 1 and (node.kind == 6 or node.kind == 8)) -> if {
            "qualified value ir = $(node.kind),$(node.targetModule),$(node.symbol),$(node.typeSymbol)" -> println
        }
    }
}
