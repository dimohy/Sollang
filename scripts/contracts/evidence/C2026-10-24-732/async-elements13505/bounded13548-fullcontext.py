from pathlib import Path
import json,subprocess,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
c=json.loads((b/'bounded13538-contract.json').read_text(encoding='utf-8'))
paths=c['reusableCheckedProducer']['stdlibSourceOrder']+['scripts/probes/declared-value-layout/bounded-index-copy-isolation.slg']
assert len(paths)==145
template=b/'bounded13548-template.slg'
text='''import sollang.compiler.semantic.context as semanticContext
import sollang.compiler.semantic.expression_type_ids as expressionTypes
import sollang.compiler.semantic.library_imports as libraryImports
import sollang.compiler.syntax.source_decoding as sourceDecoding
import sys.file as file
import sys.path as path

main {
    ['''+',\n'.join(json.dumps(p) for p in paths)+''',; ~] => paths
    [file.SourceText; ~] => owners!
    paths -> each sourcePath {
        sourcePath -> file.mapText => owner
        owners! -> push(owner)
    }
    [Text; ~] => sources!
    0 => sourceIndex!
    sourceIndex! < (owners! -> len) -> while {
        owners![sourceIndex!] -> sourceDecoding.utf8Text => source
        sources! -> push(source)
        sourceIndex! + 1 => sourceIndex!
    }
    sources! -> semanticContext.prepareParallelWithStandardLibrarySources(144) => basePrepared
    basePrepared.package -> libraryImports.load(paths, "windows-x64", path.nativeStyle()) => libraries
    basePrepared.package -> libraryImports.resolveQualified(libraries) => libraryCalls
    basePrepared.package -> libraryImports.callResultTypes(basePrepared.semantic.types, libraries, libraryCalls) => externalResults
    basePrepared -> expressionTypes.resolveCallContextWithExternalResults(externalResults) => callContext
    callContext.prepared => prepared
    callContext.types => resolved
    "sourceCount=$(prepared.package.sources -> len)" -> println
    prepared.package.ranges[144] => range
    resolved.fields -> each field {
        field.sourceModule == 144 -> if {
            "field owner=$(field.ownerType) ordinal=$(field.ordinal) type=$(field.fieldType)" -> println
        }
    }
    resolved.expressions -> each expression {
        expression.sourceModule == 144 -> if {
            prepared.package.nodes[range.astStart + expression.astNode] => node
            node.kind == 37 or node.kind == 39 -> if {
                "expression ast=$(expression.astNode) kind=$(node.kind) type=$(expression.typeId) status=$(expression.status)" -> println
                expression.typeId >= 0 -> if {
                    resolved.types[expression.typeId] => type
                    "type=$(expression.typeId) kind=$(type.kind) first=$(type.first) length=$(type.length) origin=$(type.origin) module=$(type.module) symbol=$(type.symbol)" -> println
                }
            }
        }
    }
    externalResults -> each result {
        result.sourceModule == 144 -> if {
            "external ast=$(result.astNode) type=$(result.typeId)" -> println
        }
    }
}
'''
template.write_text(text,encoding='utf-8')
s=(b/'bounded13544-run.py').read_text(encoding='utf-8').replace('bounded13544','bounded13548')
needle="contract=json.loads((b/'bounded13527-contract.json').read_text(encoding='utf-8'));sources=";assert s.count(needle)==1
s=s.replace(needle,"program.write_text((b/'bounded13548-template.slg').read_text(encoding='utf-8'),encoding='utf-8')\n"+needle)
needle="pins={str(p):sha(p) for p in inputs};";assert s.count(needle)==1
s=s.replace(needle,"inputs += [b/'bounded13548-template.slg',*[r/name for name in contract['reusableCheckedProducer']['stdlibSourceOrder']]]\n"+needle)
s=s.replace("out/'run',timeout=30","out/'run',timeout=180").replace("'sourceCount=1' in p.stdout","'sourceCount=145' in p.stdout")
s=s.replace('Actual SLG one-source AST/type observation only; no stdlib144/package equivalence or runtime acceptance.','Actual production parallel stdlib144+main1 and native library external-result preparation; final main literal types only, no LLVM/runtime acceptance.')
p=b/'bounded13548-run.py';p.write_text(s,encoding='utf-8')
sys.exit(subprocess.run([sys.executable,str(p)],cwd=r).returncode)
