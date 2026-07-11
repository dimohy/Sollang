struct Point {
    x: Int
    y: Int
}

main {
    # Explicit form: [Point { x: 1, y: 2 }, Point { x: 3, y: 4 }, Point { x: 5, y: 6 }, ~]
    [Point;
        { x: 1, y: 2 },
        { x: 3, y: 4 },
        { x: 5, y: 6 },
        ~
    ] => points!
    # Explicit form: points! -> push(Point { x: 7, y: 8 })
    points! -> push({ x: 7, y: 8 })
    points! -> each point {
        "point = $(point.x), $(point.y)" -> println
    }
}
