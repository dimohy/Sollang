struct Owned {
    value: box Int
}

main {
    [Owned { value: box 10 }, ~] => values!
    values! -> push(Owned { value: box 20 })
    values! -> len => count
    "owned dynamic count = $count" -> println
}
