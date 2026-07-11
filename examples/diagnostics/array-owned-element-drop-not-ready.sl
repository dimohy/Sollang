struct Owned {
    value: box Int
}

main {
    [Owned { value: box 1 }] => values
    values -> len -> println
}
