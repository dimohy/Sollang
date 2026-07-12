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

# Kinds: 0 source, 1 namespace, 2 import, 3 struct, 4 enum, 5 trait,
# 6 impl, 7 function, 8 main, 9 binding, 10 flow, 11 call, 12 type,
# 13 string, 14 number, 15 name, 16 path, 17 function signature.
public lower source: Text -> [AstNode; ~] {
    classify rule: Int -> Int => when {
        rule == grammar.ruleIdSourceFile => 0
        rule == grammar.ruleIdNamespaceDeclaration => 1
        rule == grammar.ruleIdImportDeclaration => 2
        rule == grammar.ruleIdStructDeclaration => 3
        rule == grammar.ruleIdEnumDeclaration => 4
        rule == grammar.ruleIdTraitDeclaration => 5
        rule == grammar.ruleIdImplDeclaration => 6
        rule == grammar.ruleIdFunctionDeclaration => 7
        rule == grammar.ruleIdMainBlock => 8
        rule == grammar.ruleIdBindingStatement => 9
        rule == grammar.ruleIdFlowExpression => 10
        rule == grammar.ruleIdFlowTargetCall => 11
        rule == grammar.ruleIdCallExpression => 11
        rule == grammar.ruleIdTypeAnnotation => 12
        rule == grammar.ruleIdStringExpression => 13
        rule == grammar.ruleIdNumberExpression => 14
        rule == grammar.ruleIdNameExpression => 15
        rule == grammar.ruleIdPath => 16
        rule == grammar.ruleIdFunctionSignature => 17
        else => -1
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
