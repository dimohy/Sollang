import sys.file as file

writeSucceeded result: Result<Unit, Text> -> Bool => result -> when {
    Ok(done) => true
    Err(error) => false
}

valueOrZero result: Result<Option<UInt16>, Text> -> Int => result -> when {
    Ok(option) => option -> when {
        Some(value) => Int(value)
        None => 0
    }
    Err(error) => 0
}

boolOrFalse result: Result<Option<Bool>, Text> -> Bool => result -> when {
    Ok(option) => option -> when {
        Some(value) => value
        None => false
    }
    Err(error) => false
}

writeFixture path: Text -> Bool {
    file.openWrite(path) => openedWriter
    openedWriter -> when {
        Ok(writer) {
            writer -> writeAt(UInt16(1027), 3) -> writeSucceeded => thirdOk
            writer -> writeAt(true, 2) -> writeSucceeded => boolOk
            writer -> writeAt<UInt16>(513, 0) -> writeSucceeded => firstOk
            firstOk and boolOk and thirdOk
        }
        Err(error) => false
    }
}

main {
    "artifacts/example-tests/265-owned-offset-writer.bin" -> writeFixture => writesOk
    file.openRead("artifacts/example-tests/265-owned-offset-writer.bin") => openedReader
    openedReader -> when {
        Ok(reader) {
            reader -> readAt<UInt16>(0) -> valueOrZero => first
            reader -> readAt<Bool>(2) -> boolOrFalse => middle
            reader -> readAt<UInt16>(3) -> valueOrZero => third
            writesOk and middle and first + third == 1540 -> if {
                "writeAt sum=1540"
            } else {
                "unexpected"
            }
        }
        Err(error) => error
    } -> println
}
