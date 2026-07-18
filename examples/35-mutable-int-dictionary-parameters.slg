addScores scores: mut {Int: Int} -> Unit {
    scores -> put(3, 300)
    scores -> put(4, 400)
}

replaceFirst scores: mut {Int: Int} -> Unit {
    150 => scores[1]
}

main {
    {Int: Int} => scores!
    scores! -> put(1, 100)
    scores! -> put(2, 200)

    scores! -> addScores
    replaceFirst(scores!)

    scores! -> len => count
    scores![1] => first
    scores![3] => third
    scores![4] => fourth

    "count = $count" -> println
    "first = $first" -> println
    "third = $third" -> println
    "fourth = $fourth" -> println
}
