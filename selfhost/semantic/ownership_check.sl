namespace smalllang.compiler.semantic.ownership_check

import smalllang.compiler.ast as ast
import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.lexer as lexer
import smalllang.compiler.syntax as syntax
import syntax.generated.smalllang as grammar

public struct OwnershipDiagnostic {
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

# Code 17 identifies whole-owner or overlapping-field use after a partial move.
public analyze sources: [Text; ~] -> [OwnershipDiagnostic; ~] {
    sources -> typedIr.lower => typed!
    typed! -> typedIr.movesFrom => moves!
    [OwnershipDiagnostic; ~] => diagnostics!
    0 => partialMoveIndex!
    partialMoveIndex! < (moves! -> len) -> while {
        moves![partialMoveIndex!] => partialMove
        partialMove.memberIr >= 0 -> if {
            typed![partialMove.siteIr] => partialMoveSite
            sources[partialMove.sourceModule] -> ast.lower => moveNodes!
            sources[partialMove.sourceModule] -> lexer.lex => moveTokens!
            moveNodes![partialMoveSite.astNode].start => partialMoveStart
            typed![partialMove.memberIr] => movedMember
            moveNodes![movedMember.astNode] => movedMemberAst
            0 => movedIdentifierCount!
            movedMemberAst.firstToken => movedTokenIndex!
            movedTokenIndex! < movedMemberAst.firstToken + movedMemberAst.tokenCount -> while {
                moveTokens![movedTokenIndex!].kind == grammar.tokenIdIdentifier -> if { movedIdentifierCount! + 1 => movedIdentifierCount! }
                movedTokenIndex! + 1 => movedTokenIndex!
            }
            0 => movedUseIndex!
            movedUseIndex! < (typed! -> len) -> while {
                typed![movedUseIndex!] => movedUse
                (movedUse.kind == 5 and movedUse.sourceModule == partialMove.sourceModule and movedUse.symbol == partialMove.symbol and moveNodes![movedUse.astNode].start > partialMoveStart) -> if {
                    movedUse.parent => movedUseAncestor!
                    -1 => movedUseMember!
                    (movedUseAncestor! >= 0 and movedUseMember! < 0) -> while {
                        typed![movedUseAncestor!].kind == 13 -> if { movedUseAncestor! => movedUseMember! } else { typed![movedUseAncestor!].parent => movedUseAncestor! }
                    }
                    movedUseMember! < 0 => invalidMovedUse!
                    movedUseMember! >= 0 -> if {
                        typed![movedUseMember!] => useMember
                        moveNodes![useMember.astNode] => useMemberAst
                        0 => useIdentifierCount!
                        useMemberAst.firstToken => useTokenIndex!
                        useTokenIndex! < useMemberAst.firstToken + useMemberAst.tokenCount -> while {
                            moveTokens![useTokenIndex!].kind == grammar.tokenIdIdentifier -> if { useIdentifierCount! + 1 => useIdentifierCount! }
                            useTokenIndex! + 1 => useTokenIndex!
                        }
                        movedIdentifierCount! < useIdentifierCount! -> if { movedIdentifierCount! } else { useIdentifierCount! } => sharedIdentifierCount
                        true => sharedPath!
                        0 => sharedIdentifierOrdinal!
                        sharedIdentifierOrdinal! < sharedIdentifierCount -> while {
                            -1 => movedIdentifierToken!
                            -1 => useIdentifierToken!
                            0 => movedIdentifierOrdinal!
                            movedMemberAst.firstToken => movedTokenIndex!
                            (movedTokenIndex! < movedMemberAst.firstToken + movedMemberAst.tokenCount and movedIdentifierToken! < 0) -> while {
                                moveTokens![movedTokenIndex!].kind == grammar.tokenIdIdentifier -> if {
                                    movedIdentifierOrdinal! == sharedIdentifierOrdinal! -> if { movedTokenIndex! => movedIdentifierToken! }
                                    movedIdentifierOrdinal! + 1 => movedIdentifierOrdinal!
                                }
                                movedTokenIndex! + 1 => movedTokenIndex!
                            }
                            0 => useIdentifierOrdinal!
                            useMemberAst.firstToken => useTokenIndex!
                            (useTokenIndex! < useMemberAst.firstToken + useMemberAst.tokenCount and useIdentifierToken! < 0) -> while {
                                moveTokens![useTokenIndex!].kind == grammar.tokenIdIdentifier -> if {
                                    useIdentifierOrdinal! == sharedIdentifierOrdinal! -> if { useTokenIndex! => useIdentifierToken! }
                                    useIdentifierOrdinal! + 1 => useIdentifierOrdinal!
                                }
                                useTokenIndex! + 1 => useTokenIndex!
                            }
                            moveTokens![movedIdentifierToken!] => movedIdentifier
                            moveTokens![useIdentifierToken!] => useIdentifier
                            movedIdentifier.span.length == useIdentifier.span.length => sameIdentifier!
                            UIntSize(0) => identifierByte!
                            (sameIdentifier! and identifierByte! < movedIdentifier.span.length) -> while {
                                sources[partialMove.sourceModule] -> byte(movedIdentifier.span.start + identifierByte!) => movedByte
                                sources[partialMove.sourceModule] -> byte(useIdentifier.span.start + identifierByte!) => useByte
                                movedByte != useByte -> if { false => sameIdentifier! }
                                identifierByte! + UIntSize(1) => identifierByte!
                            }
                            not sameIdentifier! -> if { false => sharedPath! }
                            sharedIdentifierOrdinal! + 1 => sharedIdentifierOrdinal!
                        }
                        sharedPath! => invalidMovedUse!
                    }
                    invalidMovedUse! -> if {
                        false => duplicateMoveDiagnostic!
                        0 => moveDiagnosticIndex!
                        moveDiagnosticIndex! < (diagnostics! -> len) -> while {
                            diagnostics![moveDiagnosticIndex!] => existingMoveDiagnostic
                            (existingMoveDiagnostic.code == 17 and existingMoveDiagnostic.span.fileId == partialMove.sourceModule and existingMoveDiagnostic.span.start == moveNodes![movedUse.astNode].start) -> if { true => duplicateMoveDiagnostic! }
                            moveDiagnosticIndex! + 1 => moveDiagnosticIndex!
                        }
                        not duplicateMoveDiagnostic! -> if {
                            diagnostics! -> push(OwnershipDiagnostic {
                                code: 17
                                sourceModule: partialMove.sourceModule
                                functionSymbol: -1
                                expectedOrigin: -1
                                expectedModule: -1
                                expectedSymbol: -1
                                actualOrigin: -1
                                actualModule: -1
                                actualSymbol: -1
                                actualBuiltin: -1
                                span: syntax.SourceSpan { fileId: partialMove.sourceModule, start: moveNodes![movedUse.astNode].start, length: moveNodes![movedUse.astNode].length }
                            })
                        }
                    }
                }
                movedUseIndex! + 1 => movedUseIndex!
            }
        }
        partialMoveIndex! + 1 => partialMoveIndex!
    }
    diagnostics!
}
