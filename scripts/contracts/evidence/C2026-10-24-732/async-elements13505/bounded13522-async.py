from pathlib import Path
import json,hashlib,datetime,shutil,runpy
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';out=r/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505'
proof=b/'bounded13521-managed/result.json';d=json.loads(proof.read_text(encoding='utf-8'));assert d['status']=='passed' and d['completed']==d['total']==44 and d['inputsStable'] and d['processesStopped']
masked=runpy.run_path(str(r/'scripts/verify-context-fixture-initializers.py'))['masked']
def block(s,marker):
 a=s.index(marker);q=s.index('{',a);c=masked(s);z=q+1;depth=1
 while depth:depth+=(c[z]=='{')-(c[z]=='}');z+=1
 return a,z,s[a:z]
paths=['functions.slg','core_calls.slg','call_arguments.slg']
for name in paths:shutil.copyfile(r/'selfhost/llvm/text'/name,out/(name+'.before-async'))
(out/'async-source-comparison13522.json').write_text(json.dumps(dict(schemaVersion=1,status='compared-before-slg-edit',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),managedFirst=str(proof.relative_to(r)).replace('\\','/'),managedProofSha256=hashlib.sha256(proof.read_bytes()).hexdigest().upper(),completed=44,total=44,authority=['CSharp async primary declaration/call materialize canonical aggregate values; worker primary binding dematerializes those values, matching additional arguments.','CSharp AsyncStorageLlvmType, MaterializeAsyncResult, DematerializeAsyncResult use exact typed values in input/result slots.','CSharp suspension spill stores MaterializeAggregateValue and restores DematerializeAggregateValue; mutable runtime slots remain local descriptors and frames contain owned inline bytes.','SLG local handles may remain descriptors, but async input/result/frame storage must use canonical finite bounded values; restore local handles before releasing context/frame.'],consumers=['async wrapper signature and input stores','worker input loads and local handle reconstruction','call argument materialization, including async targets','completion result materialization','await load and result reconstruction before task release','frame serialize/deserialize and owned cancellation loads'],claimsSlgRuntimePassed=False),indent=2)+'\n',encoding='utf-8')
p=r/'selfhost/llvm/text/call_arguments.slg';s=p.read_text(encoding='utf-8');needle='''    (context.ir[callIndex] -> targetsNativeFunction(context, state)) or context.ir[callIndex].flags / 8 % 2 == 1''';assert s.count(needle)==1;s=s.replace(needle,'''    (context.ir[callIndex] -> targetsNativeFunction(context, state))''');p.write_text(s,encoding='utf-8')
p=r/'selfhost/llvm/text/functions.slg';s=p.read_text(encoding='utf-8')
# Task context input/result values are canonical; the worker's expression
# readers still consume the ordinary local runtime handles.
a,z,v=block(s,'emitAsyncContextParameters functionIndex:')
v=v.replace('''        "  %arg = load " -> print
        asyncPrimaryParameter -> writeIrType(context, state)''','''        asyncPrimaryParameter -> boundedArrayValueTypeId(context, state) => asyncPrimaryBoundedType
        "  %arg" -> print
        asyncPrimaryBoundedType >= 0 -> if { "_bounded" -> print }
        " = load " -> print
        asyncPrimaryParameter -> writeFunctionValueAbiType(context, state)''')
needle='''        asyncPrimaryParameter -> storageAlign(context, state) -> writeDecimalLine''';assert v.count(needle)==1
v=v.replace(needle,needle+'''
        asyncPrimaryBoundedType >= 0 -> if {
            "arg" -> emitBoundedArrayHandle("%arg_bounded", asyncPrimaryBoundedType, context, state)
        }''')
v=v.replace('''        "  %arg$(asyncAdditionalParameterOrdinal!) = load " -> print
        asyncAdditionalParameter -> writeIrType(context, state)''','''        asyncAdditionalParameter -> boundedArrayValueTypeId(context, state) => asyncAdditionalBoundedType
        "  %arg$(asyncAdditionalParameterOrdinal!)" -> print
        asyncAdditionalBoundedType >= 0 -> if { "_bounded" -> print }
        " = load " -> print
        asyncAdditionalParameter -> writeFunctionValueAbiType(context, state)''')
needle='''        asyncAdditionalParameter -> storageAlign(context, state) -> writeDecimalLine''';assert v.count(needle)==1
v=v.replace(needle,needle+'''
        asyncAdditionalBoundedType >= 0 -> if {
            "arg$(asyncAdditionalParameterOrdinal!)" -> emitBoundedArrayHandle("%arg$(asyncAdditionalParameterOrdinal!)_bounded", asyncAdditionalBoundedType, context, state)
        }''');s=s[:a]+v+s[z:]
for name in ['asyncWrapperPrimaryParameter','asyncWrapperAdditionalParameter','asyncStoredPrimaryParameter','asyncStoredAdditionalParameter']:
 needle=f'{name} -> writeIrType(context, state)';assert s.count(needle)==1;s=s.replace(needle,f'{name} -> writeFunctionValueAbiType(context, state)')
a,z,v=block(s,'emitAsyncFunctionCompletion functionIndex:')
needle='''            "  store " -> print
            function -> writeIrType(context, state)
            " $valueName, ptr %async_context, align " -> print
            function -> storageAlign(context, state) -> writeDecimalLine''';assert needle in v
v=v.replace(needle,'''            function -> boundedArrayValueTypeId(context, state) => boundedResultType
            boundedResultType >= 0 -> if {
                Arena(0) => prefixStorage!
                "async_result$(completionIndex)" -> materialize(prefixStorage!) => prefix
                prefix -> emitBoundedArrayValueFromHandle(valueName, boundedResultType, context, state)
                "  store " -> print
                boundedResultType -> writeValueAbiTypeId(context, state)
                " %$(prefix), ptr %async_context, align $(context.typeAligns[boundedResultType])" -> println
            } else {
                "  store " -> print
                function -> writeIrType(context, state)
                " $valueName, ptr %async_context, align " -> print
                function -> storageAlign(context, state) -> writeDecimalLine
            }''');s=s[:a]+v+s[z:]
# Keep runtime descriptors in worker-local slots. Serialize their occupied
# storage as inline bytes; resume reconstructs a fresh worker-local handle.
helper='''emitBoundedAsyncFrameTransfer bindingIndex: Int, stateIndex: Int, typeId: Int, loading: Bool, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {
    Arena(0) => prefixStorage!
    "async_frame$(stateIndex)_$(bindingIndex)" -> materialize(prefixStorage!) => prefix
    Arena(0) => valueStorage!
    loading -> if { "%$(prefix)_loaded" } else { "%$(prefix)_stored" } -> materialize(valueStorage!) => valueName
    loading -> if {
        "  %$(prefix)_loaded = load " -> print
        typeId -> writeValueAbiTypeId(context, state)
        ", ptr %$(prefix)_load_address, align $(context.typeAligns[typeId])" -> println
        "$(prefix)_handle" -> emitBoundedArrayHandle(valueName, typeId, context, state)
        "  store %sollang.array.i32 %$(prefix)_handle, ptr " -> print
        bindingIndex -> writeAsyncLocalAddress(context)
        ", align 8" -> println
    } else {
        "  %$(prefix)_stored = load %sollang.array.i32, ptr " -> print
        bindingIndex -> writeAsyncLocalAddress(context)
        ", align 8" -> println
        "$(prefix)_inline" -> emitBoundedArrayValueFromHandle(valueName, typeId, context, state)
        "  store " -> print
        typeId -> writeValueAbiTypeId(context, state)
        " %$(prefix)_inline, ptr %$(prefix)_store_address, align $(context.typeAligns[typeId])" -> println
    }
}

'''
a=s.index('emitAsyncFrameTransfer point:');s=s[:a]+helper+s[a:]
a,z,v=block(s,'emitAsyncFrameTransfer point:')
first=v.index('''                "  %async_frame$(point.state)_$(bindingIndex!)_" -> print
                loading -> if { "loaded" -> print } else { "stored" -> print }''')
last=v.index('''                offset! + (bindingIndex! -> asyncContextValueSize''',first)
old=v[first:last]
v=v[:first]+'''                binding -> boundedArrayValueTypeId(context, state) => boundedFrameType
                boundedFrameType >= 0 -> if {
                    bindingIndex! -> emitBoundedAsyncFrameTransfer(point.state, boundedFrameType, loading, context, state)
                } else {
'''+''.join('    '+line+'\n' for line in old.splitlines())+'''                }
'''+v[last:];s=s[:a]+v+s[z:]
a,z,v=block(s,'emitAsyncCancelledTaskSpills point:')
needle='''                            binding -> writeIrType(context, state)''';assert v.count(needle)==1
v=v.replace(needle,'''                            binding -> writeFunctionValueAbiType(context, state)''');s=s[:a]+v+s[z:];p.write_text(s,encoding='utf-8')
p=r/'selfhost/llvm/text/core_calls.slg';s=p.read_text(encoding='utf-8');a,z,v=block(s,'emitAwaitTaskValue nodeIndex:')
needle='''                    "  %v$(nodeIndex) = load " -> print''';assert v.count(needle)==1
v=v.replace(needle,'''                    "  " -> print
                    nodeIndex -> writeMemberStorageValueName(context, state)
                    " = load " -> print''')
needle='''                    awaited -> storageAlign(context, state) -> writeDecimalLine''';assert v.count(needle)==1
v=v.replace(needle,needle+'''
                    awaited -> boundedArrayValueTypeId(context, state) => awaitedBoundedType
                    "v$(nodeIndex)" -> emitStoredBoundedValueHandle(awaitedBoundedType, context, state)''')
s=s[:a]+v+s[z:];p.write_text(s,encoding='utf-8')
print('CSharp44 verified before SLG edits; async bounded input/result/frame storage now uses canonical inline values.')
