from pathlib import Path
import json,re,hashlib
B=Path('artifacts/scratch/resume-20261006-owner-continuation22')
original=json.loads((B/'readonly17038-reference14.json').read_text());cases=[];alias=None
for c in original['cases']:
 if c['id']=='direct-owner-alias-rejects-payload':alias=c;continue
 if c['id']=='unused-immutable-payload':
  c['id']='diagnostic-unused-growable-payload';c['warnings']=['S003@2'];c['purpose']='Exact documented S003 diagnostic control; not warning-free program acceptance.'
 else:
  lines=c['source'].splitlines();inserted=None
  for index,line in enumerate(lines):
   if '[1, 2; ~] => values' in line:
    owner='values!' if line.rstrip().endswith('values!') else 'values'
    indent=line[:len(line)-len(line.lstrip())]
    lines.insert(index+1,indent+owner+' -> capacity => allocated');inserted=index+2;break
  if inserted:
   c['source']='\n'.join(lines)+'\n'
   c['expected']=[re.sub(r'@([0-9]+)',lambda m:'@'+str(int(m[1])+int(int(m[1])>=inserted)),row) for row in c['expected']]
  c['purpose']='Growable storage is intentional because its capacity is observed; readonly admission decision remains under test.'
 cases.append(c)
p=Path('tests/Sollang.ExampleTests/Fixtures/storage-placement-readonly-controls.json')
p.write_text(json.dumps(dict(schemaVersion=1,scope='source-frames',cases=cases),indent=2)+'\n',encoding='utf-8')
(B/'readonly17039-reference13.json').write_bytes(p.read_bytes())
record=dict(scope='New internal readonly fixture repair; original project sources and oracles unchanged.',baseline=(B/'readonly17038-reference14/source-frame-result.json').as_posix(),authority='docs/SPEC.md S003 at956-974 and owned binding restriction at4226. StoragePlacementAnalyzer decisions are unchanged.',classification=dict(warningFree=12,exactS003Control=1,expectedSemanticRejection=1),changes=['Normal growable cases explicitly observe intrinsic capacity, making growable storage part of the input contract. No warnings suppressed.','Unused growable case is retained as a named exact S003 diagnostic control, excluded from warning-free acceptance.','Unsupported owned alias is preserved byte-for-byte as an expected CLI semantic rejection, before LLVM.'],claimsGoalComplete=False)
(B/'readonly17039-fixture-contract.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
s=(B/'readonly17038-reference14.py').read_text().replace('readonly17038-reference14','readonly17039-reference13').replace('==14','==13')
(B/'readonly17039-reference13.py').write_text(s,encoding='utf-8')
assert alias is not None
probe=Path('scripts/probes/storage-placement/readonly-alias-rejected.slg');probe.parent.mkdir(exist_ok=True);probe.write_bytes(alias['source'].encode('utf-8'))
d=dict(schemaVersion=1,scope='Exact CSharp current-slice owned alias diagnostic; original new control source retained, reject before LLVM.',expectedManagedDllSha256='375D9B7D7448758904AFE49F1F8DDD9136E218EFFCC75A221E63C395B501DDB1',formatCheckSources=[probe.as_posix()],cases=[dict(id='owned-alias-rejected',source=probe.as_posix(),exit=1,stderr="sollang: semantic error at 3:15: [module '<main>'] owned container values must be created directly at their binding site in the current slice",stdout='',requireNoLlvm=True)])
(B/'readonly17039-alias-rejection1.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
