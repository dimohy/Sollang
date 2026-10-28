from pathlib import Path
from datetime import datetime,timezone
import json,hashlib

b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
files=['selfhost/llvm/text/platform_io.slg','selfhost/llvm/text/containers.slg']
comparison=dict(schemaVersion=1,status='compared-before-slg-edit',observedAtUtc=datetime.now(timezone.utc).isoformat(),managedFirst=[(b/'resize17780-managed1/result.json').as_posix(),(b/'allocation17755-managed4/result.json').as_posix()],structure='CSharp reserve and Arena growth both use EmitHeapAllocate, which checks nonnull before copying/freeing the old allocation. The nullable SLG resize helper already preserves the old allocation on failure, but callers publish its null return without a fatal guard.',branches='Share the existing literal allocation failure emitter with reserve and materialize. Grow paths guard before publication; keep paths do not allocate or trap. CSharp phi inputs use the actual block after EmitHeapAllocate; update both SLG pointer/capacity phi predecessors to the new successful guard block.',logic='Reuse the CSharp platform failure decision through the existing runtime trap helper. Refactor the guard only; preserve zero-length literal behavior, live-byte copy counts, old allocation ownership on failure, and all original inputs/answers.',diagnostics='Generated block identity differences stay visible and are not exact-byte parity evidence. Both emitters must keep the diagnostic attached to the actual failure block.',canonicalSourceHashes={p:sha(p) for p in files},csharpSources={p:sha(p) for p in ['src/Sollang.Compiler/CodeGen/LlvmEmitter.Containers.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Arena.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Containers.Layout.cs']},claimsGoalComplete=False)
(b/'resize17781-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
providers={}
for name in files:
    p=Path(name);text=p.read_text(encoding='utf-8')
    if p.name=='platform_io.slg':
        start=text.index('    Arena(0) => failureNames!',text.index('emitArrayAllocationGuard identity:'))
        text=text[:start]+'''    prefix -> emitAllocationGuard("_data", ownerIndex, context, state)
}

# A nullable resize and a fresh literal allocation share the same fatal
# decision. The pointer suffix also separates pointer and Boolean SSA names.
emitAllocationGuard prefix: Text, pointerSuffix: Text, ownerIndex: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {
'''+text[start:]
        text=text.replace('"  %$(prefix)_allocated = icmp ne ptr %$(prefix)_data, null"','"  %$(prefix)_allocation_ok = icmp ne ptr %$(prefix)$(pointerSuffix), null"',1)
        text=text.replace('"  br i1 %$(prefix)_allocated, label %$(prefix)_allocation_ready, label %$(prefix)_allocation_failed"','"  br i1 %$(prefix)_allocation_ok, label %$(prefix)_allocation_ready, label %$(prefix)_allocation_failed"',1)
        text=text.replace('WhileValueRequest { whileIndex: -1, ownerIndex: ownerIndex, nodeIndex: identity.resultIndex }','WhileValueRequest { whileIndex: -1, ownerIndex: ownerIndex, nodeIndex: -1 }',1)
    else:
        lines=text.splitlines(keepends=True);output=[];inserted=set()
        for line in lines:
            output.append(line)
            if '%materialize$(materializeIndex)_grown = call ptr @sollang_resize(' in line:
                output += ['    Arena(0) => materializeGuardNames!\n','    "materialize$(materializeIndex)" -> materialize(materializeGuardNames!) => materializeGuardPrefix\n','    materializeGuardPrefix -> emitAllocationGuard("_grown", request.ownerIndex, context, state)\n']
                inserted.add('materialize')
            if '%reserve$(reserveIndex)_allocated = call ptr @sollang_resize(' in line:
                output += ['    Arena(0) => reserveGuardNames!\n','    "reserve$(reserveIndex)" -> materialize(reserveGuardNames!) => reserveGuardPrefix\n','    reserveGuardPrefix -> emitAllocationGuard("_allocated", request.ownerIndex, context, state)\n']
                inserted.add('reserve')
        assert inserted=={'reserve','materialize'}
        text=''.join(output)
        # Only phi incoming edges change; labels selecting the allocation path
        # keep their original names and decisions.
        changed=0;updated=[]
        for line in text.splitlines(keepends=True):
            if '= phi ' in line and '%materialize$(materializeIndex)_grow ]' in line:
                line=line.replace('%materialize$(materializeIndex)_grow ]','%materialize$(materializeIndex)_allocation_ready ]');changed+=1
            if '= phi ' in line and '%reserve$(reserveIndex)_allocate ]' in line:
                line=line.replace('%reserve$(reserveIndex)_allocate ]','%reserve$(reserveIndex)_allocation_ready ]');changed+=1
            updated.append(line)
        assert changed==4,changed
        text=''.join(updated)
    target=b/'resize17781-candidate'/p.name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text,encoding='utf-8')
    providers[name]=target.as_posix()
(b/'resize17781-provider-map.json').write_text(json.dumps(providers,indent=2)+'\n',encoding='utf-8')
paths=Path('tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt').read_text(encoding='utf-8-sig').splitlines()
paths=[p.strip().replace('\\','/') for p in paths if p.strip()]
(b/'resize17781-sources.txt').write_text('\n'.join(providers.get(p,p) for p in paths)+'\n',encoding='utf-8')
print('prepared2 source guard refactor;4 phi predecessors updated')
