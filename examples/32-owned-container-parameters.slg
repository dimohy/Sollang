makeValues: -> [Int; ~] {
    [Int; 4~] => values!
    values! -> push(10)
    values! -> push(20)
    values! -> push(30)
    values!
}

sumValues values: move [Int; ~] -> Int {
    values -> fold 0 sum, value {
        sum + value
    }
}

makeScores: -> {Int: Int} {
    {Int: Int; 4~} => scores!
    scores! -> put(1, 100)
    scores! -> put(2, 200)
    scores!
}

sumScores scores: move {Int: Int} -> Int {
    scores[1] + scores[2]
}

main {
    makeValues => values!
    values! -> sumValues => arrayTotal

    makeScores => scores!
    sumScores(scores!) => dictTotal

    "array = $arrayTotal" -> println
    "dict = $dictTotal" -> println
}
