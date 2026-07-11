struct TokenInfo {
    name: Text
    line: Int
}

struct OwnedToken {
    name: Text
    payload: box Int
}

main {
    ["lex", "parse"] -> each stage {
        "fixed stage = $stage" -> println
    }

    [TokenInfo { name: "name", line: 1 }, TokenInfo { name: "number", line: 2 }, ~] => tokens
    tokens -> each token {
        "token $(token.name) at $(token.line)" -> println
    }

    [OwnedToken { name: "owned-a", payload: box 10 }, OwnedToken { name: "owned-b", payload: box 20 }, ~] => owned
    owned -> each token {
        "borrowed token = $(token.name)" -> println
    }
}
