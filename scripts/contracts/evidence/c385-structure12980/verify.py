from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parent
m=json.loads((r/'manifest12987.json').read_text())
for n,h in m.items():assert hashlib.sha256((r/n).read_bytes()).hexdigest().upper()==h,n
for n,c in [('c385-structure12981-pair',2),('ownership12985-pair',4),('c385-structure12986-after',1),('c385-family12984',1)]:
 d=json.loads((r/'records'/n/'result.json').read_text(encoding='utf-8-sig'))
 assert d['status']=='passed' and d['completed']==d['total']==c and d['inputsStable'] and d['processesStopped'],n
b=json.loads((r/'records/c385-family12984/batch/result.json').read_text(encoding='utf-8-sig'))
assert b['typedIr']['sourceSpanChecks']==b['typedIr']['sourceSpanTotal']==28
assert b['typedIr']['sequentialParallelExact'] and len(b['fixtures'])==7
for f in b['fixtures']:
 for k in ['managed','selfhost']:
  t=f[k];assert all(t[x]==0 for x in ['compileExit','warningNoteCount','llvmAsExit','v004Exit','nativeExit'])
  assert t['stdoutExact'] and t['stdoutSha256']==f['expectedSha256']
print('PASS preserved inputs, 28 AST/IR families, 14 exact batch runs, 6 original ownership/stream runs, structural gate; no full-goal claim')
