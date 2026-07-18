attempt value: Int -> Result<Int, Text> uses Console {
    "$value" -> println
    value -> when {
        == 3 => Result<Int, Text>.Err("three")
        == 6 => Result<Int, Text>.Err("six")
        else => Result<Int, Text>.Ok(value * 10)
    }
}

main {
    [1, 2, 3, 4, 5, 6, 7, 8, ~] -> tryParallel value {
        value -> attempt
    } => result
    result -> when {
        Ok(values) => "unexpected"
        Err(error) => error
    } -> println
}
