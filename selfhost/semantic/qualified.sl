namespace smalllang.compiler.semantic.qualified

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.module_resolve as moduleResolve
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.symbols as symbols
import syntax.generated.smalllang as grammar

public struct QualifiedResolution {
    sourceModule: Int
    pathAst: Int
    targetModule: Int
    targetSymbol: Int
    status: Int
}

# Status: 0 public symbol, 2 missing member, 3 non-public member.
public resolve sources: [Text; ~] -> [QualifiedResolution; ~] {
    sources -> modules.identities => identities!
    sources -> modules.imports => imports!
    sources -> moduleResolve.resolve => resolvedImports!
    [QualifiedResolution; ~] => results!
    sources -> len => sourceCount
    imports! -> len => importCount
    0 => sourceIndex!
    sourceIndex! < sourceCount -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> lexer.lex => tokens!
        nodes! -> len => astCount
        0 => pathAstIndex!
        pathAstIndex! < astCount -> while {
            nodes![pathAstIndex!] => pathAst
            (pathAst.kind == 16 or pathAst.kind == 36) -> if {
                -1 => firstIdentifier!
                -1 => lastIdentifier!
                pathAst.firstToken => pathToken!
                pathAst.firstToken + pathAst.tokenCount => pathEnd
                pathToken! < pathEnd -> while {
                    tokens![pathToken!].kind == grammar.tokenIdIdentifier -> if {
                        firstIdentifier! < 0 -> if { pathToken! => firstIdentifier! }
                        pathToken! => lastIdentifier!
                    }
                    pathToken! + 1 => pathToken!
                }
                (firstIdentifier! >= 0 and lastIdentifier! != firstIdentifier!) -> if {
                    0 => edgeIndex!
                    edgeIndex! < importCount -> while {
                        imports![edgeIndex!] => edge
                        resolvedImports![edgeIndex!] => resolvedImport
                        (edge.sourceModule == sourceIndex! and resolvedImport.status == 0) -> if {
                            tokens![edge.aliasToken] => aliasName
                            tokens![firstIdentifier!] => pathAlias
                            aliasName.span.length == pathAlias.span.length => aliasEqual!
                            UIntSize(0) => aliasByte!
                            (aliasEqual! and aliasByte! < aliasName.span.length) -> while {
                                source -> byte(aliasName.span.start + aliasByte!) => aliasLeftByte
                                source -> byte(pathAlias.span.start + aliasByte!) => aliasRightByte
                                aliasLeftByte != aliasRightByte -> if { false => aliasEqual! }
                                aliasByte! + UIntSize(1) => aliasByte!
                            }
                            aliasEqual! -> if {
                                resolvedImport.targetModule => targetModule
                                identities![targetModule].sourceIndex => targetSourceIndex
                                sources[targetSourceIndex] => targetSource
                                targetSource -> symbols.collect => targetSymbols!
                                targetSource -> lexer.lex => targetTokens!
                                -1 => targetSymbol!
                                false => targetPublic!
                                0 => symbolIndex!
                                symbolIndex! < (targetSymbols! -> len) -> while {
                                    targetSymbols![symbolIndex!] => candidate
                                    candidate.parent < 0 -> if {
                                        targetTokens![candidate.nameToken] => candidateName
                                        tokens![lastIdentifier!] => memberName
                                        candidateName.span.length == memberName.span.length => memberEqual!
                                        UIntSize(0) => memberByte!
                                        (memberEqual! and memberByte! < candidateName.span.length) -> while {
                                            targetSource -> byte(candidateName.span.start + memberByte!) => memberLeftByte
                                            source -> byte(memberName.span.start + memberByte!) => memberRightByte
                                            memberLeftByte != memberRightByte -> if { false => memberEqual! }
                                            memberByte! + UIntSize(1) => memberByte!
                                        }
                                        memberEqual! -> if {
                                            symbolIndex! => targetSymbol!
                                            candidate.flags >= 4 -> if { true => targetPublic! }
                                        }
                                    }
                                    symbolIndex! + 1 => symbolIndex!
                                }
                                2 => status!
                                targetSymbol! >= 0 -> if {
                                    targetPublic! -> if { 0 => status! } else { 3 => status! }
                                }
                                QualifiedResolution {
                                    sourceModule: sourceIndex!
                                    pathAst: pathAstIndex!
                                    targetModule: targetModule
                                    targetSymbol: targetSymbol!
                                    status: status!
                                } => result
                                results! -> push(result)
                                importCount => edgeIndex!
                            } else {
                                edgeIndex! + 1 => edgeIndex!
                            }
                        } else {
                            edgeIndex! + 1 => edgeIndex!
                        }
                    }
                }
            }
            pathAstIndex! + 1 => pathAstIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    results!
}
