struct Point {
    x: Int
}

trait Measure {
    measure: self -> Int
}

measureOf<T: Measure> value: T -> Int {
    value -> Measure.measure
}

main {
    Point { x: 1 } -> measureOf => result
}
