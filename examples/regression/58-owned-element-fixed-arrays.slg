struct Owned {
    value: box Int
}

main {
    # Explicit form: [Owned { value: box 10 }, Owned { value: box 20 }]
    [Owned; { value: box 10 }, { value: box 20 }] => values
    values -> len => count
    "owned count = $count" -> println
}
