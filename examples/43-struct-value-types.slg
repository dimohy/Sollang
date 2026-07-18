struct Point {
    x: Int
    y: Int
}

struct Marker {
    point: Point
    label: Text
}

impl Point {
    origin: -> Self {
        Point { x: 1, y: 2 }
    }

    fromX: Int -> Self {
        Point { x: it, y: 0 }
    }

    translated: self -> Self {
        Point {
            x: self.x + 10
            y: self.y + 20
        }
    }

    sum: self -> Int {
        self.x + self.y
    }
}

main {
    Point.origin => origin
    Point.fromX(5) => fromX

    origin.translated => moved
    moved -> sum => total
    Marker {
        point: moved
        label: "target"
    } => marker

    marker.label => markerLabel
    marker.point.x => markerX
    marker.point.y => markerY
    fromX.x => fromXValue
    "marker = $markerLabel" -> println
    "point = $markerX, $markerY" -> println
    "total = $total" -> println
    "from = $fromXValue" -> println
}
