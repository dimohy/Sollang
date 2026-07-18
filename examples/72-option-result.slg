struct OwnedNode {
    payload: box Int
}

optionValue option: Option<Int> -> Int {
    option -> when {
        Option<Int>.None => 0
        Option<Int>.Some(value) => value
    }
}

resultText result: Result<Int, Text> -> Text {
    result -> when {
        Result<Int, Text>.Ok(value) => "ok"
        Result<Int, Text>.Err(message) => message
    }
}

main {
    Option<Int>.Some(42) -> optionValue => some
    Option<Int>.None -> optionValue => none
    Result<Int, Text>.Ok(7) -> resultText => ok
    Result<Int, Text>.Err("invalid") -> resultText => err

    Option<OwnedNode>.Some(OwnedNode { payload: box 9 }) -> when {
        Option<OwnedNode>.None => 0
        Option<OwnedNode>.Some(node) => 1
    } => ownedKind

    "option = $some, $none" -> println
    "result = $ok, $err" -> println
    "owned option = $ownedKind" -> println
}
