from pathlib import Path
import json,hashlib,datetime,shutil,runpy
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';out=r/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505';proof=json.loads((b/'bounded13521-managed/result.json').read_text(encoding='utf-8'));assert proof['status']=='passed' and proof['completed']==proof['total']==44 and proof['inputsStable'] and proof['processesStopped']
masked=runpy.run_path(str(r/'scripts/verify-context-fixture-initializers.py'))['masked']
def block(s,marker):
 a=s.index(marker);q=s.index('{',a);c=masked(s);z=q+1;depth=1
 while depth:depth+=(c[z]=='{')-(c[z]=='}');z+=1
 return a,z,s[a:z]
p=r/'selfhost/llvm/text/containers.slg';s=p.read_text(encoding='utf-8');shutil.copyfile(p,out/'containers.before-elements.slg')
(out/'element-source-comparison13523.json').write_text(json.dumps(dict(schemaVersion=1,status='compared-before-slg-edit',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),managedFirst='artifacts/scratch/resume-20261006-owner-continuation22/bounded13521-managed/result.json',completed=44,total=44,authority='CSharp nested bounded growable/bounded mutation cases passed. Array push materializes bounded element values into canonical storage; take loads the canonical element into a fresh local handle before compacting the array. Exchange moves complete canonical element bytes without dematerializing them.',sourceSha256=hashlib.sha256(p.read_bytes()).hexdigest().upper(),claimsSlgRuntimePassed=False),indent=2)+'\n',encoding='utf-8')
a,z,v=block(s,'emitArrayPush request:')
needle='''    "  store " -> print
    pushSource -> writeArrayElementType(context, state)''';assert v.count(needle)==1
at=v.index(needle)
v=v[:at]+'''    pushSource -> arrayElementTypeId(context, state) => pushElementType
    pushElementType >= 0 and context.types[pushElementType].kind == 12 => pushBoundedElement
    pushBoundedElement -> if {
        "push$(pushIndex)_bounded_value" -> emitBoundedArrayValue(pushValueNameIndex!, request.ownerIndex, pushElementType, context, state)
    }
'''+v[at:]
needle='''    pushValue.kind == 3 or pushValue.kind == 4 -> if {''';assert v.count(needle)==1
v=v.replace(needle,'''    pushBoundedElement -> if { "%push$(pushIndex)_bounded_value" -> print } else {
    pushValue.kind == 3 or pushValue.kind == 4 -> if {''')
needle='''    pushSource -> arrayElementAlign(context, state) => pushElementAlign''';assert v.count(needle)==1
v=v.replace(needle,'''    }
'''+needle);s=s[:a]+v+s[z:]
a,z,v=block(s,'emitTake request:')
needle='''        "  %v$(takeIndex) = load " -> print
        takeSource -> writeArrayElementType(context, state)''';assert v.count(needle)==1
v=v.replace(needle,'''        "  " -> print
        takeIndex -> writeMemberStorageValueName(context, state)
        " = load " -> print
        takeSource -> writeArrayElementType(context, state)''')
needle='''        "  %take$(takeIndex)_new_length = sub i64 %take$(takeIndex)_length, 1" -> println''';assert v.count(needle)>=1
at=v.rfind(needle)
v=v[:at]+'''        takeNode -> boundedArrayValueTypeId(context, state) => takeBoundedElementType
        "v$(takeIndex)" -> emitStoredBoundedValueHandle(takeBoundedElementType, context, state)
'''+v[at:];s=s[:a]+v+s[z:];p.write_text(s,encoding='utf-8')
print('CSharp44 before SLG mutation edits; nested bounded push stores values and take restores an isolated handle.')
