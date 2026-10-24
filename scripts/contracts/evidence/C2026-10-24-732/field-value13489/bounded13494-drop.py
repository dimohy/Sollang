from pathlib import Path
import hashlib,json,datetime,runpy
r=Path.cwd();out=r/'scripts/contracts/evidence/C2026-10-24-732/field-value13489';p=r/'selfhost/llvm/text/ownership.slg';s=p.read_text(encoding='utf-8')
masked=runpy.run_path(str(r/'scripts/verify-context-fixture-initializers.py'))['masked']
def block(s,marker):
 a=s.index(marker);q=s.index('{',a);c=masked(s);z=q+1;d=1
 while d:d+=(c[z]=='{')-(c[z]=='}');z+=1
 return a,z,s[a:z]
(out/'drop-source-comparison13494.json').write_text(json.dumps(dict(schemaVersion=1,status='source-reviewed-before-drop-edit',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),managedFirst='source-comparison13489.json',managedCase='850-bounded-owned-element-drop',authority='LlvmEmitter.Drop.cs EmitBoundedArrayDropHelper dematerializes the canonical value then drops occupied owned elements; inline backing is never freed. LlvmEmitter.Structs.cs BuildBoundedArrayAggregate provides drop-call values.',beforeOwnershipSha256=hashlib.sha256(p.read_bytes()).hexdigest().upper(),claimsRuntimePassed=False),indent=2)+'\n',encoding='utf-8')
# Whole consuming parameters have a runtime handle after their ABI prologue.
a,z,v=block(s,'emitWholeParameterDrop parameterIndex:')
at=v.index('    "  call void @sollang_drop_t$(parameter.typeId)(')
v=v[:at]+'''    context.types[parameter.typeId].kind == 12 -> if {
        Arena(0) => prefixStorage!
        "drop_parameter$(parameterIndex)_edge$(edgeIndex)_bounded" -> materialize(prefixStorage!) => prefix
        "  %$(prefix)_handle = freeze %sollang.array.i32 " -> print
        context -> writeParameterReference(functionIndex, parameter.symbol) => parameterWritten
        "" -> println
        Arena(0) => valueStorage!
        "%$(prefix)_handle" -> materialize(valueStorage!) => handle
        prefix -> emitBoundedArrayValueFromHandle(handle, parameter.typeId, context, state)
    }
'''+v[at:]
needle='''    } else {
        context -> writeParameterReference(functionIndex, parameter.symbol) => parameterWritten
    }
    ")" -> println'''
assert needle in v
v=v.replace(needle,'''    } else {
        context.types[parameter.typeId].kind == 12 -> if {
            "%drop_parameter$(parameterIndex)_edge$(edgeIndex)_bounded" -> print
        } else { context -> writeParameterReference(functionIndex, parameter.symbol) => parameterWritten }
    }
    ")" -> println''')
s=s[:a]+v+s[z:]
# Root runtime handles must cross the canonical drop-helper boundary as inline
# values. Extracted fields/payloads (valueKind2,valueIndex-1) already are inline.
a,z,v=block(s,'emitDropGlue request:')
needle='''                "  call void @sollang_drop_t$(dropTask.typeId)(" -> print'''
at=v.rfind(needle);assert at>=0
v=v[:at]+'''                context.types[dropTask.typeId].kind == 12
                    and (dropTask.valueKind != 2 or dropTask.valueIndex >= 0) => dropTaskNeedsBoundedValue
                dropTaskNeedsBoundedValue -> if {
                    Arena(0) => prefixStorage!
                    "dropbounded$(edgeNodeIndex)_$(dropTaskIndex!)" -> materialize(prefixStorage!) => prefix
                    "  %$(prefix)_handle = freeze %sollang.array.i32 " -> print
                    dropTask -> emitDropValueName(context, state)
                    "" -> println
                    Arena(0) => valueStorage!
                    "%$(prefix)_handle" -> materialize(valueStorage!) => handle
                    prefix -> emitBoundedArrayValueFromHandle(handle, dropTask.typeId, context, state)
                }
'''+v[at:]
needle='''                } else {
                    dropTask -> emitDropValueName(context, state)
                }
                ")" -> println''';assert needle in v
v=v.replace(needle,'''                } else {
                    dropTaskNeedsBoundedValue -> if {
                        "%dropbounded$(edgeNodeIndex)_$(dropTaskIndex!)" -> print
                    } else { dropTask -> emitDropValueName(context, state) }
                }
                ")" -> println''',1)
s=s[:a]+v+s[z:]
# A pattern binding's ordinary SSA and async local reload are both handles.
a,z,v=block(s,'emitPatternBindingDrop bindingIndex:')
needle='''    } else {
        "  call void @sollang_drop_t$(typeId)(" -> print''';assert needle in v
v=v.replace(needle,'''    } else {
        context.types[typeId].kind == 12 -> if {
            "  %patternbounded$(bindingIndex)_handle = freeze %sollang.array.i32 " -> print
            frameRoot >= 0 -> if { "%dropg$(bindingIndex)_p0" -> print } else { "%v$(bindingIndex)" -> print }
            "" -> println
            "patternbounded$(bindingIndex)" -> emitBoundedArrayValueFromHandle("%patternbounded$(bindingIndex)_handle", typeId, context, state)
        }
        "  call void @sollang_drop_t$(typeId)(" -> print''')
needle='''        frameRoot >= 0 -> if { "%dropg$(bindingIndex)_p0" -> print } else { "%v$(bindingIndex)" -> print }
        ")" -> println''';assert needle in v
v=v.replace(needle,'''        context.types[typeId].kind == 12 -> if { "%patternbounded$(bindingIndex)" -> print } else {
            frameRoot >= 0 -> if { "%dropg$(bindingIndex)_p0" -> print } else { "%v$(bindingIndex)" -> print }
        }
        ")" -> println''')
s=s[:a]+v+s[z:]
# Canonical helper receives {length,[N x element]}, not {ptr,len,cap}.
needle='''                        "  %data = extractvalue %sollang.array.i32 %value, 0" -> println
                        "  %length = extractvalue %sollang.array.i32 %value, 1" -> println'''
at=s.index(needle,s.index('dropType.kind == 3 or dropType.kind == 12'))
replacement='''                        dropType.kind == 12 -> if {
                            "  %owner = alloca " -> print
                            dropTypeIndex! -> writeSemanticTypeId(context, state)
                            ", align $(context.typeAligns[dropTypeIndex!])" -> println
                            "  store " -> print
                            dropTypeIndex! -> writeSemanticTypeId(context, state)
                            " %value, ptr %owner, align $(context.typeAligns[dropTypeIndex!])" -> println
                            "  %data = getelementptr inbounds " -> print
                            dropTypeIndex! -> writeSemanticTypeId(context, state)
                            ", ptr %owner, i32 0, i32 1, i64 0" -> println
                            "  %length = extractvalue " -> print
                            dropTypeIndex! -> writeSemanticTypeId(context, state)
                            " %value, 0" -> println
                        } else {
                            "  %data = extractvalue %sollang.array.i32 %value, 0" -> println
                            "  %length = extractvalue %sollang.array.i32 %value, 1" -> println
                        }'''
s=s[:at]+replacement+s[at+len(needle):];p.write_text(s,encoding='utf-8')
print('Bounded owned drop body and consuming parameter/local/pattern call boundaries use canonical inline values.')
