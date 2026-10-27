import json,re,hashlib
from pathlib import Path
from datetime import datetime,timezone
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');run=b/'header17383-source6'
runtime=json.loads((run/'result.json').read_text());contract=json.loads((b/'header17384-inspection-contract.json').read_text());observed={x['id']:x for x in runtime['cases']};rows=[]
for expected in contract['cases']:
 i=expected['id'];case=observed.get(i)
 if not case or not case.get('passed'):continue
 raw=(run/i/'run.stdout').read_bytes();s=raw.decode();failures=[]
 values=dict(slots=[int(x) for x in re.findall(r'%stack_slot\d+ = alloca \[(\d+) x i8\]',s)],startSizes=[int(x) for x in re.findall(r'call void @llvm.lifetime.start.p0\(i64 (\d+)',s)],endSizes=[int(x) for x in re.findall(r'call void @llvm.lifetime.end.p0\(i64 (\d+)',s)])
 for key,actual in values.items():
  if sorted(actual)!=sorted(expected[key]):failures.append('C742_'+key.upper()+'_MISMATCH')
 audit=(run/i/'audit-run.stdout').read_text().strip()
 if not audit.endswith(f"allocations={expected['allocations']},releases={expected['releases']}"):failures.append('C742_ALLOCATION_AUDIT_MISMATCH')
 checkedPaths=0
 for body in re.findall(r'^define .*?\{\n(.*?)^\}',s,re.M|re.S):
  if '%stack_slot' not in body:continue
  aliases=dict(re.findall(r'(%slot\d+) = getelementptr i8, ptr (%stack_slot\d+), i64 0',body))
  blocks={};name='_entry';blocks[name]=[]
  for line in body.splitlines():
   label=re.match(r'^([-\w.$]+):',line)
   if label:name=label.group(1);blocks[name]=[]
   else:blocks[name].append(line)
  names=list(blocks)
  if not blocks['_entry'] and len(names)>1:entry=names[1]
  else:entry='_entry'
  pending=[(entry,frozenset())];visited=set()
  while pending:
   name,initial=pending.pop();key=(name,initial)
   if key in visited:continue
   visited.add(key);live=set(initial);terminated=False;successors=[]
   for line in blocks[name]:
    hint=re.search(r'call void @llvm.lifetime.(start|end).p0\(i64 (\d+), ptr (%stack_slot\d+)\)',line)
    if hint:
     if terminated:failures.append('C742_HINT_AFTER_TERMINATOR')
     kind,size,slot=hint.groups();allocation=(slot,int(size))
     if kind=='start':
      if allocation in live:failures.append('C742_OVERLAPPING_SLOT_LIFETIME')
      live.add(allocation)
     else:
      if allocation not in live:failures.append('C742_END_WITHOUT_START_ON_PATH')
      live.discard(allocation)
    if re.match(r'\s*(load |store |%[-\w.$]+ = load )',line):
     for pointer in re.findall(r'ptr (%slot\d+)\b',line):
      if pointer in aliases and (aliases[pointer],24) not in live:failures.append('C742_HEADER_ACCESS_OUTSIDE_LIFETIME')
    if re.match(r'\s*ret\b',line):
     checkedPaths+=1
     if any(size==24 for _,size in live):failures.append('C742_HEADER_LIVE_AT_RETURN')
    if re.match(r'\s*(ret |br |switch |unreachable\b)',line):
     terminated=True;successors+=re.findall(r'label %([-\w.$]+)',line)
   if not terminated:
    index=names.index(name)
    if index+1<len(names):successors.append(names[index+1])
   for target in successors:
    if target not in blocks:failures.append('C742_CFG_TARGET_MISSING')
    else:pending.append((target,frozenset(live)))
 rows.append(dict(id=i,passed=not failures,failureIds=sorted(set(failures)),**values,auditRunStdout=audit,llvmStdoutSha256=hashlib.sha256(raw).hexdigest().upper(),checkedReturnPaths=checkedPaths))
record=dict(schemaVersion=1,observedUtc=datetime.now(timezone.utc).isoformat(),status='passed' if len(rows)==6 and all(x['passed'] for x in rows) and runtime['status']=='passed' else 'partial',completed=sum(x['passed'] for x in rows),total=6,cases=rows,runtimeResult=(run/'result.json').as_posix(),inspectionContract=(b/'header17384-inspection-contract.json').as_posix(),inputsStable=runtime.get('inputsStable'),processesStopped=runtime.get('processesStopped'),claimsGoalComplete=False)
destination=b/f"header17386-inspection{len(rows)}.json";assert not destination.exists();destination.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({k:record[k] for k in ['status','completed','total']}));print([(r['id'],r['failureIds']) for r in rows])
