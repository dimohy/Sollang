plusOne value: Int -> Int => value + 1

main {
    [1, 2, 3, ~] => values!
    values! -> parallel item {
        item -> plusOne
    } => mapped!
    mapped! -> each item {
        "$item" -> println
    }
    parallelWorkers => workerCount
    workerCount > 2 -> if { "pool=true" } else { "pool=false" } -> println
}
