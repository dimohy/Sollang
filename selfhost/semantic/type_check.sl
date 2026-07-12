namespace smalllang.compiler.semantic.type_check

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.syntax as syntax

public struct TypeCheckDiagnostic {
    code: Int
    sourceModule: Int
    functionSymbol: Int
    expectedOrigin: Int
    expectedModule: Int
    expectedSymbol: Int
    actualOrigin: Int
    actualModule: Int
    actualSymbol: Int
    actualBuiltin: Int
    span: syntax.SourceSpan
}

# Code 5 identifies a function return expression whose inferred builtin type
# does not match the declared nominal return type. Builtin ids come from the
# stable nominal_types table: Text is 1 and Int is 2.
public analyze sources: [Text; ~] -> [TypeCheckDiagnostic; ~] {
    sources -> nominalTypes.resolve => nominal!
    sources -> expressionTypes.infer => expressionTypeTable!
    [TypeCheckDiagnostic; ~] => diagnostics!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> symbols.collect => table!
        0 => symbolIndex!
        symbolIndex! < (table! -> len) -> while {
            table![symbolIndex!] => function
            function.kind == 7 -> if {
                function.secondaryTypeNode >= 0 -> if {
                    function.secondaryTypeNode
                } else {
                    function.typeNode
                } => returnTypeAst
                -1 => expectedIndex!
                0 => nominalIndex!
                nominalIndex! < (nominal! -> len) -> while {
                    nominal![nominalIndex!] => candidateType
                    (candidateType.sourceModule == sourceIndex! and candidateType.typeAst == returnTypeAst) -> if {
                        nominalIndex! => expectedIndex!
                    }
                    nominalIndex! + 1 => nominalIndex!
                }
                -1 => returnExpressionAst!
                -1 => returnExpressionType!
                1000000 => returnDistance!
                0 => expressionTypeIndex!
                expressionTypeIndex! < (expressionTypeTable! -> len) -> while {
                    expressionTypeTable![expressionTypeIndex!] => candidateType
                    candidateType.sourceModule == sourceIndex! -> if {
                        nodes![candidateType.astNode].parent => ancestor!
                        1 => distance!
                        false => belongsToFunction!
                        (ancestor! >= 0 and not belongsToFunction!) -> while {
                            ancestor! == function.astNode -> if {
                                true => belongsToFunction!
                            } else {
                                nodes![ancestor!].parent => ancestor!
                                distance! + 1 => distance!
                            }
                        }
                        (belongsToFunction! and distance! < returnDistance!) -> if {
                            candidateType.astNode => returnExpressionAst!
                            expressionTypeIndex! => returnExpressionType!
                            distance! => returnDistance!
                        }
                    }
                    expressionTypeIndex! + 1 => expressionTypeIndex!
                }
                (expectedIndex! >= 0 and returnExpressionType! >= 0) -> if {
                    nominal![expectedIndex!] => expected
                    nodes![returnExpressionAst!] => returnExpression
                    expressionTypeTable![returnExpressionType!] => actualType
                    (expected.origin != actualType.origin or expected.targetModule != actualType.targetModule or expected.targetSymbol != actualType.targetSymbol) -> if {
                        TypeCheckDiagnostic {
                            code: 5
                            sourceModule: sourceIndex!
                            functionSymbol: symbolIndex!
                            expectedOrigin: expected.origin
                            expectedModule: expected.targetModule
                            expectedSymbol: expected.targetSymbol
                            actualOrigin: actualType.origin
                            actualModule: actualType.targetModule
                            actualSymbol: actualType.targetSymbol
                            actualBuiltin: actualType.origin == 1 -> if { actualType.targetSymbol } else { -1 }
                            span: syntax.SourceSpan {
                                fileId: sourceIndex!
                                start: returnExpression.start
                                length: returnExpression.length
                            }
                        } => diagnostic
                        diagnostics! -> push(diagnostic)
                    }
                }
            }
            symbolIndex! + 1 => symbolIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    diagnostics!
}
