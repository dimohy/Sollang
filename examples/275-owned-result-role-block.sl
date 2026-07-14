collect seed: Int -> [Int; ~] block item: Int {
    [Int; 2~] => values!
    seed -> yield
    values! -> push(seed)
    values!
}

main {
    3 -> collect item {
        "item=$item" -> println
    } => values!

    values! -> push(4)
    values! -> fold 0 total, value {
        total + value
    } => total
    "total=$total" -> println
}
