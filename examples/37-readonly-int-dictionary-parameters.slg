findScore scores: {Int: Int} -> Int {
    scores[2]
}

sumKnown scores: {Int: Int} -> Int {
    findFirst values: {Int: Int} -> Int {
        values[1]
    }

    findFirst(scores) + findScore(scores)
}

main {
    {Int: Int; 4~} => scores!
    scores! -> put(1, 100)
    scores! -> put(2, 200)

    scores! -> findScore => second
    sumKnown(scores!) => total

    scores! -> put(3, 300)
    scores! -> len => count

    "second = $second" -> println
    "total = $total" -> println
    "count = $count" -> println
}
