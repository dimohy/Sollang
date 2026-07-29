makeValues: -> [Int; ~] {
    [Int; 4~] => values!
    values! -> push(10)
    values! -> push(20)
    values!
}

makeScores: -> {Int: Int} {
    {Int: Int; 4~} => scores!
    scores! -> put(1, 100)
    scores! -> put(2, 200)
    scores!
}

main {
    makeValues() => values!
    values! -> push(30)
    values! -> fold 0 sum, value {
        sum + value
    } => arrayTotal

    makeScores() => scores!
    scores! -> put(3, 300)
    scores![1] + scores![2] + scores![3] => dictTotal

    "array = $arrayTotal" -> println
    "dict = $dictTotal" -> println
}
