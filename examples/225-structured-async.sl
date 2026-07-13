square value: Int -> async Int {
    value * value
}

main {
    6 -> square => first
    7 -> square => second
    first -> await => firstValue
    second -> await => secondValue
    "$(firstValue)" -> println
    "$(secondValue)" -> println
}
