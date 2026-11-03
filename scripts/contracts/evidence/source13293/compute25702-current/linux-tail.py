from pathlib import Path
import sys,json,hashlib,datetime,re,math
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();old=b/'compute25685-linux-native';birth=b/'compute25690-native/result.json';contract=b/'compute25684-contract.json';cases=read(contract)['cases'];active=next(v for v in cases if v['id']=='active');empty=next(v for v in cases if v['id']=='empty');config=r/'scripts/contracts/verification-compiler-build.json';cfg=read(config)['nativeLinux'];llvm=old/'active/probe.exe.ll';emit=old/'active/probe.exe.compiler-emit-checked.execution.json';ed=read(emit);build=old/'active/probe.exe.compiler-build.json';bd=read(build)
assert ed['status']=='passed' and ed['exit']==0 and ed['processesStopped'];assert bd['failure']=='VERIFICATION_LINUX_EMISSION_DIAGNOSTIC' and bd['inputsStable'] and bd['processesStopped'];assert Path(ed['stderrPath']).read_text(encoding='utf-8-sig').strip()==active['stderr'];assert llvm.read_bytes()==Path(ed['stdoutPath']).read_bytes();assert re.search(r'^target triple = "'+re.escape(cfg['targetTriple'])+'"$',llvm.read_text(),re.M)
# The generic zero-diagnostic builder stopped before linking. Reuse this checked emission with an exact warning oracle; preserve its failed parent record.
emptyContract=b/'compute25699-empty-contract.json';d=read(contract);d['cases']=[empty];d['formatCheckSources']=[empty['source']];emptyContract.write_text(json.dumps(d,indent=2)+'\n')
o=b/'compute25701-linux-tail-native';reuse=[b/'platform25669-native',b/'compute25690-native',b/'v20050/compiler-build01'];initialize_output(r,o,reusable_directories=reuse);o.mkdir();(o/'active').mkdir();(o/'empty').mkdir()
paths=[Path(__file__),b/'compute25701-active.ps1',old/'result.json',build,emit,Path(ed['stdoutPath']),Path(ed['stderrPath']),llvm,birth,*current_build_inputs(r,read(birth)),contract,emptyContract,config,b/'compute25685-linux.ps1',*[Path(p) for p in bd['inputHashes']]];pins={str(p.resolve()):sha(p) for p in paths};v=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='Resume only active/empty Linux controls. Reuse exact checked LLVM with original S003 warning, fixed clang identity/version/target, original compilation budget less already-spent emission time and original10s execution limit. Generic zero-diagnostic builder failure retained, not rewritten.',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);err=None
try:
 q=x.run(['pwsh','-NoProfile','-File',str(b/'compute25701-active.ps1'),'-Output',str(o)],o/'active-link-run',timeout=190);assert q.returncode==0 and not q.stderr and 'Compute active existing checked LLVM: PASS' in q.stdout,(q.stdout,q.stderr)
 v['cases'].append(dict(id='active',passed=True,checkedEmissionRecord=str(emit),originalWarning=active['stderr']));v['completed']+=1
 q=x.run(['pwsh','-NoProfile','-File',str(b/'compute25685-linux.ps1'),'-Compiler',str(b/'compute25690-native/compiler.exe'),'-Output',str(o/'empty'),'-Contract',str(emptyContract)],o/'empty-run',timeout=220);assert q.returncode==0 and not q.stderr and 'Compute Linux empty: PASS' in q.stdout,(q.stdout,q.stderr);v['cases'].append(dict(id='empty',passed=True));v['completed']+=1;v['status']='passed'
except BaseException as ex:err=ex
finally:x.finalize(err,cleanup=False)
if err:raise err
print(json.dumps({k:v[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
