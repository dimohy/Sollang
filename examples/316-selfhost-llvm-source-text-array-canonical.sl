import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        import sys.file as file

        firstSource owners: [file.SourceText; ~] -> Text {
            owners[0] -> len => sourceLength
            owners[0] -> slice(UIntSize(0), sourceLength)
        }

        main { }
        """,
        """
        namespace sys.file

        public struct SourceText {
            token: UInt64
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
