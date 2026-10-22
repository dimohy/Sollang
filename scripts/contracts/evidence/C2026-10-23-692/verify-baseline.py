from pathlib import Path
import json, hashlib
root=Path(__file__).resolve().parents[4]
folder=Path(__file__).resolve().parent
data=json.loads((folder/'baseline-contract12486.json').read_text(encoding='utf-8-sig'))
assert data['completed']==data['total']==3
for case in data['cases']:
    assert case['exit']==0 and not case['stderr']
    path=root/'scripts/probes/parallel-source-text-contract'/(case['id']+'.slg')
    assert hashlib.sha256(path.read_bytes()).hexdigest().upper()==case['sourceSha256']
    record=json.loads((folder/(case['id']+'.exe.compiler-build.json')).read_text(encoding='utf-8-sig'))
    assert record['status']=='passed' and record['inputsStable'] and record['processesStopped']
print('Actual CSharp accepts both SPEC-rejected plain and nested SourceText callback results; direct Result payload control also builds. Compile-only evidence; no program runtime claim.')
