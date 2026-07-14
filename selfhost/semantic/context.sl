namespace smalllang.compiler.semantic.context

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.analysis as analysis
import smalllang.compiler.semantic.calls as calls
import smalllang.compiler.semantic.composite_types as compositeTypes
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.module_resolve as moduleResolve
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.qualified as qualified
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.semantic.type_ids as typeIds
import smalllang.compiler.semantic.type_terms as typeTerms
import smalllang.compiler.semantic.types as semanticTypes
import smalllang.compiler.syntax as syntax
import sys.file as file

# Immutable whole-compilation facts. Consumers borrow this aggregate, so its
# owned flat arrays are built once and are not copied between semantic passes.
public struct CompilationContext {
    sources: [file.SourceText; ~]
    types: [typeIds.SemanticType; ~]
    references: [typeIds.TypeReference; ~]
    fields: [typeIds.NominalField; ~]
    nominal: [nominalTypes.NominalType; ~]
    composite: [compositeTypes.CompositeType; ~]
    modules: [modules.ModuleIdentity; ~]
    imports: [modules.ImportEdge; ~]
    resolvedImports: [moduleResolve.ResolvedImport; ~]
    qualified: [qualified.QualifiedResolution; ~]
    calls: [calls.ModuleCallResolution; ~]
    ranges: [analysis.SourceAnalysisRange; ~]
    nodes: [ast.AstNode; ~]
    tokens: [syntax.SyntaxToken; ~]
    symbols: [symbols.Symbol; ~]
    names: [resolution.ResolvedName; ~]
    terms: [typeTerms.TypeTerm; ~]
    typeUses: [semanticTypes.TypeUse; ~]
}

public prepareSources sources: move [file.SourceText; ~] -> CompilationContext {
    [Text; ~] => sourceViews!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] -> len => sourceLength
        sources[sourceIndex!] -> slice(UIntSize(0), sourceLength) => sourceView
        sourceViews! -> push(sourceView)
        sourceIndex! + 1 => sourceIndex!
    }

    sourceViews! -> analysis.analyze => packageAnalysis
    packageAnalysis -> typeIds.resolveAnalyzed => semanticSet
    packageAnalysis -> nominalTypes.resolveAnalyzed => nominalTypes!
    packageAnalysis -> compositeTypes.resolveAnalyzed => compositeTypes!
    packageAnalysis -> modules.identitiesAnalyzed => moduleIdentities!
    packageAnalysis -> modules.importsAnalyzed => importEdges!
    packageAnalysis -> moduleResolve.resolveAnalyzed => resolvedImports!
    packageAnalysis -> qualified.resolveAnalyzed => qualifiedResults!
    packageAnalysis -> calls.resolveModulesAnalyzed => resolvedCalls!

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
    [typeTerms.TypeTerm; ~] => contextTerms!
    packageAnalysis.terms -> each term { contextTerms! -> push(term) }
    [semanticTypes.TypeUse; ~] => contextTypeUses!
    packageAnalysis.typeUses -> each typeUse { contextTypeUses! -> push(typeUse) }

    CompilationContext {
        sources: sources
        types: contextTypes!
        references: contextReferences!
        fields: contextFields!
        nominal: nominalTypes!
        composite: compositeTypes!
        modules: moduleIdentities!
        imports: importEdges!
        resolvedImports: resolvedImports!
        qualified: qualifiedResults!
        calls: resolvedCalls!
        ranges: contextRanges!
        nodes: contextNodes!
        tokens: contextTokens!
        symbols: contextSymbols!
        names: contextNames!
        terms: contextTerms!
        typeUses: contextTypeUses!
    } => result!
    result!
}

public prepare sources: [Text; ~] -> CompilationContext {
    [file.SourceText; ~] => ownedSources!
    sources -> each source {
        source -> file.borrowText => ownedSource!
        ownedSources! -> push(ownedSource!)
    }
    ownedSources! -> prepareSources
}

public prepareFiles paths: [Text; ~] -> CompilationContext uses File {
    [file.SourceText; ~] => ownedSources!
    paths -> each path {
        path -> file.mapText => ownedSource!
        ownedSources! -> push(ownedSource!)
    }
    ownedSources! -> prepareSources
}
