from pathlib import Path
import json,hashlib,sys
r=Path(__file__).resolve().parent
def read(n):return json.loads((r/n).read_text(encoding='utf-8-sig'))
for n,h in read('focused-inputs13007.json')['archiveHashes'].items():assert hashlib.sha256((r/n).read_bytes()).hexdigest().upper()==h,n
mode=sys.argv[1] if len(sys.argv)>1 else 'candidate'
if mode=='baseline':
 d=read('records/c385-remaining12989/native-results/native-results-batch-results.json')
 assert d['state']=='failed' and d['passed']==11 and d['total']==12
 rows=[x for x in d['results'] if x['Fixture']=='797-partition-first-match-direct-dispatch']
 assert len(rows)==1 and not rows[0]['Success'] and 'expected instruction opcode' in rows[0]['Error']
 d=read('records/partition12991-source/result.json');assert d['status']=='failed' and d['inputsStable'] and d['processesStopped'] and 'ASSEMBLY_FAILED' in d['failure']
 print('PASS baseline reproduced in original native and current SLG source LLVM; this verifies recorded failures, not a new compiler execution')
else:
 for n in ['partition12996-managed','partition12997-source','partition12998-runtime','partition13004-native']:
  d=read('records/'+n+'/result.json');assert d['status']=='passed' and d['completed']==d['total']==4 and d['inputsStable'] and d['processesStopped'],n
 d=read('records/v13003/compiler-build01/result.json');assert d['status']=='passed' and d['inputsStable'] and all(v==0 for v in d['steps'].values())
 key=next(k for k in d['inputHashesStart'] if k.endswith('function_scheduling.slg'));assert d['inputHashesStart'][key]==hashlib.sha256((r/'function_scheduling.tested.slg.txt').read_bytes()).hexdigest().upper()
 print('PASS CSharp4/source4/fresh native4 with source runtime4 included once; canonical compiler5 checks; recorded evidence replay, no whole-goal claim')
