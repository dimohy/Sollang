sumValues values: [Int] -> Int {
    values -> fold 0 sum, value {
        sum + value
    }
}

firstValue values: [Int] -> Int {
    values[0]
}

main {
    [Int; 4~] => values!
    values! -> push(10)
    values! -> push(20)
    values! -> push(30)

    values! -> sumValues => dynamicTotal
    values! -> len => afterCount

    [7, 8, 9] => fixed
    fixed -> sumValues => staticTotal
    firstValue(fixed) => first

    "dynamic = $dynamicTotal" -> println
    "count = $afterCount" -> println
    "static = $staticTotal" -> println
    "first = $first" -> println
}
