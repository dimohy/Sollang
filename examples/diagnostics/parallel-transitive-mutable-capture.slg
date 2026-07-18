shift seed: Int -> [Int; ~] {
    addOffset value: Int -> Int {
        value + offset!
    }

    10 => offset!
    [1, 2, 3, ~] => values!
    values! -> parallel value {
        value -> addOffset
    } => shifted!
    shifted!
}

main {
    0 -> shift => shifted!
}
