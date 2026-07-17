import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        struct Request {
            nameRoot: Int
        }

        show request: Request -> Unit uses Console {
            "$(request.nameRoot)" -> println
        }

        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
