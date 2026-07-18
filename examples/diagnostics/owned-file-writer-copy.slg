import sys.file as file

main {
    file.openWrite("artifacts/example-tests/owned-writer-copy.bin") => opened
    opened -> when {
        Result<file.FileWriter, Text>.Ok(writer) {
            writer => copied
            copied -> writeAt(UInt16(1), 0)
        }
        Result<file.FileWriter, Text>.Err(error) => error
    }
}
