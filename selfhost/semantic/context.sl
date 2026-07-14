namespace smalllang.compiler.semantic.context

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.analysis as analysis
import smalllang.compiler.semantic.calls as calls
import smalllang.compiler.semantic.composite_types as compositeTypes
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.qualified as qualified
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.semantic.type_ids as typeIds
import smalllang.compiler.syntax as syntax

# Immutable whole-compilation facts. Consumers borrow this aggregate, so its
# owned flat arrays are built once and are not copied between semantic passes.
public struct CompilationContext {
    sources: [Text; ~]
    types: [typeIds.SemanticType; ~]
    references: [typeIds.TypeReference; ~]
    fields: [typeIds.NominalField; ~]
    nominal: [nominalTypes.NominalType; ~]
    composite: [compositeTypes.CompositeType; ~]
    modules: [modules.ModuleIdentity; ~]
    qualified: [qualified.QualifiedResolution; ~]
    calls: [calls.ModuleCallResolution; ~]
    ranges: [analysis.SourceAnalysisRange; ~]
    nodes: [ast.AstNode; ~]
    tokens: [syntax.SyntaxToken; ~]
    symbols: [symbols.Symbol; ~]
    names: [resolution.ResolvedName; ~]
}

public prepare sources: [Text; ~] -> CompilationContext {
    sources -> analysis.analyze => packageAnalysis
    sources -> typeIds.resolve => semanticSet
    sources -> nominalTypes.resolve => nominalTypes!
    sources -> compositeTypes.resolve => compositeTypes!
    packageAnalysis -> modules.identitiesAnalyzed => moduleIdentities!
    packageAnalysis -> qualified.resolveAnalyzed => qualifiedResults!
    packageAnalysis -> calls.resolveModulesAnalyzed => resolvedCalls!

    [Text; ~] => contextSources!
    sources -> each source { contextSources! -> push(source) }
    [typeIds.SemanticType; ~] => contextTypes!
    semanticSet.types -> each semanticType { contextTypes! -> push(semanticType) }
    [typeIds.TypeReference; ~] => contextReferences!
    semanticSet.references -> each reference { contextReferences! -> push(reference) }
    [typeIds.NominalField; ~] => contextFields!
    semanticSet.fields -> each field { contextFields! -> push(field) }
    [analysis.SourceAnalysisRange; ~] => contextRanges!
    packageAnalysis.ranges -> each sourceRange { contextRanges! -> push(sourceRange) }
    [ast.AstNode; ~] => contextNodes!
    packageAnalysis.nodes -> each node { contextNodes! -> push(node) }
    [syntax.SyntaxToken; ~] => contextTokens!
    packageAnalysis.tokens -> each token { contextTokens! -> push(token) }
    [symbols.Symbol; ~] => contextSymbols!
    packageAnalysis.symbols -> each symbol { contextSymbols! -> push(symbol) }
    [resolution.ResolvedName; ~] => contextNames!
    packageAnalysis.names -> each name { contextNames! -> push(name) }

    CompilationContext {
        sources: contextSources!
        types: contextTypes!
        references: contextReferences!
        fields: contextFields!
        nominal: nominalTypes!
        composite: compositeTypes!
        modules: moduleIdentities!
        qualified: qualifiedResults!
        calls: resolvedCalls!
        ranges: contextRanges!
        nodes: contextNodes!
        tokens: contextTokens!
        symbols: contextSymbols!
        names: contextNames!
    } => result!
    result!
}
