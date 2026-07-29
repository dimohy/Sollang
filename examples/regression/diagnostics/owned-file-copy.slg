import sys.file as file

main {
    file.openRead("missing.bin") => opened
    opened -> when {
        Result<file.File, Text>.Ok(reader) {
            reader => copied
            0
        }
        Result<file.File, Text>.Err(error) => 0
    }
}
