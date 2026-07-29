enum Reading {
    Value(Int)
    Missing
    Label(Text)
}

number reading: Reading -> Int {
    reading -> when {
        Value(value) => value
        Missing => 0
        Label(label) => 0
    }
}

kind reading: Reading -> Text {
    reading -> when {
        Value(value) => "number"
        Missing => "missing"
        Label(label) => label
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
