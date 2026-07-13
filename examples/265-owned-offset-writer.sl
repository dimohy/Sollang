import sys.file as file

writeSucceeded result: Result<Unit, Text> -> Bool => result -> when {
    Result<Unit, Text>.Ok(done) => true
    Result<Unit, Text>.Err(error) => false
}

valueOrZero result: Result<Option<UInt16>, Text> -> Int => result -> when {
    Result<Option<UInt16>, Text>.Ok(option) => option -> when {
        Option<UInt16>.Some(value) => Int(value)
        Option<UInt16>.None => 0
    }
    Result<Option<UInt16>, Text>.Err(error) => 0
}

boolOrFalse result: Result<Option<Bool>, Text> -> Bool => result -> when {
    Result<Option<Bool>, Text>.Ok(option) => option -> when {
        Option<Bool>.Some(value) => value
        Option<Bool>.None => false
    }
    Result<Option<Bool>, Text>.Err(error) => false
}

writeFixture path: Text -> Bool {
    file.openWrite(path) => openedWriter
    openedWriter -> when {
        Result<file.FileWriter, Text>.Ok(writer) {
            writer -> writeAt(UInt16(1027), 3) -> writeSucceeded => thirdOk
            writer -> writeAt(true, 2) -> writeSucceeded => boolOk
            writer -> writeAt<UInt16>(513, 0) -> writeSucceeded => firstOk
            firstOk and boolOk and thirdOk
        }
        Result<file.FileWriter, Text>.Err(error) => false
    }
}

main {
    "artifacts/example-tests/265-owned-offset-writer.bin" -> writeFixture => writesOk
    file.openRead("artifacts/example-tests/265-owned-offset-writer.bin") => openedReader
    openedReader -> when {
        Result<file.File, Text>.Ok(reader) {
            reader -> readAt<UInt16>(0) -> valueOrZero => first
            reader -> readAt<Bool>(2) -> boolOrFalse => middle
            reader -> readAt<UInt16>(3) -> valueOrZero => third
            writesOk and middle and first + third == 1540 -> if {
                "writeAt sum=1540"
            } else {
                "unexpected"
            }
        }
        Result<file.File, Text>.Err(error) => error
    } -> println
}
