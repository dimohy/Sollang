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
    # Explicit form: { SymbolKey { scope: 1, id: 10 }: "lexer", SymbolKey { scope: 1, id: 20 }: "parser", SymbolKey { scope: 2, id: 10 }: "semantic" }
    {SymbolKey: Text;
        { scope: 1, id: 10 }: "lexer",
        { scope: 1, id: 20 }: "parser",
        { scope: 2, id: 10 }: "semantic"
    } => symbols!
    # Explicit form: symbols! -> put(SymbolKey { scope: 1, id: 20 }, "syntax")
    symbols! -> put({ scope: 1, id: 20 }, "syntax")

    symbols![{ scope: 1, id: 10 }] => lexer
    symbols![{ scope: 1, id: 20 }] => parser
    symbols![{ scope: 2, id: 10 }] => semantic
    symbols! -> len => count
    "nominal lexer = $lexer" -> println
    "nominal parser = $parser" -> println
    "nominal semantic = $semantic" -> println
    "nominal count = $count" -> println
}
