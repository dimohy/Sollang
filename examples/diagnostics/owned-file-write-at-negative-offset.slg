import sys.file as file

main {
    file.openWrite("artifacts/example-tests/negative-write.bin") => opened
    opened -> when {
        Result<file.FileWriter, Text>.Ok(writer) {
            writer -> writeAt(UInt16(1), -1)
        }
        Result<file.FileWriter, Text>.Err(error) => error
    }
}
