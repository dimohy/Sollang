struct Key {
    value: Int
}

trait Hash {
    hash: self -> Text
}

trait Eq {
    eq: self -> Int
}

impl Hash for Key {
    hash: self -> Text => "bad"
}

impl Eq for Key {
    eq: self -> Int => self.value
}

main {
    { Key { value: 1 }: 10 } => values
}
