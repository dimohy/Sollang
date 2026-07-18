boxUnlessThree value: Int -> Result<box Int, Text> => when {
    value == 3 => Result<box Int, Text>.Err("owned partials cleaned")
    else => Result<box Int, Text>.Ok(box value)
}

main {
    [1, 2, 3, 4, 5, 6, 7, 8, ~] -> tryParallel value {
        value -> boxUnlessThree
    } => result
    result -> when {
        Ok(values) => "unexpected"
        Err(error) => error
    } -> println
}
