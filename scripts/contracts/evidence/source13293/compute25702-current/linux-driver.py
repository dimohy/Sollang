from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output
side=sys.argv[1];assert side in ['managed','native'];c=b/('compute25682-managed/compiler/Sollang.Compiler.exe' if side=='managed' else 'compute25690-native/compiler.exe');o=b/('compute25685-linux-'+side);reuse=[b/'platform25669-native',b/'v20050/compiler-build01'];
if side=='native':reuse.append(b/'compute25690-native')
initialize_output(r,o,reusable_directories=reuse);o.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();contract=b/'compute25684-contract.json';cases=json.loads(contract.read_text())['cases'];paths=[Path(__file__),b/'compute25685-linux.ps1',contract,c,*managed_runtime_inputs(b/'compute25682-managed/compiler/Sollang.Compiler.exe'),r/'scripts/verification-process.ps1',r/'scripts/verification-compiler-build.ps1',r/'scripts/contracts/verification-compiler-build.json',*[r/x['source'] for x in cases],*sorted((r/'stdlib').rglob('*.slg'))]
if side=='native':paths.extend([b/'compute25690-native/result.json',*current_build_inputs(r,json.loads((b/'compute25690-native/result.json').read_text()))])
pins={str(p.resolve()):sha(p) for p in paths};v=dict(schemaVersion=1,status='running',completed=0,total=len(cases),inputHashes=pins,cases=[],scope='Actual Linux compute pool executions through canonical build and supervised WSL captures; original source, output and diagnostics fixed.',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);err=None
try:
 d=x.run(['pwsh','-NoProfile','-File',str(b/'compute25685-linux.ps1'),'-Compiler',str(c),'-Output',str(o),'-Contract',str(contract)],o/'linux',timeout=1000);assert d.returncode==0 and not d.stderr,(d.stdout,d.stderr)
 for case in cases:assert ('Compute Linux '+case['id']+': PASS') in d.stdout;v['cases'].append(dict(id=case['id'],passed=True));v['completed']+=1
 v['status']='passed'
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
if err:raise err
print(json.dumps({k:v[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
