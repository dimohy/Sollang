import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        make: -> [Int; ~] => [1, 2, ~]
        forward values: move [Int; ~] -> [Int; ~] => values
        first values: [Int; ~] -> Int => values![0]
        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
