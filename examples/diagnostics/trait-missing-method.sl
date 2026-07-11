struct Point {
    x: Int
}

trait Measure {
    measure: self -> Int
    label: self -> Text
}

impl Measure for Point {
    measure: self -> Int {
        self.x
    }
}

main {
}
