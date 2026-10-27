from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');o=b/'fold17043-candidate';o.mkdir(exist_ok=False)
s=(b/'fold17041-candidate/symbols.slg').read_text();s=s.replace('prefix.kind != 35 and prefix.kind != 36 and prefix.astNode >= 0 and prefix.astNode < firstAst','prefix.astNode >= 0 and prefix.astNode < firstAst\n            and prefix.kind != 36\n            and (prefix.kind != 35 or nodes[prefix.astNode].kind == 60)');(o/'symbols.slg').write_text(s)
(o/'analysis.slg').write_bytes((b/'fold17041-candidate/analysis.slg').read_bytes())
fields=['kind','parent','astNode','nameToken','typeNode','secondaryTypeNode','blockNameToken','blockTypeNode','blockResultTypeNode','flags']
helper='''import sollang.compiler.ast as ast
import sollang.compiler.lexer as lexer
import sollang.compiler.syntax as syntax
import sollang.compiler.semantic.symbols as symbols
import sollang.compiler.semantic.analysis as analysis
import sollang.compiler.semantic.resolve as resolution
import sollang.compiler.semantic.type_terms as typeTerms
import sollang.compiler.semantic.types as types
import sollang.compiler.semantic.constant_collection_lowering as constantLowering
import sollang.compiler.ir.interpolation as interpolation
import sys.file as file

checkIdentity source: Text -> Unit uses Process {
    source -> ast.lower => nodes
    source -> lexer.lex => tokens
    nodes -> symbols.collectPrepared => original
    source -> analysis.completeSourceInterpolations(nodes, tokens, original) => completed
    0 => i!
    i! < (original -> len) -> while {
        original[i!] => a
        completed.symbols[i!] => b
        CHECK -> if { process.exit(10) }
        i! + 1 => i!
    }
    source -> resolution.resolvePrepared(nodes, original, tokens) => names
    [file.SourceText; ~] => sources!
    [ast.AstNode; ~] => flatNodes!
    [syntax.SyntaxToken; ~] => flatTokens!
    [symbols.Symbol; ~] => flatSymbols!
    [resolution.ResolvedName; ~] => flatNames!
    [analysis.SourceAnalysisRange; ~] => ranges!
    0 => module!
    module! < 2 -> while {
        sources! -> push(source -> file.borrowText)
        ranges! -> push(analysis.SourceAnalysisRange {
            sourceModule: module!, astStart: flatNodes! -> len, astCount: nodes -> len,
            tokenStart: flatTokens! -> len, tokenCount: tokens -> len,
            symbolStart: flatSymbols! -> len, symbolCount: original -> len,
            nameStart: flatNames! -> len, nameCount: names -> len,
            termStart: 0, termCount: 0, typeStart: 0, typeCount: 0,
            literalStart: 0, literalCount: 0, constantFailureStart: 0, constantFailureCount: 0
        })
        nodes -> each node { flatNodes! -> push(node) }
        tokens -> each token { flatTokens! -> push(token) }
        original -> each symbol { flatSymbols! -> push(symbol) }
        names -> each name { flatNames! -> push(name) }
        module! + 1 => module!
    }
    analysis.PackageAnalysis {
        sources: sources!, entrySourceModule: -1,
        interpolationRanges: [interpolation.InterpolationSourceRange; ~],
        interpolations: [interpolation.InterpolationNode; ~], ranges: ranges!,
        nodes: flatNodes!, tokens: flatTokens!, symbols: flatSymbols!, names: flatNames!,
        terms: [typeTerms.TypeTerm; ~], typeUses: [types.TypeUse; ~],
        constantLiterals: [constantLowering.Literal; ~], constantFailures: [constantLowering.Failure; ~]
    } -> analysis.completePackageInterpolations => legacy
    source -> resolution.resolvePrepared(completed.nodes, completed.symbols, completed.tokens) => freshNames
    0 => rangeIndex!
    legacy.ranges -> each range {
        range.symbolStart != rangeIndex! * (completed.symbols -> len)
            or range.symbolCount != (completed.symbols -> len)
            or range.nameCount != (freshNames -> len) -> if { process.exit(11) }
        0 => j!
        j! < range.symbolCount -> while {
            completed.symbols[j!] => a
            legacy.symbols[range.symbolStart + j!] => b
            CHECK -> if { process.exit(12) }
            j! + 1 => j!
        }
        0 => j!
        j! < range.nameCount -> while {
            freshNames[j!] => a
            legacy.names[range.nameStart + j!] => b
            a.astNode != b.astNode or a.symbol != b.symbol or a.nameToken != b.nameToken
                -> if { process.exit(13) }
            j! + 1 => j!
        }
        rangeIndex! + 1 => rangeIndex!
    }
}

'''.replace('CHECK',' or '.join('a.'+f+' != b.'+f for f in fields))
p=(b/'fold17041-query8.slg').read_text();p=helper+p;p=p.replace('    [source,; ~] -> semanticContext.prepare','    source -> checkIdentity\n    [source,; ~] -> semanticContext.prepare',1);(b/'fold17043-query8.slg').write_text(p)
d=json.loads((b/'fold17041-query8.json').read_text());d['cases'][0]['source']=str(b/'fold17043-query8.slg').replace('\\','/');mapping={str(b/'fold17041-candidate'/x).replace('\\','/'):str(o/x).replace('\\','/') for x in ['symbols.slg','analysis.slg']};d['cases'][0]['additionalSources']=[mapping.get(p,p) for p in d['cases'][0]['additionalSources']];d['formatCheckSources']=[mapping.get(p,p) for p in d['formatCheckSources']];d['formatCheckSources']=[d['cases'][0]['source'] if p.endswith('fold17041-query8.slg') else p for p in d['formatCheckSources']];d['scope']='Original8 result query, all binary operands, all symbol prefix fields, and fresh versus legacy two-source symbol/name identity; focused query only.';(b/'fold17043-query8.json').write_text(json.dumps(d,indent=2)+'\n')
