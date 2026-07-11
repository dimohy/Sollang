identityFirst<T, U> value: T -> T {
    value
}

main {
    42 -> identityFirst => result
    "$result" -> println
}
