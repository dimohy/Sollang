import smalllang.compiler.ast as ast
import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.semantic.analysis as analysis
import smalllang.compiler.semantic.calls as calls
import smalllang.compiler.semantic.composite_types as compositeTypes
import smalllang.compiler.semantic.context as semanticContext
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.qualified as qualified
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.semantic.type_ids as typeIds
import smalllang.compiler.syntax as syntax

main {
    [
        """
        struct Point {
            values: [Int; ~]
        }

        keep value: Point -> Point => value

        main {
            Point { values: [1, 2, ~] } -> keep => point
        }
        """,
        ~
    ] => sources!

    sources! -> typeIds.resolve => semantic
    sources! -> nominalTypes.resolve => nominal!
    sources! -> compositeTypes.resolve => composite!
    sources! -> modules.identities => moduleIdentities!
    sources! -> qualified.resolve => qualifiedResults!
    [Text; ~] => callSources!
    sources! -> each callSource { callSources! -> push(callSource) }
    [modules.ModuleIdentity; ~] => callModules!
    moduleIdentities! -> each callModule { callModules! -> push(callModule) }
    [qualified.QualifiedResolution; ~] => callQualified!
    qualifiedResults! -> each callQualifiedResult { callQualified! -> push(callQualifiedResult) }
    calls.ModuleCallRequest {
        sources: callSources!
        modules: callModules!
        qualified: callQualified!
    } => callRequest!
    callRequest! -> calls.resolveModulesPrepared => resolvedCalls!
    sources! -> analysis.analyze => packageAnalysis
    [analysis.SourceAnalysisRange; ~] => analysisRanges!
    packageAnalysis.ranges -> each sourceRange { analysisRanges! -> push(sourceRange) }
    [ast.AstNode; ~] => analysisNodes!
    packageAnalysis.nodes -> each analysisNode { analysisNodes! -> push(analysisNode) }
    [syntax.SyntaxToken; ~] => analysisTokens!
    packageAnalysis.tokens -> each analysisToken { analysisTokens! -> push(analysisToken) }
    [symbols.Symbol; ~] => analysisSymbols!
    packageAnalysis.symbols -> each analysisSymbol { analysisSymbols! -> push(analysisSymbol) }
    [resolution.ResolvedName; ~] => analysisNames!
    packageAnalysis.names -> each analysisName { analysisNames! -> push(analysisName) }
    [Text; ~] => preparedSources!
    sources! -> each preparedSource { preparedSources! -> push(preparedSource) }
    [typeIds.SemanticType; ~] => preparedTypes!
    semantic.types -> each preparedType { preparedTypes! -> push(preparedType) }
    [typeIds.TypeReference; ~] => preparedReferences!
    semantic.references -> each preparedReference { preparedReferences! -> push(preparedReference) }
    [typeIds.NominalField; ~] => preparedFields!
    semantic.fields -> each preparedField { preparedFields! -> push(preparedField) }
    typedIr.TypedIrRequest {
        sources: preparedSources!
        types: preparedTypes!
        references: preparedReferences!
        fields: preparedFields!
        nominal: nominal!
        composite: composite!
        modules: moduleIdentities!
        qualified: qualifiedResults!
        calls: resolvedCalls!
        analysisRanges: analysisRanges!
        analysisNodes: analysisNodes!
        analysisTokens: analysisTokens!
        analysisSymbols: analysisSymbols!
        analysisNames: analysisNames!
    } => request!
    request! -> typedIr.lowerPrepared => prepared!
    sources! -> typedIr.lower => baseline!
    sources! -> semanticContext.prepare => sharedContext
    sharedContext -> typedIr.lowerContext => shared!

    ((prepared! -> len) == (baseline! -> len) and (prepared! -> len) == (shared! -> len)) => equal!
    0 => canonical!
    0 => nodeIndex!
    (equal! and nodeIndex! < (prepared! -> len)) -> while {
        prepared![nodeIndex!] => left
        baseline![nodeIndex!] => right
        shared![nodeIndex!] => sharedNode
        (left.kind != right.kind or left.typeId != right.typeId or left.typeKind != right.typeKind or left.typeFlags != right.typeFlags or left.kind != sharedNode.kind or left.typeId != sharedNode.typeId or left.typeKind != sharedNode.typeKind or left.typeFlags != sharedNode.typeFlags) -> if { false => equal! }
        left.typeId >= 0 -> if { canonical! + 1 => canonical! }
        nodeIndex! + 1 => nodeIndex!
    }
    equal! -> if { "true" } else { "false" } => equalText
    "prepared=$equalText, nodes=$(prepared! -> len), canonical=$(canonical!)" -> println
}
