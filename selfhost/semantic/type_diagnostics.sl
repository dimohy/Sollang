namespace smalllang.compiler.semantic.type_diagnostics

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.syntax as syntax

public struct TypeDiagnostic {
    code: Int
    sourceModule: Int
    typeAst: Int
    targetModule: Int
    targetSymbol: Int
    span: syntax.SourceSpan
}

# Code 3 identifies a missing imported nominal type.
# Code 4 identifies an imported nominal type that is not public.
public analyze sources: [Text; ~] -> [TypeDiagnostic; ~] {
    sources -> nominalTypes.resolve => resolvedTypes!
    [TypeDiagnostic; ~] => diagnostics!
    0 => resolvedIndex!
    resolvedIndex! < (resolvedTypes! -> len) -> while {
        resolvedTypes![resolvedIndex!] => resolved
        (resolved.status == 2 or resolved.status == 3) -> if {
            sources[resolved.sourceModule] -> ast.lower => sourceNodes!
            sourceNodes![resolved.typeAst] => typeNode
            syntax.SourceSpan {
                fileId: resolved.sourceModule
                start: typeNode.start
                length: typeNode.length
            } => diagnosticSpan
            TypeDiagnostic {
                code: resolved.status == 2 -> if { 3 } else { 4 }
                sourceModule: resolved.sourceModule
                typeAst: resolved.typeAst
                targetModule: resolved.targetModule
                targetSymbol: resolved.targetSymbol
                span: diagnosticSpan
            } => diagnostic
            diagnostics! -> push(diagnostic)
        }
        resolvedIndex! + 1 => resolvedIndex!
    }
    diagnostics!
}
