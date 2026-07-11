import sample.internal_trait as hidden

struct Number {
    value: Int
}

impl hidden.SecretTrait for Number {
    reveal: self -> Int {
        self.value
    }
}

main {
}
