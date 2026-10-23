from pathlib import Path
import json
r=Path(__file__).resolve().parent
def read(n):return json.loads((r/n).read_text(encoding='utf-8-sig'))
a=read('records/c385-family13006/result.json');assert a['status']=='passed' and a['inputsStable'] and a['processesStopped']
b=read('records/c385-family13006/batch/result.json');assert b['typedIr']['sourceSpanChecks']==28 and b['typedIr']['sequentialParallelExact'] and len(b['fixtures'])==7
for f in b['fixtures']:
 for k in ['managed','selfhost']:
  v=f[k];assert all(v[x]==0 for x in ['compileExit','warningNoteCount','llvmAsExit','v004Exit','nativeExit']) and v['stdoutExact'] and v['stdoutSha256']==f['expectedSha256']
for n in ['records/c385-remaining12989/managed-results/managed-results-batch-results.json','records/c385-remaining13005/native-results/native-results-batch-results.json']:
 d=read(n);assert d['state']=='passed' and d['passed']==d['completed']==d['total']==12 and d['failed']==d['missing']==0
c=read('records/c385-coverage13008/coverage/result.json');assert c['status']=='passed' and c['inputStable'] and c['completed']==c['total']==14
f1=set(x['family'] for x in c['cases']);contract=read('c385-remaining13005-plan.json');assert f1==set(x['family'] for x in contract['cases'])
print('PASS C385 original28+14 representative families and CSharp19/current-native19 exact executions; no full-goal closure')
