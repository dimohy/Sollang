from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
out=b/'no-llvm13378-contract-validation';out.mkdir(exist_ok=False);negative=json.loads((b/'substitution13375-guards-contract.json').read_text());positive=json.loads((b/'substitution13368-contract.json').read_text());cases=[]
for id,base,value,error in [('non-boolean',negative,'true','NO_LLVM_EXPECTATION_INVALID'),('successful-case',positive,True,'NO_LLVM_REQUIRES_DIRECT_SEMANTIC_REJECTION')]:
 base['cases']=base['cases'][:1];base['cases'][0]['requireNoLlvm']=value;p=out/(id+'-contract.json');p.write_text(json.dumps(base,indent=2)+'\n');cases.append((id,p,error))
pins={str(p):sha(p) for p in [r/'scripts/verify-c385-preir-call-numeric.py',Path(__file__),*[p for _,p,_ in cases]]};d=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='Actual CLI fail-fast validation of no-LLVM contract; not compiler language or goal acceptance.')
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);err=None
try:
 for id,contract,error in cases:
  target=out/(id+'-should-not-exist');p=x.run([sys.executable,str(r/'scripts/verify-c385-preir-call-numeric.py'),'--mode','managed','--contract',str(contract),'--output',str(target),'--managed-compiler',str(b/'managed13239/compiler/Sollang.Compiler.exe')],out/id,timeout=30);assert p.returncode==1 and error in p.stderr and not target.exists();d['cases'].append(dict(id=id,status='passed',expectedFailureId=error,actualExit=p.returncode,outputNotCreated=True));d['completed']+=1
 d['status']='passed'
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if d['status']=='passed' else 1)
