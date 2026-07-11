main {
    10 => n
    nowMillis() => started

    [Int; 10~] => values!
    1..10 -> each i {
        values! -> push(i)
    }

    values! -> fold 0 total, value {
        total + value
    } => arraySum

    {Int: Int; 10~} => scores!
    1..10 -> each i {
        scores! -> put(i, i * 2)
    }

    1..10 -> fold 0 total, i {
        scores![i] => value
        total + value
    } => dictSum

    nowMillis() => finished
    finished - started => elapsedMillis

    "n = $n" -> println
    "arraySum = $arraySum" -> println
    "dictSum = $dictSum" -> println
    "elapsedMillis = $elapsedMillis" -> println
}
