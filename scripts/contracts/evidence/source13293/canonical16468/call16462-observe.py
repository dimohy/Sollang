from pathlib import Path
import json,hashlib,sys,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
prior=json.loads((b/'call16460-ast-observation/result.json').read_text(encoding='utf-8-sig'))
assert prior['inputsStable'] and prior['processesStopped']
out=b/'call16462-observation';out.mkdir(exist_ok=False)
command=list(prior['processes'][-1]['command']);assert command[1]=='build'
command[2]=str(b/'call16462-ast-ownership.slg');command[command.index('-o')+1]=str(out/'probe.exe')
paths=[Path(p) for p in prior['inputHashes'] if p!=str(b/'call16460-ast-observation.slg')]+[Path(__file__),b/'call16462-ast-ownership.slg']
pins={str(p):sha(p) for p in dict.fromkeys(paths)}
result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,scope='AST-only logical-flow ownership observation. Prior simple-flow AST proved target Path is direct; this execution distinguishes logical-flow target parentage. No original acceptance credit.',aggregateBudgetSeconds=180,maximumBuilds=1,maximumExecutions=1,fullRuntimeCaseCredit=0,claimsGoalComplete=False)
x=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None;started=time.monotonic()
try:
 built=x.run(command,out/'build',timeout=180)
 assert built.returncode==0 and not built.stderr.strip(),built.stderr
 observed=x.run([str(out/'probe.exe')],out/'observe',timeout=min(30,180-(time.monotonic()-started)))
 assert observed.returncode==0 and not observed.stderr.strip() and observed.stdout.startswith('node=')
 result.update(status='passed',completed=1,observation=observed.stdout)
except BaseException as failure:error=failure
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','failure','inputsStable','processesStopped','observation']}));sys.exit(0 if result['status']=='passed' else 1)
