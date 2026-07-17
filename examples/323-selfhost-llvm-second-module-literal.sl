import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        namespace app.main
        main { }
        """,
        """
        namespace stage2.answer
        public value: -> Int => 42
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
