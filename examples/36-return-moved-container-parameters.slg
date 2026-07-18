appendTail values: move [Int; ~] -> [Int; ~] {
    values -> append(30) => values
    values
}

chooseValues values: move [Int; ~] -> [Int; ~] {
    true -> if {
        values
    } else {
        values
    }
}

forwardScores scores: move {Int: Int} -> {Int: Int} => scores

addScore scores: move {Int: Int} -> {Int: Int} {
    scores -> updated(3, 300) => scores
    scores
}

chooseScores scores: move {Int: Int} -> {Int: Int} => when {
    true => scores
    else => scores
}

main {
    [1, 2, ~] => values
    values -> appendTail => values
    values -> chooseValues => values
    values[2] => tail

    { 1: 100, 2: 200 } => scores
    forwardScores(scores) => scores
    scores -> addScore => scores
    scores -> chooseScores => scores
    scores[3] => score

    "tail = $tail" -> println
    "score = $score" -> println
}
