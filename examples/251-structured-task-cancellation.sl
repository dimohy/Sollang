step value: Int -> async Int {
    value + 1
}

parent value: Int -> async Int {
    [value, value + 1, ~] => values!
    value -> step => firstTask
    value + 10 -> step => secondTask
    firstTask -> await => first
    secondTask -> await => second
    first + second + (values! -> len)
}

owned value: Int -> async [Int; ~] {
    [value, value + 1, ~]
}

consume values: move [Int; ~] -> async Int {
    values -> len
}

main {
    [2, 3, 5, ~] => input!
    input! -> consume => inputTask
    inputTask -> cancel

    7 -> owned => completedOwnedTask
    0 -> step => completedGate
    completedGate -> await => completedGateValue
    completedOwnedTask -> cancel

    10 -> step => queueFirst
    20 -> step => queueMiddle
    30 -> step => queueLast
    queueMiddle -> cancel
    queueFirst -> await => queueLeft
    queueLast -> await => queueRight

    5 -> parent => pending
    1 -> step => gate
    gate -> await => ignored
    pending -> cancel

    9 -> step => survivor
    survivor -> await => result
    "queue=$(queueLeft + queueRight),survivor=$result" -> println
}
