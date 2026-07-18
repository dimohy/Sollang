struct Pair {
    left: Int
    right: Int
}

build seed: Int -> Pair block field: Int {
    seed -> yield
    Pair {
        left: seed
        right: seed + 1
    }
}

main {
    Pair {
        left: 1
        right: 2
    } => direct

    10 -> build field {
        "field=$field" -> println
    } => built

    "direct=$(direct.left),$(direct.right)" -> println
    "built=$(built.left),$(built.right)" -> println
}
