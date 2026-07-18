struct Holder {
    values: [Int; ~]
}

main {
    Holder { values: [1, ~] } => holder!
    [2, 3, ~] => replacement!
    replacement! => holder!.values
    replacement! -> len => invalid
}
