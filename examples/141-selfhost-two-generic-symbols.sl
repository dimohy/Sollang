import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.lexer as lexer

main {
    "convert<T, E> value: T -> E => value\nmain { }" => source
    [source, ~] => sources!
    source -> symbols.collect => table!
    source -> lexer.lex => tokens!
    table! -> each symbol {
        symbol.kind == 32 -> if {
            tokens![symbol.nameToken] => token
            source -> slice(token.span.start, token.span.length) => name
            "generic symbol = $name,$(symbol.parent)" -> println
        }
    }
    sources! -> nominalTypes.resolve => resolved!
    resolved! -> each item {
        "generic nominal = $(item.origin),$(item.targetSymbol),$(item.status)" -> println
    }
}
