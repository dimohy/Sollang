import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        makeDictionary: -> {Int: [Int; ~]} => {
            1: [30, ~],
            2: [40, 41, ~]
        }

        consume value: move [Int; ~] -> UIntSize => value -> len

        main {
            makeDictionary => indexed!
            indexed! -> take(2) => selected!
            selected! -> consume => selectedLength
            indexed! -> len => remainingIndexed

            (selectedLength == 2 and remainingIndexed == 1) -> if {
                "owned dictionary take" -> println
            }
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emitLinux
}
