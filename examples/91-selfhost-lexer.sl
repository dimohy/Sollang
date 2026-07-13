import smalllang.compiler.lexer as lexer

main {
    """
    main {
        42 -> println
    }
    # note
    """ -> lexer.lex => tokens!
    tokens! -> each token {
        token.span.start => start
        token.span.length => length
        "kind=$(token.kind) start=$start length=$length" -> println
    }
}
