struct Point {
    x: Int
    y: Int
}

main {
    [Point { x: 10, y: 20 }, ~] => points!
    points! -> push(Point { x: 30, y: 40 })
    points![1].x => x
    points! -> len => count
    "dynamic point = $x" -> println
    "dynamic point count = $count" -> println
}
