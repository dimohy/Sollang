namespace smalllang.compiler.semantic.expression_type_ids

import smalllang.compiler.ast
import smalllang.compiler.semantic.calls
import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols
import smalllang.compiler.semantic.type_ids as typeIds

public struct ExpressionTypeId {
    sourceModule: Int
    astNode: Int
    typeId: Int
    status: Int
}

public struct ExpressionTypeIdSet {
    types: [typeIds.SemanticType; ~]
    expressions: [ExpressionTypeId; ~]
}

# Bridges the existing shallow expression pass into the canonical recursive
# type arena. Annotation-backed names and call results retain their full type;
# builtin expressions use the stable builtin id directly.
public resolve sources: [Text; ~] -> ExpressionTypeIdSet {
    sources -> typeIds.resolve => semantic!
    sources -> expressionTypes.infer => shallow!
    sources -> calls.resolveModules => moduleCalls!
    [ExpressionTypeId; ~] => expressions!

    shallow! -> each expression {
        (expression.origin == 1 and expression.targetModule < 0 and expression.targetSymbol >= 0) -> if {
            expressions! -> push(ExpressionTypeId {
                sourceModule: expression.sourceModule
                astNode: expression.astNode
                typeId: expression.targetSymbol
                status: 0
            })
        }
    }

    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> symbols.collect => table!
        source -> resolution.resolve => resolvedNames!

        resolvedNames! -> each resolvedName {
            table![resolvedName.symbol] => valueSymbol
            valueSymbol.typeNode >= 0 -> if {
                -1 => referenceIndex!
                0 => referenceSearch!
                (referenceSearch! < (semantic!.references -> len) and referenceIndex! < 0) -> while {
                    (semantic!.references)[referenceSearch!] => candidate
                    (candidate.sourceModule == sourceIndex! and candidate.typeAst == valueSymbol.typeNode) -> if {
                        referenceSearch! => referenceIndex!
                    }
                    referenceSearch! + 1 => referenceSearch!
                }
                referenceIndex! >= 0 -> if {
                    (semantic!.references)[referenceIndex!] => reference
                    -1 => existingIndex!
                    0 => existingSearch!
                    (existingSearch! < (expressions! -> len) and existingIndex! < 0) -> while {
                        (expressions![existingSearch!].sourceModule == sourceIndex! and expressions![existingSearch!].astNode == resolvedName.astNode) -> if {
                            existingSearch! => existingIndex!
                        }
                        existingSearch! + 1 => existingSearch!
                    }
                    ExpressionTypeId {
                        sourceModule: sourceIndex!
                        astNode: resolvedName.astNode
                        typeId: reference.typeId
                        status: reference.status
                    } => exactType
                    existingIndex! >= 0 -> if {
                        exactType => expressions![existingIndex!]
                    } else {
                        expressions! -> push(exactType)
                    }
                }
            }
        }
        sourceIndex! + 1 => sourceIndex!
    }

    moduleCalls! -> each call {
        (call.status == 0 and call.targetSourceModule >= 0) -> if {
            sources[call.targetSourceModule] -> symbols.collect => targetTable!
            targetTable![call.functionSymbol] => function
            function.secondaryTypeNode >= 0 -> if { function.secondaryTypeNode } else { function.typeNode } => returnTypeAst
            returnTypeAst >= 0 -> if {
                -1 => returnReference!
                0 => returnSearch!
                (returnSearch! < (semantic!.references -> len) and returnReference! < 0) -> while {
                    (semantic!.references)[returnSearch!] => candidate
                    (candidate.sourceModule == call.targetSourceModule and candidate.typeAst == returnTypeAst) -> if {
                        returnSearch! => returnReference!
                    }
                    returnSearch! + 1 => returnSearch!
                }
                returnReference! >= 0 -> if {
                    (semantic!.references)[returnReference!] => reference
                    expressions! -> push(ExpressionTypeId {
                        sourceModule: call.sourceModule
                        astNode: call.callAst
                        typeId: reference.typeId
                        status: reference.status
                    })
                }
            }
        }
    }

    [typeIds.SemanticType; ~] => outputTypes!
    semantic!.types -> each semanticType {
        outputTypes! -> push(semanticType)
    }
    ExpressionTypeIdSet { types: outputTypes!, expressions: expressions! } => result!
    result!
}
