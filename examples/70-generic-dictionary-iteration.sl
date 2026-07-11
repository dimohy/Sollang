struct SymbolInfo {
    name: Text
    depth: Int
}

struct OwnedSymbol {
    name: Text
    payload: box Int
}

main {
    { "lexer": SymbolInfo { name: "tokens", depth: 1 }, "parser": SymbolInfo { name: "syntax", depth: 2 } } => symbols
    symbols -> eachKey key {
        "symbol key = $key" -> println
    }
    symbols -> eachValue symbol {
        "symbol $(symbol.name) depth $(symbol.depth)" -> println
    }

    { 1: OwnedSymbol { name: "owned-a", payload: box 10 }, 2: OwnedSymbol { name: "owned-b", payload: box 20 } } => owned
    owned -> eachValue symbol {
        "borrowed symbol = $(symbol.name)" -> println
    }
}
