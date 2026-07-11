import smalllang.compiler.lexer as lexer
import smalllang.compiler.parser as parser
import smalllang.compiler.cst as cst

main {
    lexer.lex("main {@}") => tokens!
    tokens![3].kind => invalidKind
    parser.parseEvents("main {@}") => events!
    events! -> len => eventCount
    events![eventCount - 1].value => accepted
    cst.build("main {@}") => nodes!
    nodes![0] => root
    "invalid kind = $invalidKind" -> println
    "accepted = $accepted" -> println
    "root tokens = $(root.tokenCount)" -> println
    "root span = $(root.start),$(root.length)" -> println
}
