collect<T> value: T -> Int block items: [T; ~] {
    [value, ~] => yielded!
    yielded! -> yield
    1
}

main {
    9 -> collect items {
        items -> len => count
        "length=$count" -> println
    } => collected
    "collected=$collected" -> println
}
