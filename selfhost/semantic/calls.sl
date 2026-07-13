namespace smalllang.compiler.semantic.calls

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.qualified as qualified
import smalllang.compiler.semantic.symbols as symbols
import syntax.generated.smalllang as grammar

public struct CallResolution {
    callAst: Int
    functionSymbol: Int
    status: Int
}

public struct ModuleCallResolution {
    sourceModule: Int
    callAst: Int
    origin: Int
    targetModule: Int
    targetSourceModule: Int
    functionSymbol: Int
    status: Int
}

# Status 0 is a resolved local function and 2 is an unresolved call target.
public resolve source: Text -> [CallResolution; ~] {
    source -> ast.lower => nodes!
    source -> lexer.lex => tokens!
    source -> symbols.collect => table!
    [CallResolution; ~] => resolved!
    0 => astIndex!
    astIndex! < (nodes! -> len) -> while {
        nodes![astIndex!] => node
        false => hasControlTarget!
        false => hasFlowCallTarget!
        0 => controlTargetSearch!
        controlTargetSearch! < (nodes! -> len) -> while {
            (nodes![controlTargetSearch!].parent == astIndex! and (nodes![controlTargetSearch!].kind == 42 or nodes![controlTargetSearch!].kind == 44)) -> if { true => hasControlTarget! }
            controlTargetSearch! + 1 => controlTargetSearch!
        }
        node.firstToken => flowTokenIndex!
        (node.kind == 10 and flowTokenIndex! < node.firstToken + node.tokenCount) -> while {
            tokens![flowTokenIndex!].kind == grammar.tokenIdArrow -> if { true => hasFlowCallTarget! }
            flowTokenIndex! + 1 => flowTokenIndex!
        }
        ((node.kind == 10 and hasFlowCallTarget! and not hasControlTarget!) or (node.kind == 11 and node.cstRuleId == grammar.ruleIdCallExpression) or node.kind == 15) -> if {
            -1 => callNameToken!
            node.firstToken => tokenIndex!
            (tokenIndex! < node.firstToken + node.tokenCount and (node.kind == 10 or callNameToken! < 0)) -> while {
                tokens![tokenIndex!].kind == grammar.tokenIdIdentifier -> if { tokenIndex! => callNameToken! }
                tokenIndex! + 1 => tokenIndex!
            }
            callNameToken! >= 0 -> if {
            -1 => functionSymbol!
            0 => symbolIndex!
            (symbolIndex! < (table! -> len) and functionSymbol! < 0) -> while {
                table![symbolIndex!] => candidate
                (candidate.kind == 7 and candidate.parent < 0) -> if {
                    tokens![callNameToken!] => callName
                    tokens![candidate.nameToken] => functionName
                    callName.span.length == functionName.span.length => equal!
                    UIntSize(0) => nameByte!
                    (equal! and nameByte! < callName.span.length) -> while {
                        source -> byte(callName.span.start + nameByte!) => callByte
                        source -> byte(functionName.span.start + nameByte!) => functionByte
                        callByte != functionByte -> if { false => equal! }
                        nameByte! + UIntSize(1) => nameByte!
                    }
                    (equal! and (node.kind == 10 or node.kind == 11 or candidate.secondaryTypeNode < 0)) -> if { symbolIndex! => functionSymbol! }
                }
                symbolIndex! + 1 => symbolIndex!
            }
            (node.kind == 11 or functionSymbol! >= 0) -> if {
                resolved! -> push(CallResolution {
                    callAst: astIndex!
                    functionSymbol: functionSymbol!
                    status: functionSymbol! >= 0 -> if { 0 } else { 2 }
                })
            }
            }
        }
        astIndex! + 1 => astIndex!
    }
    resolved!
}

# Origins: 0 local function, 1 imported function. Imported statuses preserve
# qualified lookup: 0 public, 2 missing/non-function, 3 non-public.
public resolveModules sources: [Text; ~] -> [ModuleCallResolution; ~] {
    sources -> modules.identities => identities!
    sources -> qualified.resolve => qualifiedResults!
    [ModuleCallResolution; ~] => results!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> lexer.lex => tokens!
        source -> symbols.collect => table!
        [CallResolution; ~] => localCalls!
        0 => callAstIndex!
        callAstIndex! < (nodes! -> len) -> while {
            nodes![callAstIndex!] => callNode
            false => moduleHasControlTarget!
            false => moduleHasFlowCallTarget!
            0 => moduleControlTargetSearch!
            moduleControlTargetSearch! < (nodes! -> len) -> while {
                (nodes![moduleControlTargetSearch!].parent == callAstIndex! and (nodes![moduleControlTargetSearch!].kind == 42 or nodes![moduleControlTargetSearch!].kind == 44)) -> if { true => moduleHasControlTarget! }
                moduleControlTargetSearch! + 1 => moduleControlTargetSearch!
            }
            callNode.firstToken => moduleFlowTokenIndex!
            (callNode.kind == 10 and moduleFlowTokenIndex! < callNode.firstToken + callNode.tokenCount) -> while {
                tokens![moduleFlowTokenIndex!].kind == grammar.tokenIdArrow -> if { true => moduleHasFlowCallTarget! }
                moduleFlowTokenIndex! + 1 => moduleFlowTokenIndex!
            }
            ((callNode.kind == 10 and moduleHasFlowCallTarget! and not moduleHasControlTarget!) or (callNode.kind == 11 and callNode.cstRuleId == grammar.ruleIdCallExpression) or callNode.kind == 15) -> if {
                -1 => callNameToken!
                callNode.firstToken => callTokenIndex!
                (callTokenIndex! < callNode.firstToken + callNode.tokenCount and (callNode.kind == 10 or callNameToken! < 0)) -> while {
                    tokens![callTokenIndex!].kind == grammar.tokenIdIdentifier -> if { callTokenIndex! => callNameToken! }
                    callTokenIndex! + 1 => callTokenIndex!
                }
                callNameToken! >= 0 -> if {
                -1 => localFunctionSymbol!
                0 => localSymbolIndex!
                (localSymbolIndex! < (table! -> len) and localFunctionSymbol! < 0) -> while {
                    table![localSymbolIndex!] => localCandidate
                    (localCandidate.kind == 7 and localCandidate.parent < 0) -> if {
                        tokens![callNameToken!] => callName
                        tokens![localCandidate.nameToken] => functionName
                        callName.span.length == functionName.span.length => localEqual!
                        UIntSize(0) => localNameByte!
                        (localEqual! and localNameByte! < callName.span.length) -> while {
                            source -> byte(callName.span.start + localNameByte!) => callByte
                            source -> byte(functionName.span.start + localNameByte!) => functionByte
                            callByte != functionByte -> if { false => localEqual! }
                            localNameByte! + UIntSize(1) => localNameByte!
                        }
                        (localEqual! and (callNode.kind == 10 or callNode.kind == 11 or localCandidate.secondaryTypeNode < 0)) -> if { localSymbolIndex! => localFunctionSymbol! }
                    }
                    localSymbolIndex! + 1 => localSymbolIndex!
                }
                ((callNode.kind == 10 or callNode.kind == 11) and localFunctionSymbol! < 0) -> if {
                    tokens![callNameToken!] => runtimeName
                    runtimeName.span.length == UIntSize(5) -> if {
                        source -> byte(runtimeName.span.start) => runtimeByte0
                        source -> byte(runtimeName.span.start + UIntSize(1)) => runtimeByte1
                        source -> byte(runtimeName.span.start + UIntSize(2)) => runtimeByte2
                        source -> byte(runtimeName.span.start + UIntSize(3)) => runtimeByte3
                        source -> byte(runtimeName.span.start + UIntSize(4)) => runtimeByte4
                        (runtimeByte0 == UInt8(112) and runtimeByte1 == UInt8(114) and runtimeByte2 == UInt8(105) and runtimeByte3 == UInt8(110) and runtimeByte4 == UInt8(116)) -> if {
                            -101 => localFunctionSymbol!
                        }
                    }
                    runtimeName.span.length == UIntSize(7) -> if {
                        source -> byte(runtimeName.span.start) => runtimeByte0
                        source -> byte(runtimeName.span.start + UIntSize(1)) => runtimeByte1
                        source -> byte(runtimeName.span.start + UIntSize(2)) => runtimeByte2
                        source -> byte(runtimeName.span.start + UIntSize(3)) => runtimeByte3
                        source -> byte(runtimeName.span.start + UIntSize(4)) => runtimeByte4
                        source -> byte(runtimeName.span.start + UIntSize(5)) => runtimeByte5
                        source -> byte(runtimeName.span.start + UIntSize(6)) => runtimeByte6
                        (runtimeByte0 == UInt8(112) and runtimeByte1 == UInt8(114) and runtimeByte2 == UInt8(105) and runtimeByte3 == UInt8(110) and runtimeByte4 == UInt8(116) and runtimeByte5 == UInt8(108) and runtimeByte6 == UInt8(110)) -> if {
                            -102 => localFunctionSymbol!
                        }
                    }
                }
                (callNode.kind == 11 or localFunctionSymbol! != -1) -> if {
                    localCalls! -> push(CallResolution {
                        callAst: callAstIndex!
                        functionSymbol: localFunctionSymbol!
                        status: localFunctionSymbol! != -1 -> if { 0 } else { 2 }
                    })
                }
                }
            }
            callAstIndex! + 1 => callAstIndex!
        }
        0 => localIndex!
        localIndex! < (localCalls! -> len) -> while {
            localCalls![localIndex!] => local
            nodes![local.callAst] => localCallNode
            localCallNode.firstToken + localCallNode.tokenCount => callLeftParenToken!
            localCallNode.firstToken => callScanToken!
            callScanToken! < localCallNode.firstToken + localCallNode.tokenCount -> while {
                tokens![callScanToken!].kind == grammar.tokenIdLeftParen -> if {
                    callScanToken! => callLeftParenToken!
                    localCallNode.firstToken + localCallNode.tokenCount => callScanToken!
                } else {
                    callScanToken! + 1 => callScanToken!
                }
            }
            -1 => importedIndex!
            0 => qualifiedIndex!
            qualifiedIndex! < (qualifiedResults! -> len) -> while {
                qualifiedResults![qualifiedIndex!] => candidate
                candidate.sourceModule == sourceIndex! -> if {
                    candidate.pathAst => ancestor!
                    0 => callPathDistance!
                    false => belongsToCall!
                    (ancestor! >= 0 and not belongsToCall!) -> while {
                        ancestor! == local.callAst -> if {
                            true => belongsToCall!
                        } else {
                            nodes![ancestor!].parent => ancestor!
                            callPathDistance! + 1 => callPathDistance!
                        }
                    }
                    nodes![candidate.pathAst] => candidatePath
                    (belongsToCall! and candidatePath.firstToken + candidatePath.tokenCount <= callLeftParenToken!) -> if { qualifiedIndex! => importedIndex! }
                }
                qualifiedIndex! + 1 => qualifiedIndex!
            }
            importedIndex! >= 0 -> if {
                qualifiedResults![importedIndex!] => imported
                identities![imported.targetModule].sourceIndex => targetSourceModule
                imported.status => importedStatus!
                imported.status == 0 -> if {
                    sources[targetSourceModule] -> symbols.collect => targetSymbols!
                    targetSymbols![imported.targetSymbol].kind != 7 -> if { 2 => importedStatus! }
                }
                results! -> push(ModuleCallResolution {
                    sourceModule: sourceIndex!
                    callAst: local.callAst
                    origin: 1
                    targetModule: imported.targetModule
                    targetSourceModule: targetSourceModule
                    functionSymbol: imported.targetSymbol
                    status: importedStatus!
                })
            } else {
                local.functionSymbol < -1 => runtimeCall
                results! -> push(ModuleCallResolution {
                    sourceModule: sourceIndex!
                    callAst: local.callAst
                    origin: runtimeCall -> if { 2 } else { 0 }
                    targetModule: sourceIndex!
                    targetSourceModule: runtimeCall -> if { -1 } else { sourceIndex! }
                    functionSymbol: local.functionSymbol
                    status: local.status
                })
            }
            localIndex! + 1 => localIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    results!
}
