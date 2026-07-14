namespace smalllang.compiler.semantic.nominal_types

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.semantic.type_resolve as typeResolve
import smalllang.compiler.semantic.types as types
import syntax.generated.smalllang as grammar

public struct NominalType {
    sourceModule: Int
    typeAst: Int
    canonical: Int
    origin: Int
    targetModule: Int
    targetSymbol: Int
    status: Int
}

# Origins: 0 local declaration, 1 builtin, 2 imported declaration.
# Status: 0 resolved, 2 missing, 3 non-public imported declaration.
public resolve sources: [Text; ~] -> [NominalType; ~] {
    ["Unit", "Text", "Int", "Int8", "Int16", "Int32", "Int64", "Long", "UInt8", "UInt16", "UInt32", "UInt64", "Size", "UIntSize", "CodePoint", "Arena", "Arguments", "MappedBytes", "MutableMappedBytes", "Float", "Float32", "Float64", "Double", "Bool", ~] => builtinNames!
    sources -> typeResolve.resolve => importedTypes!
    [NominalType; ~] => results!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> lexer.lex => tokens!
        source -> types.canonicalize => typeUses!
        nodes! -> symbols.collectPrepared => table!
        0 => typeIndex!
        typeIndex! < (typeUses! -> len) -> while {
            typeUses![typeIndex!] => typeUse
            typeUse.kind == 1 -> if {
                -1 => importedIndex!
                0 => importedSearch!
                importedSearch! < (importedTypes! -> len) -> while {
                    importedTypes![importedSearch!] => imported
                    (imported.sourceModule == sourceIndex! and imported.typeAst == typeUse.astNode) -> if {
                        importedSearch! => importedIndex!
                    }
                    importedSearch! + 1 => importedSearch!
                }
                importedIndex! >= 0 -> if {
                    importedTypes![importedIndex!] => imported
                    NominalType {
                        sourceModule: sourceIndex!
                        typeAst: typeUse.astNode
                        canonical: typeUse.canonical
                        origin: 2
                        targetModule: imported.targetModule
                        targetSymbol: imported.targetSymbol
                        status: imported.status
                    } => importedResult
                    results! -> push(importedResult)
                } else {
                    nodes![typeUse.astNode] => typeNode
                    -1 => nameToken!
                    typeNode.firstToken => tokenIndex!
                    (tokenIndex! < typeNode.firstToken + typeNode.tokenCount and nameToken! < 0) -> while {
                        tokens![tokenIndex!].kind == grammar.tokenIdIdentifier -> if {
                            tokenIndex! => nameToken!
                        }
                        tokenIndex! + 1 => tokenIndex!
                    }
                    tokens![nameToken!] => name
                    -1 => builtinIndex!
                    0 => builtinSearch!
                    (builtinSearch! < (builtinNames! -> len) and builtinIndex! < 0) -> while {
                        builtinNames![builtinSearch!] => builtinName
                        name.span.length == (builtinName -> len) => equal!
                        UIntSize(0) => nameByte!
                        (equal! and nameByte! < name.span.length) -> while {
                            source -> byte(name.span.start + nameByte!) => leftByte
                            builtinName -> byte(nameByte!) => rightByte
                            leftByte != rightByte -> if { false => equal! }
                            nameByte! + UIntSize(1) => nameByte!
                        }
                        equal! -> if { builtinSearch! => builtinIndex! }
                        builtinSearch! + 1 => builtinSearch!
                    }
                    builtinIndex! >= 0 -> if {
                        NominalType {
                            sourceModule: sourceIndex!
                            typeAst: typeUse.astNode
                            canonical: typeUse.canonical
                            origin: 1
                            targetModule: -1
                            targetSymbol: builtinIndex!
                            status: 0
                        } => builtinResult
                        results! -> push(builtinResult)
                    } else {
                        -1 => typeOwnerFunction!
                        nodes![typeUse.astNode].parent => ownerAst!
                        (ownerAst! >= 0 and typeOwnerFunction! < 0) -> while {
                            0 => ownerSymbolIndex!
                            ownerSymbolIndex! < (table! -> len) -> while {
                                table![ownerSymbolIndex!] => ownerCandidate
                                (ownerCandidate.kind == 7 and ownerCandidate.astNode == ownerAst!) -> if {
                                    ownerSymbolIndex! => typeOwnerFunction!
                                }
                                ownerSymbolIndex! + 1 => ownerSymbolIndex!
                            }
                            typeOwnerFunction! < 0 -> if { nodes![ownerAst!].parent => ownerAst! }
                        }
                        -1 => localSymbol!
                        0 => symbolIndex!
                        (symbolIndex! < (table! -> len) and localSymbol! < 0) -> while {
                            table![symbolIndex!] => candidate
                            ((candidate.parent < 0 and (candidate.kind == 3 or candidate.kind == 4)) or (candidate.kind == 32 and candidate.parent == typeOwnerFunction!)) -> if {
                                tokens![candidate.nameToken] => candidateName
                                name.span.length == candidateName.span.length => equal!
                                UIntSize(0) => nameByte!
                                (equal! and nameByte! < name.span.length) -> while {
                                    source -> byte(name.span.start + nameByte!) => leftByte
                                    source -> byte(candidateName.span.start + nameByte!) => rightByte
                                    leftByte != rightByte -> if { false => equal! }
                                    nameByte! + UIntSize(1) => nameByte!
                                }
                                equal! -> if { symbolIndex! => localSymbol! }
                            }
                            symbolIndex! + 1 => symbolIndex!
                        }
                        0 => localOrigin!
                        localSymbol! >= 0 -> if {
                            table![localSymbol!].kind == 32 -> if { 3 => localOrigin! }
                        }
                        NominalType {
                            sourceModule: sourceIndex!
                            typeAst: typeUse.astNode
                            canonical: typeUse.canonical
                            origin: localOrigin!
                            targetModule: sourceIndex!
                            targetSymbol: localSymbol!
                            status: localSymbol! >= 0 -> if { 0 } else { 2 }
                        } => localResult
                        results! -> push(localResult)
                    }
                }
            }
            typeIndex! + 1 => typeIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    results!
}
