import json,re,hashlib
from pathlib import Path
from datetime import datetime,timezone
b=Path('artifacts/scratch/resume-20261006-owner-continuation22'); run=b/'ending17405-source4'
contract=json.loads((b/'ending17406-inspection-contract.json').read_text()); runtime=json.loads((run/'result.json').read_text())
observed={c['id']:c for c in runtime['cases']}; rows=[]
for expected in contract['cases']:
 i=expected['id'];case=observed.get(i)
 if not case or not case.get('passed'):continue
 s=(run/i/'run.stdout').read_text(); failures=[]
 slots=[int(x) for x in re.findall(r'%stack_slot\d+ = alloca \[(\d+) x i8\]',s)]
 starts=[int(x) for x in re.findall(r'call void @llvm.lifetime.start.p0\(i64 (\d+)',s)]
 ends=[int(x) for x in re.findall(r'call void @llvm.lifetime.end.p0\(i64 (\d+)',s)]
 for key,actual in [('slots',slots),('startSizes',starts),('endSizes',ends)]:
  if sorted(actual)!=sorted(expected[key]):failures.append('C742_'+key.upper()+'_MISMATCH')
 audit=(run/i/'audit-run.stdout').read_text().strip()
 if not audit.endswith(f"allocations={expected['allocations']},releases={expected['releases']}"):failures.append('C742_ALLOCATION_AUDIT_MISMATCH')
 for body in re.findall(r'^define .*?\{\n(.*?)^\}',s,re.M|re.S):
  terminated=False;live=set()
  for line in body.splitlines():
   if re.match(r'^[-\w.$]+:',line):terminated=False
   hint=re.search(r'call void @llvm.lifetime.(start|end).p0\(i64 (\d+), ptr (%stack_slot\d+)\)',line)
   if hint:
    if terminated:failures.append('C742_HINT_AFTER_TERMINATOR')
    kind,size,slot=hint.groups();key=(slot,size)
    if kind=='start':
     if key in live:failures.append('C742_OVERLAPPING_SLOT_LIFETIME')
     live.add(key)
    else:
     if key not in live:failures.append('C742_END_WITHOUT_START')
     live.discard(key)
   if re.match(r'\s*(ret |br |unreachable\b)',line):terminated=True
 if i=='42-fixed-array-placement':
  end=s.find('call void @llvm.lifetime.end.p0(i64 32,');heap=s.find('call ptr @malloc(i64 4800)')
  if not 0<=end<heap:failures.append('C742_SOURCE_UNIT_END_REORDERED')
 rows.append(dict(id=i,passed=not failures,failureIds=failures,slots=slots,startSizes=starts,endSizes=ends,auditRunStdout=audit,llvmStdoutSha256=hashlib.sha256((run/i/'run.stdout').read_bytes()).hexdigest().upper()))
record=dict(schemaVersion=1,observedUtc=datetime.now(timezone.utc).isoformat(),status='passed' if len(rows)==4 and all(x['passed'] for x in rows) and runtime['status']=='passed' else 'partial',completed=sum(x['passed'] for x in rows),total=4,cases=rows,runtimeResult=(run/'result.json').as_posix(),inspectionContract=(b/'ending17406-inspection-contract.json').as_posix(),inputsStable=runtime.get('inputsStable'),processesStopped=runtime.get('processesStopped'),claimsGoalComplete=False)
destination=b/f"ending17409-inspection{len(rows)}.json";assert not destination.exists();destination.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:record[k] for k in ['status','completed','total']}));print([(r['id'],r['failureIds']) for r in rows])
