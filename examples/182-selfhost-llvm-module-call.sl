import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        namespace sample.math
        public double value: Int -> Int => value + value
        """,
        """
        namespace app.main
        import sample.math as math
        calculate: -> Int => math.double(21)
        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
