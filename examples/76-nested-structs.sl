struct Lexer {
    struct Cursor {
        offset: Int
        line: Int
    }

    cursor: Cursor
}

impl Lexer {
    start: -> Lexer => Lexer {
        cursor: Cursor { offset: 0, line: 1 }
    }
}

main {
    Lexer.start => lexer
    "cursor = $(lexer.cursor.offset):$(lexer.cursor.line)" -> println
}
