import sys.file as file

valueOrZero result: Result<Option<UInt16>, Text> -> Int => result -> when {
    Result<Option<UInt16>, Text>.Ok(option) => option -> when {
        Option<UInt16>.Some(value) => Int(value)
        Option<UInt16>.None => 0
    }
    Result<Option<UInt16>, Text>.Err(error) => 0
}

main {
    "artifacts/example-tests/263-owned-offset-file.bin" -> file.openWriter
    UInt16(513) -> file.write
    true -> file.write
    UInt16(1027) -> file.write
    file.closeWriter

    file.openRead("artifacts/example-tests/263-owned-offset-file.bin") => opened
    opened -> when {
        Result<file.File, Text>.Ok(reader) {
            reader -> readAt<UInt16>(0) -> valueOrZero => syncFirst
            reader -> readAtAsync<UInt16>(0) => cancelledTask
            cancelledTask -> cancel
            reader -> readAtAsync<UInt16>(3) => thirdTask
            reader -> readAtAsync<UInt16>(0) => firstTask
            thirdTask -> await -> valueOrZero => third
            firstTask -> await -> valueOrZero => first
            syncFirst + first + third == 2053 -> if {
                "sum=2053"
            } else {
                "unexpected"
            }
        }
        Result<file.File, Text>.Err(error) => error
    } -> println
}
