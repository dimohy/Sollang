import json,hashlib
from pathlib import Path
root=Path.cwd();out=Path(__file__).resolve().parent;meta=json.loads((out/'schema.json').read_text());p=root/'scripts/probes/call-context-stability-facts.slg';original=p.read_text();tail=original[original.index('public checkStable '):].replace('public checkStable sources: [Text; ~], label: Text -> Unit uses Console {','public checkStable sources: [Text; ~], label: Text -> [UInt64; ~] uses Console {').replace('    before -> digest => hash\n    hash -> each byte { byte -> println }','    before').replace('    before -> generations.checksum(before -> len) => hash\n    hash -> each byte { byte -> println }','    before')
lines=['namespace sollang.compiler.semantic.expression_type_ids','','import sollang.compiler.semantic.context as semanticContext','import sollang.compiler.semantic.calls as calls','','signedProbeWord value: Int -> UInt64 {','    value >= 0 -> if {','        UInt64(value) * 2','    } else {','        UInt64(-(value + 1)) * 2 + 1','    }','}','','boolProbeWord value: Bool -> UInt64 {','    value -> if { 1 } else { 0 }','}','','fingerprint context: ref ResolvedCallContext -> [UInt64; ~] {','    [UInt64; ~] => values!']
for ordinal,row in enumerate(meta['coverage'],1):
 source='context.'+row['owner']+'.'+row['field'];lines+=['    values! -> push('+str(ordinal)+')','    values! -> push(UInt64('+source+' -> len))','    '+source+' -> each entry {']
 for name,kind in row['leaves']:
  value='entry'+('.'+name if name else '')
  encoded=value+' -> signedProbeWord' if kind=='Int' else value+' -> boolProbeWord' if kind=='Bool' else value
  assert kind in ['Int','Bool','UInt64'],kind
  lines.append('        values! -> push('+encoded+')')
 lines.append('    }')
lines+=['    values!','}','',''];p.write_text('\n'.join(lines)+tail,encoding='utf-8',newline='\n');meta.update(representation='UInt64 words: signed zigzag, bool0/1, UInt64 identity; ordinal and count prefixes per table.',checksumAuthority='selfhost/semantic/semantic_generations.slg:85',signedEncodingAuthority='selfhost/ir/module_artifacts.slg:217',deferredTextStorage=False);(out/'schema.json').write_text(json.dumps(meta,indent=2)+'\n');print('NUMERIC_FACT_SERIALIZATION_GENERATED',len(meta['coverage']))

mainpath=root/'scripts/probes/call-context-stability.slg';main=mainpath.read_text();main=main.replace('    ] -> facts.checkStable(', '    ] -> report(')
if 'as generations' not in main:main=main.replace('as facts\n','as facts\nimport sollang.compiler.semantic.semantic_generations as generations\n',1)
if 'report sources:' not in main:main=main.replace('main {','report sources: [Text; ~], label: Text -> Unit uses Console {\n    sources -> facts.checkStable(label) => words\n    words -> generations.checksum(words -> len) => hash\n    hash -> each byte { byte -> println }\n}\n\n'+'main {',1)
mainpath.write_text(main,encoding='utf-8',newline='\n')

import re
probe=root/"scripts/probes/call-context-stability-facts.slg";code=probe.read_text();code=code.replace("    left! -> callContextDecisionsEqual([calls.ModuleCallResolution; ~])","    [calls.ModuleCallResolution; ~] => empty\n    left! -> callContextDecisionsEqual(empty)");code=re.sub('(?m)^    left! -> callContextDecisionsEqual\\(\\[(changed\\w+!); ~\\]\\)','    \\1 => right![0]\\n    left! -> callContextDecisionsEqual(right!)',code);probe.write_text(code,encoding="utf-8",newline="\n")

probe=root/"scripts/probes/call-context-stability-facts.slg";code=probe.read_text()
old='    completed.types.callArguments -> each argument { argument.genericParameterSymbol >= 0 -> if { genericArguments! + 1 => genericArguments! } }\n'
if old in code:
 code=code.replace(old,"").replace("    0 => genericArguments!\n","").replace("    0 => selectedCalls!\n","    0 => selectedCalls!\n    0 => genericCalls!\n").replace("            selectedCalls! + 1 => selectedCalls!\n","            selectedCalls! + 1 => selectedCalls!\n"+'            completed.prepared -> genericTarget(call) -> if { genericCalls! + 1 => genericCalls! }\n').replace("genericArguments!","genericCalls!")
if "genericTarget prepared:" not in code:code+='\n\ngenericTarget prepared: ref semanticContext.SemanticSnapshot, call: calls.ModuleCallResolution -> Bool {\n    call.targetSourceModule < 0 or call.targetSourceModule >= (prepared.package.ranges -> len) -> if { false -> return }\n    prepared.package.ranges[call.targetSourceModule] => range\n    call.functionSymbol < 0 or call.functionSymbol >= range.symbolCount -> if { false -> return }\n    0 => index!\n    index! < range.symbolCount -> while {\n        prepared.package.symbols[range.symbolStart + index!] => declaration\n        declaration.kind == 32 and declaration.parent == call.functionSymbol -> if { true -> return }\n        index! + 1 => index!\n    }\n    false\n}\n'
probe.write_text(code,encoding="utf-8",newline="\n")
