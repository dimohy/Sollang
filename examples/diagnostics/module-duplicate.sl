import duplicate.module as duplicated

main {
    1 -> duplicated.value => result
    "$result" -> println
}
