adjust value: Int -> async Int {
    value * 10 + 1
}

main {
    3 -> adjust => first
    7 -> adjust => second

    # Awaiting the later task first drives every earlier ready task safely.
    second -> await => secondValue
    first -> await => firstValue

    "$(secondValue),$(firstValue)" -> println
}
