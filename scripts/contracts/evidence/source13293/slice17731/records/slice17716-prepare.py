import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone

root = Path.cwd()
base = Path('artifacts/scratch/resume-20261006-owner-continuation22')
sources = []
for path in Path('selfhost/llvm/text').glob('*.slg'):
    if '{ ptr, i64 }' in path.read_text(encoding='utf-8'):
        sources.append(path)
sources.append(Path('selfhost/llvm/text/storage_frames.slg'))
comparison = {
    'schemaVersion': 1, 'status': 'compared-before-slg-edit',
    'observedAtUtc': datetime.now(timezone.utc).isoformat(),
    'managedFirstOriginal': str(base / 'common17703-csharp38.json'),
    'structure': 'CSharp RuntimeIntSlice/RuntimeInlineSlice and static array value carriers share sollang.int_slice (ptr,i64). SLG semantic kind2 and fixed array value carriers use anonymous (ptr,i64). Preserve inline backing arrays, text and native socket structures.',
    'branches': 'CSharp TryGetRuntimeArrayView reuses the owner pointer and length. SLG direct and while call projection first extracts the same owner members but loses the physical planned slot in its pointer spelling. Use the existing checked placement lookup for a planned literal owner; otherwise retain the extracted pointer. Interpolation projections use source AST indexes, not IR indexes, and must retain their existing extracted pointer.',
    'logic': 'Align the named slice carrier across every text-emitter producer and consumer. Do not alter element types, storage placement, ownership, lifetimes, source fixtures or expected output. Keep native socket anonymous ABI and named text declarations untouched.',
    'diagnostics': 'Preserve checked placement S052 rejection for invalid/missing allocation. No fixture names, thresholds or alternate oracle branches. Private candidate requires semantic preflight before runtime checks.',
    'canonicalSourceHashes': {str(p).replace('\\','/'): hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in sources},
    'csharpSources': {str(p): hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in map(Path, ['src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs'])},
    'claimsGoalComplete': False
}
(base / 'slice17716-comparison.json').write_text(json.dumps(comparison, indent=2)+'\n', encoding='utf-8')
providers = {}
for source in sources:
    target = base / 'slice17716-candidate' / source.relative_to('selfhost/llvm')
    text = source.read_text(encoding='utf-8')
    lines = text.splitlines(keepends=True)
    for n, line in enumerate(lines):
        if line.lstrip().startswith('#') or '%sollang.text = type' in line:
            continue
        lines[n] = line.replace('{ ptr, i64 }', '%sollang.int_slice')
    text = ''.join(lines)
    if source.name == 'runtime_preamble.slg':
        anchor = '    usesDynamicArray! -> if { "%sollang.array.i32 = type { ptr, i64, i64 }" -> println }'
        assert text.count(anchor) == 1
        text = text.replace(anchor, '    "%sollang.int_slice = type { ptr, i64 }" -> println\n'+anchor)
    if source.name == 'storage_frames.slg':
        text += '''
# A readonly call view reuses the selected owner's physical storage. Only an
# admitted literal has a placement slot; every other owner keeps its actual
# extracted pointer, including heap-backed and mutable values.
writeCallSliceDataPointer valueIndex: Int, extractedPointer: Text, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console, Process {
    valueIndex -> isPlannedDynamicIntPayload(context, state) -> if {
        valueIndex -> ownedValueSourceIndex(context, state) => sourceIndex
        sourceIndex -> checkedStorageAllocation(context) -> when {
            None {
                "; sollang compiler error S052: PLACEMENT_MISSING_ALLOCATION $sourceIndex" -> println
                process.exit(1)
                return
            }
            Some(allocation) { "%stack_slot$(allocation.slot)" -> print }
        }
    } else { extractedPointer -> print }
}
'''
    if source.name == 'call_arguments.slg':
        old = '"  %call$(callIndex)_arg$(ordinal)_slice0 = insertvalue %sollang.int_slice poison, ptr %call$(callIndex)_arg$(ordinal)_slice_data, 0" -> println'
        new = '''"  %call$(callIndex)_arg$(ordinal)_slice0 = insertvalue %sollang.int_slice poison, ptr " -> print
                        sliceValueIndex -> writeCallSliceDataPointer("%call$(callIndex)_arg$(ordinal)_slice_data", context, state)
                        ", 0" -> println'''
        assert text.count(old) == 1
        text = text.replace(old, new)
    if source.name == 'container_control.slg':
        old = '"  %while$(whileIndex)_call$(callIndex)_arg$(ordinal)_slice0 = insertvalue %sollang.int_slice poison, ptr %while$(whileIndex)_call$(callIndex)_arg$(ordinal)_slice_data, 0" -> println'
        new = '''"  %while$(whileIndex)_call$(callIndex)_arg$(ordinal)_slice0 = insertvalue %sollang.int_slice poison, ptr " -> print
                        whileSliceValueIndex -> writeCallSliceDataPointer("%while$(whileIndex)_call$(callIndex)_arg$(ordinal)_slice_data", context, state)
                        ", 0" -> println'''
        assert text.count(old) == 1
        text = text.replace(old, new)
    if text == source.read_text(encoding='utf-8'):
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8', newline='\n')
    providers[str(source).replace('\\','/')] = str(target).replace('\\','/')
(base / 'slice17716-provider-map.json').write_text(json.dumps(providers, indent=2)+'\n',encoding='utf-8')
manifest = base / 'dictionary17700-sources.txt'
previous = json.loads((base/'dictionary17700-provider-map.json').read_text(encoding='utf-8'))
reverse = {v:k for k,v in previous.items()}
paths = [reverse.get(line.replace('\\','/'),line.replace('\\','/')) for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
(base/'slice17716-sources.txt').write_text('\n'.join(providers.get(p,p) for p in paths)+'\n',encoding='utf-8')
print(json.dumps({'privateCandidateFiles':len(providers),'sourceCount':len(paths)}))
