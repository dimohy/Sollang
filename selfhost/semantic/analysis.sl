namespace smalllang.compiler.semantic.analysis

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.semantic.type_terms as typeTerms
import smalllang.compiler.semantic.types as types
import smalllang.compiler.syntax as syntax

# One package owns relocatable flat products. Every index stored inside an AST,
# symbol, or resolved name remains source-local; SourceAnalysisRange maps that
# local index space onto the package arrays without nested owned containers.
public struct SourceAnalysisRange {
    sourceModule: Int
    astStart: Int
    astCount: Int
    tokenStart: Int
    tokenCount: Int
    symbolStart: Int
    symbolCount: Int
    nameStart: Int
    nameCount: Int
    termStart: Int
    termCount: Int
    typeStart: Int
    typeCount: Int
}

public struct PackageAnalysis {
    sources: [Text; ~]
    ranges: [SourceAnalysisRange; ~]
    nodes: [ast.AstNode; ~]
    tokens: [syntax.SyntaxToken; ~]
    symbols: [symbols.Symbol; ~]
    names: [resolution.ResolvedName; ~]
    terms: [typeTerms.TypeTerm; ~]
    typeUses: [types.TypeUse; ~]
}

public analyze sources: [Text; ~] -> PackageAnalysis {
    [Text; ~] => preparedSources!
    [SourceAnalysisRange; ~] => ranges!
    [ast.AstNode; ~] => nodes!
    [syntax.SyntaxToken; ~] => tokens!
    [symbols.Symbol; ~] => symbolTable!
    [resolution.ResolvedName; ~] => names!
    [typeTerms.TypeTerm; ~] => terms!
    [types.TypeUse; ~] => typeUses!

    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] => source
        preparedSources! -> push(source)
        source -> ast.lower => sourceNodes!
        source -> lexer.lex => sourceTokens!
        sourceNodes! -> symbols.collectPrepared => sourceSymbols!
        resolution.ResolutionRequest {
            source: source
            nodes: sourceNodes!
            symbols: sourceSymbols!
            tokens: sourceTokens!
        } => resolutionRequest!
        resolutionRequest! -> resolution.resolvePrepared => sourceNames!
        [ast.AstNode; ~] => termNodes!
        resolutionRequest!.nodes -> each node { termNodes! -> push(node) }
        [syntax.SyntaxToken; ~] => termTokens!
        resolutionRequest!.tokens -> each token { termTokens! -> push(token) }
        typeTerms.TypeTermRequest {
            source: source
            nodes: termNodes!
            tokens: termTokens!
        } => termRequest!
        termRequest! -> typeTerms.lowerPrepared => sourceTerms!
        termRequest! -> types.canonicalizePrepared => sourceTypeUses!

        SourceAnalysisRange {
            sourceModule: sourceIndex!
            astStart: nodes! -> len
            astCount: resolutionRequest!.nodes -> len
            tokenStart: tokens! -> len
            tokenCount: resolutionRequest!.tokens -> len
            symbolStart: symbolTable! -> len
            symbolCount: resolutionRequest!.symbols -> len
            nameStart: names! -> len
            nameCount: sourceNames! -> len
            termStart: terms! -> len
            termCount: sourceTerms! -> len
            typeStart: typeUses! -> len
            typeCount: sourceTypeUses! -> len
        } => range
        ranges! -> push(range)
        resolutionRequest!.nodes -> each node { nodes! -> push(node) }
        resolutionRequest!.tokens -> each token { tokens! -> push(token) }
        resolutionRequest!.symbols -> each symbol { symbolTable! -> push(symbol) }
        sourceNames! -> each name { names! -> push(name) }
        sourceTerms! -> each term { terms! -> push(term) }
        sourceTypeUses! -> each typeUse { typeUses! -> push(typeUse) }
        sourceIndex! + 1 => sourceIndex!
    }

    PackageAnalysis {
        sources: preparedSources!
        ranges: ranges!
        nodes: nodes!
        tokens: tokens!
        symbols: symbolTable!
        names: names!
        terms: terms!
        typeUses: typeUses!
    } => result!
    result!
}
