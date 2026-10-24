from pathlib import Path
import json,hashlib,subprocess
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def rel(p):return p.relative_to(r).as_posix()
refs=[('bounded13460-managed','bounded13460-contract.json'),('bounded13473-managed','bounded13473-contract.json'),('bounded13476-managed','bounded13476-contract.json'),('bounded13478-managed','bounded13478-contract.json'),('bounded13488-managed','bounded13488-contract.json')]
expected={};proofs=[]
for folder,name in refs:
 p=b/folder/'result.json';d=read(p);contract=b/name;c=read(contract)
 assert d['status']=='passed' and d['completed']==d['total']==len(c['cases']) and d['inputsStable'] and d['processesStopped']
 assert d['inputHashes'][str(contract)]==sha(contract)
 assert c['expectedManagedDllSha256']==sha(b/'managed13455/compiler/Sollang.Compiler.dll')
 for case in c['cases']:
  source=r/case['source'];assert d['inputHashes'][str(source)]==sha(source);expected[case['id']]=case
 proofs.append(dict(path=rel(p),sha256=sha(p),completed=d['completed'],total=d['total']))
assert len(expected)==35
d=read(b/'bounded13481-contract.json');emitter=b/'bounded13497-emitter.slg'
d.update(scope='Current SLG declared storage/function/index/drop matrix35 against the verified CSharp35. This is focused evidence; async consumers, fresh Native and all final whole gates remain pending.',semanticPreflightProof=rel(b/'bounded13495-semantic/result.json'),stdlibSourcePreflightProof=rel(b/'bounded13496-stdlib/result.json'),formatCheckSources=[rel(emitter)],managedReferenceEvidence=proofs)
d['reusableCheckedProducer'].update(id='c732-bounded-field-index-drop',source=rel(emitter))
group=d['reusableCheckedProducer'];d['cases']=[]
for name,c in expected.items():
 positive=c['exit']==0
 case=dict(id=name,source=rel(emitter),additionalSources=group['additionalSources'],programSource=c['source'],observedSourceOrder=group['stdlibSourceOrder']+[c['source']],runArguments=[c['source']],exit=0,stderr='',stdout=c['stdout'] if positive else c['stderr']+'\nselection-emission-rejected',emittedLlvm=positive,runStderr='')
 if 'expectedAllocations' in c:case['expectedAllocations']=c['expectedAllocations']
 d['cases'].append(case)
contract=b/'bounded13497-contract.json';contract.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
subprocess.run(['python','scripts/generate-selection-result-emitter.py','--program',d['cases'][0]['programSource'],'--emitter',rel(emitter),'--checked','--package-contract',rel(contract),'--load-program-from-file','--runtime-program-argument'],check=True)
print('CSharp35 identities verified; bounded field/index/drop35 producer inputs declared, no runtime success claimed.')
