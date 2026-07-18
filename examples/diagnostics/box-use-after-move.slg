struct Point {
    x: Int
}

consume boxed: move box Point -> Int {
    boxed.x
}

main {
    box Point { x: 42 } => boxed
    boxed -> consume => value
    boxed.x -> println
}
