namespace smalllang.compiler.semantic.symbols

import smalllang.compiler.ast as ast

# Symbol and AST indexes are stable offsets into owned arrays. This keeps the
# semantic graph relocatable and avoids one heap allocation per declaration.
public struct Symbol {
    kind: Int
    parent: Int
    astNode: Int
    nameToken: Int
    typeNode: Int
    secondaryTypeNode: Int
    flags: Int
}

public collect source: Text -> [Symbol; ~] {
    source -> ast.lower => nodes!
    [Symbol; ~] => symbols!
    [Int; ~] => astToSymbol!
    nodes! -> len => astCount
    0 => astIndex!

    astIndex! < astCount -> while {
        nodes![astIndex!] => node
        astToSymbol! -> push(-1)
        false => isSymbol!
        node.kind >= 3 -> if {
            node.kind <= 7 -> if { true => isSymbol! }
        }
        node.kind == 9 -> if { true => isSymbol! }
        node.kind >= 26 -> if {
            node.kind <= 34 -> if { true => isSymbol! }
        }
        isSymbol! -> if {
            -1 => parentSymbol!
            node.parent => parentAst!
            (parentAst! >= 0 and parentSymbol! < 0) -> while {
                astToSymbol![parentAst!] => mappedParent
                mappedParent >= 0 -> if {
                    mappedParent => parentSymbol!
                } else {
                    nodes![parentAst!].parent => parentAst!
                }
            }
            Symbol {
                kind: node.kind
                parent: parentSymbol!
                astNode: astIndex!
                nameToken: node.payloadToken
                typeNode: -1
                secondaryTypeNode: -1
                flags: node.flags
            } => symbol
            symbols! -> len => symbolIndex
            symbols! -> push(symbol)
            symbolIndex => astToSymbol![astIndex!]
        }
        astIndex! + 1 => astIndex!
    }

    # Attach each type node to its nearest symbol ancestor. The nearest rule
    # prevents a field or method type from being mistaken for its owner type.
    0 => typeAstIndex!
    typeAstIndex! < astCount -> while {
        nodes![typeAstIndex!] => typeAst
        typeAst.kind == 12 -> if {
            typeAst.parent => typeParentAst!
            -1 => typeOwnerSymbol!
            (typeParentAst! >= 0 and typeOwnerSymbol! < 0) -> while {
                astToSymbol![typeParentAst!] => mappedOwner
                mappedOwner >= 0 -> if {
                    mappedOwner => typeOwnerSymbol!
                } else {
                    nodes![typeParentAst!].parent => typeParentAst!
                }
            }
            typeOwnerSymbol! >= 0 -> if {
                symbols![typeOwnerSymbol!] => owner!
                owner!.typeNode < 0 -> if {
                    typeAstIndex! => owner!.typeNode
                } else {
                    owner!.secondaryTypeNode < 0 -> if {
                        typeAstIndex! => owner!.secondaryTypeNode
                    }
                }
                owner! => symbols![typeOwnerSymbol!]
            }
        }
        typeAstIndex! + 1 => typeAstIndex!
    }

    # Parameters and method self values are synthetic lexical symbols owned by
    # their declaration symbol; they reuse the declaration AST index.
    symbols! -> len => declaredSymbolCount
    0 => declarationSymbolIndex!
    declarationSymbolIndex! < declaredSymbolCount -> while {
        symbols![declarationSymbolIndex!] => declarationSymbol
        nodes![declarationSymbol.astNode] => declarationAst
        declarationAst.secondaryToken >= 0 -> if {
            (declarationSymbol.kind == 7 or declarationSymbol.kind == 29 or declarationSymbol.kind == 31) -> if {
                -1 => parameterTypeNode!
                declarationSymbol.kind == 7 -> if {
                    declarationSymbol.typeNode => parameterTypeNode!
                }
                Symbol {
                    kind: 35
                    parent: declarationSymbolIndex!
                    astNode: declarationSymbol.astNode
                    nameToken: declarationAst.secondaryToken
                    typeNode: parameterTypeNode!
                    secondaryTypeNode: -1
                    flags: declarationSymbol.flags
                } => parameterSymbol
                symbols! -> push(parameterSymbol)
            }
        }
        declarationSymbolIndex! + 1 => declarationSymbolIndex!
    }

    symbols!
}
