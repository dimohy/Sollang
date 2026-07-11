namespace smalllang.compiler.cst

import smalllang.compiler.lexer as lexer
import smalllang.compiler.parser as parser

# Flat green nodes use stable array indexes instead of pointers. Parent links
# and token ranges make the tree traversable without per-node heap allocation.
public struct GreenNode {
    ruleId: Int
    parent: Int
    firstToken: Int
    tokenCount: Int
    start: UIntSize
    length: UIntSize
}

public build source: Text -> [GreenNode; ~] {
    source -> lexer.lex => tokens!
    source -> parser.parseEvents => events!
    [GreenNode; ~] => nodes!
    [Int; ~] => nodeStack!
    0 => stackDepth!

    events! -> each event {
        event.kind == 0 -> if {
            -1 => parent!
            stackDepth! > 0 -> if {
                nodeStack![stackDepth! - 1] => parent!
            }
            source -> len => nodeStart!
            event.tokenIndex < (tokens! -> len) -> if {
                tokens![event.tokenIndex].span.start => nodeStart!
            }
            GreenNode {
                ruleId: event.value
                parent: parent!
                firstToken: -1
                tokenCount: 0
                start: nodeStart!
                length: UIntSize(0)
            } => node
            nodes! -> len => nodeIndex
            nodes! -> push(node)
            nodeStack! -> len => stackCapacity
            stackDepth! < stackCapacity -> if {
                nodeIndex => nodeStack![stackDepth!]
            } else {
                nodeStack! -> push(nodeIndex)
            }
            stackDepth! + 1 => stackDepth!
        } else {
            event.kind == 1 -> if {
                stackDepth! - 1 => stackDepth!
            } else {
                event.kind == 2 -> if {
                    tokens![event.tokenIndex] => token
                    0 => ancestor!
                    ancestor! < stackDepth! -> while {
                        nodeStack![ancestor!] => nodeIndex
                        nodes![nodeIndex] => current!
                        current!.firstToken < 0 -> if {
                            event.tokenIndex => current!.firstToken
                        }
                        current!.tokenCount + 1 => current!.tokenCount
                        token.span.start + token.span.length - current!.start => current!.length
                        current! => nodes![nodeIndex]
                        ancestor! + 1 => ancestor!
                    }
                }
            }
        }
    }

    nodes!
}
