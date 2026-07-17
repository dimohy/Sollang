namespace smalllang.compiler.semantic.type_diagnostics

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.composite_types as compositeTypes
import smalllang.compiler.semantic.context as semanticContext
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
    sources -> semanticContext.prepare => prepared
    prepared -> analyzeContext
}

public analyzeContext prepared: semanticContext.CompilationContext -> [TypeDiagnostic; ~] {
    [TypeDiagnostic; ~] => diagnostics!
    0 => resolvedIndex!
    resolvedIndex! < (prepared.nominal -> len) -> while {
        prepared.nominal[resolvedIndex!] => resolved
        (resolved.status == 2 or resolved.status == 3) -> if {
            prepared.package.ranges[resolved.sourceModule] => sourceRange
            prepared.package.nodes[sourceRange.astStart + resolved.typeAst] => typeNode
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
    0 => compositeIndex!
    compositeIndex! < (prepared.composite -> len) -> while {
        prepared.composite[compositeIndex!] => resolvedComposite
        resolvedComposite.status == 2 -> if {
            prepared.package.ranges[resolvedComposite.sourceModule] => sourceRange
            prepared.package.nodes[sourceRange.astStart + resolvedComposite.typeAst] => typeNode
            diagnostics! -> push(TypeDiagnostic {
                code: 3
                sourceModule: resolvedComposite.sourceModule
                typeAst: resolvedComposite.typeAst
                targetModule: -1
                targetSymbol: -1
                span: syntax.SourceSpan {
                    fileId: resolvedComposite.sourceModule
                    start: typeNode.start
                    length: typeNode.length
                }
            })
        }
        compositeIndex! + 1 => compositeIndex!
    }
    diagnostics!
}
