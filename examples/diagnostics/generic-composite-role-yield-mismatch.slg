collect<T> value: T -> Int block items: [T; ~] {
    ["wrong", ~] => yielded!
    yielded! -> yield
    1
}

main {
    9 -> collect items {
        items -> len => count
    } => collected
}
