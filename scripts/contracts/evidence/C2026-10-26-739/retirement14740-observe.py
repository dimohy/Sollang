from pathlib import Path
import json,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from completed_artifact_plan import consumer_closure_record
B=root/'artifacts/scratch/resume-20261006-owner-continuation22'
consumers=[B/p/'result.json' for p in ['call14449-native-golden','call14451-native3','context14463-native-diagnostic','dictionary14455-native4','dictionary14430-native-geometry']]
proposal=consumer_closure_record(root,B/'v14390/compiler-build01',consumers,B/'v14562/compiler-build01',legacy_terminal=True)
p=root/'scripts/contracts/evidence/C2026-10-26-739/retirement14740-proposal.json'
p.write_text(json.dumps(proposal,indent=2)+'\n',encoding='utf-8')
print('Read-only canonical closure accepted for5 top-level consumers. No deletion or retirement executed.')
