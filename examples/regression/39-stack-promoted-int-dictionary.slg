findScore scores: {Int: Int} -> Int {
    scores[2]
}

sumLocal: -> Int {
    { 1: 10, 2: 20 } => localScores
    localScores[1] + localScores[2]
}

main {
    { 1: 100, 2: 200, 3: 300 } => scores
    scores -> findScore => second
    scores[1] + scores[3] => edges
    scores -> len => count
    scores -> capacity => capacity
    sumLocal() => functionTotal

    "second = $second" -> println
    "edges = $edges" -> println
    "count = $count" -> println
    "capacity = $capacity" -> println
    "function total = $functionTotal" -> println
}
