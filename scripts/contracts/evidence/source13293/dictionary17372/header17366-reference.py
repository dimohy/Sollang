import json,hashlib,sys
from pathlib import Path
from datetime import datetime,timezone
root=Path.cwd();b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler=b/'managed17069/compiler/Sollang.Compiler.dll'; harness=b/'candidates17000-reference19/bin/Sollang.ExampleTests.dll'
assert sha(compiler)=='672CD039C491A57E7C26472FEEFB886552DF2A6560DCDC0673467DA7B7B82B98'
assert sha(harness)=='F1931069A05DAF171F033B498C85300FBF3F00934B63B818FAD9DBD2730B8800'
fixture=b/'header17366-reference3.json';out=b/'header17366-reference3';assert not out.exists();out.mkdir()
cases=[]
for name in ['array','dictionary','return']:
 expected=['main|slots:24/8','main|alloc:BindingStatement@2,0,24']
 if name=='return':expected=['main|slots:','function:makeValues@1|slots:24/8','function:makeValues@1|alloc:BindingStatement@2,0,24']
 cases.append(dict(id='header-'+name,source=(b/f'header17361-{name}.slg').read_text(),warnings=['S003@2'] if name=='array' else [],expected=expected))
fixture.write_text(json.dumps(dict(schemaVersion=1,scope='source-frames',cases=cases),indent=2)+'\n')
inputs={str(p):sha(p) for p in [fixture,compiler,harness]}
stable=lambda:all(sha(p)==h for p,h in inputs.items())
record=dict(schemaVersion=1,status='running',inputHashes=inputs,startedUtc=datetime.now(timezone.utc).isoformat(),completed=0,total=3)
execution=VerificationExecution(root,out,record,stable,sha)
result=execution.run(['dotnet',str(harness.resolve()),'--storage-placement-reference',str(compiler.resolve()),str(fixture.resolve()),str((out/'source-frame-result.json').resolve())],'reference',timeout=180)
data=json.loads((out/'source-frame-result.json').read_text())
record.update(status='passed' if result.returncode==0 else 'failed',exit=result.returncode,completed=sum(c['passed'] for c in data['cases']),inputsStable=stable(),processesStopped=all(p['shutdownConfirmed'] for p in record['processes']),observedUtc=datetime.now(timezone.utc).isoformat())
execution.save();print(json.dumps({k:record[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
assert result.returncode==0
