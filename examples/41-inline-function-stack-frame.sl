run: -> Int {
    rowTotal seed: Int -> Int {
        [seed, seed * 10, ~] => row
        row -> fold 0 sum, value {
            sum + value
        }
    }

    1..3 -> fold 0 total, i {
        i -> rowTotal => row
        total + row
    }
}

main {
    run => total
    "inline total = $total" -> println
}
