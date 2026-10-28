from pathlib import Path
from datetime import datetime,timezone
import json,shutil,hashlib

b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
old=json.loads((b/'allocation17750-provider-map.json').read_text())
comparison=dict(schemaVersion=1,status='compared-before-slg-edit',observedAtUtc=datetime.now(timezone.utc).isoformat(),managedFirst=str(b/'placement17610-managed4/result.json'),rawCandidateRuntime=str(b/'allocation17756-source7/result.json'),commonOriginal42Failure=str(b/'common17757-candidate42.json'),structure='CSharp RuntimeStaticIntArray retains the actual allocation pointer and drops that pointer. SLG always re-extracts a literal pointer from an already-known descriptor. Give expression heap allocation one physical identity shared by its producer and literal cleanup. Keep descriptors for transport and opaque returned/copied values.',branches='Zero-byte dynamic backing remains null. Every positive literal allocation receives a physical heap identity; ordinary, region and while literals share their IR identity, while interpolation includes its AST emission owner. Literal cleanup uses this known pointer only when no backing copy owns the result. Other cleanup keeps descriptor extraction. No source/fixture-specific branch.',logic='This is pointer provenance, not an SSA-only rename: allocation and literal ownership release share the actual backing identity; opaque calls and independent copies retain their own backing. Check stack/heap boundaries, fixed return/transfer and generic controls without editing originals or expected output.',diagnostics='The prior strict injected-failure comparison still differs in compiler-generated block identity. Preserve that failure and do not call the whole original42 unit complete.',sourceHashes={p:sha(q) for p,q in old.items()},claimsGoalComplete=False)
(b/'allocation17761-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
target=b/'allocation17761-candidate';shutil.copytree(b/'allocation17750-candidate',target)
p=target/'text/platform_io.slg';text=p.read_text(encoding='utf-8')
anchor='emitArrayStackBacking identity:'
pos=text.index(anchor)
text=text[:pos]+'''# Physical heap identity survives descriptor publication. A while expression
# has the same IR allocation identity; interpolation has a separate AST domain.
writeArrayHeapIdentity identity: ArrayStorageIdentity -> Unit uses Console {
    identity.resultDomain == 1 -> if {
        "%heap_v$(identity.labelIndex)_expression$(identity.resultIndex)" -> print
    } else { "%heap_v$(identity.resultIndex)" -> print }
}

'''+text[pos:]
oldbody='''    "  " -> print
    identity -> writeArrayStorageIdentity("_data")
    byteLength == 0 -> if { " = inttoptr i64 0 to ptr" -> println } else {
        " = call ptr @sollang_alloc(i64 $byteLength)" -> println
        identity -> emitArrayAllocationGuard(ownerIndex, context, state)
    }'''
newbody='''    byteLength == 0 -> if {
        "  " -> print
        identity -> writeArrayStorageIdentity("_data")
        " = inttoptr i64 0 to ptr" -> println
    } else {
        "  " -> print
        identity -> writeArrayHeapIdentity
        " = call ptr @sollang_alloc(i64 $byteLength)" -> println
        "  " -> print
        identity -> writeArrayStorageIdentity("_data")
        " = getelementptr i8, ptr " -> print
        identity -> writeArrayHeapIdentity
        ", i64 0" -> println
        identity -> emitArrayAllocationGuard(ownerIndex, context, state)
    }'''
assert text.count(oldbody)==1;text=text.replace(oldbody,newbody)
oldwriter='''    identity.resultDomain == 1 -> if {
        "%v$(identity.labelIndex)_expression$(identity.resultIndex)$suffix" -> print
    } else { "%v$(identity.resultIndex)$suffix" -> print }'''
newwriter='''    identity.resultDomain == 1 -> if {
        "%v$(identity.labelIndex)_expression$(identity.resultIndex)$suffix" -> print
    } else { identity.resultDomain == 2 -> if {
            "%while$(identity.labelIndex)_v$(identity.resultIndex)$suffix" -> print
        } else { "%v$(identity.resultIndex)$suffix" -> print } }'''
assert text.count(oldwriter)==1;text=text.replace(oldwriter,newwriter);p.write_text(text,encoding='utf-8')
p=target/'text/container_control.slg';text=p.read_text(encoding='utf-8')
for size in ('emptyWhileCallStorageBytes','whileArrayByteLength'):
    oldcall=f'"  %while$(whileIndex)_v$(valueNodeIndex)_data = call ptr @sollang_alloc(i64 ${size})" -> println\n'
    start=text.index(oldcall);end=text.index('\n',text.index('-> emitArrayAllocationGuard(ownerIndex, context, state)',start))
    text=text[:start]+f'ArrayStorageIdentity {{ resultDomain: 2, resultIndex: valueNodeIndex, labelIndex: whileIndex }} -> emitArrayHeapBacking({size}, ownerIndex, context, state)'+text[end:]
p.write_text(text,encoding='utf-8')
p=target/'text/foundation.slg';text=p.read_text(encoding='utf-8')
oldcall='    "  %v$(nodeIndex)_data = call ptr @sollang_alloc(i64 %v$(nodeIndex)_repeat_bytes)" -> println'
newcall='''    "  %heap_v$(nodeIndex) = call ptr @sollang_alloc(i64 %v$(nodeIndex)_repeat_bytes)" -> println
    "  %v$(nodeIndex)_data = getelementptr i8, ptr %heap_v$(nodeIndex), i64 0" -> println'''
assert text.count(oldcall)==1;text=text.replace(oldcall,newcall);p.write_text(text,encoding='utf-8')
p=target/'text/ownership.slg';text=p.read_text(encoding='utf-8')
anchor='emitPromotedFixedBackingDrop callIndex: Int, edgeIndex: Int, context: ref emitterContext.EmitContext -> Unit uses Console {\n'
assert text.count(anchor)==1
text=text.replace(anchor,anchor+'''    # A direct literal owns its physical allocation; a copy or returned value
    # owns the backing carried by its descriptor instead.
    context.ir[callIndex].kind == 14 and (callIndex -> bindingFixedStorageCopyTypeId(context)) < 0
        -> if {
            "  call void @sollang_free(ptr " -> print
            ArrayStorageIdentity { resultDomain: 0, resultIndex: callIndex, labelIndex: -1 } -> writeArrayHeapIdentity
            ")" -> println
            return
        }
''')
p.write_text(text,encoding='utf-8')
new={k:v.replace('allocation17750-candidate','allocation17761-candidate') for k,v in old.items()}
(b/'allocation17761-provider-map.json').write_text(json.dumps(new,indent=2)+'\n',encoding='utf-8')
(b/'allocation17761-sources.txt').write_text((b/'allocation17750-sources.txt').read_text().replace('allocation17750-candidate','allocation17761-candidate'),encoding='utf-8')
print('prepared physical heap-pointer source candidate; prior failures preserved')
