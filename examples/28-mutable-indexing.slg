main {
    [1, 2, 3] => fixed!
    99 => fixed![1]
    fixed![1] => fixedChanged

    [10, 20, ~] => values!
    values! -> push(30)
    77 => values![2]
    values![2] => dynamicChanged
    values! -> len => dynamicCount

    { 1: 100, 2: 200 } => scores!
    250 => scores![2]
    scores![2] => scoreChanged
    scores! -> len => scoreCount

    "fixedChanged = $fixedChanged" -> println
    "dynamicChanged = $dynamicChanged" -> println
    "dynamicCount = $dynamicCount" -> println
    "scoreChanged = $scoreChanged" -> println
    "scoreCount = $scoreCount" -> println
}
