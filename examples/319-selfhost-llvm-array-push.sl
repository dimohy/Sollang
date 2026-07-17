import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        collect: -> [Text; ~] {
            [Text; ~] => values!
            values! -> push("hello")
            values!
        }

        main {
            collect => values
            values -> len => count
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
