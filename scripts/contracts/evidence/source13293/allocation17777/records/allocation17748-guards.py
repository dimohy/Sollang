from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,re

b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
old=json.loads((b/'allocation17741-provider-map.json').read_text())
canonical='selfhost/llvm/emitter/diagnostics.slg';old[canonical]=canonical
comparison=dict(schemaVersion=1,status='compared-before-slg-edit',observedAtUtc=datetime.now(timezone.utc).isoformat(),managedFirstNormal=str(b/'placement17610-managed4/result.json'),managedFirstFailureObservation=str(b/'allocation17740-managed-failure/result.json'),structure='CSharp EmitHeapAllocate checks a nullable raw platform allocation before initializing the payload. Existing SLG text-slice trap emission already builds the same function-owned diagnostic and platform-specific fatal branch; share that implementation with array allocation.',branches='Zero-length backing remains null without an allocation. Positive allocation must branch on nonnull before any store. Apply the common guard to entry, ordinary function, control region, interpolation and while literals, plus symbolic fixed-array repeat. Windows writes a function-owned failure diagnostic; browser calls panic; Linux traps directly, matching the CSharp platform decision.',logic='Keep actual pointer names and owner representations while adding the missing failure decision. Original42 common cleanup-pointer assertion may still expose the remaining static-array representation difference; do not rename SSA or replace the oracle to conceal it.',diagnostics='CSharp fallback trap messages use compiler-generated block identities. The SLG branch identity remains its own emitted block; exact numeric block-name identity is not established. Do not claim complete diagnostic equality from a matching exit status alone.',canonicalSourceHashes={p:sha(p) for p in old},rawCandidateComparison=str(b/'allocation17741-comparison.json'),claimsGoalComplete=False)
(b/'allocation17748-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
new={}
for canonical,source in old.items():
    p=Path(canonical);text=Path(source).read_text(encoding='utf-8')
    if p.name in ('entry_expressions.slg','function_expressions.slg','control_region_expressions.slg','foundation.slg'):
        owner='functionIndex' if p.name in ('entry_expressions.slg','function_expressions.slg') else 'ownerIndex'
        text,count=re.subn(r'-> emitArrayHeapBacking\((\w+)\)',rf'-> emitArrayHeapBacking(\1, {owner}, context, state)',text)
        assert count>0,p
    if p.name=='platform_io.slg':
        oldhelper='''emitArrayHeapBacking identity: ArrayStorageIdentity, byteLength: Int -> Unit uses Console {
    "  " -> print
    identity -> writeArrayStorageIdentity("_data")
    byteLength == 0 -> if { " = inttoptr i64 0 to ptr" -> println } else {
        " = call ptr @sollang_alloc(i64 $byteLength)" -> println
    }
}'''
        newhelper='''emitArrayHeapBacking identity: ArrayStorageIdentity, byteLength: Int, ownerIndex: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {
    "  " -> print
    identity -> writeArrayStorageIdentity("_data")
    byteLength == 0 -> if { " = inttoptr i64 0 to ptr" -> println } else {
        " = call ptr @sollang_alloc(i64 $byteLength)" -> println
        identity -> emitArrayAllocationGuard(ownerIndex, context, state)
    }
}

# The raw primitive may return null. Expression allocation owns the fatal
# decision, before payload initialization or publication to a container.
emitArrayAllocationGuard identity: ArrayStorageIdentity, ownerIndex: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {
    Arena(0) => names!
    (identity.resultDomain == 1 -> if {
        "v$(identity.labelIndex)_expression$(identity.resultIndex)" -> materialize(names!)
    } else { identity.resultDomain == 2 -> if {
            "while$(identity.labelIndex)_v$(identity.resultIndex)" -> materialize(names!)
        } else { "v$(identity.resultIndex)" -> materialize(names!) } }) => prefix
    "$(prefix)_allocation_failed" -> materialize(names!) => failureIdentity
    "  %$(prefix)_allocated = icmp ne ptr %$(prefix)_data, null" -> println
    "  br i1 %$(prefix)_allocated, label %$(prefix)_allocation_ready, label %$(prefix)_allocation_failed" -> println
    "$(prefix)_allocation_failed:" -> println
    WhileValueRequest { whileIndex: -1, ownerIndex: ownerIndex, nodeIndex: identity.resultIndex }
        -> emitRuntimeTrap(prefix, "allocation", failureIdentity, context, state)
    "$(prefix)_allocation_ready:" -> println
}'''
        assert text.count(oldhelper)==1
        text=text.replace(oldhelper,newhelper)
    if p.name=='function_expressions.slg':
        text=text.replace('emitTextSliceTrap','emitRuntimeTrap')
        marker='emitRuntimeTrap request:';start=text.index(marker);end=text.index('\nemitTextSliceBoundary',start)
        helper=text[start:end]
        helper=helper.replace('context.expectedPathStyle == 1 -> if {','context.expectedPathStyle == 1 or context.pointerBitWidth == 32 -> if {',1)
        line='        "  call void @sollang_runtime_eprint(ptr %$(prefix)_$(suffix)_diagnostic, i64 $(diagnosticLength), i1 false)" -> println'
        assert helper.count(line)==1
        helper=helper.replace(line,'''        context.pointerBitWidth == 32 -> if {
            "  call void @sollang_browser_panic(ptr %$(prefix)_$(suffix)_diagnostic, i32 $(diagnosticLength))" -> println
        } else {
            "  call void @sollang_runtime_eprint(ptr %$(prefix)_$(suffix)_diagnostic, i64 $(diagnosticLength), i1 false)" -> println
        }''')
        text=text[:start]+helper+text[end:]
    if p.name=='foundation.slg':
        line='    "  %v$(nodeIndex)_data = call ptr @sollang_alloc(i64 %v$(nodeIndex)_repeat_bytes)" -> println'
        assert text.count(line)==1
        text=text.replace(line,line+'\n    ArrayStorageIdentity { resultDomain: 0, resultIndex: nodeIndex, labelIndex: -1 } -> emitArrayAllocationGuard(ownerIndex, context, state)')
    if p.name=='container_control.slg':
        for size in ('emptyWhileCallStorageBytes','whileArrayByteLength'):
            line=f'"  %while$(whileIndex)_v$(valueNodeIndex)_data = call ptr @sollang_alloc(i64 ${size})" -> println'
            assert text.count(line)==1
            text=text.replace(line,line+'\n                                                        ArrayStorageIdentity { resultDomain: 2, resultIndex: valueNodeIndex, labelIndex: whileIndex } -> emitArrayAllocationGuard(ownerIndex, context, state)')
    if p.name=='diagnostics.slg':
        start=text.index('public usesStandardError ');end=text.index('\npublic usesParallelRuntime',start)
        helper=text[start:end]
        line='        node.symbol == -116 or node.symbol == -117'
        assert helper.count(line)==1
        helper=helper.replace(line,line+'\n            or (context.expectedPathStyle == 1 and node.kind == 14)')
        text=text[:start]+helper+text[end:]
    if p.name=='runtime_preamble.slg':
        line='    usesCollectionCapacityTrap! or usesDictionary! or usesBoundedDictionary!'
        assert text.count(line)==1
        text=text.replace(line,'    usesArrayAllocation! or usesCollectionCapacityTrap! or usesDictionary! or usesBoundedDictionary!')
    if p.name=='text_output_runtime.slg':
        line='        declare i32 @sollang_browser_alloc(i64)'
        assert text.count(line)==1
        text=text.replace(line,line+'\n        declare void @sollang_browser_panic(ptr, i32)')
    target=b/'allocation17748-candidate'/p.relative_to('selfhost/llvm')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text,encoding='utf-8',newline='\n')
    new[canonical]=target.as_posix()
(b/'allocation17748-provider-map.json').write_text(json.dumps(new,indent=2)+'\n',encoding='utf-8')
paths=Path('tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt').read_text(encoding='utf-8-sig').splitlines()
paths=[p.strip().replace('\\','/') for p in paths if p.strip()]
(b/'allocation17748-sources.txt').write_text('\n'.join(new.get(p,p) for p in paths)+'\n',encoding='utf-8')
print(json.dumps(dict(privateCandidateFiles=len(new),sourceCount=len(paths))))
