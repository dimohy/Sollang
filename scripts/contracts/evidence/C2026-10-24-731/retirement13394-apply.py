from pathlib import Path
import json,sys
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from completed_artifact_plan import close_compiler_consumers,verified_consumer_closure,cleanup_output
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
proof=read(base/'arraylayout13390-source/result.json')
assert proof['status']=='passed' and proof['completed']==proof['total']==23 and proof['inputsStable'] and proof['processesStopped']
old=base/'v13312/compiler-build01'
replacement=base/'v13347/compiler-build01'
proposal=read(base/'retirement13393-audit/proposed-consumer-closure.json')
consumers=[Path(row['path']) for row in proposal['consumers']]
closure=close_compiler_consumers(root,old,consumers,replacement,legacy_terminal=True)
verified_consumer_closure(root,old)
plan=cleanup_output(root,old,execute=True,retention_terminal=True,reusable_directories=[base/'v12432/compiler-build01',replacement])
assert not (old/'compiler.exe').exists()
verified_consumer_closure(root,old,allow_missing_product=True)
record=dict(schemaVersion=1,status='retired-through-canonical-lifecycle',compiler='34AB2672AF54170BB3F586835F20D4AF3E7576B4E1054F9FD797C0D59309A45E',replacement='EB1476A851AA60C02B0C66C1F0746E232AA76A7905FFD45ADCA3399458F649BA',closure=str(closure),cleanupPlan=str(plan),failedWhole405Preserved=True,claimsCompilerAcceptance=False,remainingReusableProducts=['v12432/compiler-build01','v13347/compiler-build01'],reservedNewSlot='v13395/compiler-build01')
(base/'retirement13393-audit/applied.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record),flush=True)
