struct Point {
    x: Int
    y: Int
}

main {
    [Point; { x: 1, y: 2 }, ~] => points!
    points! -> push({ x: 3 })
}
