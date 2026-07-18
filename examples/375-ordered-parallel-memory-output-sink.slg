emitValue value: Int -> Int uses Console {
    "[$value]" -> print
    value * 2
}

main {
    [8, 1, 6, 3, 7, 2, 5, 4, ~] -> parallel value {
        value -> emitValue
    } => doubled!

    " results=$(doubled![0]),$(doubled![7])" -> println
}
