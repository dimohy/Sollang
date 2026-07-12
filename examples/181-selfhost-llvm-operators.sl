import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        calculate: -> Int => 1 + 2 * 3
        positive: -> Bool => 3 > 1
        invert: -> Bool => not false
        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
