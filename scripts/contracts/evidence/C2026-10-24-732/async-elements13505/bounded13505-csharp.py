from pathlib import Path
import json,hashlib,datetime,shutil
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';out=r/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
for folder in ['bounded13500-managed','bounded13504-managed']:
 for p in (b/folder).rglob('*'):
  if p.is_file():q=out/folder/p.relative_to(b/folder);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
for name in ['bounded13499-contract.json','bounded13503-contract.json']:shutil.copyfile(b/name,out/name)
p=r/'src/Sollang.Compiler/Semantics/SemanticCompiler.cs';shutil.copyfile(p,out/'SemanticCompiler.before.cs')
for p0 in r.glob('scripts/probes/declared-value-layout/bounded-*-mutation.slg'):shutil.copyfile(p0,out/p0.name)
record=dict(schemaVersion=1,observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),status='csharp-defects-reproduced-before-csharp-edit',sourceSha256=sha(p),asyncBaseline='bounded13500-managed/result.json',arrayBaseline='bounded13504-managed/result.json',cause=['IsValueTypeSupported has no finite bounded-array element recursion although CSharp canonical inline materialization already supports its result/input storage.','ParseType/typed-empty array and growable element admission treat finite inline bounded arrays as unsupported nested container descriptors; declared nominal fields already support these elements.'],specification=['docs/SPEC.md S027/S028 canonical fixed/bounded array identities and declared field shape.','docs/SPEC.md async context specializes exact input/result types; mutable borrows and nontransferable borrowed views remain rejected.','docs/SPEC.md exchange is restricted to growable arrays. Remove exchange from unexecuted bounded-parent probe before testing, retain its preimage and do not broaden that API.'],scope='Existing finite bounded-array inline values only; retain Unit/view/heap-containing container restrictions and owned-copy/move checks.',claimsPassed=False)
(out/'source-comparison13505.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
p=r/'src/Sollang.Compiler/Semantics/SemanticCompiler.cs';s=p.read_text(encoding='utf-8')
needle='''            if (_types.IsDynamicArray(type))
            {
                return IsValueTypeSupported(_types.GetDynamicArray(type).ElementType, allowSharedSourceText, visiting);
            }'''
assert s.count(needle)==1
s=s.replace(needle,needle+'''
            if (_types.IsBoundedArray(type))
            {
                return IsValueTypeSupported(_types.GetBoundedArray(type).ElementType, allowSharedSourceText, visiting);
            }''')
needle='''                && !_types.IsDynamicArray(type));''';assert s.count(needle)==1
s=s.replace(needle,'''                && !_types.IsDynamicArray(type)
                && !_types.IsBoundedArray(type));''')
needle='''    private bool IsNestedContainerElementType(BoundType type)''';assert s.count(needle)==1
s=s.replace(needle,'''    private bool IsUnsupportedInlineArrayElementType(BoundType type) =>
        type == BoundType.Unit
        || (IsNestedContainerElementType(type) && !_types.IsBoundedArray(type));

'''+needle)
needle='boundedElementType == BoundType.Unit || IsNestedContainerElementType(boundedElementType)';assert s.count(needle)==1
s=s.replace(needle,'IsUnsupportedInlineArrayElementType(boundedElementType)')
# Keep Deque and repeat-value admission unchanged: their contracts differ.
a=s.index('''        if (typeName.StartsWith('[', StringComparison.Ordinal)
            && typeName.EndsWith("; ~]", StringComparison.Ordinal))''');z=s.index('''        if (typeName.Length >= 5 && typeName[0] == '{' ''',a)
v=s[a:z];needle='elementType == BoundType.Unit || IsNestedContainerElementType(elementType)';assert v.count(needle)==3
v=v.replace(needle,'IsUnsupportedInlineArrayElementType(elementType)');s=s[:a]+v+s[z:];p.write_text(s,encoding='utf-8')
p=r/'scripts/probes/declared-value-layout/bounded-elements-bounded-mutation.slg';s=p.read_text(encoding='utf-8');assert s.count('    values! -> exchange(0, 1)\n')==1;p.write_text(s.replace('    values! -> exchange(0, 1)\n',''),encoding='utf-8')
d=json.loads((b/'bounded13503-contract.json').read_text(encoding='utf-8'))
next(c for c in d['cases'] if c['id']=='bounded-elements-bounded-mutation')['stdout']='7\n9\n1\n3'
(b/'bounded13506-contract.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
print('CSharp finite bounded array type admission and sendability fixed; bounded exchange remains unsupported.')
