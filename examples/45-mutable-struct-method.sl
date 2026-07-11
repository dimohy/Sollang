struct Counter {
    value: Int
}

impl Counter {
    increment: mut self -> Unit {
        self.value + 1 => self.value
    }

    take: move self -> Int {
        self.value
    }
}

main {
    Counter { value: 40 } => counter!
    counter! -> increment
    counter! -> increment
    counter!.value => current
    counter! -> take => taken
    "counter = $current" -> println
    "taken = $taken" -> println
}
