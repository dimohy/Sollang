namespace smalllang.compiler.semantic.analysis

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
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
}

public struct PackageAnalysis {
    sources: [Text; ~]
    ranges: [SourceAnalysisRange; ~]
    nodes: [ast.AstNode; ~]
    tokens: [syntax.SyntaxToken; ~]
    symbols: [symbols.Symbol; ~]
    names: [resolution.ResolvedName; ~]
}

public analyze sources: [Text; ~] -> PackageAnalysis {
    [Text; ~] => preparedSources!
    [SourceAnalysisRange; ~] => ranges!
    [ast.AstNode; ~] => nodes!
    [syntax.SyntaxToken; ~] => tokens!
    [symbols.Symbol; ~] => symbolTable!
    [resolution.ResolvedName; ~] => names!

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
        } => range
        ranges! -> push(range)
        resolutionRequest!.nodes -> each node { nodes! -> push(node) }
        resolutionRequest!.tokens -> each token { tokens! -> push(token) }
        resolutionRequest!.symbols -> each symbol { symbolTable! -> push(symbol) }
        sourceNames! -> each name { names! -> push(name) }
        sourceIndex! + 1 => sourceIndex!
    }

    PackageAnalysis {
        sources: preparedSources!
        ranges: ranges!
        nodes: nodes!
        tokens: tokens!
        symbols: symbolTable!
        names: names!
    } => result!
    result!
}
