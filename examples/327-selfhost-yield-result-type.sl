import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.expression_types as expressionTypes

main {
    """
    map value: Int -> Bool block item: Int -> Bool {
        value -> yield => mapped
        mapped
    }

    main {
        1 -> map item {
            item == 1
        } => result
    }
    """ => source
    [source, ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    source -> ast.lower => nodes!
    source -> lexer.lex => tokens!
    0 => boolYieldFlows!
    inferred! -> each expressionType {
        (nodes![expressionType.astNode].kind == 10 and expressionType.origin == 1 and expressionType.targetSymbol == 23) -> if {
            false => isYield!
            0 => childIndex!
            childIndex! < (nodes! -> len) -> while {
                nodes![childIndex!] => child
                (child.parent == expressionType.astNode and child.kind == 16 and child.payloadToken >= 0) -> if {
                    tokens![child.payloadToken] => name
                    (name.span.length == UIntSize(5) and (source -> byte(name.span.start)) == UInt8(121) and (source -> byte(name.span.start + UIntSize(1))) == UInt8(105) and (source -> byte(name.span.start + UIntSize(2))) == UInt8(101) and (source -> byte(name.span.start + UIntSize(3))) == UInt8(108) and (source -> byte(name.span.start + UIntSize(4))) == UInt8(100)) -> if {
                        true => isYield!
                    }
                }
                childIndex! + 1 => childIndex!
            }
            isYield! -> if { boolYieldFlows! + 1 => boolYieldFlows! }
        }
    }
    boolYieldFlows! => count
    "yield result types=$count" -> println
}
