namespace smalllang.compiler.ir.typed

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.symbols as symbols

# Stable, flat typed IR. Indexes are relocatable array offsets so later LLVM
# lowering can consume the table without allocating an object graph.
# Kinds: 0 function, 1 return, 2 Text constant, 3 Int constant,
# 4 Bool constant, 5 name, 6 call, 7 unary, 8 binary, 9 other expression.
public struct TypedIrNode {
    kind: Int
    parent: Int
    sourceModule: Int
    astNode: Int
    symbol: Int
    typeOrigin: Int
    typeModule: Int
    typeSymbol: Int
    payloadToken: Int
    operand0: Int
    operand1: Int
    flags: Int
}

public lower sources: [Text; ~] -> [TypedIrNode; ~] {
    sources -> expressionTypes.infer => inferred!
    [TypedIrNode; ~] => results!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> symbols.collect => table!
        0 => symbolIndex!
        symbolIndex! < (table! -> len) -> while {
            table![symbolIndex!] => function
            function.kind == 7 -> if {
                -1 => resultTypeIndex!
                1000000 => resultDistance!
                0 => typeSearch!
                typeSearch! < (inferred! -> len) -> while {
                    inferred![typeSearch!] => candidateType
                    candidateType.sourceModule == sourceIndex! -> if {
                        nodes![candidateType.astNode].parent => ancestor!
                        1 => distance!
                        false => belongsToFunction!
                        (ancestor! >= 0 and not belongsToFunction!) -> while {
                            ancestor! == function.astNode -> if { true => belongsToFunction! } else {
                                nodes![ancestor!].parent => ancestor!
                                distance! + 1 => distance!
                            }
                        }
                        (belongsToFunction! and distance! < resultDistance!) -> if {
                            typeSearch! => resultTypeIndex!
                            distance! => resultDistance!
                        }
                    }
                    typeSearch! + 1 => typeSearch!
                }
                resultTypeIndex! >= 0 -> if {
                    inferred![resultTypeIndex!] => resultType
                    nodes![resultType.astNode] => expression
                    results! -> len => functionIr!
                    functionIr! + 1 => returnIr
                    returnIr + 1 => expressionIr
                    results! -> push(TypedIrNode {
                        kind: 0
                        parent: -1
                        sourceModule: sourceIndex!
                        astNode: function.astNode
                        symbol: symbolIndex!
                        typeOrigin: resultType.origin
                        typeModule: resultType.targetModule
                        typeSymbol: resultType.targetSymbol
                        payloadToken: function.nameToken
                        operand0: returnIr
                        operand1: -1
                        flags: function.flags
                    })
                    results! -> push(TypedIrNode {
                        kind: 1
                        parent: functionIr!
                        sourceModule: sourceIndex!
                        astNode: resultType.astNode
                        symbol: symbolIndex!
                        typeOrigin: resultType.origin
                        typeModule: resultType.targetModule
                        typeSymbol: resultType.targetSymbol
                        payloadToken: -1
                        operand0: expressionIr
                        operand1: -1
                        flags: 0
                    })
                    9 => expressionKind!
                    expression.kind == 13 -> if { 2 => expressionKind! }
                    expression.kind == 14 -> if { 3 => expressionKind! }
                    expression.kind == 15 -> if {
                        resultType.origin == 1 and resultType.targetSymbol == 23 -> if { 4 => expressionKind! } else { 5 => expressionKind! }
                    }
                    expression.kind == 11 -> if { 6 => expressionKind! }
                    expression.kind == 22 -> if { 7 => expressionKind! }
                    (expression.kind >= 18 and expression.kind <= 21) -> if { 8 => expressionKind! }
                    (expression.kind == 24 or expression.kind == 25) -> if { 8 => expressionKind! }
                    results! -> push(TypedIrNode {
                        kind: expressionKind!
                        parent: returnIr
                        sourceModule: sourceIndex!
                        astNode: resultType.astNode
                        symbol: -1
                        typeOrigin: resultType.origin
                        typeModule: resultType.targetModule
                        typeSymbol: resultType.targetSymbol
                        payloadToken: expression.payloadToken
                        operand0: -1
                        operand1: -1
                        flags: expression.flags
                    })
                }
            }
            symbolIndex! + 1 => symbolIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    results!
}
