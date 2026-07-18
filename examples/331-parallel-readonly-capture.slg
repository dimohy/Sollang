shift base: Int -> [Int; ~] {
    addBase value: Int -> Int {
        value + base
    }

    [1, 2, 3, 4, ~] => values!
    values! -> parallel value {
        value -> addBase
    } => shifted!
    shifted!
}

main {
    10 -> shift => shifted!
    shifted! -> each value {
        "$value" -> println
    }
}
