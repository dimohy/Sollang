step value: Int -> async Int {
    value + 1
}

probe count: Int -> async Int {
    0 => index!
    index! < count -> while {
        index! -> step => pending
        pending -> await => next
        index! + next => index!
        continue
    }
    index!
}

main { }
