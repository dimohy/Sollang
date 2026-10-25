from pathlib import Path
import json,hashlib
R=Path.cwd(); B=R/'artifacts/scratch/resume-20261006-owner-continuation22'; E=R/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
for name,n in [('call14237-semantic',4),('call14238-stdlib',1)]:
    d=load(B/name/'result.json');assert d['status']=='passed' and d['completed']==d['total']==n and d['inputsStable'] and d['processesStopped']
for old,new in [('call14080-contract.json','recovery14240-golden.json'),('typed14083-contract.json','recovery14240-source6.json'),('typed14085-contract.json','recovery14240-source94.json'),('exchange14087-contract.json','recovery14240-exchange1.json'),('result14081-contract.json','recovery14240-result12.json')]:
    src=load(B/old); d=load(B/old)
    d['semanticPreflightProof']=(B/'call14237-semantic/result.json').relative_to(R).as_posix()
    d['stdlibSourcePreflightProof']=(B/'call14238-stdlib/result.json').relative_to(R).as_posix()
    assert d['cases']==src['cases']
    assert {k:v for k,v in d.items() if k not in ['semanticPreflightProof','stdlibSourcePreflightProof']}=={k:v for k,v in src.items() if k not in ['semanticPreflightProof','stdlibSourcePreflightProof']}
    path=B/new;path.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8');(E/new).write_bytes(path.read_bytes())
print('Five contracts copied; only two prerequisite paths changed. All cases, sources, order, expectations and budgets unchanged.')
