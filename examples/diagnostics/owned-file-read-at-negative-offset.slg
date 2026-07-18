import sys.file as file

main {
    file.openRead("missing.bin") => opened
    opened -> when {
        Result<file.File, Text>.Ok(reader) {
            reader -> readAt<UInt16>(-1) => value
            0
        }
        Result<file.File, Text>.Err(error) => 0
    }
}
