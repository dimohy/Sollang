import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        scan source: Text -> UIntSize {
            UIntSize(0) => index!
            (index! < (source -> len) and (source -> byte(index!)) != UInt8(46)) -> while {
                index! + UIntSize(1) => index!
            }
            index!
        }

        main { }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
