import json,sys,hashlib
from pathlib import Path
root=Path.cwd();b=Path('artifacts/scratch/resume-20261006-owner-continuation22');sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
approval=json.loads((b/'s00317368-approval-applied.json').read_text()); compiler=b/'managed17069/compiler/Sollang.Compiler.dll';harness=b/'candidates17000-reference19/bin/Sollang.ExampleTests.dll'
assert sha(compiler)=='672CD039C491A57E7C26472FEEFB886552DF2A6560DCDC0673467DA7B7B82B98'
assert sha(harness)=='F1931069A05DAF171F033B498C85300FBF3F00934B63B818FAD9DBD2730B8800'
inputs=approval['preservedHashes']|{r['path']:r['sha256'] for r in approval['files']}|{str(compiler):sha(compiler),str(harness):sha(harness)}
stable=lambda:all(sha(p)==h for p,h in inputs.items());assert stable()
out=b/'s00317369-original3';out.mkdir();record=dict(schemaVersion=1,status='running',inputHashes=inputs,completed=0,total=3,caseBudgetSeconds=180,approval=(b/'s00317368-approval-applied.json').as_posix())
execution=VerificationExecution(root,out,record,stable,sha)
command=['dotnet',str(harness.resolve()),'--suite','reference','--skip-bootstrap','--compiler',str(compiler.resolve()),'--output-directory',str((out/'strict').resolve()),'--jobs','1']
for row in json.loads((b/'s00317325-proposal/proposal.json').read_text())['files']:command+=['--exact',Path(row['source']).stem]
result=execution.run(command,'strict-originals',timeout=180)
inner=json.loads((out/'strict/result.json').read_text());record.update(status='passed' if result.returncode==0 else 'failed',exit=result.returncode,completed=inner.get('completed',0),strictResult=(out/'strict/result.json').as_posix(),preservedInputsUnchanged=stable())
execution.finalize(cleanup=False);print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}));assert result.returncode==0
