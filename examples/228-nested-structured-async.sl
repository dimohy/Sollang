square value: Int -> async Int {
    value * value
}

outer value: Int -> async Int {
    value -> square => child
    child -> await
}

main {
    9 -> outer => task
    task -> await => result
    "$(result)" -> println
}
