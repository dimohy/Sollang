struct Owned {
    value: box Int
}

main {
    [Owned { value: box 1 }, ~] => values!
    Owned { value: box 2 } => item
    values! -> push(item)
    values! -> len => count
    "owned push count = $count" -> println
}
