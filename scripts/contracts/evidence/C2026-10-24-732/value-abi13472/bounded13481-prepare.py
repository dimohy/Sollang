from pathlib import Path
import json,hashlib,subprocess
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def rel(p):return str(p.relative_to(r)).replace('\\','/')
references=[('bounded13460-managed','bounded13460-contract.json'),('bounded13473-managed','bounded13473-contract.json'),('bounded13476-managed','bounded13476-contract.json'),('bounded13478-managed','bounded13478-contract.json')]
expected={};proofs=[]
for folder,name in references:
 proof=b/folder/'result.json';d=read(proof);contract=b/name;c=read(contract)
 assert d['status']=='passed' and d['completed']==d['total']==len(c['cases']) and d['inputsStable'] and d['processesStopped']
 assert d['inputHashes'][str(contract)]==sha(contract)
 assert c['expectedManagedDllSha256']==sha(b/'managed13455/compiler/Sollang.Compiler.dll')
 for case in c['cases']:
  source=r/case['source'];assert d['inputHashes'][str(source)]==sha(source),case['id'];expected[case['id']]=case
 proofs.append(dict(path=rel(proof),sha256=sha(proof),completed=d['completed'],total=d['total']))
assert len(expected)==32
d=read(b/'declaredlayout13439-contract.json');emitter=b/'bounded13481-emitter.slg';d['expectedManagedDllSha256']=sha(b/'managed13455/compiler/Sollang.Compiler.dll');d['scope']='Current actual SLG function value ABI6: inline returns, forwarding, readonly input/return, primary/additional value inputs, copy isolation, early return and live mutable-to-readonly borrow. Full field/index/drop and async ABI remain pending; no whole/final acceptance.'
d['semanticPreflightProof']=rel(b/'bounded13482-semantic/result.json');d['stdlibSourcePreflightProof']=rel(b/'bounded13483-stdlib/result.json');d['formatCheckSources']=[rel(emitter)];d['managedReferenceEvidence']=proofs
d['reusableCheckedProducer'].update(id='c732-bounded-function-value-abi',source=rel(emitter))
names=['bounded-return-value','bounded-return-forward','bounded-readonly-reference','bounded-value-arguments','bounded-control-return','bounded-reference-return'];group=d['reusableCheckedProducer'];d['cases']=[]
for name in names:
 c=expected[name];assert c['exit']==0 and c['stderr']==''
 d['cases'].append(dict(id=name,source=rel(emitter),additionalSources=group['additionalSources'],programSource=c['source'],observedSourceOrder=group['stdlibSourceOrder']+[c['source']],runArguments=[c['source']],exit=0,stderr='',stdout=c['stdout'],emittedLlvm=True,runStderr=''))
contract=b/'bounded13481-contract.json';contract.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
subprocess.run(['python','scripts/generate-selection-result-emitter.py','--program',d['cases'][0]['programSource'],'--emitter',rel(emitter),'--checked','--package-contract',rel(contract),'--load-program-from-file','--runtime-program-argument'],check=True)
print('Current CSharp32 identities checked; source function ABI6 contract and one checked producer prepared. No producer build yet.')
