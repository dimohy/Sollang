namespace smalllang.compiler.semantic.diagnostics

import smalllang.compiler.lexer as lexer
import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.syntax as syntax

public struct SemanticDiagnostic {
    code: Int
    symbol: Int
    previousSymbol: Int
    span: syntax.SourceSpan
}

# Code 1 identifies a duplicate declaration in the same lexical owner.
# Code 2 identifies an unresolved name expression.
public analyze source: Text -> [SemanticDiagnostic; ~] {
    source -> symbols.collect => table!
    source -> lexer.lex => tokens!
    [SemanticDiagnostic; ~] => diagnostics!
    table! -> len => symbolCount
    0 => symbolIndex!

    symbolIndex! < symbolCount -> while {
        table![symbolIndex!] => current
        -1 => duplicateOf!
        0 => candidateIndex!
        (candidateIndex! < symbolIndex! and duplicateOf! < 0) -> while {
            table![candidateIndex!] => candidate
            current.parent == candidate.parent -> if {
                tokens![current.nameToken] => currentName
                tokens![candidate.nameToken] => candidateName
                currentName.span.length == candidateName.span.length => namesEqual!
                UIntSize(0) => nameByte!
                (namesEqual! and nameByte! < currentName.span.length) -> while {
                    source -> byte(currentName.span.start + nameByte!) => currentByte
                    source -> byte(candidateName.span.start + nameByte!) => candidateByte
                    currentByte != candidateByte -> if {
                        false => namesEqual!
                    }
                    nameByte! + UIntSize(1) => nameByte!
                }
                namesEqual! -> if {
                    candidateIndex! => duplicateOf!
                }
            }
            candidateIndex! + 1 => candidateIndex!
        }
        duplicateOf! >= 0 -> if {
            tokens![current.nameToken] => duplicateName
            SemanticDiagnostic {
                code: 1
                symbol: symbolIndex!
                previousSymbol: duplicateOf!
                span: duplicateName.span
            } => diagnostic
            diagnostics! -> push(diagnostic)
        }
        symbolIndex! + 1 => symbolIndex!
    }

    source -> ast.lower => nodes!
    source -> resolution.resolve => resolved!
    nodes! -> len => astCount
    resolved! -> len => resolvedCount
    0 => diagnosticAstIndex!
    diagnosticAstIndex! < astCount -> while {
        nodes![diagnosticAstIndex!] => nameAst
        nameAst.kind == 15 -> if {
            false => nameResolved!
            0 => resolutionIndex!
            resolutionIndex! < resolvedCount -> while {
                resolved![resolutionIndex!].astNode == diagnosticAstIndex! -> if {
                    true => nameResolved!
                }
                resolutionIndex! + 1 => resolutionIndex!
            }
            not nameResolved! -> if {
                tokens![nameAst.payloadToken] => unresolvedName
                SemanticDiagnostic {
                    code: 2
                    symbol: -1
                    previousSymbol: -1
                    span: unresolvedName.span
                } => unresolvedDiagnostic
                diagnostics! -> push(unresolvedDiagnostic)
            }
        }
        diagnosticAstIndex! + 1 => diagnosticAstIndex!
    }

    diagnostics!
}
