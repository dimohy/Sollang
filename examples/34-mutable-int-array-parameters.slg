addTail values: mut [Int; ~] -> Unit {
    values -> push(30)
}

replaceFirst values: mut [Int; ~] -> Unit {
    99 => values[0]
}

sumValues values: [Int] -> Int {
    values -> fold 0 sum, value {
        sum + value
    }
}

main {
    [Int; 4~] => values!
    values! -> push(10)
    values! -> push(20)

    values! -> addTail
    replaceFirst(values!)

    values! -> len => count
    values! -> sumValues => total
    values![0] => first

    "count = $count" -> println
    "total = $total" -> println
    "first = $first" -> println
}
