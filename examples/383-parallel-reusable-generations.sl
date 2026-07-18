double value: Int -> Int => value * 2

main {
    2 -> limitParallelWorkers => workers
    0 => iteration!
    0 => checksum!
    iteration! < 100 -> while {
        [1, 2, 3, 4, 5, 6, 7, 8, ~] -> parallel value {
            value -> double
        } => mapped!
        checksum! + mapped![0] + mapped![7] => checksum!
        iteration! + 1 => iteration!
    }
    "generations=$(iteration!), checksum=$(checksum!), workers=$workers" -> println
}
