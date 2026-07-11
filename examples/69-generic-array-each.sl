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

    # Explicit form: [TokenInfo { name: "name", line: 1 }, TokenInfo { name: "number", line: 2 }, ~]
    [TokenInfo; { name: "name", line: 1 }, { name: "number", line: 2 }, ~] => tokens
    tokens -> each token {
        "token $(token.name) at $(token.line)" -> println
    }

    # Explicit form: [OwnedToken { name: "owned-a", payload: box 10 }, OwnedToken { name: "owned-b", payload: box 20 }, ~]
    [OwnedToken; { name: "owned-a", payload: box 10 }, { name: "owned-b", payload: box 20 }, ~] => owned
    owned -> each token {
        "borrowed token = $(token.name)" -> println
    }
}
