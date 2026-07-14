import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.parser as parser
import sys.file as file

main {
    "examples/01-function-basic-hello.sl" -> file.mapText => source!
    source! -> lexer.lexSource => tokens!
    source! -> parser.parseSourceEvents => events!
    source! -> ast.lowerSource => nodes!

    "mapped syntax = $(tokens! -> len),$(events! -> len),$(nodes! -> len)" -> println
}
