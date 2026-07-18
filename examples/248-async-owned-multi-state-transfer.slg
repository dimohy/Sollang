bump value: Int -> async Int {
    value + 1
}

collect value: Int -> async [Int; ~] {
    [1, 2, 3, ~] => saved
    value -> bump => firstTask
    firstTask -> await => first
    first -> bump => secondTask
    secondTask -> await => second
    saved -> append(second) => saved
    saved
}

main {
    5 -> collect => task
    task -> await => values!
    "count=$(values! -> len),last=$(values![3])" -> println
}
