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

identity<T> value: T -> T {
    value
}

measureOf<T: Measure> value: T -> Int {
    value -> Measure.measure
}

main {
    Point { x: 19, y: 23 } => point
    point -> identity => copied
    copied -> measureOf => measured
    7 -> identity => seven
    "generic = $measured" -> println
    "identity = $seven" -> println
}
