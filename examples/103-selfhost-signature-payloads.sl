import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer

main {
    ["take values: move [Int; ~] -> Int { 1 } main { }", "borrow values: mut [Int; ~] -> Int { 1 } main { }", "impl Worker { run: move self -> Int { 1 } } main { }"] -> each source {
        source -> ast.lower => nodes!
        source -> lexer.lex => tokens!
        nodes! -> len => count
        0 => index!
        index! < count -> while {
            nodes![index!] => node
            (node.kind == 7 or node.kind == 31) -> if {
                tokens![node.payloadToken] => nameToken
                tokens![node.secondaryToken] => secondaryToken
                source -> slice(nameToken.span.start, nameToken.span.length) => name
                source -> slice(secondaryToken.span.start, secondaryToken.span.length) => secondary
                "signature = $(node.kind),$name,$secondary,$(node.flags)" -> println
            }
            index! + 1 => index!
        }
    }
}
