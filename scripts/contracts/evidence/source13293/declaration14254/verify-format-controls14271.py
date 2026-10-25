"""Replay existing syntax rejection controls through format --stdin."""
from pathlib import Path
import argparse, hashlib, json, sys

ROOT=Path.cwd()
sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output, cleanup_output

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--mode',choices=['managed','native'],required=True)
p.add_argument('--compiler',type=Path,required=True)
p.add_argument('--contract',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--build',type=Path)
p.add_argument('--reusable-directory',type=Path,action='append',default=[])
a=p.parse_args()
compiler=a.compiler.resolve();contract=a.contract.resolve();output=a.output.resolve();data=read(contract)
assert data['schemaVersion']==1 and len(data['cases'])==2 and data['timeoutSeconds']==180
inputs=[compiler,contract,Path(__file__).resolve(),ROOT/'scripts/verification_execution.py',ROOT/'scripts/completed_artifact_plan.py',Path(sys.executable)]
inputs += [ROOT/path for path in data['expectationAuthority']]
if a.mode=='managed': inputs+=managed_runtime_inputs(compiler)
else:
    if a.build is None: p.error('native mode requires --build')
    build=a.build.resolve();record=read(build/'result.json')
    assert compiler==build/'compiler.exe' and sha(compiler)==record['compilerSha256']
    inputs+=[build/'result.json',*current_build_inputs(ROOT,record)]
for case in data['cases']:
    source=(ROOT/case['source']).resolve()
    assert sha(source)==case['sourceSha256'] and case['exit']==1 and case['stdout']==''
    inputs.append(source)
pins={str(path):sha(path) for path in inputs}
initialize_output(ROOT,output,reusable_directories=a.reusable_directory);output.mkdir(exist_ok=False)
result=dict(schemaVersion=1,status='running',scope='Original formatter syntax rejection controls only; no lowering or Stage acceptance.',mode=a.mode,inputHashes=pins,completed=0,total=2,cases=[],claimsGoalComplete=False)
x=VerificationExecution(ROOT,output,result,lambda:all(Path(path).is_file() and sha(path)==value for path,value in pins.items()),sha)
error=None
try:
    stdin_command='import subprocess,sys;from pathlib import Path;sys.exit(subprocess.run([sys.argv[1],"format","--stdin"],input=Path(sys.argv[2]).read_bytes()).returncode)'
    for case in data['cases']:
        actual=x.run([sys.executable,'-c',stdin_command,str(compiler),str((ROOT/case['source']).resolve())],output/case['id'],timeout=data['timeoutSeconds'])
        passed=actual.returncode==case['exit'] and actual.stdout==case['stdout'] and actual.stderr.replace('\r\n','\n')==case['stderr']
        result['cases'].append(dict(id=case['id'],status='passed' if passed else 'failed',passed=passed,exit=actual.returncode,stdout=actual.stdout,stderr=actual.stderr))
        assert passed,case['id']
        result['completed']+=1;x.save()
    result['status']='passed'
except BaseException as caught: error=caught
finally: x.finalize(error,cleanup=False)
if result['status']=='passed':cleanup_output(ROOT,output,execute=True,reusable_directories=a.reusable_directory)
print(json.dumps({key:result.get(key) for key in ['status','completed','total','inputsStable','processesStopped','failure']}))
sys.exit(0 if result['status']=='passed' else 1)
