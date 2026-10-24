from pathlib import Path
import runpy,json,hashlib,datetime
r=Path.cwd(); b=r/'artifacts/scratch/resume-20261006-owner-continuation22'; out=r/'scripts/contracts/evidence/C2026-10-24-732/field-value13489'
masked=runpy.run_path(str(r/'scripts/verify-context-fixture-initializers.py'))['masked']
def block(s,marker):
 start=s.index(marker); brace=s.index('{',start); clean=masked(s); end=brace+1; depth=1
 while depth: depth+=(clean[end]=='{')-(clean[end]=='}');end+=1
 return start,end,s[start:end]
paths=['ownership.slg','function_expressions.slg','control_region_expressions.slg','foundation.slg']
before={p:hashlib.sha256((r/'selfhost/llvm/text'/p).read_bytes()).hexdigest().upper() for p in paths}
# C# CreateRuntimeAggregateValue uses a fresh owner and a local descriptor for
# inline bounded values loaded at any field or index boundary. The loaded
# descriptor must not reuse the outer index operation's data/length SSA names.
record=dict(schemaVersion=1,status='source-compared-before-index-edit',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),managedFirst='source-comparison13489.json',managedCases=35,before=before,authority='LlvmEmitter.Structs.cs CreateRuntimeAggregateValue bounded branch: alloca/store inline value, data GEP field1, length extract field0; array element access loads the canonical stored type.',observedMismatch='Function and region array indexing load runtime descriptor types from canonical inline elements; bounded/growable dictionary reads retain inline values without reconstruction. Readonly bounded source indexing also assumes dynamic descriptor field order.',claimsRuntimePassed=False)
(out/'index-source-comparison13492.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
p=r/'selfhost/llvm/text/ownership.slg';s=p.read_text(encoding='utf-8');at=s.index('writeMemberStorageValueName ')
helpers='''# Inline element loads become local runtime handles. Keep their temporary
# names separate from the outer index operation's data and length values.
emitStoredBoundedValueHandle prefix: Text, typeId: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {
    typeId >= 0 and context.types[typeId].kind == 12 -> if {
        Arena(0) => nameStorage!
        "$(prefix)_loaded" -> materialize(nameStorage!) => handlePrefix
        "%$(prefix)_bounded_value" -> materialize(nameStorage!) => storedValue
        handlePrefix -> emitBoundedArrayHandle(storedValue, typeId, context, state)
        "  %$(prefix) = freeze %sollang.array.i32 %$(handlePrefix)" -> println
    }
}

emitIndexedReadonlySource prefix: Text, sourceIndex: Int, ownerIndex: Int, typeId: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console, Process {
    "  %$(prefix)" -> print
    context.types[typeId].kind == 12 -> if { "_bounded_value" -> print }
    " = load " -> print
    typeId -> writeAggregateFieldTypeId(context, state)
    ", ptr " -> print
    ownerIndex -> writeForwardedReferenceValue(sourceIndex, context, state)
    ", align $(context.typeAligns[typeId])" -> println
    prefix -> emitStoredBoundedValueHandle(typeId, context, state)
}

writeIndexedSourceType typeId: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {
    context.types[typeId].kind == 12 -> if { "%sollang.array.i32" -> print } else {
        typeId -> writeAggregateFieldTypeId(context, state)
    }
}

'''
s=s[:at]+helpers+s[at:];p.write_text(s,encoding='utf-8')
for filename,var,node,owner,container,readonly in [
 ('function_expressions.slg','expressionIndex','expression','functionIndex','indexedContainerTypeId!','indexedReadonlyReference!'),
 ('control_region_expressions.slg','regionNodeIndex','regionNode','ownerIndex','regionIndexedContainerTypeId!','regionIndexedReadonlyReference!')]:
 p=r/'selfhost/llvm/text'/filename;s=p.read_text(encoding='utf-8');start,end,v=block(s,f'    {node}.kind == 15 -> if {{')
 # Replace only the initial readonly source load, preserving dynamic handling.
 first=v.index(f'                "  %v$({var})_indexed_source = load " -> print')
 last=v.index(' -> writeDecimalLine',first)+len(' -> writeDecimalLine')
 v=v[:first]+f'                "v$({var})_indexed_source" -> emitIndexedReadonlySource({node}.operand0, {owner}, {container}, context, state)'+v[last:]
 # Canonical bounded source loads were reconstructed above; extraction now
 # uses the runtime descriptor, as all non-reference source expressions do.
 v=v.replace(f'{container} -> writeAggregateFieldTypeId(context, state)',f'{container} -> writeIndexedSourceType(context, state)')
 # GEP and load refer to the stored element type, not its local descriptor.
 v=v.replace(f'{node} -> writeIrType(context, state)',f'{node}.typeId >= 0 -> if {{ {node}.typeId -> writeAggregateFieldTypeId(context, state) }} else {{ {node} -> writeIrType(context, state) }}')
 token=f'"  %v$({var}) = load " -> print';assert v.count(token)>=1
 v=v.replace(token,f'"  " -> print\n                {var} -> writeMemberStorageValueName(context, state)\n                " = load " -> print')
 # Region dictionaries return canonical values too; convert them here. The
 # function dictionary path converts inside its shared helper instead.
 post=f'''        {node} -> boundedArrayValueTypeId(context, state) => indexedBoundedTypeId
        indexedBoundedTypeId >= 0'''
 if filename.startswith('function_'):post+=f' and not indexedIsDictionary'
 post+=f''' -> if {{
            "v$({var})" -> emitStoredBoundedValueHandle(indexedBoundedTypeId, context, state)
        }}
    '''
 at=v.rfind('}');v=v[:at]+post+v[at:];p.write_text(s[:start]+v+s[end:],encoding='utf-8')
# The shared growable dictionary reader also serves loop emission with a
# distinct prefix. Preserve that prefix when materializing the loaded result.
p=r/'selfhost/llvm/text/function_expressions.slg';s=p.read_text(encoding='utf-8');a,z,v=block(s,'emitGrowableDictionaryIndex request:')
needle='    "  %$(prefix) = load " -> print';assert v.count(needle)==1
v=v.replace(needle,'''    "  %$(prefix)" -> print
    indexedDictionaryValueTypeId! >= 0 and context.types[indexedDictionaryValueTypeId!].kind == 12 -> if { "_bounded_value" -> print }
    " = load " -> print''')
at=v.rfind('}');v=v[:at]+'''    prefix -> emitStoredBoundedValueHandle(indexedDictionaryValueTypeId!, context, state)
'''+v[at:];p.write_text(s[:a]+v+s[z:],encoding='utf-8')
p=r/'selfhost/llvm/text/foundation.slg';s=p.read_text(encoding='utf-8');a,z,v=block(s,'emitBoundedDictionaryIndex nodeIndex:')
needle='    "  %v$(nodeIndex) = load " -> print';assert v.count(needle)==1
v=v.replace(needle,'''    "  " -> print
    nodeIndex -> writeMemberStorageValueName(context, state)
    " = load " -> print''')
at=v.rfind('}');v=v[:at]+'''    "v$(nodeIndex)" -> emitStoredBoundedValueHandle(valueTypeId, context, state)
'''+v[at:];p.write_text(s[:a]+v+s[z:],encoding='utf-8')
print('Canonical array and dictionary element reads reconstructed; readonly bounded source field order corrected.')
