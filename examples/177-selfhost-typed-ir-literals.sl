import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.lexer as lexer

main {
    [
        """"
        answer: -> Int => 42
        message: -> Text => "ok"
        ready: -> Bool => true
        main { }
        """",
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    ir! -> each node {
        "-" => payload!
        node.payloadToken >= 0 -> if {
            sources![node.sourceModule] -> lexer.lex => tokens!
            tokens![node.payloadToken] => token
            sources![node.sourceModule] -> slice(token.span.start, token.span.length) => payload!
        }
        "ir = $(node.kind),$(node.parent),$(node.symbol),$(node.typeOrigin),$(node.typeModule),$(node.typeSymbol),$(payload!),$(node.operand0)" -> println
    }
}
