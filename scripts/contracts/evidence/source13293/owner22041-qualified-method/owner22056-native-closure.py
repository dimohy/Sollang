from pathlib import Path
import sys,json,hashlib
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'owner22056-native-closure';producer=B/'owner22048-source-emitter/result.json';p=json.loads(producer.read_text(encoding='utf-8-sig'));assert p['status']=='passed' and p['inputsStable'] and p['processesStopped'];inputs0=[B/n/'P1.ll' for n in ['owner22049-native-original','owner22050-native-controls']];script=ROOT/'scripts/verify-llvm-direct-call-closure.ps1';sha=lambda x:hashlib.sha256(Path(x).read_bytes()).hexdigest().upper();paths=[Path(__file__),producer,*map(Path,p['inputHashes']),script,*inputs0];assert all(sha(x)==h for x,h in p['inputHashes'].items());inputs={str(x.resolve()):sha(x) for x in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(paths):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,scope='V004 on original and explicit-qualified noncopyable inherent block runtime LLVM.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(x)==h for x,h in inputs.items()),sha);err=None
 try:
  for index,ll in enumerate(inputs0):
   done=ex.run(['pwsh','-NoProfile','-File',str(script),'-LlvmPath',str(ll)],OUT/str(index),timeout=60);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;result['cases'].append(dict(id=str(ll),passed=True));result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
