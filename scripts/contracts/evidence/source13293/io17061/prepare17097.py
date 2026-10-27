from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');o=b/'placement17097-candidate';o.mkdir(exist_ok=False)
(b/'readonly17097-source-comparison.json').write_text(json.dumps(dict(status='compared-before-slg-edit',csharp=(b/'readonly17086-reference17/source-frame-result.json').as_posix(),graph=(b/'readonly17096-graph4.json').as_posix(),decision='CSharp recursively checks interpolation expressions. Canonical IR index7 and len intrinsic6 may borrow an owner; resolved source call8 follows its committed primary input type/ownership. Preserve direct versus flowed call arity and canonical17 AST ownership; no string search or callee-name fallback.',claimsGoalComplete=False),indent=2)+'\n',encoding='utf-8')
s=(b/'placement16881-candidate/storage_placement_readonly.slg').read_text();a=s.index('readonlyFunction callAst:');z=s.index('\n# Transparent grammar',a)
old=s[a:z];body=old[old.index('                prepared.package.ranges[call.targetSourceModule]'):old.index('                false -> return\n            }')];body=body.replace('call.targetSourceModule','targetSource').replace('call.functionSymbol','functionSymbol');body='\n'.join(line[12:] if line.startswith('            ') else line for line in body.splitlines())
symbol='''readonlySymbol functionSymbol: Int, targetSource: Int, owner: ReadonlyOwner, prepared: ref semanticContext.SemanticSnapshot -> Bool {
    targetSource < 0 or targetSource >= (prepared.package.ranges -> len) -> if { false -> return }
    functionSymbol < 0 or functionSymbol >= prepared.package.ranges[targetSource].symbolCount -> if { false -> return }
'''+body+'''\n    false
}

readonlyFunction callAst: Int, owner: ReadonlyOwner, prepared: ref semanticContext.SemanticSnapshot, sourceModule: Int -> Bool {
    prepared.calls -> each call {
        call.sourceModule == sourceModule and call.callAst == callAst and call.status == 0
            and call.targetSourceModule >= 0 and call.functionSymbol >= 0 -> if {
                call.functionSymbol -> readonlySymbol(call.targetSourceModule, owner, prepared) -> return
            }
    }
    false
}
'''
s=s[:a]+symbol+s[z:]
a=s.index('    node.kind == 13 -> if {');z=s.index('    # The remaining supported',a);s=s[:a]+'''    node.kind == 13 -> if {
        prepared.interpolationRanges -> each fragments {
            fragments.sourceModule == sourceModule -> if {
                fragments.nodeStart => fragmentIndex!
                fragmentIndex! < fragments.nodeStart + fragments.nodeCount -> while {
                    prepared.interpolations[fragmentIndex!] => fragment
                    fragment.sourceToken == node.payloadToken and fragment.parent < 0 -> if {
                        fragmentIndex! -> readonlyInterpolation(owner, source, prepared, sourceModule, indexed)
                            -> unless { false -> return }
                    }
                    fragmentIndex! + 1 => fragmentIndex!
                }
            }
        }
        true -> return
    }
'''+s[z:]
a=s.index('\npublic readonlyPayload');extra='''
interpolationOwner index: Int, owner: ReadonlyOwner, source: Text, prepared: ref semanticContext.SemanticSnapshot -> Bool {
    index < 0 or index >= (prepared.interpolations -> len) -> if { false -> return }
    prepared.interpolations[index] => node
    node.kind == 1 and (source -> slice(node.payloadStart, node.payloadLength)) == owner.name
}

readonlyInterpolationFunction index: Int, owner: ReadonlyOwner, prepared: ref semanticContext.SemanticSnapshot, sourceModule: Int -> Bool {
    prepared.interpolations[index] => node
    prepared.qualified -> each target {
        target.sourceModule == sourceModule and target.pathAst == node.targetAst -> if {
            target.status != 0 or target.targetModule < 0 or target.targetModule >= (prepared.modules -> len)
                -> if { false -> return }
            target.targetSymbol -> readonlySymbol(prepared.modules[target.targetModule].sourceIndex, owner, prepared) -> return
        }
    }
    node.prefixSymbol >= 0 -> if { false -> return }
    node.symbol -> readonlySymbol(sourceModule, owner, prepared)
}

readonlyInterpolation index: Int, owner: ReadonlyOwner, source: Text, prepared: ref semanticContext.SemanticSnapshot, sourceModule: Int, indexed: ref sourceIndex.SourceIndex -> Bool {
    prepared.interpolations[index] => node
    node.kind == 0 or node.kind == 4 -> if { true -> return }
    node.kind == 1 -> if { not (index -> interpolationOwner(owner, source, prepared)) -> return }
    node.kind == 16 or node.kind == 17 -> if {
        node.valueAst >= 0 and node.valueAst < indexed.astCount -> unless { false -> return }
        node.valueAst -> readOnly(owner, source, prepared, sourceModule, indexed) -> return
    }
    -1 => skipped!
    node.operand0 -> interpolationOwner(owner, source, prepared) -> if {
        node.kind == 7 -> if { node.operand0 => skipped! }
        node.kind == 6 -> if {
            source -> slice(node.callNameStart, node.callNameLength) => target
            target == "len" or target == "capacity" -> unless { false -> return }
            node.operand0 => skipped!
        }
        node.kind == 8 -> if {
            # Both spans belong to this canonical fragment. A flowed primary
            # precedes its target; an explicit prefix argument follows it.
            prepared.interpolations[node.operand0].payloadStart < node.callNameStart => flowed
            not flowed and node.argumentCount != 1 -> if { false -> return }
            index -> readonlyInterpolationFunction(owner, prepared, sourceModule) -> unless { false -> return }
            node.operand0 => skipped!
        }
    }
    node.kind == 2 or node.kind == 3 or (node.kind >= 5 and node.kind <= 15) -> unless { false -> return }
    0 => child!
    child! < (prepared.interpolations -> len) -> while {
        child! != skipped! and prepared.interpolations[child!].parent == index -> if {
            child! -> readonlyInterpolation(owner, source, prepared, sourceModule, indexed) -> unless { false -> return }
        }
        child! + 1 => child!
    }
    true
}
''';s=s[:a]+extra+s[a:];(o/'storage_placement_readonly.slg').write_text(s,encoding='utf-8')
# Reuse the existing probe behavior; only case data and the readonly provider vary.
s=(b/'readonly17082-probe13.slg').read_text().split('\nmain {')[0]+'\n\nmain {\n';cases=json.loads((b/'readonly17086-reference17.json').read_text())['cases'];expected=[]
for i,c in enumerate(cases):
 s+='    """\n'+''.join('    '+x+'\n' for x in c['source'].splitlines())+f'    """ => source{i}\n    '+json.dumps(c['id'])+f' -> inspect(source{i})\n';expected.append(c['id']+'|'+str(any('|alloc:ArrayLiteralExpression' in x or '|alloc:DictionaryLiteralExpression' in x for x in c['expected'])).lower())
s+='}\n';(b/'readonly17097-probe17.slg').write_text(s,encoding='utf-8');d=json.loads((b/'readonly17082-contract13.json').read_text());c=d['cases'][0];old=(b/'placement16881-candidate/storage_placement_readonly.slg').as_posix();new=(o/'storage_placement_readonly.slg').as_posix();c.update(id='readonly-admission17',source=(b/'readonly17097-probe17.slg').as_posix(),stdout='\n'.join(expected));c['additionalSources']=[new if p==old else p for p in c['additionalSources']];d['formatCheckSources']=[c['source'],new];d['runtimeInputFiles']=[(b/'readonly17086-reference17.json').as_posix(),(b/'readonly17086-reference17/source-frame-result.json').as_posix(),(b/'readonly17097-source-comparison.json').as_posix()];d['scope']='C742 readonly admission17, including canonical interpolation index/len/local readonly source call and owning source call rejection. Wider source families/headers/consumers remain pending.';(b/'readonly17097-contract17.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
