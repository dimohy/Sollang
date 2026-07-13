import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.symbols as symbols

main {
    """
    struct Point { x: Int y: Int }
    impl Point { reset: mut self -> Int { 1 } }
    make value: move Int -> Int { value }
    main { }
    """ => source
    source -> symbols.collect => table!
    source -> lexer.lex => tokens!
    source -> ast.lower => nodes!
    table! -> each symbol {
        tokens![symbol.nameToken] => nameToken
        source -> slice(nameToken.span.start, nameToken.span.length) => name
        -1 => typeStart!
        -1 => secondaryTypeStart!
        symbol.typeNode >= 0 -> if {
            Int(nodes![symbol.typeNode].start) => typeStart!
        }
        symbol.secondaryTypeNode >= 0 -> if {
            Int(nodes![symbol.secondaryTypeNode].start) => secondaryTypeStart!
        }
        typeStart! => resolvedTypeStart
        secondaryTypeStart! => resolvedSecondaryTypeStart
        "symbol = $(symbol.kind),$(symbol.parent),$name,$resolvedTypeStart,$resolvedSecondaryTypeStart,$(symbol.flags)" -> println
    }
}
