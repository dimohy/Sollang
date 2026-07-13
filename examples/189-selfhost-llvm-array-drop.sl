import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        discard: -> Int {
            [1, 2, ~]
            0
        }
        consume values: move [Int; ~] -> Int => 0
        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
