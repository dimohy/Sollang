from pathlib import Path
import json,hashlib,subprocess
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def rel(p):return p.relative_to(r).as_posix()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
proof=b/'bounded13521-managed/result.json';p=read(proof);c=read(b/'bounded13520-contract.json')
assert p['status']=='passed' and p['completed']==p['total']==44 and p['inputsStable'] and p['processesStopped']
assert p['inputHashes'][str(b/'bounded13520-contract.json')]==sha(b/'bounded13520-contract.json')
expected={x['id']:x for x in c['cases']};d=read(b/'bounded13497-contract.json');emitter=b/'bounded13527-emitter.slg'
d.update(scope='Current actual SLG field-context5: recursively contextual empty bounded elements in dynamic/bounded/fixed fields, projected bounded field mutation and indexed copy isolation. Full current44 and interpolation/capture consumers remain pending; no Native image or final acceptance.',expectedManagedDllSha256=c['expectedManagedDllSha256'],semanticPreflightProof=rel(b/'bounded13525-semantic/result.json'),stdlibSourcePreflightProof=rel(b/'bounded13526-stdlib/result.json'),formatCheckSources=[rel(emitter)],managedReferenceEvidence=[dict(path=rel(proof),sha256=sha(proof),completed=44,total=44)])
d['reusableCheckedProducer'].update(id='c732-bounded-field-context-five',source=rel(emitter));group=d['reusableCheckedProducer'];d['cases']=[]
for name in ['growable-bounded-elements-runtime','bounded-bounded-elements-runtime','fixed-bounded-elements-runtime','bounded-field-mut-argument','bounded-index-copy-isolation']:
 case=expected[name];assert case['exit']==0 and case['stderr']=='' and p['inputHashes'][str(r/case['source'])]==sha(r/case['source'])
 d['cases'].append(dict(id=name,source=rel(emitter),additionalSources=group['additionalSources'],programSource=case['source'],observedSourceOrder=group['stdlibSourceOrder']+[case['source']],runArguments=[case['source']],exit=0,stderr='',stdout=case['stdout'],emittedLlvm=True,runStderr=''))
contract=b/'bounded13527-contract.json';contract.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
subprocess.run(['python','scripts/generate-selection-result-emitter.py','--program',d['cases'][0]['programSource'],'--emitter',rel(emitter),'--checked','--package-contract',rel(contract),'--load-program-from-file','--runtime-program-argument'],check=True)
print('Current CSharp44 and exact source identities verified; field-context5 prepared with one producer and unchanged build/case180s limits, no retry.')
