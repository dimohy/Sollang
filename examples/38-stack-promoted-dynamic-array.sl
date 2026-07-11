sumValues values: [Int] -> Int {
    values -> fold 0 sum, value {
        sum + value
    }
}

sumLocal: -> Int {
    [4, 5, 6, ~] => localValues
    localValues -> sumValues
}

main {
    [10, 20, 30, ~] => localValues
    localValues -> sumValues => localTotal
    localValues[1] => middle
    localValues -> len => localCount
    sumLocal => functionTotal

    "local total = $localTotal" -> println
    "middle = $middle" -> println
    "local count = $localCount" -> println
    "function total = $functionTotal" -> println
}
