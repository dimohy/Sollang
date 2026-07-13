import sys.file as file

describeUInt16 result: Result<Option<UInt16>, Text> -> Text {
    result -> when {
        Result<Option<UInt16>, Text>.Ok(option) => option -> when {
            Option<UInt16>.Some(value) => value == UInt16(513) -> if {
                "513"
            } else {
                "unexpected"
            }
            Option<UInt16>.None => "eof"
        }
        Result<Option<UInt16>, Text>.Err(error) => error
    }
}

describeBool result: Result<Option<Bool>, Text> -> Text {
    result -> when {
        Result<Option<Bool>, Text>.Ok(option) => option -> when {
            Option<Bool>.Some(value) => value -> if {
                "true"
            } else {
                "false"
            }
            Option<Bool>.None => "eof"
        }
        Result<Option<Bool>, Text>.Err(error) => error
    }
}

readFirst: -> async Result<Option<UInt16>, Text> {
    file.readAsync<UInt16> => pending
    pending -> await => result
    result
}

main {
    "artifacts/example-tests/261-async-file-readiness.bin" -> file.openWriter
    UInt16(513) -> file.write
    true -> file.write
    file.closeWriter

    "artifacts/example-tests/261-async-file-readiness.bin" -> file.openReader
    file.readAsync<UInt16> => cancelled
    cancelled -> cancel
    file.readAsync<UInt16> => first
    file.readAsync<Bool> => second
    file.readAsync<UInt16> => eof
    1 -> milliseconds -> sleep => timer

    timer -> await
    second -> await -> describeBool => secondText
    first -> await -> describeUInt16 => firstText
    eof -> await -> describeUInt16 => eofText
    file.closeReader

    "artifacts/example-tests/261-async-file-readiness.bin" -> file.openReader
    readFirst => parent
    parent -> await -> describeUInt16 => parentText
    file.closeReader

    "first=$firstText,second=$secondText,eof=$eofText,parent=$parentText,cancelled=true" -> println
}
