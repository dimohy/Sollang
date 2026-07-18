import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        import sys.file as file

        struct Scan {
            bytes: [UInt8; ~]
        }

        scan source: file.SourceText -> Scan {
            [UInt8; ~] => bytes!
            UIntSize(0) => index!
            index! < (source -> len) -> while {
                bytes! -> push(source -> byte(index!))
                index! + UIntSize(1) => index!
            }
            Scan { bytes: bytes! }
        }

        scanAll sources: move [file.SourceText; ~] -> [Scan; ~] {
            sources -> parallel source {
                source -> scan
            }
        }

        main {
            0 => iteration!
            iteration! < 100 -> while {
                [file.SourceText; ~] => sources!
                "lexer" -> file.borrowText => lexer!
                sources! -> push(lexer!)
                "semantic" -> file.borrowText => semantic!
                sources! -> push(semantic!)
                sources! -> scanAll => scans!
                iteration! + 1 => iteration!
            }
            "source worker transfer done" -> println
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
