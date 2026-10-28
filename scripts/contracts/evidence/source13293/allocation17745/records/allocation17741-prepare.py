from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,re

r=Path.cwd();b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
sources=[p for p in Path('selfhost/llvm').rglob('*.slg') if re.search(r'@(malloc|realloc|free)\(',p.read_text(encoding='utf-8'))]
sources+= [Path('selfhost/llvm/text/context_prepare.slg'),Path('selfhost/llvm/emitter/text_output_runtime.slg')]
sources=list(dict.fromkeys(sources))
comparison=dict(schemaVersion=1,status='compared-before-slg-edit',observedAtUtc=datetime.now(timezone.utc).isoformat(),managedFirstNormal=str(b/'placement17610-managed4/result.json'),managedFailureObservation=str(b/'allocation17740-managed-failure/result.json'),structure='CSharp platform memory primitives select Windows process heap, Linux malloc/free or browser allocation. Raw primitives return null; expression allocation adds the guard. SLG currently calls CRT allocation directly across runtime and container producers. Migrate every allocator-family consumer together; keep native API-specific releases such as LocalFree/freeaddrinfo unchanged.',branches='Three realloc consumers must not pass a process-heap pointer to CRT realloc. Match the CSharp allocate/copy/free growth sequence with a shared nullable resize helper preserving the old allocation when allocation fails. Copy live bytes: input length, materialization used length, reserve length times element size.',logic='This private unit aligns raw allocation family and resize ownership only. Expression null guards and Windows trap diagnostics remain a subsequent required part of original42 parity. No original source, expected output or LLVM oracle edits.',diagnostics='Managed original42 failure injection observed STATUS_ILLEGAL_INSTRUCTION and stderr main:bb_alloc_fail3. The older assumption that a nonzero empty-stderr exit was sufficient was wrong. Failure-injection outputs are retained because lifecycle cleanup rejects the unbound nonzero runtime expectation; no cleanup bypass.',canonicalSourceHashes={p.as_posix():sha(p) for p in sources},csharpSources={p:sha(p) for p in ['src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs','src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs','src/Sollang.Compiler/CodeGen/WasmBrowserLlvmRuntimePlatform.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Containers.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Containers.Layout.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Expressions.Control.cs']},claimsGoalComplete=False)
(b/'allocation17741-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
primitive='''
# Raw platform allocation matches the managed memory primitive contract.
# A null result belongs to the caller's failure decision; allocation does not
# trap here because I/O callers can return a recoverable failure.
public emitMemoryPrimitives pathStyle: Int, pointerBitWidth: Int -> Unit uses Console {
    pointerBitWidth == 32 -> if {
        """
        declare i32 @sollang_browser_alloc(i64)
        define ptr @sollang_alloc(i64 %bytes) {
        entry:
          %value32 = call i32 @sollang_browser_alloc(i64 %bytes)
          %value = inttoptr i32 %value32 to ptr
          ret ptr %value
        }
        define internal void @sollang_free(ptr %value) {
        entry:
          ret void
        }
        """ -> println
    } else {
        pathStyle == 1 -> if {
            """
            declare ptr @GetProcessHeap()
            declare ptr @HeapAlloc(ptr, i32, i64)
            declare i32 @HeapFree(ptr, i32, ptr)
            define internal ptr @sollang_alloc(i64 %bytes) {
            entry:
              %heap = call ptr @GetProcessHeap()
              %value = call ptr @HeapAlloc(ptr %heap, i32 0, i64 %bytes)
              ret ptr %value
            }
            """ -> println
        } else {
            """
            declare ptr @malloc(i64)
            declare void @free(ptr)
            define internal ptr @sollang_alloc(i64 %bytes) {
            entry:
              %value = call ptr @malloc(i64 %bytes)
              ret ptr %value
            }
            """ -> println
        }
        """
        define internal void @sollang_free(ptr %value) {
        entry:
          %is_null = icmp eq ptr %value, null
          br i1 %is_null, label %done, label %release
        release:
        """ -> println
        pathStyle == 1 -> if {
            """
              %heap = call ptr @GetProcessHeap()
              %ignored = call i32 @HeapFree(ptr %heap, i32 0, ptr %value)
            """ -> println
        } else { "  call void @free(ptr %value)" -> println }
        """
          br label %done
        done:
          ret void
        }
        """ -> println
    }
    """
    declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1 immarg)
    define internal ptr @sollang_resize(ptr %old, i64 %used_bytes, i64 %new_bytes) {
    entry:
      %value = call ptr @sollang_alloc(i64 %new_bytes)
      %allocated = icmp ne ptr %value, null
      br i1 %allocated, label %inspect_old, label %failure
    inspect_old:
      %has_old = icmp ne ptr %old, null
      %has_bytes = icmp ne i64 %used_bytes, 0
      %copy_needed = and i1 %has_old, %has_bytes
      br i1 %copy_needed, label %copy, label %release
    copy:
      %fits = icmp ule i64 %used_bytes, %new_bytes
      %copy_bytes = select i1 %fits, i64 %used_bytes, i64 %new_bytes
      call void @llvm.memcpy.p0.p0.i64(ptr %value, ptr %old, i64 %copy_bytes, i1 false)
      br label %release
    release:
      call void @sollang_free(ptr %old)
      ret ptr %value
    failure:
      ret ptr null
    }
    """ -> println
}
'''
providers={}
for p in sources:
    text=p.read_text(encoding='utf-8')
    if p.name=='runtime_preamble.slg':
        start=text.index('    usesArrayAllocation! or usesArrayReallocation! or usesArenaAllocation!')
        end=text.index('    false => usesDictionary!',start)
        text=text[:start]+text[end:]
        fallback='''        not usesDynamicArray! and not usesSourceText and not usesComputePool and intrinsicRuntimeModule < 0 and not usesOwnedDropRuntime
            -> if {
                "declare ptr @malloc(i64)" -> println
                "declare void @free(ptr)" -> println
            }
'''
        assert text.count(fallback)==1
        text=text.replace(fallback,'')
    if p.name=='containers.slg':
        old='@realloc(ptr %materialize$(materializeIndex)_data, i64 %materialize$(materializeIndex)_new_capacity)'
        assert text.count(old)==1
        text=text.replace(old,'@sollang_resize(ptr %materialize$(materializeIndex)_data, i64 %materialize$(materializeIndex)_used, i64 %materialize$(materializeIndex)_new_capacity)')
        old='    "  %reserve$(reserveIndex)_allocated = call ptr @realloc(ptr %reserve$(reserveIndex)_data, i64 %reserve$(reserveIndex)_bytes)" -> println'
        assert text.count(old)==1
        text=text.replace(old,'    "  %reserve$(reserveIndex)_used_bytes = mul i64 %reserve$(reserveIndex)_length, $reserveElementSize" -> println\n    "  %reserve$(reserveIndex)_allocated = call ptr @sollang_resize(ptr %reserve$(reserveIndex)_data, i64 %reserve$(reserveIndex)_used_bytes, i64 %reserve$(reserveIndex)_bytes)" -> println')
    if p.as_posix()=='selfhost/llvm/runtime.slg':
        old='@realloc(ptr %buffer, i64 %next_capacity)'
        assert text.count(old)==1
        text=text.replace(old,'@sollang_resize(ptr %buffer, i64 %next_length, i64 %next_capacity)')
    text=re.sub(r'@malloc\b','@sollang_alloc',text)
    text=re.sub(r'@free\b','@sollang_free',text)
    if p.name=='text_output_runtime.slg':
        for line in ['    declare ptr @GetProcessHeap()\n','    declare ptr @HeapAlloc(ptr, i32, i64)\n','    declare i32 @HeapFree(ptr, i32, ptr)\n','        declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1 immarg)\n']:
            assert text.count(line)>=1
            text=text.replace(line,'')
        text+=primitive
    if p.name=='context_prepare.slg':
        for target in ('Windows','Linux','Wasm'):
            signature=f'emitPrepared{target}Context context: emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console, Process {{\n'
            assert text.count(signature)==1
            text=text.replace(signature,signature+'    context.expectedPathStyle -> textOutputRuntime.emitMemoryPrimitives(context.pointerBitWidth)\n')
        text=text.replace('    "declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1 immarg)" -> println\n','')
    assert '@realloc(' not in text,p
    target=b/'allocation17741-candidate'/p.relative_to('selfhost/llvm')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text,encoding='utf-8',newline='\n')
    providers[p.as_posix()]=target.as_posix()
(b/'allocation17741-provider-map.json').write_text(json.dumps(providers,indent=2)+'\n',encoding='utf-8')
paths=Path('tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt').read_text(encoding='utf-8-sig').splitlines()
paths=[line.strip().replace('\\','/') for line in paths if line.strip()]
(b/'allocation17741-sources.txt').write_text('\n'.join(providers.get(p,p) for p in paths)+'\n',encoding='utf-8')
print(json.dumps(dict(privateCandidateFiles=len(providers),sourceCount=len(paths),expressionGuardsStillPending=True)))
