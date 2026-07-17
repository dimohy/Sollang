import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.symbols as symbols

main {
    """
    map value: Int -> Int block item: Int -> Bool {
        value -> yield
    }

    main { }
    """ => source
    source -> ast.lower => nodes!
    nodes! -> symbols.collectPrepared => table!
    false => valid!
    table! -> each symbol {
        (symbol.kind == 7 and symbol.blockTypeNode >= 0 and symbol.blockResultTypeNode >= 0 and symbol.blockTypeNode != symbol.blockResultTypeNode) -> if {
            true => valid!
        }
    }
    valid! -> if {
        "callback result symbol = valid" -> println
    } else {
        "callback result symbol = invalid" -> println
    }
}
