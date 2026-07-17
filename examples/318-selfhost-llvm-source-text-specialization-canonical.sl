import smalllang.compiler.llvm.text as llvm

main {
    [
        """
        import sys.file as file

        scan inputs: [file.SourceText; ~] -> UIntSize {
            [file.SourceText; ~] => owners!
            0 => inputIndex!
            inputIndex! < (inputs -> len) -> while {
                inputs[inputIndex!] => owner
                owners! -> push(owner)
                inputIndex! + 1 => inputIndex!
            }
            UIntSize(0) => total!
            0 => index!
            index! < (owners -> len) -> while {
                owners[index!] => owner
                owner -> len => sourceLength
                total! + sourceLength => total!
                index! + 1 => index!
            }
            total!
        }

        main { }
        """,
        """
        namespace sys.file

        public struct File {
            token: UInt64
        }

        public struct FileWriter {
            token: UInt64
        }

        public struct SourceText {
            token: UInt64
        }
        """,
        ~
    ] => sources!
    sources! -> llvm.emit
}
