main {
    true -> if {
        [10, 20, 30, ~] => values
        values -> fold 0 sum, value {
            sum + value
        } => total
        "array = $total" -> println
    } else {
        "array branch skipped" -> println
    }

    false -> if {
        "dictionary branch skipped" -> println
    } else {
        { 1: 100, 2: 200 } => scores
        scores[2] => score
        "score = $score" -> println
    }

    1..3 -> each i {
        [i, i * 10, ~] => row
        row -> fold 0 sum, value {
            sum + value
        } => rowTotal
        "row $i = $rowTotal" -> println
    }
}
