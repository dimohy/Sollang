namespace smalllang.compiler.semantic.user_effects

import smalllang.compiler.semantic.context as semanticContext
import smalllang.compiler.semantic.expression_type_ids as expressionTypeIds
import smalllang.compiler.syntax as syntax
import syntax.generated.smalllang as grammar

public struct UserEffectSignature {
    sourceModule: Int
    effectSymbol: Int
    nameToken: Int
    flags: Int
}

public struct UserEffectOperation {
    sourceModule: Int
    effectSymbol: Int
    operationSymbol: Int
    nameToken: Int
    inputTypeNode: Int
    returnTypeNode: Int
    inputTypeId: Int
    returnTypeId: Int
}

public struct UserEffectRequirement {
    sourceModule: Int
    functionSymbol: Int
    effectSourceModule: Int
    effectSymbol: Int
    astNode: Int
    status: Int
}

public struct UserEffectCall {
    sourceModule: Int
    functionSymbol: Int
    effectSourceModule: Int
    effectSymbol: Int
    operationSymbol: Int
    astNode: Int
    status: Int
    argumentTypeId: Int
    returnTypeId: Int
}

# Codes: 1 duplicate operation, 2 unknown effect, 3 private imported effect,
# 4 operation requires the effect in uses, 5 ambiguous operation,
# 6 operation argument type mismatch, 7 operation arity mismatch.
public struct UserEffectDiagnostic {
    code: Int
    sourceModule: Int
    functionSymbol: Int
    effectSourceModule: Int
    effectSymbol: Int
    operationSymbol: Int
    astNode: Int
    expectedTypeId: Int
    actualTypeId: Int
    span: syntax.SourceSpan
}

public struct UserEffectAnalysis {
    signatures: [UserEffectSignature; ~]
    operations: [UserEffectOperation; ~]
    requirements: [UserEffectRequirement; ~]
    calls: [UserEffectCall; ~]
    diagnostics: [UserEffectDiagnostic; ~]
}

struct TokenPairRequest {
    leftSource: Text
    left: syntax.SyntaxToken
    rightSource: Text
    right: syntax.SyntaxToken
}

tokenEqual request: TokenPairRequest -> Bool {
    request.left.span.length == request.right.span.length => equal!
    UIntSize(0) => index!
    (equal! and index! < request.left.span.length) -> while {
        (request.leftSource -> byte(request.left.span.start + index!)) != (request.rightSource -> byte(request.right.span.start + index!)) -> if {
            false => equal!
        }
        index! + UIntSize(1) => index!
    }
    equal!
}

public analyze sources: [Text; ~] -> UserEffectAnalysis {
    sources -> semanticContext.prepare => prepared
    prepared -> analyzeContext
}

public analyzeContext prepared: semanticContext.SemanticSnapshot -> UserEffectAnalysis {
    [UserEffectSignature; ~] => signatures!
    [UserEffectOperation; ~] => operations!
    [UserEffectRequirement; ~] => requirements!
    [UserEffectCall; ~] => calls!
    [UserEffectDiagnostic; ~] => diagnostics!

    # Declarations and their typed operation signatures are ordinary symbols.
    0 => sourceIndex!
    sourceIndex! < (prepared.package.sources -> len) -> while {
        prepared.package.ranges[sourceIndex!] => sourceRange
        0 => symbolIndex!
        symbolIndex! < sourceRange.symbolCount -> while {
            prepared.package.symbols[sourceRange.symbolStart + symbolIndex!] => symbol
            symbol.kind == 50 -> if {
                signatures! -> push(UserEffectSignature {
                    sourceModule: sourceIndex!
                    effectSymbol: symbolIndex!
                    nameToken: symbol.nameToken
                    flags: symbol.flags
                })
            }
            symbol.kind == 51 -> if {
                symbol.typeNode => inputTypeNode!
                symbol.secondaryTypeNode => returnTypeNode!
                symbol.secondaryTypeNode < 0 -> if {
                    -1 => inputTypeNode!
                    symbol.typeNode => returnTypeNode!
                }
                -1 => inputTypeId!
                -1 => returnTypeId!
                0 => operationTypeSearch!
                operationTypeSearch! < (prepared.semantic.references -> len) -> while {
                    prepared.semantic.references[operationTypeSearch!] => operationTypeReference
                    (operationTypeReference.sourceModule == sourceIndex! and operationTypeReference.status == 0) -> if {
                        operationTypeReference.typeAst == inputTypeNode! -> if { operationTypeReference.typeId => inputTypeId! }
                        operationTypeReference.typeAst == returnTypeNode! -> if { operationTypeReference.typeId => returnTypeId! }
                    }
                    operationTypeSearch! + 1 => operationTypeSearch!
                }
                operations! -> push(UserEffectOperation {
                    sourceModule: sourceIndex!
                    effectSymbol: symbol.parent
                    operationSymbol: symbolIndex!
                    nameToken: symbol.nameToken
                    inputTypeNode: inputTypeNode!
                    returnTypeNode: returnTypeNode!
                    inputTypeId: inputTypeId!
                    returnTypeId: returnTypeId!
                })
            }
            symbolIndex! + 1 => symbolIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }

    # Duplicate operation names are rejected within one effect signature.
    0 => leftOperationIndex!
    leftOperationIndex! < (operations! -> len) -> while {
        operations![leftOperationIndex!] => leftOperation
        leftOperationIndex! + 1 => rightOperationIndex!
        rightOperationIndex! < (operations! -> len) -> while {
            operations![rightOperationIndex!] => rightOperation
            (leftOperation.sourceModule == rightOperation.sourceModule and leftOperation.effectSymbol == rightOperation.effectSymbol) -> if {
                prepared.package.sources[leftOperation.sourceModule] -> len => leftSourceLength
                prepared.package.sources[leftOperation.sourceModule] -> slice(UIntSize(0), leftSourceLength) => leftSource
                prepared.package.sources[rightOperation.sourceModule] -> len => rightSourceLength
                prepared.package.sources[rightOperation.sourceModule] -> slice(UIntSize(0), rightSourceLength) => rightSource
                TokenPairRequest {
                    leftSource: leftSource
                    left: prepared.package.tokens[prepared.package.ranges[leftOperation.sourceModule].tokenStart + leftOperation.nameToken]
                    rightSource: rightSource
                    right: prepared.package.tokens[prepared.package.ranges[rightOperation.sourceModule].tokenStart + rightOperation.nameToken]
                } -> tokenEqual -> if {
                    prepared.package.symbols[prepared.package.ranges[rightOperation.sourceModule].symbolStart + rightOperation.operationSymbol] => duplicateSymbol
                    prepared.package.nodes[prepared.package.ranges[rightOperation.sourceModule].astStart + duplicateSymbol.astNode] => duplicateNode
                    diagnostics! -> push(UserEffectDiagnostic {
                        code: 1
                        sourceModule: rightOperation.sourceModule
                        functionSymbol: -1
                        effectSourceModule: rightOperation.sourceModule
                        effectSymbol: rightOperation.effectSymbol
                        operationSymbol: rightOperation.operationSymbol
                        astNode: duplicateSymbol.astNode
                        expectedTypeId: -1
                        actualTypeId: -1
                        span: syntax.SourceSpan { fileId: rightOperation.sourceModule, start: duplicateNode.start, length: duplicateNode.length }
                    })
                }
            }
            rightOperationIndex! + 1 => rightOperationIndex!
        }
        leftOperationIndex! + 1 => leftOperationIndex!
    }

    # Resolve every user effect reference in a function uses clause. Local
    # effects use lexical names; imported effects reuse qualified module facts.
    0 => requirementSourceIndex!
    requirementSourceIndex! < (prepared.package.sources -> len) -> while {
        prepared.package.sources[requirementSourceIndex!] -> len => requirementSourceLength
        prepared.package.sources[requirementSourceIndex!] -> slice(UIntSize(0), requirementSourceLength) => requirementSource
        prepared.package.ranges[requirementSourceIndex!] => requirementRange
        0 => requirementAstIndex!
        requirementAstIndex! < requirementRange.astCount -> while {
            prepared.package.nodes[requirementRange.astStart + requirementAstIndex!] => requirementNode
            requirementNode.kind == 52 -> if {
                requirementNode.parent => requirementAncestor!
                -1 => requirementFunctionAst!
                (requirementAncestor! >= 0 and requirementFunctionAst! < 0) -> while {
                    prepared.package.nodes[requirementRange.astStart + requirementAncestor!] => ancestorNode
                    ancestorNode.kind == 7 -> if { requirementAncestor! => requirementFunctionAst! } else { ancestorNode.parent => requirementAncestor! }
                }
                -1 => requirementFunctionSymbol!
                0 => functionSearch!
                (functionSearch! < requirementRange.symbolCount and requirementFunctionSymbol! < 0) -> while {
                    prepared.package.symbols[requirementRange.symbolStart + functionSearch!] => functionCandidate
                    (functionCandidate.kind == 7 and functionCandidate.astNode == requirementFunctionAst!) -> if { functionSearch! => requirementFunctionSymbol! }
                    functionSearch! + 1 => functionSearch!
                }

                -1 => referenceNameToken!
                requirementNode.firstToken => referenceTokenIndex!
                referenceTokenIndex! < requirementNode.firstToken + requirementNode.tokenCount -> while {
                    prepared.package.tokens[requirementRange.tokenStart + referenceTokenIndex!].kind == grammar.tokenIdIdentifier -> if { referenceTokenIndex! => referenceNameToken! }
                    referenceTokenIndex! + 1 => referenceTokenIndex!
                }
                -1 => effectSourceModule!
                -1 => effectSymbol!
                2 => requirementStatus!
                0 => localSignatureIndex!
                localSignatureIndex! < (signatures! -> len) -> while {
                    signatures![localSignatureIndex!] => signature
                    signature.sourceModule == requirementSourceIndex! -> if {
                        prepared.package.sources[signature.sourceModule] -> len => signatureSourceLength
                        prepared.package.sources[signature.sourceModule] -> slice(UIntSize(0), signatureSourceLength) => signatureSource
                        TokenPairRequest {
                            leftSource: requirementSource
                            left: prepared.package.tokens[requirementRange.tokenStart + referenceNameToken!]
                            rightSource: signatureSource
                            right: prepared.package.tokens[prepared.package.ranges[signature.sourceModule].tokenStart + signature.nameToken]
                        } -> tokenEqual -> if {
                            signature.sourceModule => effectSourceModule!
                            signature.effectSymbol => effectSymbol!
                            0 => requirementStatus!
                        }
                    }
                    localSignatureIndex! + 1 => localSignatureIndex!
                }
                0 => qualifiedIndex!
                qualifiedIndex! < (prepared.qualified -> len) -> while {
                    prepared.qualified[qualifiedIndex!] => qualifiedEffect
                    (qualifiedEffect.sourceModule == requirementSourceIndex! and effectSymbol! < 0) -> if {
                        qualifiedEffect.pathAst => qualifiedAncestor!
                        false => belongsToReference!
                        (qualifiedAncestor! >= 0 and not belongsToReference!) -> while {
                            qualifiedAncestor! == requirementAstIndex! -> if { true => belongsToReference! } else {
                                prepared.package.nodes[requirementRange.astStart + qualifiedAncestor!].parent => qualifiedAncestor!
                            }
                        }
                        belongsToReference! -> if {
                            prepared.modules[qualifiedEffect.targetModule].sourceIndex => targetSourceModule
                            prepared.package.ranges[targetSourceModule] => targetRange
                            (qualifiedEffect.targetSymbol >= 0 and prepared.package.symbols[targetRange.symbolStart + qualifiedEffect.targetSymbol].kind == 50) -> if {
                                targetSourceModule => effectSourceModule!
                                qualifiedEffect.targetSymbol => effectSymbol!
                                qualifiedEffect.status => requirementStatus!
                            }
                        }
                    }
                    qualifiedIndex! + 1 => qualifiedIndex!
                }
                requirements! -> push(UserEffectRequirement {
                    sourceModule: requirementSourceIndex!
                    functionSymbol: requirementFunctionSymbol!
                    effectSourceModule: effectSourceModule!
                    effectSymbol: effectSymbol!
                    astNode: requirementAstIndex!
                    status: requirementStatus!
                })
                requirementStatus! != 0 -> if {
                    diagnostics! -> push(UserEffectDiagnostic {
                        code: requirementStatus! == 3 -> if { 3 } else { 2 }
                        sourceModule: requirementSourceIndex!
                        functionSymbol: requirementFunctionSymbol!
                        effectSourceModule: effectSourceModule!
                        effectSymbol: effectSymbol!
                        operationSymbol: -1
                        astNode: requirementAstIndex!
                        expectedTypeId: -1
                        actualTypeId: -1
                        span: syntax.SourceSpan { fileId: requirementSourceIndex!, start: requirementNode.start, length: requirementNode.length }
                    })
                }
            }
            requirementAstIndex! + 1 => requirementAstIndex!
        }
        requirementSourceIndex! + 1 => requirementSourceIndex!
    }

    # Resolve bare operation calls against the caller's declared user effects.
    # Ordinary resolved functions win, so an operation never steals a lexical
    # function call with the same name.
    0 => callSourceIndex!
    callSourceIndex! < (prepared.package.sources -> len) -> while {
        prepared.package.sources[callSourceIndex!] -> len => callSourceLength
        prepared.package.sources[callSourceIndex!] -> slice(UIntSize(0), callSourceLength) => callSource
        prepared.package.ranges[callSourceIndex!] => callRange
        0 => callAstIndex!
        callAstIndex! < callRange.astCount -> while {
            prepared.package.nodes[callRange.astStart + callAstIndex!] => callNode
            false => flowArrow!
            callNode.firstToken => arrowSearch!
            arrowSearch! < callNode.firstToken + callNode.tokenCount -> while {
                prepared.package.tokens[callRange.tokenStart + arrowSearch!].kind == grammar.tokenIdArrow -> if { true => flowArrow! }
                arrowSearch! + 1 => arrowSearch!
            }
            (callNode.kind == 11 or callNode.kind == 15 or (callNode.kind == 10 and flowArrow!)) -> if {
                false => ordinaryResolved!
                0 => preparedCallIndex!
                preparedCallIndex! < (prepared.calls -> len) -> while {
                    prepared.calls[preparedCallIndex!] => preparedCall
                    (preparedCall.sourceModule == callSourceIndex! and preparedCall.callAst == callAstIndex! and preparedCall.status == 0) -> if { true => ordinaryResolved! }
                    preparedCallIndex! + 1 => preparedCallIndex!
                }
                not ordinaryResolved! -> if {
                    callNode.parent => callAncestor!
                    -1 => callFunctionAst!
                    (callAncestor! >= 0 and callFunctionAst! < 0) -> while {
                        prepared.package.nodes[callRange.astStart + callAncestor!] => callAncestorNode
                        callAncestorNode.kind == 7 -> if { callAncestor! => callFunctionAst! } else { callAncestorNode.parent => callAncestor! }
                    }
                    -1 => callFunctionSymbol!
                    0 => callFunctionSearch!
                    (callFunctionSearch! < callRange.symbolCount and callFunctionSymbol! < 0) -> while {
                        prepared.package.symbols[callRange.symbolStart + callFunctionSearch!] => callFunctionCandidate
                        (callFunctionCandidate.kind == 7 and callFunctionCandidate.astNode == callFunctionAst!) -> if { callFunctionSearch! => callFunctionSymbol! }
                        callFunctionSearch! + 1 => callFunctionSearch!
                    }

                    -1 => callNameToken!
                    -1 => firstCallNameToken!
                    -1 => previousCallNameToken!
                    false => afterArrow!
                    false => insideArguments!
                    callNode.firstToken => callTokenIndex!
                    callTokenIndex! < callNode.firstToken + callNode.tokenCount -> while {
                        prepared.package.tokens[callRange.tokenStart + callTokenIndex!] => callToken
                        callToken.kind == grammar.tokenIdArrow -> if {
                            true => afterArrow!
                            -1 => callNameToken!
                            -1 => firstCallNameToken!
                            -1 => previousCallNameToken!
                        }
                        callToken.kind == grammar.tokenIdLeftParen -> if { true => insideArguments! }
                        callToken.kind == grammar.tokenIdRightParen -> if { false => insideArguments! }
                        (callToken.kind == grammar.tokenIdIdentifier and not insideArguments! and (callNode.kind == 11 or callNode.kind == 15 or afterArrow!)) -> if {
                            firstCallNameToken! < 0 -> if { callTokenIndex! => firstCallNameToken! }
                            callNameToken! >= 0 -> if { callNameToken! => previousCallNameToken! }
                            callTokenIndex! => callNameToken!
                        }
                        callTokenIndex! + 1 => callTokenIndex!
                    }
                    callNameToken! >= 0 -> if {
                        firstCallNameToken! == callNameToken! -> if {
                            0 => matchCount!
                            -1 => matchedEffectSource!
                            -1 => matchedEffectSymbol!
                            -1 => matchedOperationSymbol!
                            -1 => matchedReturnTypeId!
                            0 => callerRequirementIndex!
                            callerRequirementIndex! < (requirements! -> len) -> while {
                                requirements![callerRequirementIndex!] => requirement
                                (requirement.sourceModule == callSourceIndex! and requirement.functionSymbol == callFunctionSymbol! and requirement.status == 0) -> if {
                                    0 => operationSearch!
                                    operationSearch! < (operations! -> len) -> while {
                                        operations![operationSearch!] => operation
                                        (operation.sourceModule == requirement.effectSourceModule and operation.effectSymbol == requirement.effectSymbol) -> if {
                                            prepared.package.sources[operation.sourceModule] -> len => operationSourceLength
                                            prepared.package.sources[operation.sourceModule] -> slice(UIntSize(0), operationSourceLength) => operationSource
                                            TokenPairRequest {
                                                leftSource: callSource
                                                left: prepared.package.tokens[callRange.tokenStart + callNameToken!]
                                                rightSource: operationSource
                                                right: prepared.package.tokens[prepared.package.ranges[operation.sourceModule].tokenStart + operation.nameToken]
                                            } -> tokenEqual -> if {
                                                matchCount! + 1 => matchCount!
                                                operation.sourceModule => matchedEffectSource!
                                                operation.effectSymbol => matchedEffectSymbol!
                                                operation.operationSymbol => matchedOperationSymbol!
                                                operation.returnTypeId => matchedReturnTypeId!
                                            }
                                        }
                                        operationSearch! + 1 => operationSearch!
                                    }
                                }
                                callerRequirementIndex! + 1 => callerRequirementIndex!
                            }
                            matchCount! == 1 -> if {
                                calls! -> push(UserEffectCall {
                                    sourceModule: callSourceIndex!
                                    functionSymbol: callFunctionSymbol!
                                    effectSourceModule: matchedEffectSource!
                                    effectSymbol: matchedEffectSymbol!
                                    operationSymbol: matchedOperationSymbol!
                                    astNode: callAstIndex!
                                    status: 0
                                    argumentTypeId: -1
                                    returnTypeId: matchedReturnTypeId!
                                })
                            }
                            matchCount! > 1 -> if {
                                diagnostics! -> push(UserEffectDiagnostic {
                                    code: 5
                                    sourceModule: callSourceIndex!
                                    functionSymbol: callFunctionSymbol!
                                    effectSourceModule: -1
                                    effectSymbol: -1
                                    operationSymbol: -1
                                    astNode: callAstIndex!
                                    expectedTypeId: -1
                                    actualTypeId: -1
                                    span: syntax.SourceSpan { fileId: callSourceIndex!, start: callNode.start, length: callNode.length }
                                })
                            }
                        } else {
                            previousCallNameToken! >= 0 -> if {
                                -1 => explicitEffectSource!
                                -1 => explicitEffectSymbol!
                                0 => explicitSignatureIndex!
                                explicitSignatureIndex! < (signatures! -> len) -> while {
                                    signatures![explicitSignatureIndex!] => explicitSignature
                                    explicitSignature.sourceModule == callSourceIndex! -> if {
                                        prepared.package.sources[explicitSignature.sourceModule] -> len => explicitSignatureSourceLength
                                        prepared.package.sources[explicitSignature.sourceModule] -> slice(UIntSize(0), explicitSignatureSourceLength) => explicitSignatureSource
                                        TokenPairRequest {
                                            leftSource: callSource
                                            left: prepared.package.tokens[callRange.tokenStart + previousCallNameToken!]
                                            rightSource: explicitSignatureSource
                                            right: prepared.package.tokens[prepared.package.ranges[explicitSignature.sourceModule].tokenStart + explicitSignature.nameToken]
                                        } -> tokenEqual -> if {
                                            callSourceIndex! => explicitEffectSource!
                                            explicitSignature.effectSymbol => explicitEffectSymbol!
                                        }
                                    }
                                    explicitSignatureIndex! + 1 => explicitSignatureIndex!
                                }
                                (explicitEffectSymbol! < 0 and firstCallNameToken! != previousCallNameToken!) -> if {
                                    0 => explicitImportIndex!
                                    explicitImportIndex! < (prepared.imports -> len) -> while {
                                        prepared.imports[explicitImportIndex!] => explicitImport
                                        explicitImport.sourceModule == callSourceIndex! -> if {
                                            TokenPairRequest {
                                                leftSource: callSource
                                                left: prepared.package.tokens[callRange.tokenStart + firstCallNameToken!]
                                                rightSource: callSource
                                                right: prepared.package.tokens[callRange.tokenStart + explicitImport.aliasToken]
                                            } -> tokenEqual -> if {
                                                prepared.resolvedImports[explicitImportIndex!] => resolvedImport
                                                resolvedImport.status == 0 -> if {
                                                    prepared.modules[resolvedImport.targetModule].sourceIndex => importedEffectSource
                                                    0 => importedSignatureIndex!
                                                    importedSignatureIndex! < (signatures! -> len) -> while {
                                                        signatures![importedSignatureIndex!] => importedSignature
                                                        (importedSignature.sourceModule == importedEffectSource and importedSignature.flags >= 4) -> if {
                                                            prepared.package.sources[importedEffectSource] -> len => importedEffectSourceLength
                                                            prepared.package.sources[importedEffectSource] -> slice(UIntSize(0), importedEffectSourceLength) => importedEffectSourceView
                                                            TokenPairRequest {
                                                                leftSource: callSource
                                                                left: prepared.package.tokens[callRange.tokenStart + previousCallNameToken!]
                                                                rightSource: importedEffectSourceView
                                                                right: prepared.package.tokens[prepared.package.ranges[importedEffectSource].tokenStart + importedSignature.nameToken]
                                                            } -> tokenEqual -> if {
                                                                importedEffectSource => explicitEffectSource!
                                                                importedSignature.effectSymbol => explicitEffectSymbol!
                                                            }
                                                        }
                                                        importedSignatureIndex! + 1 => importedSignatureIndex!
                                                    }
                                                }
                                            }
                                        }
                                        explicitImportIndex! + 1 => explicitImportIndex!
                                    }
                                }
                                -1 => explicitOperationSymbol!
                                -1 => explicitReturnTypeId!
                                0 => explicitOperationIndex!
                                explicitOperationIndex! < (operations! -> len) -> while {
                                    operations![explicitOperationIndex!] => explicitOperation
                                    (explicitOperation.sourceModule == explicitEffectSource! and explicitOperation.effectSymbol == explicitEffectSymbol!) -> if {
                                        prepared.package.sources[explicitOperation.sourceModule] -> len => explicitOperationSourceLength
                                        prepared.package.sources[explicitOperation.sourceModule] -> slice(UIntSize(0), explicitOperationSourceLength) => explicitOperationSource
                                        TokenPairRequest {
                                            leftSource: callSource
                                            left: prepared.package.tokens[callRange.tokenStart + callNameToken!]
                                            rightSource: explicitOperationSource
                                            right: prepared.package.tokens[prepared.package.ranges[explicitOperation.sourceModule].tokenStart + explicitOperation.nameToken]
                                        } -> tokenEqual -> if {
                                            explicitOperation.operationSymbol => explicitOperationSymbol!
                                            explicitOperation.returnTypeId => explicitReturnTypeId!
                                        }
                                    }
                                    explicitOperationIndex! + 1 => explicitOperationIndex!
                                }
                                explicitOperationSymbol! >= 0 -> if {
                                    false => explicitRequirementFound!
                                    0 => explicitRequirementIndex!
                                    explicitRequirementIndex! < (requirements! -> len) -> while {
                                        requirements![explicitRequirementIndex!] => explicitRequirement
                                        (explicitRequirement.sourceModule == callSourceIndex! and explicitRequirement.functionSymbol == callFunctionSymbol! and explicitRequirement.status == 0 and explicitRequirement.effectSourceModule == explicitEffectSource! and explicitRequirement.effectSymbol == explicitEffectSymbol!) -> if {
                                            true => explicitRequirementFound!
                                        }
                                        explicitRequirementIndex! + 1 => explicitRequirementIndex!
                                    }
                                    calls! -> push(UserEffectCall {
                                        sourceModule: callSourceIndex!
                                        functionSymbol: callFunctionSymbol!
                                        effectSourceModule: explicitEffectSource!
                                        effectSymbol: explicitEffectSymbol!
                                        operationSymbol: explicitOperationSymbol!
                                        astNode: callAstIndex!
                                        status: explicitRequirementFound! -> if { 0 } else { 2 }
                                        argumentTypeId: -1
                                        returnTypeId: explicitReturnTypeId!
                                    })
                                    not explicitRequirementFound! -> if {
                                        diagnostics! -> push(UserEffectDiagnostic {
                                            code: 4
                                            sourceModule: callSourceIndex!
                                            functionSymbol: callFunctionSymbol!
                                            effectSourceModule: explicitEffectSource!
                                            effectSymbol: explicitEffectSymbol!
                                            operationSymbol: explicitOperationSymbol!
                                            astNode: callAstIndex!
                                            expectedTypeId: -1
                                            actualTypeId: -1
                                            span: syntax.SourceSpan { fileId: callSourceIndex!, start: callNode.start, length: callNode.length }
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
            callAstIndex! + 1 => callAstIndex!
        }
        callSourceIndex! + 1 => callSourceIndex!
    }

    # Attach canonical argument/result types to resolved operation calls and
    # reject arity or concrete type mismatches before handler lowering.
    prepared -> expressionTypeIds.resolveContext => expressionTypeSet
    0 => typedCallIndex!
    typedCallIndex! < (calls! -> len) -> while {
        calls![typedCallIndex!] => typedCall!
        prepared.package.ranges[typedCall!.sourceModule] => typedCallRange
        prepared.package.nodes[typedCallRange.astStart + typedCall!.astNode] => typedCallNode
        -1 => expectedInputTypeId!
        0 => typedOperationSearch!
        typedOperationSearch! < (operations! -> len) -> while {
            operations![typedOperationSearch!] => typedOperation
            (typedOperation.sourceModule == typedCall!.effectSourceModule and typedOperation.effectSymbol == typedCall!.effectSymbol and typedOperation.operationSymbol == typedCall!.operationSymbol) -> if {
                typedOperation.inputTypeId => expectedInputTypeId!
                typedOperation.returnTypeId => typedCall!.returnTypeId
            }
            typedOperationSearch! + 1 => typedOperationSearch!
        }

        false => hasOperationArgument!
        UIntSize(0) => argumentBoundaryStart!
        UIntSize(0) => argumentBoundaryEnd!
        typedCallNode.kind == 10 -> if {
            typedCallNode.firstToken => typedCallTokenIndex!
            typedCallTokenIndex! < typedCallNode.firstToken + typedCallNode.tokenCount -> while {
                prepared.package.tokens[typedCallRange.tokenStart + typedCallTokenIndex!] => typedCallToken
                typedCallToken.kind == grammar.tokenIdArrow -> if {
                    true => hasOperationArgument!
                    typedCallToken.span.start => argumentBoundaryEnd!
                    typedCallNode.firstToken + typedCallNode.tokenCount => typedCallTokenIndex!
                } else {
                    typedCallTokenIndex! + 1 => typedCallTokenIndex!
                }
            }
        }
        typedCallNode.kind == 11 -> if {
            false => afterOperationLeftParen!
            typedCallNode.firstToken => typedCallTokenIndex!
            typedCallTokenIndex! < typedCallNode.firstToken + typedCallNode.tokenCount -> while {
                prepared.package.tokens[typedCallRange.tokenStart + typedCallTokenIndex!] => typedCallToken
                typedCallToken.kind == grammar.tokenIdLeftParen -> if {
                    true => afterOperationLeftParen!
                    typedCallToken.span.start + typedCallToken.span.length => argumentBoundaryStart!
                } else {
                    typedCallToken.kind == grammar.tokenIdRightParen -> if {
                        typedCallToken.span.start => argumentBoundaryEnd!
                        false => afterOperationLeftParen!
                    } else {
                        (afterOperationLeftParen! and typedCallToken.kind != grammar.triviaIdWhitespace and typedCallToken.kind != grammar.triviaIdComment) -> if {
                            true => hasOperationArgument!
                        }
                    }
                }
                typedCallTokenIndex! + 1 => typedCallTokenIndex!
            }
        }

        -1 => actualArgumentExpression!
        1000000 => actualArgumentDistance!
        0 => typedExpressionSearch!
        typedExpressionSearch! < (expressionTypeSet.expressions -> len) -> while {
            expressionTypeSet.expressions[typedExpressionSearch!] => typedExpression
            (typedExpression.sourceModule == typedCall!.sourceModule and typedExpression.astNode != typedCall!.astNode and typedExpression.status == 0) -> if {
                prepared.package.nodes[typedCallRange.astStart + typedExpression.astNode] => typedExpressionNode
                true => insideArgumentBoundary!
                typedCallNode.kind == 10 -> if {
                    typedExpressionNode.start + typedExpressionNode.length > argumentBoundaryEnd! -> if { false => insideArgumentBoundary! }
                }
                typedCallNode.kind == 11 -> if {
                    (typedExpressionNode.start < argumentBoundaryStart! or typedExpressionNode.start + typedExpressionNode.length > argumentBoundaryEnd!) -> if { false => insideArgumentBoundary! }
                }
                typedExpressionNode.parent => typedExpressionAncestor!
                1 => typedExpressionDistance!
                false => belongsToOperationCall!
                (typedExpressionAncestor! >= 0 and not belongsToOperationCall!) -> while {
                    typedExpressionAncestor! == typedCall!.astNode -> if { true => belongsToOperationCall! } else {
                        prepared.package.nodes[typedCallRange.astStart + typedExpressionAncestor!].parent => typedExpressionAncestor!
                        typedExpressionDistance! + 1 => typedExpressionDistance!
                    }
                }
                (insideArgumentBoundary! and belongsToOperationCall! and typedExpressionDistance! < actualArgumentDistance!) -> if {
                    typedExpressionSearch! => actualArgumentExpression!
                    typedExpressionDistance! => actualArgumentDistance!
                }
            }
            typedExpressionSearch! + 1 => typedExpressionSearch!
        }
        actualArgumentExpression! >= 0 -> if {
            expressionTypeSet.expressions[actualArgumentExpression!].typeId => typedCall!.argumentTypeId
        }
        typedCall! => calls![typedCallIndex!]

        ((expectedInputTypeId! >= 0 and not hasOperationArgument!) or (expectedInputTypeId! < 0 and hasOperationArgument!)) -> if {
            diagnostics! -> push(UserEffectDiagnostic {
                code: 7
                sourceModule: typedCall!.sourceModule
                functionSymbol: typedCall!.functionSymbol
                effectSourceModule: typedCall!.effectSourceModule
                effectSymbol: typedCall!.effectSymbol
                operationSymbol: typedCall!.operationSymbol
                astNode: typedCall!.astNode
                expectedTypeId: expectedInputTypeId!
                actualTypeId: typedCall!.argumentTypeId
                span: syntax.SourceSpan { fileId: typedCall!.sourceModule, start: typedCallNode.start, length: typedCallNode.length }
            })
        }
        (expectedInputTypeId! >= 0 and typedCall!.argumentTypeId >= 0 and expectedInputTypeId! != typedCall!.argumentTypeId) -> if {
            expressionTypeSet.types[expectedInputTypeId!] => expectedInputType
            expressionTypeSet.types[typedCall!.argumentTypeId] => actualInputType
            (not expectedInputType.containsParameter and not actualInputType.containsParameter) -> if {
                expressionTypeSet.expressions[actualArgumentExpression!] => actualArgument
                prepared.package.nodes[typedCallRange.astStart + actualArgument.astNode] => actualArgumentNode
                diagnostics! -> push(UserEffectDiagnostic {
                    code: 6
                    sourceModule: typedCall!.sourceModule
                    functionSymbol: typedCall!.functionSymbol
                    effectSourceModule: typedCall!.effectSourceModule
                    effectSymbol: typedCall!.effectSymbol
                    operationSymbol: typedCall!.operationSymbol
                    astNode: typedCall!.astNode
                    expectedTypeId: expectedInputTypeId!
                    actualTypeId: typedCall!.argumentTypeId
                    span: syntax.SourceSpan { fileId: typedCall!.sourceModule, start: actualArgumentNode.start, length: actualArgumentNode.length }
                })
            }
        }
        typedCallIndex! + 1 => typedCallIndex!
    }

    UserEffectAnalysis {
        signatures: signatures!
        operations: operations!
        requirements: requirements!
        calls: calls!
        diagnostics: diagnostics!
    } => result!
    result!
}
