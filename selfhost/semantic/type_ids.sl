namespace smalllang.compiler.semantic.type_ids

import smalllang.compiler.ast
import smalllang.compiler.lexer
import smalllang.compiler.semantic.modules
import smalllang.compiler.semantic.qualified
import smalllang.compiler.semantic.symbols
import smalllang.compiler.semantic.type_terms as typeTerms
import syntax.generated.smalllang as grammar

# Kinds match type_terms: 1 nominal, 2 slice, 3 dynamic array, 4 fixed
# array, 5 dictionary, 6 box, 7 nominal application.
# Nominal origins: 0 local declaration, 1 builtin, 2 imported declaration,
# 3 generic parameter, 4 intrinsic type constructor.
public struct SemanticType {
    kind: Int
    origin: Int
    module: Int
    symbol: Int
    first: Int
    second: Int
    lengthHash: UInt64
    status: Int
}

public struct TypeReference {
    sourceModule: Int
    typeAst: Int
    typeId: Int
    status: Int
}

public struct SemanticTypeSet {
    types: [SemanticType; ~]
    references: [TypeReference; ~]
}

# Resolves and globally interns recursive annotation types across source files.
# Nominal equality uses declaration identity, not source spelling.
public resolve sources: [Text; ~] -> SemanticTypeSet {
    ["Unit", "Text", "Int", "Int8", "Int16", "Int32", "Int64", "Long", "UInt8", "UInt16", "UInt32", "UInt64", "Size", "UIntSize", "CodePoint", "Arena", "Arguments", "MappedBytes", "MutableMappedBytes", "Float", "Float32", "Float64", "Double", "Bool", ~] => builtinNames!
    sources -> modules.identities => identities!
    sources -> qualified.resolve => qualifiedResults!
    [SemanticType; ~] => semanticTypes!
    [TypeReference; ~] => references!

    # Seed builtins in their stable nominal-symbol order. Expression inference
    # can therefore use the same id without an adapter or encounter-order map.
    0 => builtinSeed!
    builtinSeed! < (builtinNames! -> len) -> while {
        semanticTypes! -> push(SemanticType {
            kind: 1
            origin: 1
            module: -1
            symbol: builtinSeed!
            first: -1
            second: -1
            lengthHash: UInt64(0)
            status: 0
        })
        builtinSeed! + 1 => builtinSeed!
    }

    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> lexer.lex => tokens!
        source -> symbols.collect => table!
        source -> typeTerms.lower => terms!
        [Int; ~] => mapped!
        0 => mapSeed!
        mapSeed! < (terms! -> len) -> while {
            mapped! -> push(-1)
            mapSeed! + 1 => mapSeed!
        }

        0 => completed!
        true => changed!
        (completed! < (terms! -> len) and changed!) -> while {
            false => changed!
            0 => termIndex!
            termIndex! < (terms! -> len) -> while {
                mapped![termIndex!] < 0 -> if {
                    terms![termIndex!] => term
                    (term.firstArgument < 0 or mapped![term.firstArgument] >= 0) => firstReady
                    (term.secondArgument < 0 or mapped![term.secondArgument] >= 0) => secondReady
                    (firstReady and secondReady) -> if {
                        -1 => origin!
                        -1 => targetModule!
                        -1 => targetSymbol!
                        0 => status!
                        term.kind == 1 -> if {
                            -1 => qualifiedIndex!
                            0 => qualifiedSearch!
                            qualifiedSearch! < (qualifiedResults! -> len) -> while {
                                qualifiedResults![qualifiedSearch!] => candidate
                                candidate.sourceModule == sourceIndex! -> if {
                                    candidate.pathAst => ancestor!
                                    false => belongsToTerm!
                                    (ancestor! >= 0 and not belongsToTerm!) -> while {
                                        ancestor! == term.astNode -> if {
                                            true => belongsToTerm!
                                        } else {
                                            nodes![ancestor!].parent => ancestor!
                                        }
                                    }
                                    belongsToTerm! -> if { qualifiedSearch! => qualifiedIndex! }
                                }
                                qualifiedSearch! + 1 => qualifiedSearch!
                            }
                            qualifiedIndex! >= 0 -> if {
                                qualifiedResults![qualifiedIndex!] => imported
                                2 => origin!
                                identities![imported.targetModule].sourceIndex => targetModule!
                                imported.targetSymbol => targetSymbol!
                                imported.status => status!
                            } else {
                                tokens![term.nameToken] => name
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
                                    1 => origin!
                                    -1 => targetModule!
                                    builtinIndex! => targetSymbol!
                                } else {
                                    -1 => ownerFunction!
                                    nodes![term.astNode].parent => ownerAst!
                                    (ownerAst! >= 0 and ownerFunction! < 0) -> while {
                                        0 => ownerSymbolIndex!
                                        ownerSymbolIndex! < (table! -> len) -> while {
                                            table![ownerSymbolIndex!] => ownerCandidate
                                            (ownerCandidate.kind == 7 and ownerCandidate.astNode == ownerAst!) -> if {
                                                ownerSymbolIndex! => ownerFunction!
                                            }
                                            ownerSymbolIndex! + 1 => ownerSymbolIndex!
                                        }
                                        ownerFunction! < 0 -> if { nodes![ownerAst!].parent => ownerAst! }
                                    }
                                    -1 => localSymbol!
                                    0 => symbolIndex!
                                    (symbolIndex! < (table! -> len) and localSymbol! < 0) -> while {
                                        table![symbolIndex!] => candidate
                                        ((candidate.parent < 0 and (candidate.kind == 3 or candidate.kind == 4)) or (candidate.kind == 32 and candidate.parent == ownerFunction!)) -> if {
                                            tokens![candidate.nameToken] => candidateName
                                            name.span.length == candidateName.span.length => equal!
                                            UIntSize(0) => localByte!
                                            (equal! and localByte! < name.span.length) -> while {
                                                source -> byte(name.span.start + localByte!) => leftByte
                                                source -> byte(candidateName.span.start + localByte!) => rightByte
                                                leftByte != rightByte -> if { false => equal! }
                                                localByte! + UIntSize(1) => localByte!
                                            }
                                            equal! -> if { symbolIndex! => localSymbol! }
                                        }
                                        symbolIndex! + 1 => symbolIndex!
                                    }
                                    localSymbol! >= 0 -> if {
                                        table![localSymbol!].kind == 32 -> if { 3 => origin! } else { 0 => origin! }
                                        sourceIndex! => targetModule!
                                        localSymbol! => targetSymbol!
                                    } else {
                                        2 => status!
                                    }
                                }
                            }
                        }
                        term.kind == 7 -> if {
                            4 => origin!
                            -1 => targetModule!
                            tokens![term.nameToken] => constructorName
                            constructorName.span.length == UIntSize(6) -> if {
                                source -> byte(constructorName.span.start) => byte0
                                source -> byte(constructorName.span.start + UIntSize(1)) => byte1
                                source -> byte(constructorName.span.start + UIntSize(2)) => byte2
                                source -> byte(constructorName.span.start + UIntSize(3)) => byte3
                                source -> byte(constructorName.span.start + UIntSize(4)) => byte4
                                source -> byte(constructorName.span.start + UIntSize(5)) => byte5
                                (byte0 == UInt8(82) and byte1 == UInt8(101) and byte2 == UInt8(115) and byte3 == UInt8(117) and byte4 == UInt8(108) and byte5 == UInt8(116)) -> if { 1 => targetSymbol! }
                                (byte0 == UInt8(79) and byte1 == UInt8(112) and byte2 == UInt8(116) and byte3 == UInt8(105) and byte4 == UInt8(111) and byte5 == UInt8(110)) -> if { 0 => targetSymbol! }
                            }
                            constructorName.span.length == UIntSize(4) -> if {
                                source -> byte(constructorName.span.start) => byte0
                                source -> byte(constructorName.span.start + UIntSize(1)) => byte1
                                source -> byte(constructorName.span.start + UIntSize(2)) => byte2
                                source -> byte(constructorName.span.start + UIntSize(3)) => byte3
                                (byte0 == UInt8(84) and byte1 == UInt8(97) and byte2 == UInt8(115) and byte3 == UInt8(107)) -> if { 2 => targetSymbol! }
                            }
                            targetSymbol! < 0 -> if { 2 => status! }
                        }

                        term.firstArgument < 0 -> if { -1 } else { mapped![term.firstArgument] } => firstType
                        term.secondArgument < 0 -> if { -1 } else { mapped![term.secondArgument] } => secondType
                        UInt64(0) => lengthHash!
                        term.lengthToken >= 0 -> if {
                            UInt64(1469598103934665603) => lengthHash!
                            tokens![term.lengthToken] => length
                            UIntSize(0) => lengthByte!
                            lengthByte! < length.span.length -> while {
                                source -> byte(length.span.start + lengthByte!) => value
                                lengthHash! * UInt64(1099511628211) + UInt64(value) => lengthHash!
                                lengthByte! + UIntSize(1) => lengthByte!
                            }
                        }
                        -1 => existing!
                        0 => semanticIndex!
                        (semanticIndex! < (semanticTypes! -> len) and existing! < 0) -> while {
                            semanticTypes![semanticIndex!] => known
                            known.origin == origin! => sameOrigin!
                            (term.kind == 1 and ((known.origin == 0 and origin! == 2) or (known.origin == 2 and origin! == 0))) -> if { true => sameOrigin! }
                            (known.kind == term.kind and sameOrigin! and known.module == targetModule! and known.symbol == targetSymbol! and known.first == firstType and known.second == secondType and known.lengthHash == lengthHash! and known.status == status!) -> if {
                                semanticIndex! => existing!
                            }
                            semanticIndex! + 1 => semanticIndex!
                        }
                        existing! < 0 -> if {
                            semanticTypes! -> len => existing!
                            semanticTypes! -> push(SemanticType {
                                kind: term.kind
                                origin: origin!
                                module: targetModule!
                                symbol: targetSymbol!
                                first: firstType
                                second: secondType
                                lengthHash: lengthHash!
                                status: status!
                            })
                        }
                        existing! => mapped![termIndex!]
                        references! -> push(TypeReference {
                            sourceModule: sourceIndex!
                            typeAst: term.astNode
                            typeId: existing!
                            status: status!
                        })
                        completed! + 1 => completed!
                        true => changed!
                    }
                }
                termIndex! + 1 => termIndex!
            }
        }
        sourceIndex! + 1 => sourceIndex!
    }
    SemanticTypeSet { types: semanticTypes!, references: references! } => result!
    result!
}
