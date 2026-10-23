from pathlib import Path
import json,sys
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from completed_artifact_plan import close_compiler_consumers,verified_consumer_closure,cleanup_output
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
proof=read(base/'grouped13306-source/result.json')
assert proof['status']=='passed' and proof['completed']==proof['total']==10 and proof['inputsStable'] and proof['processesStopped']
old=base/'v13220/compiler-build01'
replacement=base/'v13262/compiler-build01'
proposal=read(base/'retirement13310-audit/proposed-consumer-closure.json')
consumers=[Path(row['path']) for row in proposal['consumers']]
closure=close_compiler_consumers(root,old,consumers,replacement,legacy_terminal=True)
verified_consumer_closure(root,old)
plan=cleanup_output(root,old,execute=True,retention_terminal=True,reusable_directories=[base/'v12432/compiler-build01',replacement])
assert not (old/'compiler.exe').exists()
verified_consumer_closure(root,old,allow_missing_product=True)
record=dict(schemaVersion=1,status='retired-through-canonical-lifecycle',compiler='99F45F979992ADFB2E68954731049DB7A6019B5A1F50FFE8A66679EC2D30A61A',replacement='F847EA01E66FFB7BD9A9E497F89C87E64C93CA3B87B3D4D6265A9A0C3D3DF693',closure=str(closure),cleanupPlan=str(plan),failedWhole405Preserved=True,claimsCompilerAcceptance=False,remainingReusableProducts=['v12432/compiler-build01','v13262/compiler-build01'],reservedNewSlot='v13312/compiler-build01')
(base/'retirement13310-audit/applied.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record),flush=True)
