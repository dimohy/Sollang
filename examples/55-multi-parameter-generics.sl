struct NumberSource {
    value: Int
}

struct TextSource {
    value: Text
}

trait Source {
    type Item
    read: self -> Item
}

impl Source for NumberSource {
    type Item = Int

    read: self -> Int {
        self.value
    }
}

impl Source for TextSource {
    type Item = Text

    read: self -> Text {
        self.value
    }
}

readAny[T, Item] where T: Source[Item = Item] value: T -> Item {
    value -> Source.read
}

main {
    NumberSource { value: 42 } -> readAny => number
    TextSource { value: "generic text" } -> readAny => text
    "multi number = $number" -> println
    "multi text = $text" -> println
}
