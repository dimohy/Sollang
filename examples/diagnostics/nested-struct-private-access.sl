struct Lexer {
    struct Cursor {
        offset: Int
    }
}

main {
    Lexer.Cursor { offset: 0 } => cursor
    "$(cursor.offset)" -> println
}
