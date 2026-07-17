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
    semantic: typeIds.SemanticTypeSet
    package: analysis.PackageAnalysis
    nominal: [nominalTypes.NominalType; ~]
    composite: [compositeTypes.CompositeType; ~]
    modules: [modules.ModuleIdentity; ~]
    imports: [modules.ImportEdge; ~]
    resolvedImports: [moduleResolve.ResolvedImport; ~]
    qualified: [qualified.QualifiedResolution; ~]
    calls: [calls.ModuleCallResolution; ~]
}

public prepareSources sources: move [file.SourceText; ~] -> CompilationContext {
    sources -> analysis.analyzeSources => packageAnalysis!
    packageAnalysis! -> typeIds.resolveAnalyzed => semanticSet!
    packageAnalysis! -> nominalTypes.resolveAnalyzed => nominalTypes!
    packageAnalysis! -> compositeTypes.resolveAnalyzed => compositeTypes!
    packageAnalysis! -> modules.identitiesAnalyzed => moduleIdentities!
    packageAnalysis! -> modules.importsAnalyzed => importEdges!
    packageAnalysis! -> moduleResolve.resolveAnalyzed => resolvedImports!
    packageAnalysis! -> qualified.resolveAnalyzed => qualifiedResults!
    packageAnalysis! -> calls.resolveModulesAnalyzed => resolvedCalls!

    CompilationContext {
        semantic: semanticSet!
        package: packageAnalysis!
        nominal: nominalTypes!
        composite: compositeTypes!
        modules: moduleIdentities!
        imports: importEdges!
        resolvedImports: resolvedImports!
        qualified: qualifiedResults!
        calls: resolvedCalls!
    } => result!
    result!
}

public prepare sources: [Text; ~] -> CompilationContext {
    [file.SourceText; ~] => ownedSources!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        source -> file.borrowText => ownedSource
        ownedSources! -> push(ownedSource)
        sourceIndex! + 1 => sourceIndex!
    }
    ownedSources! -> prepareSources
}

public prepareFiles paths: [Text; ~] -> CompilationContext uses File {
    [file.SourceText; ~] => ownedSources!
    0 => pathIndex!
    pathIndex! < (paths -> len) -> while {
        paths[pathIndex!] => path
        path -> file.mapText => ownedSource
        ownedSources! -> push(ownedSource)
        pathIndex! + 1 => pathIndex!
    }
    ownedSources! -> prepareSources
}
