namespace smalllang.compiler.semantic.modules

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.analysis as analysis
import syntax.generated.smalllang as grammar

public struct ModuleIdentity {
    sourceIndex: Int
    pathHash: UInt64
    pathStart: UIntSize
    pathLength: UIntSize
    importCount: Int
}

public struct ImportEdge {
    sourceModule: Int
    targetHash: UInt64
    pathStart: UIntSize
    pathLength: UIntSize
    aliasToken: Int
}

public identities sources: [Text; ~] -> [ModuleIdentity; ~] {
    sources -> analysis.analyze => package
    package -> identitiesAnalyzed
}
public imports sources: [Text; ~] -> [ImportEdge; ~] {
    sources -> analysis.analyze => package
    package -> importsAnalyzed
}
public identitiesAnalyzed package: analysis.PackageAnalysis -> [ModuleIdentity; ~] {
    [ModuleIdentity; ~] => modules!
    package.sources -> len => sourceCount
    0 => sourceIndex!
    sourceIndex! < sourceCount -> while {
        package.sources[sourceIndex!] -> len => sourceLength
        package.sources[sourceIndex!] -> slice(UIntSize(0), sourceLength) => source
        package.ranges[sourceIndex!] => sourceRange
        UInt64(0) => pathHash!
        UIntSize(0) => pathStart!
        UIntSize(0) => pathLength!
        0 => importCount!
        sourceRange.astCount => nodeCount
        0 => nodeIndex!
        nodeIndex! < nodeCount -> while {
            package.nodes[sourceRange.astStart + nodeIndex!] => node
            node.kind == 2 -> if { importCount! + 1 => importCount! }
            node.kind == 1 -> if {
                0 => pathIndex!
                pathIndex! < nodeCount -> while {
                    package.nodes[sourceRange.astStart + pathIndex!] => pathNode
                    (pathNode.parent == nodeIndex! and pathNode.kind == 16) -> if {
                        pathNode.start => pathStart!
                        pathNode.length => pathLength!
                        UInt64(1469598103934665603) => pathHash!
                        pathNode.firstToken => pathToken!
                        pathNode.firstToken + pathNode.tokenCount => pathTokenEnd
                        pathToken! < pathTokenEnd -> while {
                            package.tokens[sourceRange.tokenStart + pathToken!] => token
                            token.kind == grammar.triviaIdWhitespace -> if {
                            } else {
                                token.kind == grammar.triviaIdComment -> if {
                                } else {
                                    UIntSize(0) => pathByte!
                                    pathByte! < token.span.length -> while {
                                        source -> byte(token.span.start + pathByte!) => value
                                        pathHash! * UInt64(1099511628211) + UInt64(value) => pathHash!
                                        pathByte! + UIntSize(1) => pathByte!
                                    }
                                }
                            }
                            pathToken! + 1 => pathToken!
                        }
                        nodeCount => pathIndex!
                    } else {
                        pathIndex! + 1 => pathIndex!
                    }
                }
            }
            nodeIndex! + 1 => nodeIndex!
        }
        ModuleIdentity {
            sourceIndex: sourceIndex!
            pathHash: pathHash!
            pathStart: pathStart!
            pathLength: pathLength!
            importCount: importCount!
        } => module
        modules! -> push(module)
        sourceIndex! + 1 => sourceIndex!
    }
    modules!
}


public importsAnalyzed package: analysis.PackageAnalysis -> [ImportEdge; ~] {
    [ImportEdge; ~] => edges!
    package.sources -> len => sourceCount
    0 => sourceIndex!
    sourceIndex! < sourceCount -> while {
        package.sources[sourceIndex!] -> len => sourceLength
        package.sources[sourceIndex!] -> slice(UIntSize(0), sourceLength) => source
        package.ranges[sourceIndex!] => sourceRange
        sourceRange.astCount => nodeCount
        0 => nodeIndex!
        nodeIndex! < nodeCount -> while {
            package.nodes[sourceRange.astStart + nodeIndex!] => node
            node.kind == 2 -> if {
                UInt64(0) => targetHash!
                UIntSize(0) => importStart!
                UIntSize(0) => importLength!
                -1 => aliasToken!
                -1 => defaultAliasToken!
                0 => pathIndex!
                pathIndex! < nodeCount -> while {
                    package.nodes[sourceRange.astStart + pathIndex!] => pathNode
                    (pathNode.parent == nodeIndex! and pathNode.kind == 16) -> if {
                        pathNode.start => importStart!
                        pathNode.length => importLength!
                        UInt64(1469598103934665603) => targetHash!
                        pathNode.firstToken => importPathToken!
                        pathNode.firstToken + pathNode.tokenCount => importPathEnd
                        importPathToken! < importPathEnd -> while {
                            package.tokens[sourceRange.tokenStart + importPathToken!] => token
                            token.kind == grammar.tokenIdIdentifier -> if {
                                importPathToken! => defaultAliasToken!
                            }
                            token.kind == grammar.triviaIdWhitespace -> if {
                            } else {
                                token.kind == grammar.triviaIdComment -> if {
                                } else {
                                    UIntSize(0) => importByte!
                                    importByte! < token.span.length -> while {
                                        source -> byte(token.span.start + importByte!) => value
                                        targetHash! * UInt64(1099511628211) + UInt64(value) => targetHash!
                                        importByte! + UIntSize(1) => importByte!
                                    }
                                }
                            }
                            importPathToken! + 1 => importPathToken!
                        }
                        nodeCount => pathIndex!
                    } else {
                        pathIndex! + 1 => pathIndex!
                    }
                }
                false => afterAs!
                node.firstToken => importToken!
                node.firstToken + node.tokenCount => importTokenEnd
                importToken! < importTokenEnd -> while {
                    package.tokens[sourceRange.tokenStart + importToken!] => token
                    afterAs! -> if {
                        token.kind == grammar.tokenIdIdentifier -> if {
                            importToken! => aliasToken!
                            importTokenEnd => importToken!
                        } else {
                            importToken! + 1 => importToken!
                        }
                    } else {
                        token.kind == grammar.tokenIdIdentifier -> if {
                            token.span.length == UIntSize(2) -> if {
                                source -> byte(token.span.start) => asByte0
                                source -> byte(token.span.start + UIntSize(1)) => asByte1
                                (asByte0 == UInt8(97) and asByte1 == UInt8(115)) -> if { true => afterAs! }
                            }
                        }
                        importToken! + 1 => importToken!
                    }
                }
                aliasToken! < 0 -> if { defaultAliasToken! => aliasToken! }
                ImportEdge {
                    sourceModule: sourceIndex!
                    targetHash: targetHash!
                    pathStart: importStart!
                    pathLength: importLength!
                    aliasToken: aliasToken!
                } => edge
                edges! -> push(edge)
            }
            nodeIndex! + 1 => nodeIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    edges!
}
