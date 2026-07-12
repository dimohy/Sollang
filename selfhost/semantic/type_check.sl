namespace smalllang.compiler.semantic.type_check

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.resolve as resolution
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
    [TypeCheckDiagnostic; ~] => diagnostics!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> symbols.collect => table!
        source -> resolution.resolve => resolvedNames!
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
                0 => astIndex!
                astIndex! < (nodes! -> len) -> while {
                    nodes![astIndex!] => candidateExpression
                    (candidateExpression.kind == 13 or candidateExpression.kind == 14 or candidateExpression.kind == 15) -> if {
                        candidateExpression.parent => ancestor!
                        false => belongsToFunction!
                        (ancestor! >= 0 and not belongsToFunction!) -> while {
                            ancestor! == function.astNode -> if {
                                true => belongsToFunction!
                            } else {
                                nodes![ancestor!].parent => ancestor!
                            }
                        }
                        belongsToFunction! -> if { astIndex! => returnExpressionAst! }
                    }
                    astIndex! + 1 => astIndex!
                }
                (expectedIndex! >= 0 and returnExpressionAst! >= 0) -> if {
                    nominal![expectedIndex!] => expected
                    nodes![returnExpressionAst!] => returnExpression
                    -1 => actualOrigin!
                    -1 => actualModule!
                    -1 => actualSymbol!
                    returnExpression.kind == 13 -> if {
                        1 => actualOrigin!
                        -1 => actualModule!
                        1 => actualSymbol!
                    }
                    returnExpression.kind == 14 -> if {
                        1 => actualOrigin!
                        -1 => actualModule!
                        2 => actualSymbol!
                    }
                    returnExpression.kind == 15 -> if {
                        -1 => resolvedNameIndex!
                        0 => nameSearch!
                        nameSearch! < (resolvedNames! -> len) -> while {
                            resolvedNames![nameSearch!].astNode == returnExpressionAst! -> if {
                                nameSearch! => resolvedNameIndex!
                            }
                            nameSearch! + 1 => nameSearch!
                        }
                        resolvedNameIndex! >= 0 -> if {
                            resolvedNames![resolvedNameIndex!].symbol => valueSymbolIndex
                            table![valueSymbolIndex] => valueSymbol
                            -1 => valueTypeIndex!
                            0 => valueTypeSearch!
                            valueTypeSearch! < (nominal! -> len) -> while {
                                nominal![valueTypeSearch!] => valueType
                                (valueType.sourceModule == sourceIndex! and valueType.typeAst == valueSymbol.typeNode) -> if {
                                    valueTypeSearch! => valueTypeIndex!
                                }
                                valueTypeSearch! + 1 => valueTypeSearch!
                            }
                            valueTypeIndex! >= 0 -> if {
                                nominal![valueTypeIndex!] => actualType
                                actualType.origin => actualOrigin!
                                actualType.targetModule => actualModule!
                                actualType.targetSymbol => actualSymbol!
                            }
                        }
                    }
                    (actualOrigin! >= 0 and (expected.origin != actualOrigin! or expected.targetModule != actualModule! or expected.targetSymbol != actualSymbol!)) -> if {
                        TypeCheckDiagnostic {
                            code: 5
                            sourceModule: sourceIndex!
                            functionSymbol: symbolIndex!
                            expectedOrigin: expected.origin
                            expectedModule: expected.targetModule
                            expectedSymbol: expected.targetSymbol
                            actualOrigin: actualOrigin!
                            actualModule: actualModule!
                            actualSymbol: actualSymbol!
                            actualBuiltin: actualOrigin! == 1 -> if { actualSymbol! } else { -1 }
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
