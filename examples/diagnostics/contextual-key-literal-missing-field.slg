struct SymbolKey {
    scope: Int
    id: Int
}

trait Hash {
    hash: self -> Int
}

trait Eq {
    eq: self -> Int
}

impl Hash for SymbolKey {
    hash: self -> Int => self.scope * 1009 + self.id
}

impl Eq for SymbolKey {
    eq: self -> Int => self.scope * 100000 + self.id
}

main {
    {SymbolKey: Text; { scope: 2 }: "semantic" } => symbols!
}
