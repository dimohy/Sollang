enum Reading {
    Value(Int)
    Missing
    Label(Text)
}

number reading: Reading -> Int {
    reading -> when {
        Reading.Value(value) => value
        Reading.Missing => 0
        Reading.Label(label) => 0
    }
}

kind reading: Reading -> Text {
    reading -> when {
        Reading.Value(value) => "number"
        Reading.Missing => "missing"
        Reading.Label(label) => label
    }
}

main {
    Reading.Value(42) => valueReading
    Reading.Missing => missingReading
    Reading.Label("sensor") => labelReading

    valueReading -> number => value
    valueReading -> kind => valueKind
    missingReading -> kind => missingKind
    labelReading -> kind => labelKind

    "value = $value, $valueKind" -> println
    "missing = $missingKind" -> println
    "label = $labelKind" -> println
}
