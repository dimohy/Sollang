import sys.file as file

operationSucceeded result: Result<Unit, Text> -> Bool => result -> when {
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

openFailed result: Result<file.File, Text> -> Bool => result -> when {
    Result<file.File, Text>.Ok(reader) => false
    Result<file.File, Text>.Err(error) => true
}

writeFixture path: Text -> async Bool {
    file.openWriteAsync(path) => opening
    opening -> await -> when {
        Result<file.FileWriter, Text>.Ok(writer) {
            writer -> writeAtAsync(UInt16(513), 0) => firstTask
            writer -> writeAtAsync(UInt16(1027), 3) => thirdTask
            firstTask -> await -> operationSucceeded => firstOk
            thirdTask -> await -> operationSucceeded => thirdOk
            writer -> syncAsync => syncing
            syncing -> await -> operationSucceeded => syncOk
            firstOk and thirdOk and syncOk
        }
        Result<file.FileWriter, Text>.Err(error) => false
    }
}

main {
    "artifacts/example-tests/270-async-owned-file-open.bin" => path
    path -> writeFixture => writing
    writing -> await => wrote

    file.openReadAsync(path) => opening
    opening -> await -> when {
        Result<file.File, Text>.Ok(reader) {
            reader -> readAt<UInt16>(0) -> valueOrZero => first
            reader -> readAt<UInt16>(3) -> valueOrZero => third
            first + third
        }
        Result<file.File, Text>.Err(error) => 0
    } => sum

    file.openReadAsync("artifacts/example-tests/270-does-not-exist.bin") => missingTask
    missingTask -> await -> openFailed => missing

    file.openReadAsync(path) => cancelledOpen
    cancelledOpen -> cancel

    wrote and sum == 1540 and missing -> if {
        "openAsync sum=1540,missing=true,cancelled=true"
    } else {
        "unexpected"
    } -> println
}
