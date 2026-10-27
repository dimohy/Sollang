from pathlib import Path
import json,sys,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'));from completed_artifact_plan import consumer_closure_record
selected=json.loads((b/'retire16700-selected.json').read_text(encoding='utf-8-sig'))['consumers'];excluded=[];consumers=[]
for r in selected:
 p=Path(r['path'])
 if 'interpolation16429-replay-controls' in p.parts:excluded.append(dict(path=str(p),reason='Intentional mutated record copy, not a compiler execution; restart16770 explicitly identifies fixture boundary'));continue
 if p==b/'catalog16664-missing-modules-native3/52-multi-file-modules/result.json':
  parent=b/'catalog16664-missing-modules-native3/result.json';coverage=json.loads((b/'retire16703-coverage.json').read_text(encoding='utf-8-sig'))
  assert hashlib.sha256(p.read_bytes()).hexdigest()==coverage['childSha256'] and hashlib.sha256(parent.read_bytes()).hexdigest()==coverage['parentSha256']
  assert any(Path(row['path'])==parent for row in selected)
  excluded.append(dict(path=str(p),reason='Existing exact outer owned-job containment proof retire16703-coverage.json; enclosing supervisor included',parent=str(parent)));continue
 consumers.append(p)
out=b/'retire16785-review';out.mkdir(exist_ok=False)
def trace(frame,event,arg):
 if event=='exception' and frame.f_code.co_name=='consumer_closure_record':print('blocked',frame.f_locals.get('path'),str(arg[1]),flush=True)
 return trace
sys.settrace(trace)
try:
 result=consumer_closure_record(root,b/'v16382/compiler-build01',consumers,b/'v16730/compiler-build01',legacy_terminal=True)
 (out/'proposed-closure.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');status='qualified-not-closed'
except ValueError as e:status=str(e)
finally:sys.settrace(None)
(out/'selection.json').write_text(json.dumps(dict(status=status,consumerCount=len(consumers),consumers=list(map(str,consumers)),excluded=excluded,existingGuardsChanged=False,originalResultsChanged=False),indent=2)+'\n',encoding='utf-8');print(status,len(consumers))
