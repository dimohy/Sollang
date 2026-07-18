struct Bundle {
    values: [Int; ~]
    scores: {Int: Int}
    marker: box Int
}

adjust value: Int -> async Int {
    value + 1
}

inspect value: Int -> async Int {
    Bundle {
        values: [value, value + 2, value + 4, ~]
        scores: { 1: 10, 2: 20 }
        marker: box 99
    } => saved
    value -> adjust => pending
    pending -> await => adjusted
    (saved.values -> len) + saved.scores[2] + adjusted
}

main {
    5 -> inspect => task
    task -> await => result
    "result=$result" -> println
}
