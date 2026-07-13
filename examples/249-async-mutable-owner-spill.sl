bump value: Int -> async Int {
    value + 1
}

grow value: Int -> async Int {
    [1, 2, ~] => values!
    values! -> push(3)
    value -> bump => pending
    pending -> await => next
    values! -> push(next)
    values! -> len
}

main {
    5 -> grow => task
    task -> await => count
    "count=$count" -> println
}
