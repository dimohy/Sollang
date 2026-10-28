from pathlib import Path
import json,hashlib,sys
root=Path.cwd();B=Path('artifacts/scratch/resume-20261006-owner-continuation22');sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
P=B/'oracle17625-proposal';llvm=B/'placement17614-native4/42-fixed-array-placement/probe.exe.ll';out=B/'oracle17629-pinned14';out.mkdir()
inputs=[Path(__file__),llvm,B/'oracle17623-Driver.cs',Path('tests/Sollang.ExampleTests/LlvmAssertions.cs'),*P.glob('*'),*(B/'oracle17623-bin').glob('*')]
pins={str(p):sha(p) for p in inputs if p.is_file()};record=dict(schemaVersion=1,status='running',completed=0,total=14,inputHashes=pins,caseBudgetSeconds=180,proposedFilesApplied=False)
execution=VerificationExecution(root,out,record,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
    run=execution.run(['C:/Program Files/dotnet/dotnet.exe',str((B/'oracle17623-bin/oracle17623.dll').resolve()),str(P.resolve()),str(llvm.resolve()),str((out/'controls').resolve())],'controls',timeout=180)
    (out/'controls.stdout.txt').write_text(run.stdout,encoding='utf-8');(out/'controls.stderr.txt').write_text(run.stderr,encoding='utf-8')
    data=json.loads((out/'controls/result.json').read_text(encoding='utf-8'));record['completed']=data['completed'];assert run.returncode==0 and data['completed']==14 and data['status']=='passed'
    plan=json.loads((P/'proposal.json').read_text(encoding='utf-8'));assert all(sha(p)==h for p,h in plan['preservedOriginalHashes'].items());assert not Path(plan['files'][0]['target']).exists()
    record.update(status='passed',originalsUnchanged=True)
except BaseException as caught:error=caught
finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if error:raise error
