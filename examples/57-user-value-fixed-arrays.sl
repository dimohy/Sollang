struct Point {
    x: Int
    y: Int
}

enum Reading {
    Value(Int)
    Missing
}

number reading: Reading -> Int {
    reading -> when {
        Reading.Value(value) => value
        Reading.Missing => 0
    }
}

main {
    # Explicit form: [Point { x: 10, y: 20 }, Point { x: 30, y: 40 }]
    [Point; { x: 10, y: 20 }, { x: 30, y: 40 }] => points
    points[1].x => x
    points[0].y => y
    points -> len => count
    [Reading.Missing, Reading.Value(7)] => readings
    readings[1] -> number => reading
    "point = $x, $y" -> println
    "point count = $count" -> println
    "reading = $reading" -> println
}
