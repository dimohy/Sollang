from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');o=b/'fold17041-candidate';o.mkdir(exist_ok=False)
c=dict(status='compared-before-slg-edit',csharpReference=str(b/'interp16996-managed8/result.json'),csharpDecision='SemanticCompiler.InferFoldExpression creates accumulator/item Int bodyBindings before InferBlockBody. Original fold oracle remains value=6.',slgObserved='analysis completes interpolation AST but resolves it with pre-completion symbols. symbols.collectPrepared already owns role generation; retained fold body has no accumulator/item symbols, so binary IR operands are -1.',decision='Reuse the canonical collector with an existing symbol prefix and an appended AST suffix. Preserve all original symbol indices and append only new declarations/roles. Fresh and legacy prepared package paths both consume completed symbols.',claimsGoalComplete=False)
(b/'fold17041-source-comparison.json').write_text(json.dumps(c,indent=2)+'\n')
s=Path('selfhost/semantic/symbols.slg').read_text()
start=s.index('public collectPrepared nodes:');body=s.index('    [Symbol; ~] => symbols!',start)
s=s[:start]+'''public collectPrepared nodes: [ast.AstNode; ~] -> [Symbol; ~] {
    nodes -> extendPrepared(0, [Symbol; ~])
}

# Existing source-local symbol identities remain a stable prefix. Only appended
# AST nodes contribute declarations and synthetic lexical roles.
public extendPrepared nodes: ref [ast.AstNode; ~], firstAst: Int, existing: move [Symbol; ~] -> [Symbol; ~] {
'''+s[body:]
s=s.replace('    [Symbol; ~] => symbols!','    existing => symbols!\n    symbols! -> len => firstSymbol',1)
s=s.replace('    0 => astIndex!','''    0 => prefixIndex!
    prefixIndex! < firstSymbol -> while {
        symbols![prefixIndex!] => prefix
        prefix.kind != 35 and prefix.kind != 36 and prefix.astNode >= 0 and prefix.astNode < firstAst
            -> if {
                astToSymbol![prefix.astNode] < 0 -> if { prefixIndex! => astToSymbol![prefix.astNode] }
            }
        prefixIndex! + 1 => prefixIndex!
    }
    firstAst => astIndex!''',1)
for var in ['reparentSymbolIndex','genericSymbolIndex','comInterfaceSymbolIndex','declarationSymbolIndex','comParameterFunctionIndex','comReceiverFunctionIndex','enumArmScopeIndex','roleScopeIndex','foldScopeIndex']:
 old='    0 => '+var+'!';assert s.count(old)==1,var;s=s.replace(old,'    firstSymbol => '+var+'!')
s=s.replace('    0 => typeAstIndex!','    firstAst => typeAstIndex!',1)
(o/'symbols.slg').write_text(s,encoding='utf-8')
s=Path('selfhost/semantic/analysis.slg').read_text();anchor='public struct CompletedSourceInterpolations {';pos=s.index(anchor);s=s[:pos]+s[pos:].replace('    public nodes:','    public symbols: [symbols.Symbol; ~]\n    public nodes:',1)
s=s.replace('CompletedSourceInterpolations { nodes: sourceNodes!, tokens: sourceTokens!, interpolations: sourceInterpolations! }','''sourceNodes! -> symbols.extendPrepared(typeNodeStart, sourceSymbols -> copy) => completedSymbols
    CompletedSourceInterpolations { symbols: completedSymbols, nodes: sourceNodes!, tokens: sourceTokens!, interpolations: sourceInterpolations! }''')
# Copy borrowed prefix explicitly; arrays do not expose a generic copy intrinsic.
s=s.replace('sourceNodes! -> symbols.extendPrepared(typeNodeStart, sourceSymbols -> copy)', '''[symbols.Symbol; ~] => completedPrefix!
    sourceSymbols -> each symbol { completedPrefix! -> push(symbol) }
    sourceNodes! -> symbols.extendPrepared(typeNodeStart, completedPrefix!)''')
s=s.replace('    [resolution.ResolvedName; ~] => names!\n    [interpolation.InterpolationSourceRange;', '    [resolution.ResolvedName; ~] => names!\n    [symbols.Symbol; ~] => completedSymbolTable!\n    [interpolation.InterpolationSourceRange;',1)
s=s.replace('resolution.resolvePrepared(completed.nodes, sourceSymbols!, completed.tokens)','resolution.resolvePrepared(completed.nodes, completed.symbols, completed.tokens)')
s=s.replace('        originalRange => range!','''        originalRange => range!
        completedSymbolTable! -> len => range!.symbolStart
        completed.symbols -> len => range!.symbolCount
        completed.symbols -> each symbol { completedSymbolTable! -> push(symbol) }''',1)
s=s.replace('symbols: package.symbols, names: names!','symbols: completedSymbolTable!, names: names!',1)
s=s.replace('lowered.nodes -> symbols.collectPrepared => sourceSymbols','lowered.nodes -> symbols.collectPrepared => originalSymbols',1).replace('completeSourceInterpolations(lowered.nodes, originalTokens, sourceSymbols)','completeSourceInterpolations(lowered.nodes, originalTokens, originalSymbols)',1)
s=s.replace('    completed.nodes => sourceNodes','    completed.symbols => sourceSymbols\n    completed.nodes => sourceNodes',1)
(o/'analysis.slg').write_text(s,encoding='utf-8')
d=json.loads((b/'fold17029-query8.json').read_text());mapping={'selfhost/semantic/analysis.slg':str(o/'analysis.slg').replace('\\','/'),'selfhost/semantic/symbols.slg':str(o/'symbols.slg').replace('\\','/')}
d['cases'][0]['additionalSources']=[mapping.get(p,p) for p in d['cases'][0]['additionalSources']];d['formatCheckSources']+=list(mapping.values());d['runtimeInputFiles']+=[str(b/'fold17041-source-comparison.json').replace('\\','/')]
p=(b/'fold17029-query8.slg').read_text();p=p.replace('    false => found!', '''    ir -> each value {
        value.kind == 8 and (value.operand0 < 0 or value.operand1 < 0) -> if { process.exit(3) }
    }
    false => found!''',1);(b/'fold17041-query8.slg').write_text(p,encoding='utf-8');d['cases'][0]['source']=str(b/'fold17041-query8.slg').replace('\\','/');d['formatCheckSources'][0]=d['cases'][0]['source'];d['scope']='Fixed original8 source result selection plus every binary operand resolved after canonical appended-symbol collection; no LLVM runtime acceptance.'
(b/'fold17041-query8.json').write_text(json.dumps(d,indent=2)+'\n')
