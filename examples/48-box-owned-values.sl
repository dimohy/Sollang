struct Point {
    x: Int
    y: Int
}

impl Point {
    boxed: -> box Point {
        box Point { x: 20, y: 22 }
    }
}

consume boxed: move box Point -> Int {
    boxed.x + boxed.y
}

main {
    Point.boxed => boxed
    boxed -> consume => total
    "boxed = $total" -> println
}
