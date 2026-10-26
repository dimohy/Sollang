from pathlib import Path
import json,hashlib,sys,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
mode=sys.argv[1];assert mode in ['managed111','source111','native100']
native=mode=='native100';sequence={'managed111':16465,'source111':16467,'native100':16466}[mode]
total=100 if native else 111;budget=3600 if native else 20160
contract=b/f'epoch{sequence}-{mode}.json';inner=b/f'epoch{sequence}-{mode}';out=b/f'epoch{sequence}-{mode}-supervised'
focus=b/'epoch16401-native66/result.json';gate=json.loads(focus.read_text(encoding='utf-8-sig'))
assert gate['status']=='passed' and gate['completed']==gate['total']==66 and gate['inputsStable'] and gate['processesStopped']
for p,h in gate['inputHashes'].items():assert sha(p)==h,p
paths=[Path(__file__),contract,focus,*map(Path,gate['inputHashes'])]
if native:paths += [b/'epoch16466-managed100.json',b/'epoch16466-source-comparison.json',b/'v16382/compiler-build01/result.json',b/'v16382/compiler-build01/compiler.exe']
pins={str(p):sha(p) for p in dict.fromkeys(paths)}
out.mkdir(exist_ok=False);result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=total,scope='Current exact unchanged '+mode+' requalification; original case objects, optimization/jobs and 180 second program limits preserved.',aggregateBudgetSeconds=budget,caseBudgetSeconds=180,retryCount=0,innerResult=str(inner/'result.json'),claimsGoalComplete=False)
x=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 command=[sys.executable,str(r/'scripts/verify-c385-preir-call-numeric.py'),'--mode','paired' if native else 'managed','--output',str(inner),'--contract',str(contract),'--managed-compiler',str(b/'managed16362/compiler/Sollang.Compiler.exe'),'--format-compiler',str(b/'v12432/compiler-build01/compiler.exe')]
 if native:command+=['--managed-proof',str(b/'epoch16466-managed100.json'),'--build',str(b/'v16382/compiler-build01'),'--source-comparison',str(b/'epoch16466-source-comparison.json')]
 for name in ['v12432','v16219','v16382']:command+=['--reusable-compiler-directory',str(b/name/'compiler-build01')]
 observed=x.run(command,out/'verification',timeout=budget)
 assert observed.returncode==0,'CURRENT_COHORT_FAILED'
 proof=json.loads((inner/'result.json').read_text(encoding='utf-8-sig'));assert proof['status']=='passed' and proof['completed']==proof['total']==total and proof['inputsStable'] and proof['processesStopped']
 result.update(status='passed',completed=total,innerResultSha256=sha(inner/'result.json'))
except BaseException as failure:error=failure
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if result['status']=='passed' else 1)
