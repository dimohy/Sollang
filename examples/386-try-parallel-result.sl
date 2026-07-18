doubleUnlessThree value: Int -> Result<Int, Text> => when {
    value == 3 => Result<Int, Text>.Err("three")
    else => Result<Int, Text>.Ok(value * 2)
}

main {
    [Int; ~] => empty!
    empty! -> tryParallel value {
        value -> doubleUnlessThree
    } => emptyResult
    emptyResult -> when {
        Ok(values) => (values -> len) == 0 -> if { "empty" } else { "unexpected" }
        Err(error) => error
    } -> println

    [1, 2, 4, ~] -> tryParallel value {
        value -> doubleUnlessThree
    } => succeeded
    succeeded -> when {
        Ok(values) {
            values[0] + values[1] + values[2] == 14 -> if {
                "success"
            } else {
                "unexpected"
            }
        }
        Err(error) => error
    } -> println

    [1, 3, 4, ~] -> tryParallel value {
        value -> doubleUnlessThree
    } => failed
    failed -> when {
        Ok(values) => "unexpected"
        Err(error) => error
    } -> println
}
