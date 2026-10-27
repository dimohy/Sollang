from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');o=b/'io17075-candidate';o.mkdir(exist_ok=False)
s=Path('selfhost/llvm/runtime.slg').read_text();a=s.index('public emitGlobalBinaryFileRuntime:');z=s.index('\n# Browser builds',a);region=s[a:z];assert region.count('      call void @llvm.trap()')==4
region=region.replace('public emitGlobalBinaryFileRuntime: -> Unit uses Console {','''public emitGlobalBinaryFileRuntime windows: Bool, flushOutput: Bool -> Unit uses Console {
    "define internal void @sollang_binary_failure() noreturn {" -> println
    "entry:" -> println
    flushOutput -> if { "  call void @sollang_runtime_flush_stdout()" -> println }
    windows -> if { "  call void @ExitProcess(i32 1)" -> println } else { "  call void @exit(i32 1)" -> println }
    "  unreachable" -> println
    "}" -> println''');region=region.replace('      call void @llvm.trap()','      call void @sollang_binary_failure()');(o/'runtime.slg').write_text(s[:a]+region+s[z:],encoding='utf-8')
s=Path('selfhost/llvm/text/context_prepare.slg').read_text();assert s.count('llvmRuntime.emitGlobalBinaryFileRuntime()')==2;s=s.replace('llvmRuntime.emitGlobalBinaryFileRuntime()','llvmRuntime.emitGlobalBinaryFileRuntime(true, context -> diagnostics.usesTextRuntime)',1);s=s.replace('llvmRuntime.emitGlobalBinaryFileRuntime()','llvmRuntime.emitGlobalBinaryFileRuntime(false, context -> diagnostics.usesTextRuntime)',1);(o/'context_prepare.slg').write_text(s,encoding='utf-8')
s=Path('selfhost/llvm/text/runtime_preamble.slg').read_text();s=s.replace('needsProcessExit or (intrinsicRuntimeModule >= 0 and context.pointerBitWidth != 32)','needsProcessExit or (context.pointerBitWidth != 32 and (intrinsicRuntimeModule >= 0 or (context -> diagnostics.usesOwnedFileRuntime)))',1);(o/'runtime_preamble.slg').write_text(s,encoding='utf-8')
s=(b/'interp16997-emitter.slg').read_text();a=s.index('    [\n');z=s.index('    ] => allowedPrograms',a);c=json.loads((b/'io17070-managed8.json').read_text());s=s[:a]+'    [\n'+',\n'.join('    '+json.dumps(x['source']) for x in c['cases'])+'\n'+s[z:];(b/'io17075-emitter.slg').write_text(s,encoding='utf-8')
d=json.loads((b/'fold17046-contract8.json').read_text());m={'selfhost/llvm/runtime.slg':(o/'runtime.slg').as_posix(),'selfhost/llvm/text/context_prepare.slg':(o/'context_prepare.slg').as_posix(),'selfhost/llvm/text/runtime_preamble.slg':(o/'runtime_preamble.slg').as_posix()};g=d['reusableCheckedProducer'];g['source']=(b/'io17075-emitter.slg').as_posix();g['additionalSources']=[m.get(p,p) for p in g['additionalSources']];g['id']='io-failure-abi8';d['expectedManagedDllSha256']=c['expectedManagedDllSha256'];d['semanticPreflightProof']=(b/'io17076-semantic/result.json').as_posix();d['scope']='C745 actualSLG8 source runtime after CSharp8 and source comparison; runtime status1 must not depend on caller ABI. Producer1/build180/case180/retry0.'
template=d['cases'][0];d['cases']=[]
for x in c['cases']:
 row=dict(template);row.update(id=x['id'],source=g['source'],additionalSources=g['additionalSources'],programSource=x['source'],runArguments=[x['source']],observedSourceOrder=[x['source']]+g['stdlibSourceOrder'],stdout=x['stdout'],expectedEmittedRuntimeExit=x['expectedRuntimeExit']);d['cases'].append(row)
d['formatCheckSources']=[g['source']]+list(m.values())+[x['source'] for x in c['cases']];d['runtimeInputFiles']=[(b/'io17071-managed8/result.json').as_posix(),(b/'io17073-source-comparison.json').as_posix()];(b/'io17075-source8.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8');(b/'io17075-sources.txt').write_text('\n'.join([g['source']]+g['additionalSources'])+'\n',encoding='utf-8')
