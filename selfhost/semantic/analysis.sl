namespace smalllang.compiler.semantic.analysis

import smalllang.compiler.ast as ast
import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols as symbols
import smalllang.compiler.semantic.type_terms as typeTerms
import smalllang.compiler.semantic.types as types
import smalllang.compiler.syntax as syntax
import sys.file as file

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
    sources: [file.SourceText; ~]
    ranges: [SourceAnalysisRange; ~]
    nodes: [ast.AstNode; ~]
    tokens: [syntax.SyntaxToken; ~]
    symbols: [symbols.Symbol; ~]
    names: [resolution.ResolvedName; ~]
    terms: [typeTerms.TypeTerm; ~]
    typeUses: [types.TypeUse; ~]
}

# A source-local product is safe to compute on a native worker: it borrows only
# the immutable source text and owns every array it returns. Package assembly
# later consumes these products in source-index order, so scheduling never
# changes public symbol, token, or type identities.
public struct SourceAnalysis {
    nodes: [ast.AstNode; ~]
    tokens: [syntax.SyntaxToken; ~]
    symbols: [symbols.Symbol; ~]
    names: [resolution.ResolvedName; ~]
    terms: [typeTerms.TypeTerm; ~]
    typeUses: [types.TypeUse; ~]
}

public analyzeSource sourceText: file.SourceText -> SourceAnalysis {
    sourceText -> len => sourceLength
    sourceText -> slice(UIntSize(0), sourceLength) => source
    source -> ast.lower => sourceNodes!
    source -> lexer.lex => sourceTokens!
    sourceNodes! -> symbols.collectPrepared => sourceSymbols!
    resolution.ResolutionRequest {
        source: source
        nodes: sourceNodes!
        symbols: sourceSymbols!
        tokens: sourceTokens!
    } => resolutionRequest
    resolutionRequest -> resolution.resolvePrepared => sourceNames!

    [ast.AstNode; ~] => termNodes!
    0 => termNodeIndex!
    termNodeIndex! < (resolutionRequest.nodes -> len) -> while {
        resolutionRequest.nodes[termNodeIndex!] => node
        termNodes! -> push(node)
        termNodeIndex! + 1 => termNodeIndex!
    }
    [syntax.SyntaxToken; ~] => termTokens!
    0 => termTokenIndex!
    termTokenIndex! < (resolutionRequest.tokens -> len) -> while {
        resolutionRequest.tokens[termTokenIndex!] => token
        termTokens! -> push(token)
        termTokenIndex! + 1 => termTokenIndex!
    }
    typeTerms.TypeTermRequest {
        source: source
        nodes: termNodes!
        tokens: termTokens!
    } => termRequest!
    termRequest! -> typeTerms.lowerPrepared => sourceTerms!
    termRequest! -> types.canonicalizePrepared => sourceTypeUses!

    [ast.AstNode; ~] => resultNodes!
    0 => resultNodeIndex!
    resultNodeIndex! < (resolutionRequest.nodes -> len) -> while {
        resolutionRequest.nodes[resultNodeIndex!] => node
        resultNodes! -> push(node)
        resultNodeIndex! + 1 => resultNodeIndex!
    }
    [syntax.SyntaxToken; ~] => resultTokens!
    0 => resultTokenIndex!
    resultTokenIndex! < (resolutionRequest.tokens -> len) -> while {
        resolutionRequest.tokens[resultTokenIndex!] => token
        resultTokens! -> push(token)
        resultTokenIndex! + 1 => resultTokenIndex!
    }
    [symbols.Symbol; ~] => resultSymbols!
    0 => resultSymbolIndex!
    resultSymbolIndex! < (resolutionRequest.symbols -> len) -> while {
        resolutionRequest.symbols[resultSymbolIndex!] => symbol
        resultSymbols! -> push(symbol)
        resultSymbolIndex! + 1 => resultSymbolIndex!
    }

    SourceAnalysis {
        nodes: resultNodes!
        tokens: resultTokens!
        symbols: resultSymbols!
        names: sourceNames!
        terms: sourceTerms!
        typeUses: sourceTypeUses!
    } => result!
    result!
}

public analyzeSources sources: move [file.SourceText; ~] -> PackageAnalysis {
    [SourceAnalysisRange; ~] => ranges!
    [ast.AstNode; ~] => nodes!
    [syntax.SyntaxToken; ~] => tokens!
    [symbols.Symbol; ~] => symbolTable!
    [resolution.ResolvedName; ~] => names!
    [typeTerms.TypeTerm; ~] => terms!
    [types.TypeUse; ~] => typeUses!

    sources -> parallel sourceText {
        sourceText -> analyzeSource
    } => sourceAnalyses!

    0 => sourceIndex!
    sourceAnalyses! -> each sourceAnalysis {

        SourceAnalysisRange {
            sourceModule: sourceIndex!
            astStart: nodes! -> len
            astCount: Int(sourceAnalysis.nodes -> len)
            tokenStart: tokens! -> len
            tokenCount: Int(sourceAnalysis.tokens -> len)
            symbolStart: symbolTable! -> len
            symbolCount: Int(sourceAnalysis.symbols -> len)
            nameStart: names! -> len
            nameCount: Int(sourceAnalysis.names -> len)
            termStart: terms! -> len
            termCount: Int(sourceAnalysis.terms -> len)
            typeStart: typeUses! -> len
            typeCount: Int(sourceAnalysis.typeUses -> len)
        } => range
        ranges! -> push(range)
        0 => nodeCopyIndex93!
        nodeCopyIndex93! < (sourceAnalysis.nodes -> len) -> while {
            (sourceAnalysis.nodes)[nodeCopyIndex93!] => node
            nodes! -> push(node)
            nodeCopyIndex93! + 1 => nodeCopyIndex93!
        }
        0 => tokenCopyIndex94!
        tokenCopyIndex94! < (sourceAnalysis.tokens -> len) -> while {
            (sourceAnalysis.tokens)[tokenCopyIndex94!] => token
            tokens! -> push(token)
            tokenCopyIndex94! + 1 => tokenCopyIndex94!
        }
        0 => symbolCopyIndex95!
        symbolCopyIndex95! < (sourceAnalysis.symbols -> len) -> while {
            (sourceAnalysis.symbols)[symbolCopyIndex95!] => symbol
            symbolTable! -> push(symbol)
            symbolCopyIndex95! + 1 => symbolCopyIndex95!
        }
        0 => nameCopyIndex96!
        nameCopyIndex96! < (sourceAnalysis.names -> len) -> while {
            (sourceAnalysis.names)[nameCopyIndex96!] => name
            names! -> push(name)
            nameCopyIndex96! + 1 => nameCopyIndex96!
        }
        0 => termCopyIndex97!
        termCopyIndex97! < (sourceAnalysis.terms -> len) -> while {
            (sourceAnalysis.terms)[termCopyIndex97!] => term
            terms! -> push(term)
            termCopyIndex97! + 1 => termCopyIndex97!
        }
        0 => typeUseCopyIndex98!
        typeUseCopyIndex98! < (sourceAnalysis.typeUses -> len) -> while {
            (sourceAnalysis.typeUses)[typeUseCopyIndex98!] => typeUse
            typeUses! -> push(typeUse)
            typeUseCopyIndex98! + 1 => typeUseCopyIndex98!
        }
        sourceIndex! + 1 => sourceIndex!
    }

    PackageAnalysis {
        sources: sources
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

public analyze sources: [Text; ~] -> PackageAnalysis {
    [file.SourceText; ~] => ownedSources!
    0 => sourceIndex!
    sourceIndex! < (sources -> len) -> while {
        sources[sourceIndex!] -> file.borrowText => ownedSource
        ownedSources! -> push(ownedSource)
        sourceIndex! + 1 => sourceIndex!
    }
    ownedSources! -> analyzeSources
}
