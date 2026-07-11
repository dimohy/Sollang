struct Owned {
    value: box Int
}

main {
    # Explicit form: [Owned { value: box 10 }, ~]
    [Owned; { value: box 10 }, ~] => values!
    # Explicit form: values! -> push(Owned { value: box 20 })
    values! -> push({ value: box 20 })
    values! -> len => count
    "owned dynamic count = $count" -> println
}
