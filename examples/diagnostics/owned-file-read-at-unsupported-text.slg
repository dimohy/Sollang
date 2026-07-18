import sys.file as file

main {
    file.openRead("missing.bin") => opened
    opened -> when {
        Result<file.File, Text>.Ok(reader) {
            reader -> readAt<Text>(0) => value
            0
        }
        Result<file.File, Text>.Err(error) => 0
    }
}
