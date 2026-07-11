import smalllang.compiler.lexer as lexer

main {
    lexer.lex("main { 42 -> println }") => tokens!
    tokens! -> each token {
        token.span.start => start
        token.span.length => length
        "kind=$(token.kind) start=$start length=$length" -> println
    }
}
