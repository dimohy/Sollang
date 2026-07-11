struct Point {
    x: Int
    y: Int
}

main {
    # Explicit form: [Point { x: 10, y: 20 }, ~]
    [Point; { x: 10, y: 20 }, ~] => points!
    # Explicit form: points! -> push(Point { x: 30, y: 40 })
    points! -> push({ x: 30, y: 40 })
    points![1].x => x
    points! -> len => count
    "dynamic point = $x" -> println
    "dynamic point count = $count" -> println
}
