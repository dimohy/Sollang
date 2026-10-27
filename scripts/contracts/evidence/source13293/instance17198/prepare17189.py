from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');ref=json.loads((b/'instance17188-reference-view/source-frame-result.json').read_text());s='''import sollang.compiler.semantic.context as semanticContext
import sollang.compiler.semantic.expression_type_ids as expressionTypes
import sollang.compiler.semantic.storage_placement_source_index as sourceIndex
import sollang.compiler.semantic.storage_placement_units as sourceUnits
import sollang.compiler.semantic.storage_placement_frames as frames
import sollang.compiler.semantic.type_ids as typeIds
import sollang.compiler.diagnostics as diagnostics
import sys.process as process

struct Query { label: Text, name: Text, line: Int }

location nodeIndex: Int, source: Text, prepared: ref semanticContext.SemanticSnapshot, indexed: ref sourceIndex.SourceIndex, units: ref sourceUnits.UnitPlan -> diagnostics.SourceLocation {
    prepared.package.ranges[0] => range
    prepared.package.nodes[range.astStart + nodeIndex] => node
    node.start => offset!
    node.kind == 9 -> if {
        prepared.package.tokens[range.tokenStart + node.payloadToken].span.start => offset!
    }
    units.units -> each unit { unit.astNode == nodeIndex -> if {
            prepared.package.tokens[range.tokenStart + unit.locationToken].span.start => offset!
    } }
    source -> diagnostics.sourceLocation(offset!)
}

kindCode nodeIndex: Int, prepared: ref semanticContext.SemanticSnapshot -> Int {
    prepared.package.ranges[0] => range
    prepared.package.nodes[range.astStart + nodeIndex] => node
    node.kind == 9 -> if { 2 -> return }
    node.kind == 38 -> if { 3 -> return }
    prepared.package -> typeIds.arrayStorageSyntax(0, nodeIndex) => storage
    storage.isRepeat -> if { 1 } else { 0 }
}

inspect label: Text, source: Text, queries: [Query] -> Unit uses Console, Process {
    [source,; ~] -> semanticContext.prepare => prepared
    prepared -> expressionTypes.resolveContext => facts
    prepared.package.ranges[0] => range
    range.astStart -> sourceIndex.build(range.astCount, prepared.package.nodes) -> when {
        Err(_) { process.exit(1) }
        Ok(indexed) { prepared.package -> sourceUnits.build(0, indexed) -> when {
                Err(_) { process.exit(2) }
                Ok(units) {
                    "case:$label" -> println
                    queries -> each query {
                        -1 => frame!
                        0 => i!
                        i! < range.astCount -> while {
                            prepared.package.nodes[range.astStart + i!] => node
                            query.line == 0 and node.kind == 8 -> if { i! => frame! }
                            query.line > 0 and (node.kind == 7 or node.kind == 31) -> if {
                                source -> diagnostics.sourceLocation(node.start) => location
                                prepared.package.tokens[range.tokenStart + node.payloadToken] => name
                                location.line == query.line and (source -> slice(name.span.start, name.span.length)) == query.name -> if { i! => frame! }
                            }
                            i! + 1 => i!
                        }
                        frame! < 0 -> if { process.exit(3) }
                        frame! -> frames.build(source, prepared, facts, 0, indexed, units) -> when {
                            Err(_) { process.exit(4) }
                            Ok(plan) {
                                "$(query.label)|slots:$(plan.slots -> len)" -> println
                                0 => slot!
                                plan.slots -> each item {
                                    "s|$(slot!):$(item.size):$(item.align)" -> println
                                    slot! + 1 => slot!
                                }
                                0 => ordinal!
                                plan.candidates -> each candidate {
                                    candidate.source -> kindCode(prepared) => kind
                                    candidate.source -> location(source, prepared, indexed, units) => start
                                    candidate.endUnit -> location(source, prepared, indexed, units) => end
                                    "c|$(ordinal!):$kind:$(start.line):$(start.column):$(candidate.size):$(candidate.start):$(candidate.end):$(end.line):$(end.column):$(candidate.automaticEnd):$(plan.slotsByCandidate[ordinal!])" -> println
                                    ordinal! + 1 => ordinal!
                                }
                                plan.ends -> each ending {
                                    ending.unit -> location(source, prepared, indexed, units) => end
                                    units.isResultByAst[ending.unit] -> if { "V" } else { "S" } => kind
                                    "e|$(ending.position):$(end.line):$(end.column):$kind:$(ending.slot):$(ending.size)" -> println
                                }
                            }
                        }
                    }
                }
        } }
    }
}

main {
''';expected=[]
kind={'ArrayLiteralExpression':0,'ArrayRepeatExpression':1,'BindingStatement':2,'DictionaryLiteralExpression':3}
for i,case in enumerate(ref['cases']):
 expected.append('case:'+case['id']);queries=[];prefixes=[x.split('|slots:')[0] for x in case['actual'] if '|slots:' in x]
 for prefix in prefixes:
  if prefix=='main':queries.append('Query { label: "main", name: "", line: 0 }')
  else:
   name,line=prefix[len('function:'):].rsplit('@',1);queries.append('Query { label: '+json.dumps(prefix)+', name: '+json.dumps(name)+', line: '+line+' }')
  entries=[x for x in case['actual'] if x.startswith(prefix+'|')];slots=entries[0].split('|slots:')[1].split(',') if entries[0].split('|slots:')[1] else [];expected.append(prefix+'|slots:'+str(len(slots)))
  for n,item in enumerate(slots):size,align=item.split('/');expected.append(f's|{n}:{size}:{align}')
  allocated={}
  for entry in entries:
   if '|alloc:' in entry:
    id,slot,size=entry.split('|alloc:')[1].split(',');allocated[id]=int(slot)
  candidates=sorted([c for c in case['candidateReferences'] if c['Frame']==prefix],key=lambda c:c['StartPosition']);ends=[]
  for n,c in enumerate(candidates):
   slot=allocated.get(c['Kind']+'@'+str(c['Line']),-1);auto=str(c['EmitAutomaticEnd']).lower();expected.append(f"c|{n}:{kind[c['Kind']]}:{c['Line']}:{c['Column']}:{c['Size']}:{c['StartPosition']}:{c['EndPosition']}:{c['EndLine']}:{c['EndColumn']}:{auto}:{slot}")
   if slot>=0 and c['EmitAutomaticEnd']:ends.append((c['EndPosition'],n,f"e|{c['EndPosition']}:{c['EndLine']}:{c['EndColumn']}:{'S' if c['EndKind'].endswith('Statement') else 'V'}:{slot}:{c['Size']}"))
  expected += [x[2] for x in sorted(ends)]
 s+='    """\n'+''.join('    '+x+'\n' for x in case['source'].splitlines())+f'    """ => source{i}\n    '+json.dumps(case['id'])+f' -> inspect(source{i}, ['+', '.join(queries)+'])\n'
s+='}\n';(b/'instance17189-probe4.slg').write_text(s,encoding='utf-8');d=json.loads((b/'fold17043-query8.json').read_text());c=d['cases'][0];c.update(id='source-frame-instances4',source=(b/'instance17189-probe4.slg').as_posix(),stdout='\n'.join(expected));c['additionalSources'] += [(b/'frames17107-candidate/storage_placement_frames.slg').as_posix(),(b/'placement16881-candidate/storage_placement.slg').as_posix(),(b/'placement16881-candidate/storage_placement_literals.slg').as_posix(),(b/'placement16881-candidate/storage_placement_source_index.slg').as_posix(),(b/'placement16881-candidate/storage_placement_units.slg').as_posix(),(b/'placement16881-candidate/storage_placement_uses.slg').as_posix(),(b/'placement17097-candidate/storage_placement_readonly.slg').as_posix()];c['additionalSources']=list(dict.fromkeys(c['additionalSources']));d['formatCheckSources']=[c['source'],(b/'frames17107-candidate/storage_placement_frames.slg').as_posix()];d['runtimeInputFiles']=[(b/'instance17188-reference-view/source-frame-result.json').as_posix(),(b/'frames17107-source-comparison.json').as_posix()];d['expectedManagedDllSha256']='672CD039C491A57E7C26472FEEFB886552DF2A6560DCDC0673467DA7B7B82B98';d['scope']='C742 whole per-source frame plans for four unchanged instance sources, raw main/template plans only; specialization identity mapping is separate. Compare all candidates, exact geometry/intervals/header automatic-end, accepted/rejected slots, slot size/alignment and lifetime ends against current CSharp production reference. Inline merge and LLVM consumers remain separate.';(b/'instance17189-contract4.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
