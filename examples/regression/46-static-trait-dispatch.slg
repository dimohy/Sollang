struct Point {
    x: Int
    y: Int
}

trait Measure {
    measure: self -> Int
}

impl Measure for Point {
    measure: self -> Int {
        self.x + self.y
    }
}

main {
    Point { x: 20, y: 22 } => point
    point.measure => direct
    point -> Measure.measure => qualified
    "measure = $direct, $qualified" -> println
}
