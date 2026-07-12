namespace smalllang.compiler.ast

import smalllang.compiler.cst as cst
import smalllang.compiler.lexer as lexer
import syntax.generated.smalllang as grammar

# The bootstrap AST is flat and index-addressed like the green CST. Later
# lowering slices will add declaration/expression payload tables without
# introducing per-node heap allocation.
public struct AstNode {
    kind: Int
    parent: Int
    cstRuleId: Int
    firstToken: Int
    tokenCount: Int
    start: UIntSize
    length: UIntSize
}

# Kinds: 0 source file, 1 main block, 2 number expression, 3 name expression.
public lower source: Text -> [AstNode; ~] {
    classify rule: Int -> Int {
        rule == grammar.ruleIdSourceFile -> if {
            0
        } else {
            rule == grammar.ruleIdMainBlock -> if {
                1
            } else {
                rule == grammar.ruleIdNumberExpression -> if {
                    2
                } else {
                    rule == grammar.ruleIdNameExpression -> if { 3 } else { -1 }
                }
            }
        }
    }
    source -> cst.build => green!
    source -> lexer.lex => tokens!
    [AstNode; ~] => ast!
    [Int; ~] => cstToAst!
    0 => cstIndex!
    0 - 1 => missingNode

    green! -> len => greenCount
    cstIndex! < greenCount -> while {
        green![cstIndex!] => node
        node.ruleId -> classify => astKind
        cstToAst! -> push(missingNode)
        astKind >= 0 -> if {
            -1 => astParent!
            node.parent => parentCst!
            (parentCst! >= 0 and astParent! < 0) -> while {
                cstToAst![parentCst!] => mappedParent
                mappedParent >= 0 -> if {
                    mappedParent => astParent!
                } else {
                    green![parentCst!].parent => parentCst!
                }
            }
            node.firstToken => astFirstToken!
            node.tokenCount => astTokenCount!
            (astTokenCount! > 0 and (tokens![astFirstToken!].kind == grammar.triviaIdWhitespace or tokens![astFirstToken!].kind == grammar.triviaIdComment)) -> while {
                astFirstToken! + 1 => astFirstToken!
                astTokenCount! - 1 => astTokenCount!
            }
            (astTokenCount! > 0 and (tokens![astFirstToken! + astTokenCount! - 1].kind == grammar.triviaIdWhitespace or tokens![astFirstToken! + astTokenCount! - 1].kind == grammar.triviaIdComment)) -> while {
                astTokenCount! - 1 => astTokenCount!
            }
            node.start => astStart!
            UIntSize(0) => astLength!
            astTokenCount! > 0 -> if {
                tokens![astFirstToken!].span.start => astStart!
                tokens![astFirstToken! + astTokenCount! - 1] => astLastToken
                astLastToken.span.start + astLastToken.span.length - astStart! => astLength!
            }
            AstNode {
                kind: astKind
                parent: astParent!
                cstRuleId: node.ruleId
                firstToken: astFirstToken!
                tokenCount: astTokenCount!
                start: astStart!
                length: astLength!
            } => astNode
            ast! -> len => astIndex
            ast! -> push(astNode)
            astIndex => cstToAst![cstIndex!]
        }
        cstIndex! + 1 => cstIndex!
    }

    ast!
}
