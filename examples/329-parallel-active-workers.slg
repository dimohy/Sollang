busy value: Int -> Int {
    0 => index!
    value => total!
    index! < 1000000 -> while {
        total! + (index! % 17) => total!
        index! + 1 => index!
    }
    total!
}

main {
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, ~] => values!
    values! -> parallel item {
        item -> busy
    } => mapped!
    parallelWorkers => workerCount
    parallelPeakWorkers => peakCount
    workerCount > 2 -> if { peakCount > 2 } else { peakCount > 0 } => active
    active -> if { "true" } else { "false" } => activeText
    "pool-active=$activeText, results=$(mapped! -> len)" -> println
}
