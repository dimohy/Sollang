mapPlusOne value: Int -> Int block item: Int -> Int {
    value -> yield => mapped
    mapped + 1
}

main {
    5 -> mapPlusOne item {
        item * 2
    } => result
    "$(result)" -> println
}
