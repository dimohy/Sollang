struct Owned {
    value: box Int
}

main {
    [Owned { value: box 10 }, Owned { value: box 20 }] => values
    values -> len => count
    "owned count = $count" -> println
}
