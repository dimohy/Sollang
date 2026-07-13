step value: Int -> async Int {
    value + 1
}

accumulate count: Int -> async Int {
    0 => index!
    0 => total!
    [count, ~] => values!
    index! < count -> while {
        box index! => owned
        index! -> step => firstTask
        index! + 10 -> step => secondTask
        firstTask -> await => first
        secondTask -> await => second
        total! + first + second => total!
        values! -> push(first + second)
        index! + 1 => index!
    }
    total! + (values! -> len)
}

selective count: Int -> async Int {
    0 => index!
    0 => total!
    index! < count -> while {
        index! % 2 == 0 -> if {
            index! -> step => pending
            pending -> await => next
            total! + next => total!
        } else {
            total! + 10 => total!
        }
        index! + 1 => index!
    }
    total!
}

main {
    3 -> accumulate => repeated
    0 -> accumulate => empty
    5 -> accumulate => cancelled
    4 -> selective => selected
    1 -> step => gate
    gate -> await => ignored
    cancelled -> cancel
    repeated -> await => repeatedValue
    empty -> await => emptyValue
    selected -> await => selectedValue
    "loop=$repeatedValue,empty=$emptyValue,branch=$selectedValue" -> println
}
