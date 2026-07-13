import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.semantic.calls as calls

main {
    [
        """
        namespace sys.file

        public struct File {
            token: UInt64
        }

        public struct FileWriter {
            token: UInt64
        }

        public openReadAsync path: Text -> async Result<File, Text> = intrinsic
        public openWriteAsync path: Text -> async Result<FileWriter, Text> = intrinsic
        """,
        """
        namespace sample.loader

        import sys.file as file

        load path: Text -> async Unit {
            file.openReadAsync(path) => reading
            reading -> await
            file.openWriteAsync(path) => writing
            writing -> await
        }

        main { }
        """,
        ~
    ] => sources!

    sources! -> calls.resolveModules => resolved!
    sources! -> typedIr.suspensions => points!
    0 => importedCalls!
    resolved! -> each call {
        (call.sourceModule == 1 and call.origin == 1 and call.status == 0) -> if {
            importedCalls! + 1 => importedCalls!
        }
    }
    "async opens=$(importedCalls!),suspensions=$(points! -> len)" -> println
}
