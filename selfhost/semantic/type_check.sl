namespace smalllang.compiler.semantic.type_check

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.calls as calls
import smalllang.compiler.semantic.composite_types as compositeTypes
import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.expression_type_ids as expressionTypeIds
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.syntax as syntax
import syntax.generated.smalllang as grammar

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

# Code 5 identifies a mismatching function return expression. Code 6 identifies
# a call argument that does not match the local function input type. Code 7
# identifies an unresolved local call target. Code 8 identifies a binary
# operator whose typed operands are incompatible. Code 9 identifies a
# non-public imported call target. Code 10 identifies missing or extra call
# arguments for the current zero-or-one-input function surface. Code 11 is an
# unknown struct initializer field, code 12 is a field value type mismatch, and
# code 13 identifies a required field missing from a struct literal. Code 14 is
# an unknown value member on a resolved struct type. Code 15 identifies an
# indexed value that is not array-like, code 16 identifies a non-Int index,
# and code 17 identifies role syntax targeting a function without a block
# input contract.
public analyze sources: [Text; ~] -> [TypeCheckDiagnostic; ~] {
    sources -> nominalTypes.resolve => nominal!
    sources -> compositeTypes.resolve => composite!
    sources -> expressionTypes.infer => expressionTypeTable!
    sources -> expressionTypeIds.resolve => recursiveTypes
    sources -> calls.resolveModules => moduleCalls!
    sources -> modules.identities => moduleIdentities!
    [TypeCheckDiagnostic; ~] => diagnostics!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> lexer.lex => tokens!
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
                -1 => expectedCompositeIndex!
                0 => nominalIndex!
                nominalIndex! < (nominal! -> len) -> while {
                    nominal![nominalIndex!] => candidateType
                    (candidateType.sourceModule == sourceIndex! and candidateType.typeAst == returnTypeAst) -> if {
                        nominalIndex! => expectedIndex!
                    }
                    nominalIndex! + 1 => nominalIndex!
                }
                0 => expectedCompositeSearch!
                expectedCompositeSearch! < (composite! -> len) -> while {
                    composite![expectedCompositeSearch!] => candidateComposite
                    (candidateComposite.sourceModule == sourceIndex! and candidateComposite.typeAst == returnTypeAst) -> if {
                        expectedCompositeSearch! => expectedCompositeIndex!
                    }
                    expectedCompositeSearch! + 1 => expectedCompositeSearch!
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
                        (belongsToFunction! and (distance! < returnDistance! or (distance! == returnDistance! and (returnExpressionAst! < 0 or nodes![candidateType.astNode].start > nodes![returnExpressionAst!].start)))) -> if {
                            candidateType.astNode => returnExpressionAst!
                            expressionTypeIndex! => returnExpressionType!
                            distance! => returnDistance!
                        }
                    }
                    expressionTypeIndex! + 1 => expressionTypeIndex!
                }
                returnExpressionType! >= 0 -> if {
                    nodes![returnExpressionAst!].parent => outerExpression!
                    false => blockedByUntypedOuter!
                    (outerExpression! >= 0 and outerExpression! != function.astNode and not blockedByUntypedOuter!) -> while {
                        nodes![outerExpression!] => outerNode
                        ((outerNode.kind >= 18 and outerNode.kind <= 25) or outerNode.kind == 11 or outerNode.kind == 36 or outerNode.kind == 37 or outerNode.kind == 38 or outerNode.kind == 39 or outerNode.kind == 41) -> if {
                            false => outerInferred!
                            0 => outerTypeSearch!
                            outerTypeSearch! < (expressionTypeTable! -> len) -> while {
                                expressionTypeTable![outerTypeSearch!] => outerType
                                (outerType.sourceModule == sourceIndex! and outerType.astNode == outerExpression!) -> if { true => outerInferred! }
                                (outerType.sourceModule == sourceIndex! and nodes![outerType.astNode].start == outerNode.start and nodes![outerType.astNode].length == outerNode.length) -> if { true => outerInferred! }
                                outerTypeSearch! + 1 => outerTypeSearch!
                            }
                            not outerInferred! -> if { true => blockedByUntypedOuter! }
                        }
                        nodes![outerExpression!].parent => outerExpression!
                    }
                    blockedByUntypedOuter! -> if {
                        -1 => returnExpressionType!
                        -1 => returnExpressionAst!
                    }
                }
                -1 => expectedRecursiveReference!
                0 => expectedRecursiveSearch!
                (expectedRecursiveSearch! < (recursiveTypes.references -> len) and expectedRecursiveReference! < 0) -> while {
                    recursiveTypes.references[expectedRecursiveSearch!] => candidate
                    (candidate.sourceModule == sourceIndex! and candidate.typeAst == returnTypeAst) -> if {
                        expectedRecursiveSearch! => expectedRecursiveReference!
                    }
                    expectedRecursiveSearch! + 1 => expectedRecursiveSearch!
                }
                -1 => recursiveReturnExpression!
                1000000 => recursiveReturnDistance!
                0 => recursiveReturnSearch!
                recursiveReturnSearch! < (recursiveTypes.expressions -> len) -> while {
                    recursiveTypes.expressions[recursiveReturnSearch!] => candidate
                    candidate.sourceModule == sourceIndex! -> if {
                        nodes![candidate.astNode].parent => ancestor!
                        1 => distance!
                        false => belongsToFunction!
                        (ancestor! >= 0 and not belongsToFunction!) -> while {
                            ancestor! == function.astNode -> if { true => belongsToFunction! } else {
                                nodes![ancestor!].parent => ancestor!
                                distance! + 1 => distance!
                            }
                        }
                        (belongsToFunction! and (distance! < recursiveReturnDistance! or (distance! == recursiveReturnDistance! and (recursiveReturnExpression! < 0 or nodes![candidate.astNode].start > nodes![recursiveTypes.expressions[recursiveReturnExpression!].astNode].start)))) -> if {
                            recursiveReturnSearch! => recursiveReturnExpression!
                            distance! => recursiveReturnDistance!
                        }
                    }
                    recursiveReturnSearch! + 1 => recursiveReturnSearch!
                }
                false => recursiveReturnChecked!
                false => recursiveReturnMismatch!
                (expectedRecursiveReference! >= 0 and recursiveReturnExpression! >= 0) -> if {
                    recursiveTypes.references[expectedRecursiveReference!] => expectedReference
                    recursiveTypes.expressions[recursiveReturnExpression!] => actualReference
                    recursiveTypes.types[expectedReference.typeId] => expectedType
                    recursiveTypes.types[actualReference.typeId] => actualType
                    nodes![actualReference.astNode].parent == function.astNode => directRecursiveReturn
                    (directRecursiveReturn and expectedReference.status == 0 and actualReference.status == 0 and not expectedType.containsParameter and not actualType.containsParameter) -> if {
                        true => recursiveReturnChecked!
                        expectedReference.typeId != actualReference.typeId -> if {
                            true => recursiveReturnMismatch!
                        }
                    }
                }
                ((not recursiveReturnChecked! or recursiveReturnMismatch!) and expectedIndex! >= 0 and returnExpressionType! >= 0) -> if {
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
                ((not recursiveReturnChecked! or recursiveReturnMismatch!) and expectedCompositeIndex! >= 0 and returnExpressionType! >= 0) -> if {
                    composite![expectedCompositeIndex!] => expectedComposite
                    expressionTypeTable![returnExpressionType!] => actualType
                    10 + expectedComposite.kind => expectedShape
                    true => compositeReturnMatches!
                    expectedComposite.kind == 5 -> if {
                        actualType.origin != expectedShape -> if { false => compositeReturnMatches! }
                        (expectedComposite.keyOrigin != 3 and (actualType.keyOrigin != expectedComposite.keyOrigin or actualType.keyModule != expectedComposite.keyModule or actualType.targetModule != expectedComposite.keySymbol)) -> if { false => compositeReturnMatches! }
                        (expectedComposite.valueOrigin != 3 and (actualType.valueOrigin != expectedComposite.valueOrigin or actualType.valueModule != expectedComposite.valueModule or actualType.targetSymbol != expectedComposite.valueSymbol)) -> if { false => compositeReturnMatches! }
                    } else {
                        expectedComposite.elementOrigin != 3 -> if {
                            (actualType.origin != expectedShape or actualType.targetModule != expectedComposite.elementModule or actualType.targetSymbol != expectedComposite.elementSymbol) -> if { false => compositeReturnMatches! }
                        }
                    }
                    not compositeReturnMatches! -> if {
                        nodes![returnExpressionAst!] => returnExpression
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 5
                            sourceModule: sourceIndex!
                            functionSymbol: symbolIndex!
                            expectedOrigin: expectedShape
                            expectedModule: expectedComposite.kind == 5 -> if { expectedComposite.keySymbol } else { expectedComposite.elementModule }
                            expectedSymbol: expectedComposite.kind == 5 -> if { expectedComposite.valueSymbol } else { expectedComposite.elementSymbol }
                            actualOrigin: actualType.origin
                            actualModule: actualType.targetModule
                            actualSymbol: actualType.targetSymbol
                            actualBuiltin: -1
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: returnExpression.start, length: returnExpression.length }
                        })
                    }
                }
                recursiveReturnMismatch! -> if {
                    false => existingReturnDiagnostic!
                    0 => existingReturnSearch!
                    existingReturnSearch! < (diagnostics! -> len) -> while {
                        diagnostics![existingReturnSearch!] => existing
                        (existing.code == 5 and existing.sourceModule == sourceIndex! and existing.functionSymbol == symbolIndex!) -> if {
                            true => existingReturnDiagnostic!
                        }
                        existingReturnSearch! + 1 => existingReturnSearch!
                    }
                    not existingReturnDiagnostic! -> if {
                        recursiveTypes.references[expectedRecursiveReference!] => expectedReference
                        recursiveTypes.expressions[recursiveReturnExpression!] => actualReference
                        recursiveTypes.types[expectedReference.typeId] => expectedType
                        recursiveTypes.types[actualReference.typeId] => actualType
                        nodes![actualReference.astNode] => returnExpression
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 5
                            sourceModule: sourceIndex!
                            functionSymbol: symbolIndex!
                            expectedOrigin: expectedType.kind == 1 -> if { expectedType.origin } else { 10 + expectedType.kind }
                            expectedModule: expectedType.module
                            expectedSymbol: expectedType.symbol
                            actualOrigin: actualType.kind == 1 -> if { actualType.origin } else { 10 + actualType.kind }
                            actualModule: actualType.module
                            actualSymbol: actualType.symbol
                            actualBuiltin: (actualType.kind == 1 and actualType.origin == 1) -> if { actualType.symbol } else { -1 }
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: returnExpression.start, length: returnExpression.length }
                        })
                    }
                }
            }
            symbolIndex! + 1 => symbolIndex!
        }

        0 => callIndex!
        callIndex! < (moduleCalls! -> len) -> while {
            moduleCalls![callIndex!] => call
            (call.sourceModule == sourceIndex! and call.status == 0 and call.targetSourceModule >= 0) -> if {
                sources[call.targetSourceModule] -> symbols.collect => targetTable!
                targetTable![call.functionSymbol] => targetFunction
                nodes![call.callAst] => callNode
                false => invalidRoleTarget!
                (callNode.kind == 48 and targetFunction.blockTypeNode < 0) -> if {
                    true => invalidRoleTarget!
                    diagnostics! -> push(TypeCheckDiagnostic {
                        code: 17
                        sourceModule: sourceIndex!
                        functionSymbol: call.functionSymbol
                        expectedOrigin: -1
                        expectedModule: call.targetModule
                        expectedSymbol: -1
                        actualOrigin: -1
                        actualModule: -1
                        actualSymbol: -1
                        actualBuiltin: -1
                        span: syntax.SourceSpan { fileId: sourceIndex!, start: callNode.start, length: callNode.length }
                    })
                }
                not invalidRoleTarget! -> if {
                false => afterLeftParen!
                false => hasArgument!
                callNode.firstToken => callTokenIndex!
                callTokenIndex! < callNode.firstToken + callNode.tokenCount -> while {
                    tokens![callTokenIndex!].kind == grammar.tokenIdLeftParen -> if {
                        true => afterLeftParen!
                    } else {
                        (afterLeftParen! and tokens![callTokenIndex!].kind != grammar.tokenIdRightParen and tokens![callTokenIndex!].kind != grammar.triviaIdWhitespace and tokens![callTokenIndex!].kind != grammar.triviaIdComment) -> if {
                            true => hasArgument!
                        }
                    }
                    callTokenIndex! + 1 => callTokenIndex!
                }
                callNode.kind == 48 -> if { true => hasArgument! }
                targetFunction.secondaryTypeNode >= 0 -> if {
                    -1 => expectedInputIndex!
                    -1 => expectedInputCompositeIndex!
                    0 => inputSearch!
                    inputSearch! < (nominal! -> len) -> while {
                        nominal![inputSearch!] => inputType
                        (inputType.sourceModule == call.targetSourceModule and inputType.typeAst == targetFunction.typeNode) -> if {
                            inputSearch! => expectedInputIndex!
                        }
                        inputSearch! + 1 => inputSearch!
                    }
                    0 => inputCompositeSearch!
                    inputCompositeSearch! < (composite! -> len) -> while {
                        composite![inputCompositeSearch!] => inputCompositeCandidate
                        (inputCompositeCandidate.sourceModule == call.targetSourceModule and inputCompositeCandidate.typeAst == targetFunction.typeNode) -> if {
                            inputCompositeSearch! => expectedInputCompositeIndex!
                        }
                        inputCompositeSearch! + 1 => inputCompositeSearch!
                    }
                    -1 => actualArgumentIndex!
                    1000000 => argumentDistance!
                    0 => argumentSearch!
                    argumentSearch! < (expressionTypeTable! -> len) -> while {
                        expressionTypeTable![argumentSearch!] => argumentType
                        argumentType.sourceModule == sourceIndex! -> if {
                            true => beforeRoleTarget!
                            callNode.kind == 48 -> if {
                                nodes![argumentType.astNode] => argumentNode
                                argumentNode.start + argumentNode.length > tokens![callNode.payloadToken].span.start -> if {
                                    false => beforeRoleTarget!
                                }
                            }
                            nodes![argumentType.astNode].parent => argumentAncestor!
                            1 => distance!
                            false => belongsToCall!
                            (argumentAncestor! >= 0 and not belongsToCall!) -> while {
                                argumentAncestor! == call.callAst -> if {
                                    true => belongsToCall!
                                } else {
                                    nodes![argumentAncestor!].parent => argumentAncestor!
                                    distance! + 1 => distance!
                                }
                            }
                            (belongsToCall! and beforeRoleTarget! and distance! < argumentDistance!) -> if {
                                argumentSearch! => actualArgumentIndex!
                                distance! => argumentDistance!
                            }
                        }
                        argumentSearch! + 1 => argumentSearch!
                    }
                    -1 => expectedInputReference!
                    0 => expectedInputReferenceSearch!
                    (expectedInputReferenceSearch! < (recursiveTypes.references -> len) and expectedInputReference! < 0) -> while {
                        recursiveTypes.references[expectedInputReferenceSearch!] => candidate
                        (candidate.sourceModule == call.targetSourceModule and candidate.typeAst == targetFunction.typeNode) -> if {
                            expectedInputReferenceSearch! => expectedInputReference!
                        }
                        expectedInputReferenceSearch! + 1 => expectedInputReferenceSearch!
                    }
                    -1 => recursiveArgumentExpression!
                    1000000 => recursiveArgumentDistance!
                    0 => recursiveArgumentSearch!
                    recursiveArgumentSearch! < (recursiveTypes.expressions -> len) -> while {
                        recursiveTypes.expressions[recursiveArgumentSearch!] => candidate
                        candidate.sourceModule == sourceIndex! -> if {
                            true => beforeRoleTarget!
                            callNode.kind == 48 -> if {
                                nodes![candidate.astNode] => argumentNode
                                argumentNode.start + argumentNode.length > tokens![callNode.payloadToken].span.start -> if { false => beforeRoleTarget! }
                            }
                            nodes![candidate.astNode].parent => argumentAncestor!
                            1 => distance!
                            false => belongsToCall!
                            (argumentAncestor! >= 0 and not belongsToCall!) -> while {
                                argumentAncestor! == call.callAst -> if { true => belongsToCall! } else {
                                    nodes![argumentAncestor!].parent => argumentAncestor!
                                    distance! + 1 => distance!
                                }
                            }
                            (belongsToCall! and beforeRoleTarget! and distance! < recursiveArgumentDistance!) -> if {
                                recursiveArgumentSearch! => recursiveArgumentExpression!
                                distance! => recursiveArgumentDistance!
                            }
                        }
                        recursiveArgumentSearch! + 1 => recursiveArgumentSearch!
                    }
                    false => recursiveArgumentChecked!
                    false => recursiveArgumentMismatch!
                    (expectedInputReference! >= 0 and recursiveArgumentExpression! >= 0) -> if {
                        recursiveTypes.references[expectedInputReference!] => expectedReference
                        recursiveTypes.expressions[recursiveArgumentExpression!] => actualReference
                        recursiveTypes.types[expectedReference.typeId] => expectedType
                        recursiveTypes.types[actualReference.typeId] => actualType
                        nodes![actualReference.astNode].parent == call.callAst => directRecursiveArgument
                        (actualArgumentIndex! >= 0 and expressionTypeTable![actualArgumentIndex!].astNode == actualReference.astNode) => sameRecursiveArgumentSurface
                        ((directRecursiveArgument or sameRecursiveArgumentSurface) and expectedReference.status == 0 and actualReference.status == 0 and not expectedType.containsParameter and not actualType.containsParameter) -> if {
                            true => recursiveArgumentChecked!
                            expectedReference.typeId != actualReference.typeId -> if {
                                true => recursiveArgumentMismatch!
                            }
                        }
                    }
                    ((not recursiveArgumentChecked! or recursiveArgumentMismatch!) and expectedInputIndex! >= 0 and actualArgumentIndex! >= 0) -> if {
                        nominal![expectedInputIndex!] => expected
                        expressionTypeTable![actualArgumentIndex!] => actual
                        (expected.origin != 3 and (expected.origin != actual.origin or expected.targetModule != actual.targetModule or expected.targetSymbol != actual.targetSymbol)) -> if {
                            nodes![actual.astNode] => argumentExpression
                            diagnostics! -> push(TypeCheckDiagnostic {
                                code: 6
                                sourceModule: sourceIndex!
                                functionSymbol: call.functionSymbol
                                expectedOrigin: expected.origin
                                expectedModule: expected.targetModule
                                expectedSymbol: expected.targetSymbol
                                actualOrigin: actual.origin
                                actualModule: actual.targetModule
                                actualSymbol: actual.targetSymbol
                                actualBuiltin: actual.origin == 1 -> if { actual.targetSymbol } else { -1 }
                                span: syntax.SourceSpan {
                                    fileId: sourceIndex!
                                    start: argumentExpression.start
                                    length: argumentExpression.length
                                }
                            })
                        }
                    }
                    ((not recursiveArgumentChecked! or recursiveArgumentMismatch!) and expectedInputCompositeIndex! >= 0 and actualArgumentIndex! >= 0) -> if {
                        composite![expectedInputCompositeIndex!] => expectedComposite
                        expressionTypeTable![actualArgumentIndex!] => actual
                        10 + expectedComposite.kind => expectedShape
                        false => compositeMatches!
                        actual.origin == expectedShape -> if {
                            expectedComposite.kind == 5 -> if {
                                true => compositeMatches!
                                (expectedComposite.keyOrigin != 3 and (actual.keyOrigin != expectedComposite.keyOrigin or actual.keyModule != expectedComposite.keyModule or actual.targetModule != expectedComposite.keySymbol)) -> if { false => compositeMatches! }
                                (expectedComposite.valueOrigin != 3 and (actual.valueOrigin != expectedComposite.valueOrigin or actual.valueModule != expectedComposite.valueModule or actual.targetSymbol != expectedComposite.valueSymbol)) -> if { false => compositeMatches! }
                            } else {
                                expectedComposite.elementOrigin == 3 -> if {
                                    true => compositeMatches!
                                } else {
                                    (actual.targetModule == expectedComposite.elementModule and actual.targetSymbol == expectedComposite.elementSymbol) -> if { true => compositeMatches! }
                                }
                            }
                        }
                        not compositeMatches! -> if {
                            nodes![actual.astNode] => argumentExpression
                            diagnostics! -> push(TypeCheckDiagnostic {
                                code: 6
                                sourceModule: sourceIndex!
                                functionSymbol: call.functionSymbol
                                expectedOrigin: expectedShape
                                expectedModule: expectedComposite.kind == 5 -> if { expectedComposite.keySymbol } else { expectedComposite.elementModule }
                                expectedSymbol: expectedComposite.kind == 5 -> if { expectedComposite.valueSymbol } else { expectedComposite.elementSymbol }
                                actualOrigin: actual.origin
                                actualModule: actual.targetModule
                                actualSymbol: actual.targetSymbol
                                actualBuiltin: -1
                                span: syntax.SourceSpan { fileId: sourceIndex!, start: argumentExpression.start, length: argumentExpression.length }
                            })
                        }
                    }
                    recursiveArgumentMismatch! -> if {
                        false => existingArgumentDiagnostic!
                        0 => existingArgumentSearch!
                        existingArgumentSearch! < (diagnostics! -> len) -> while {
                            diagnostics![existingArgumentSearch!] => existing
                            (existing.code == 6 and existing.sourceModule == sourceIndex! and existing.span.start >= callNode.start and existing.span.start + existing.span.length <= callNode.start + callNode.length) -> if {
                                true => existingArgumentDiagnostic!
                            }
                            existingArgumentSearch! + 1 => existingArgumentSearch!
                        }
                        not existingArgumentDiagnostic! -> if {
                            recursiveTypes.references[expectedInputReference!] => expectedReference
                            recursiveTypes.expressions[recursiveArgumentExpression!] => actualReference
                            recursiveTypes.types[expectedReference.typeId] => expectedType
                            recursiveTypes.types[actualReference.typeId] => actualType
                            nodes![actualReference.astNode] => argumentExpression
                            diagnostics! -> push(TypeCheckDiagnostic {
                                code: 6
                                sourceModule: sourceIndex!
                                functionSymbol: call.functionSymbol
                                expectedOrigin: expectedType.kind == 1 -> if { expectedType.origin } else { 10 + expectedType.kind }
                                expectedModule: expectedType.module
                                expectedSymbol: expectedType.symbol
                                actualOrigin: actualType.kind == 1 -> if { actualType.origin } else { 10 + actualType.kind }
                                actualModule: actualType.module
                                actualSymbol: actualType.symbol
                                actualBuiltin: (actualType.kind == 1 and actualType.origin == 1) -> if { actualType.symbol } else { -1 }
                                span: syntax.SourceSpan { fileId: sourceIndex!, start: argumentExpression.start, length: argumentExpression.length }
                            })
                        }
                    }
                    not hasArgument! -> if {
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 10
                            sourceModule: sourceIndex!
                            functionSymbol: call.functionSymbol
                            expectedOrigin: -1
                            expectedModule: call.targetModule
                            expectedSymbol: -1
                            actualOrigin: -1
                            actualModule: -1
                            actualSymbol: -1
                            actualBuiltin: -1
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: callNode.start, length: callNode.length }
                        })
                    }
                } else {
                    true -> if {
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 10
                            sourceModule: sourceIndex!
                            functionSymbol: call.functionSymbol
                            expectedOrigin: -1
                            expectedModule: call.targetModule
                            expectedSymbol: -1
                            actualOrigin: -1
                            actualModule: -1
                            actualSymbol: -1
                            actualBuiltin: -1
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: callNode.start, length: callNode.length }
                        })
                    }
                }
                }
            } else {
                (call.sourceModule == sourceIndex! and call.targetSourceModule >= 0) -> if {
                nodes![call.callAst] => unresolvedCall
                diagnostics! -> push(TypeCheckDiagnostic {
                    code: call.status == 3 -> if { 9 } else { 7 }
                    sourceModule: sourceIndex!
                    functionSymbol: -1
                    expectedOrigin: -1
                    expectedModule: -1
                    expectedSymbol: -1
                    actualOrigin: -1
                    actualModule: -1
                    actualSymbol: -1
                    actualBuiltin: -1
                    span: syntax.SourceSpan {
                        fileId: sourceIndex!
                        start: unresolvedCall.start
                        length: unresolvedCall.length
                    }
                })
                }
            }
            callIndex! + 1 => callIndex!
        }

        0 => initializerIndex!
        initializerIndex! < (nodes! -> len) -> while {
            nodes![initializerIndex!] => initializer
            initializer.kind == 40 -> if {
                initializer.parent => literalAst!
                (literalAst! >= 0 and nodes![literalAst!].kind != 39) -> while {
                    nodes![literalAst!].parent => literalAst!
                }
                -1 => literalTypeIndex!
                0 => literalTypeSearch!
                literalTypeSearch! < (expressionTypeTable! -> len) -> while {
                    expressionTypeTable![literalTypeSearch!] => literalTypeCandidate
                    (literalTypeCandidate.sourceModule == sourceIndex! and literalTypeCandidate.astNode == literalAst!) -> if {
                        literalTypeSearch! => literalTypeIndex!
                    }
                    literalTypeSearch! + 1 => literalTypeSearch!
                }
                literalTypeIndex! >= 0 -> if {
                    expressionTypeTable![literalTypeIndex!] => literalType
                    sourceIndex! => targetSourceModule!
                    literalType.origin == 2 -> if {
                        moduleIdentities![literalType.targetModule].sourceIndex => targetSourceModule!
                    }
                    sources[targetSourceModule!] -> symbols.collect => targetTable!
                    sources[targetSourceModule!] -> lexer.lex => targetTokens!
                    -1 => fieldSymbol!
                    0 => fieldSearch!
                    (fieldSearch! < (targetTable! -> len) and fieldSymbol! < 0) -> while {
                        targetTable![fieldSearch!] => fieldCandidate
                        (fieldCandidate.kind == 26 and fieldCandidate.parent == literalType.targetSymbol) -> if {
                            tokens![initializer.payloadToken] => initializerName
                            targetTokens![fieldCandidate.nameToken] => fieldName
                            initializerName.span.length == fieldName.span.length => equal!
                            UIntSize(0) => fieldByte!
                            (equal! and fieldByte! < initializerName.span.length) -> while {
                                source -> byte(initializerName.span.start + fieldByte!) => leftByte
                                sources[targetSourceModule!] -> byte(fieldName.span.start + fieldByte!) => rightByte
                                leftByte != rightByte -> if { false => equal! }
                                fieldByte! + UIntSize(1) => fieldByte!
                            }
                            equal! -> if { fieldSearch! => fieldSymbol! }
                        }
                        fieldSearch! + 1 => fieldSearch!
                    }
                    fieldSymbol! < 0 -> if {
                        tokens![initializer.payloadToken] => unknownField
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 11
                            sourceModule: sourceIndex!
                            functionSymbol: -1
                            expectedOrigin: -1
                            expectedModule: literalType.targetModule
                            expectedSymbol: -1
                            actualOrigin: -1
                            actualModule: -1
                            actualSymbol: -1
                            actualBuiltin: -1
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: unknownField.span.start, length: unknownField.span.length }
                        })
                    } else {
                        -1 => initializerValueType!
                        1000000 => initializerValueDistance!
                        0 => valueTypeSearch!
                        valueTypeSearch! < (expressionTypeTable! -> len) -> while {
                            expressionTypeTable![valueTypeSearch!] => valueType
                            valueType.sourceModule == sourceIndex! -> if {
                                nodes![valueType.astNode].parent => valueAncestor!
                                1 => distance!
                                false => belongsToInitializer!
                                (valueAncestor! >= 0 and not belongsToInitializer!) -> while {
                                    valueAncestor! == initializerIndex! -> if { true => belongsToInitializer! } else {
                                        nodes![valueAncestor!].parent => valueAncestor!
                                        distance! + 1 => distance!
                                    }
                                }
                                (belongsToInitializer! and distance! < initializerValueDistance!) -> if {
                                    valueTypeSearch! => initializerValueType!
                                    distance! => initializerValueDistance!
                                }
                            }
                            valueTypeSearch! + 1 => valueTypeSearch!
                        }
                        initializerValueType! >= 0 -> if {
                            targetTable![fieldSymbol!] => field
                            -1 => fieldNominalIndex!
                            0 => fieldTypeSearch!
                            fieldTypeSearch! < (nominal! -> len) -> while {
                                nominal![fieldTypeSearch!] => fieldTypeCandidate
                                (fieldTypeCandidate.sourceModule == targetSourceModule! and fieldTypeCandidate.typeAst == field.typeNode) -> if { fieldTypeSearch! => fieldNominalIndex! }
                                fieldTypeSearch! + 1 => fieldTypeSearch!
                            }
                            fieldNominalIndex! >= 0 -> if {
                                nominal![fieldNominalIndex!] => expectedFieldType
                                expressionTypeTable![initializerValueType!] => actualFieldType
                                (expectedFieldType.origin != actualFieldType.origin or expectedFieldType.targetModule != actualFieldType.targetModule or expectedFieldType.targetSymbol != actualFieldType.targetSymbol) -> if {
                                    nodes![actualFieldType.astNode] => fieldValue
                                    diagnostics! -> push(TypeCheckDiagnostic {
                                        code: 12
                                        sourceModule: sourceIndex!
                                        functionSymbol: fieldSymbol!
                                        expectedOrigin: expectedFieldType.origin
                                        expectedModule: expectedFieldType.targetModule
                                        expectedSymbol: expectedFieldType.targetSymbol
                                        actualOrigin: actualFieldType.origin
                                        actualModule: actualFieldType.targetModule
                                        actualSymbol: actualFieldType.targetSymbol
                                        actualBuiltin: actualFieldType.origin == 1 -> if { actualFieldType.targetSymbol } else { -1 }
                                        span: syntax.SourceSpan { fileId: sourceIndex!, start: fieldValue.start, length: fieldValue.length }
                                    })
                                }
                            }
                        }
                    }
                }
            }
            initializerIndex! + 1 => initializerIndex!
        }

        0 => literalCoverageIndex!
        literalCoverageIndex! < (expressionTypeTable! -> len) -> while {
            expressionTypeTable![literalCoverageIndex!] => literalType
            (literalType.sourceModule == sourceIndex! and nodes![literalType.astNode].kind == 39) -> if {
                nodes![literalType.astNode] => literal
                sourceIndex! => targetSourceModule!
                literalType.origin == 2 -> if { moduleIdentities![literalType.targetModule].sourceIndex => targetSourceModule! }
                sources[targetSourceModule!] -> symbols.collect => targetTable!
                sources[targetSourceModule!] -> lexer.lex => targetTokens!
                0 => fieldCoverageIndex!
                fieldCoverageIndex! < (targetTable! -> len) -> while {
                    targetTable![fieldCoverageIndex!] => field
                    (field.kind == 26 and field.parent == literalType.targetSymbol) -> if {
                        false => fieldInitialized!
                        0 => initializerSearch!
                        initializerSearch! < (nodes! -> len) -> while {
                            nodes![initializerSearch!] => candidateInitializer
                            candidateInitializer.kind == 40 -> if {
                                candidateInitializer.parent => candidateLiteral!
                                (candidateLiteral! >= 0 and nodes![candidateLiteral!].kind != 39) -> while {
                                    nodes![candidateLiteral!].parent => candidateLiteral!
                                }
                                candidateLiteral! == literalType.astNode -> if {
                                    tokens![candidateInitializer.payloadToken] => initializerName
                                    targetTokens![field.nameToken] => fieldName
                                    initializerName.span.length == fieldName.span.length => equal!
                                    UIntSize(0) => fieldByte!
                                    (equal! and fieldByte! < initializerName.span.length) -> while {
                                        source -> byte(initializerName.span.start + fieldByte!) => leftByte
                                        sources[targetSourceModule!] -> byte(fieldName.span.start + fieldByte!) => rightByte
                                        leftByte != rightByte -> if { false => equal! }
                                        fieldByte! + UIntSize(1) => fieldByte!
                                    }
                                    equal! -> if { true => fieldInitialized! }
                                }
                            }
                            initializerSearch! + 1 => initializerSearch!
                        }
                        not fieldInitialized! -> if {
                            diagnostics! -> push(TypeCheckDiagnostic {
                                code: 13
                                sourceModule: sourceIndex!
                                functionSymbol: fieldCoverageIndex!
                                expectedOrigin: -1
                                expectedModule: literalType.targetModule
                                expectedSymbol: fieldCoverageIndex!
                                actualOrigin: -1
                                actualModule: -1
                                actualSymbol: -1
                                actualBuiltin: -1
                                span: syntax.SourceSpan { fileId: sourceIndex!, start: literal.start, length: literal.length }
                            })
                        }
                    }
                    fieldCoverageIndex! + 1 => fieldCoverageIndex!
                }
            }
            literalCoverageIndex! + 1 => literalCoverageIndex!
        }

        0 => memberDiagnosticIndex!
        memberDiagnosticIndex! < (nodes! -> len) -> while {
            nodes![memberDiagnosticIndex!] => member
            member.kind == 36 -> if {
                -1 => baseTypeIndex!
                1000000 => baseDistance!
                0 => baseSearch!
                baseSearch! < (expressionTypeTable! -> len) -> while {
                    expressionTypeTable![baseSearch!] => baseType
                    baseType.sourceModule == sourceIndex! -> if {
                        nodes![baseType.astNode].parent => baseAncestor!
                        1 => distance!
                        false => belongsToMember!
                        (baseAncestor! >= 0 and not belongsToMember!) -> while {
                            baseAncestor! == memberDiagnosticIndex! -> if { true => belongsToMember! } else {
                                nodes![baseAncestor!].parent => baseAncestor!
                                distance! + 1 => distance!
                            }
                        }
                        (belongsToMember! and distance! < baseDistance!) -> if {
                            baseSearch! => baseTypeIndex!
                            distance! => baseDistance!
                        }
                    }
                    baseSearch! + 1 => baseSearch!
                }
                baseTypeIndex! >= 0 -> if {
                    expressionTypeTable![baseTypeIndex!] => baseType
                    ((baseType.origin == 0 or baseType.origin == 2) and nodes![baseType.astNode].kind != 39) -> if {
                        sourceIndex! => targetSourceModule!
                        baseType.origin == 2 -> if { moduleIdentities![baseType.targetModule].sourceIndex => targetSourceModule! }
                        sources[targetSourceModule!] -> symbols.collect => targetTable!
                        sources[targetSourceModule!] -> lexer.lex => targetTokens!
                        -1 => memberNameToken!
                        member.firstToken => memberTokenIndex!
                        memberTokenIndex! < member.firstToken + member.tokenCount -> while {
                            tokens![memberTokenIndex!].kind == grammar.tokenIdIdentifier -> if { memberTokenIndex! => memberNameToken! }
                            memberTokenIndex! + 1 => memberTokenIndex!
                        }
                        false => fieldFound!
                        0 => fieldSearch!
                        fieldSearch! < (targetTable! -> len) -> while {
                            targetTable![fieldSearch!] => field
                            (field.kind == 26 and field.parent == baseType.targetSymbol) -> if {
                                tokens![memberNameToken!] => memberName
                                targetTokens![field.nameToken] => fieldName
                                memberName.span.length == fieldName.span.length => equal!
                                UIntSize(0) => fieldByte!
                                (equal! and fieldByte! < memberName.span.length) -> while {
                                    source -> byte(memberName.span.start + fieldByte!) => leftByte
                                    sources[targetSourceModule!] -> byte(fieldName.span.start + fieldByte!) => rightByte
                                    leftByte != rightByte -> if { false => equal! }
                                    fieldByte! + UIntSize(1) => fieldByte!
                                }
                                equal! -> if { true => fieldFound! }
                            }
                            fieldSearch! + 1 => fieldSearch!
                        }
                        not fieldFound! -> if {
                            tokens![memberNameToken!] => unknownMember
                            diagnostics! -> push(TypeCheckDiagnostic {
                                code: 14
                                sourceModule: sourceIndex!
                                functionSymbol: -1
                                expectedOrigin: baseType.origin
                                expectedModule: baseType.targetModule
                                expectedSymbol: baseType.targetSymbol
                                actualOrigin: -1
                                actualModule: -1
                                actualSymbol: -1
                                actualBuiltin: -1
                                span: syntax.SourceSpan { fileId: sourceIndex!, start: unknownMember.span.start, length: unknownMember.span.length }
                            })
                        }
                    }
                }
            }
            memberDiagnosticIndex! + 1 => memberDiagnosticIndex!
        }

        0 => indexDiagnosticIndex!
        indexDiagnosticIndex! < (nodes! -> len) -> while {
            nodes![indexDiagnosticIndex!] => indexAccess
            indexAccess.kind == 41 -> if {
                tokens![indexAccess.payloadToken] => leftBracket
                -1 => indexedValueTypeIndex!
                -1 => indexValueTypeIndex!
                1000000 => indexedValueDistance!
                1000000 => indexValueDistance!
                0 => indexTypeSearch!
                indexTypeSearch! < (expressionTypeTable! -> len) -> while {
                    expressionTypeTable![indexTypeSearch!] => candidateType
                    (candidateType.sourceModule == sourceIndex! and candidateType.astNode != indexDiagnosticIndex!) -> if {
                        nodes![candidateType.astNode] => candidateNode
                        candidateNode.parent => candidateAncestor!
                        1 => candidateDistance!
                        false => belongsToIndex!
                        (candidateAncestor! >= 0 and not belongsToIndex!) -> while {
                            candidateAncestor! == indexDiagnosticIndex! -> if { true => belongsToIndex! } else {
                                nodes![candidateAncestor!].parent => candidateAncestor!
                                candidateDistance! + 1 => candidateDistance!
                            }
                        }
                        belongsToIndex! -> if {
                            candidateNode.start < leftBracket.span.start -> if {
                                candidateDistance! < indexedValueDistance! -> if {
                                    indexTypeSearch! => indexedValueTypeIndex!
                                    candidateDistance! => indexedValueDistance!
                                }
                            } else {
                                candidateDistance! < indexValueDistance! -> if {
                                    indexTypeSearch! => indexValueTypeIndex!
                                    candidateDistance! => indexValueDistance!
                                }
                            }
                        }
                    }
                    indexTypeSearch! + 1 => indexTypeSearch!
                }
                1 => expectedIndexOrigin!
                -1 => expectedIndexModule!
                2 => expectedIndexSymbol!
                indexedValueTypeIndex! >= 0 -> if {
                    expressionTypeTable![indexedValueTypeIndex!] => indexedValueType
                    indexedValueType.origin == 15 -> if {
                        indexedValueType.keyOrigin => expectedIndexOrigin!
                        indexedValueType.keyModule => expectedIndexModule!
                        indexedValueType.targetModule => expectedIndexSymbol!
                    }
                    (indexedValueType.origin < 12 or indexedValueType.origin > 15) -> if {
                        nodes![indexedValueType.astNode] => indexedValueNode
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 15
                            sourceModule: sourceIndex!
                            functionSymbol: -1
                            expectedOrigin: 12
                            expectedModule: -1
                            expectedSymbol: -1
                            actualOrigin: indexedValueType.origin
                            actualModule: indexedValueType.targetModule
                            actualSymbol: indexedValueType.targetSymbol
                            actualBuiltin: indexedValueType.origin == 1 -> if { indexedValueType.targetSymbol } else { -1 }
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: indexedValueNode.start, length: indexedValueNode.length }
                        })
                    }
                }
                indexValueTypeIndex! >= 0 -> if {
                    expressionTypeTable![indexValueTypeIndex!] => indexValueType
                    (indexValueType.origin != expectedIndexOrigin! or indexValueType.targetModule != expectedIndexModule! or indexValueType.targetSymbol != expectedIndexSymbol!) -> if {
                        nodes![indexValueType.astNode] => indexValueNode
                        diagnostics! -> push(TypeCheckDiagnostic {
                            code: 16
                            sourceModule: sourceIndex!
                            functionSymbol: -1
                            expectedOrigin: expectedIndexOrigin!
                            expectedModule: expectedIndexModule!
                            expectedSymbol: expectedIndexSymbol!
                            actualOrigin: indexValueType.origin
                            actualModule: indexValueType.targetModule
                            actualSymbol: indexValueType.targetSymbol
                            actualBuiltin: indexValueType.origin == 1 -> if { indexValueType.targetSymbol } else { -1 }
                            span: syntax.SourceSpan { fileId: sourceIndex!, start: indexValueNode.start, length: indexValueNode.length }
                        })
                    }
                }
            }
            indexDiagnosticIndex! + 1 => indexDiagnosticIndex!
        }

        0 => operatorIndex!
        operatorIndex! < (nodes! -> len) -> while {
            nodes![operatorIndex!] => operator
            ((operator.kind >= 18 and operator.kind <= 22) or operator.kind == 24 or operator.kind == 25) -> if {
                false => operatorInferred!
                -1 => leftTypeIndex!
                -1 => rightTypeIndex!
                1000000 => leftDistance!
                1000000 => rightDistance!
                0 => inferredIndex!
                inferredIndex! < (expressionTypeTable! -> len) -> while {
                    expressionTypeTable![inferredIndex!] => inferredType
                    inferredType.sourceModule == sourceIndex! -> if {
                        inferredType.astNode == operatorIndex! -> if { true => operatorInferred! }
                        (nodes![inferredType.astNode].start == operator.start and nodes![inferredType.astNode].length == operator.length) -> if { true => operatorInferred! }
                        inferredType.astNode != operatorIndex! -> if {
                            nodes![inferredType.astNode].parent => operandAncestor!
                            1 => operandDistance!
                            false => belongsToOperator!
                            (operandAncestor! >= 0 and not belongsToOperator!) -> while {
                                operandAncestor! == operatorIndex! -> if {
                                    true => belongsToOperator!
                                } else {
                                    nodes![operandAncestor!].parent => operandAncestor!
                                    operandDistance! + 1 => operandDistance!
                                }
                            }
                            belongsToOperator! -> if {
                                operandDistance! < leftDistance! -> if {
                                    leftTypeIndex! => rightTypeIndex!
                                    leftDistance! => rightDistance!
                                    inferredIndex! => leftTypeIndex!
                                    operandDistance! => leftDistance!
                                } else {
                                    operandDistance! < rightDistance! -> if {
                                        inferredIndex! => rightTypeIndex!
                                        operandDistance! => rightDistance!
                                    }
                                }
                            }
                        }
                    }
                    inferredIndex! + 1 => inferredIndex!
                }
                (operator.kind == 22 and not operatorInferred! and leftTypeIndex! >= 0) -> if {
                    expressionTypeTable![leftTypeIndex!] => operandType
                    operator.operatorKind == -26 -> if { 23 } else { 2 } => expectedUnaryBuiltin
                    diagnostics! -> push(TypeCheckDiagnostic {
                        code: 8
                        sourceModule: sourceIndex!
                        functionSymbol: -1
                        expectedOrigin: 1
                        expectedModule: -1
                        expectedSymbol: expectedUnaryBuiltin
                        actualOrigin: operandType.origin
                        actualModule: operandType.targetModule
                        actualSymbol: operandType.targetSymbol
                        actualBuiltin: operandType.origin == 1 -> if { operandType.targetSymbol } else { -1 }
                        span: syntax.SourceSpan { fileId: sourceIndex!, start: operator.start, length: operator.length }
                    })
                }
                (operator.kind != 22 and not operatorInferred! and leftTypeIndex! >= 0 and rightTypeIndex! >= 0) -> if {
                    expressionTypeTable![leftTypeIndex!] => leftType
                    expressionTypeTable![rightTypeIndex!] => rightType
                    false => duplicateOperatorDiagnostic!
                    0 => diagnosticIndex!
                    diagnosticIndex! < (diagnostics! -> len) -> while {
                        diagnostics![diagnosticIndex!] => existingDiagnostic
                        (existingDiagnostic.code == 8 and existingDiagnostic.span.fileId == sourceIndex! and existingDiagnostic.span.start == operator.start and existingDiagnostic.span.length == operator.length) -> if {
                            true => duplicateOperatorDiagnostic!
                        }
                        diagnosticIndex! + 1 => diagnosticIndex!
                    }
                    not duplicateOperatorDiagnostic! -> if {
                        diagnostics! -> push(TypeCheckDiagnostic {
                        code: 8
                        sourceModule: sourceIndex!
                        functionSymbol: -1
                        expectedOrigin: leftType.origin
                        expectedModule: leftType.targetModule
                        expectedSymbol: leftType.targetSymbol
                        actualOrigin: rightType.origin
                        actualModule: rightType.targetModule
                        actualSymbol: rightType.targetSymbol
                        actualBuiltin: rightType.origin == 1 -> if { rightType.targetSymbol } else { -1 }
                        span: syntax.SourceSpan {
                            fileId: sourceIndex!
                            start: operator.start
                            length: operator.length
                        }
                        })
                    }
                }
            }
            operatorIndex! + 1 => operatorIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    diagnostics!
}
