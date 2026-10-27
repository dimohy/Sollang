from pathlib import Path
import sys,json,hashlib,time
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_source_proof import current_build_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();planpath=b/'duplicate16750-reference10.json';plan=json.loads(planpath.read_text(encoding='utf-8-sig'));compiler=b/'v16808/compiler-build01/compiler.exe';buildpath=compiler.parent/'result.json';build=json.loads(buildpath.read_text(encoding='utf-8-sig'));assert sha(compiler)==build['compilerSha256']=='7C94937B2AD1F7FBA41B5C254C635EB7B18E84782ABF17DA86D102211F8C193E';buildinputs=current_build_inputs(root,build);referencepath=b/'duplicate16751-reference10/result.json';reference=json.loads(referencepath.read_text(encoding='utf-8-sig'));assert reference['status']=='passed' and reference['completed']==reference['total']==10 and reference['inputsStable'] and reference['processesStopped'];references={c['id']:c for c in reference['cases']}
for p,h in reference['inputHashes'].items():assert sha(p)==h.upper(),p
inputs=[Path(__file__),planpath,compiler,buildpath,*buildinputs,referencepath,*map(Path,reference['inputHashes']),*[root/p for case in plan['cases'] for p in case['sources']],*root.glob('stdlib/**/*.slg'),root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py'];inputs=list(dict.fromkeys(inputs));out=b/'declaration16809-native10';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=len(plan['cases']),inputHashes=pins,cases=[],scope='Fresh canonical Native declaration diagnostics against unchanged exact CSharp10 references. Includes original cross-module duplicate, namespaces/trivia/arity/local scope and error priority; no final/Stage credit.',caseBudgetSeconds=180,claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for case in plan['cases']:
   folder=out/case['id'];folder.mkdir();deadline=time.monotonic()+180;program=folder/'program.exe';expected=references[case['id']]
   compiled=x.run([str(compiler),'build',*[str(root/p) for p in case['sources']],'-o',str(program),'--target','windows-x64','--llvm',str(root/'.tools/llvm-22.1.8'),'-O0','--jobs','1','--keep-temps'],folder/'build',timeout=180);stderr=compiled.stderr.strip();ok=compiled.returncode==expected['buildExit'] and stderr==expected['buildStderr'];row=dict(id=case['id'],status='failed',buildExit=compiled.returncode,expectedBuildExit=expected['buildExit'],buildStderr=stderr,expectedBuildStderr=expected['buildStderr'])
   if ok and compiled.returncode==0:
    remaining=int(deadline-time.monotonic());assert remaining>0,'DECLARATION_CASE_180_SECONDS_EXHAUSTED';run=x.run([str(program)],folder/'run',timeout=remaining);actual=run.stdout.strip();runerr=run.stderr.strip();ok=run.returncode==0 and actual==expected['runStdout'] and not runerr;row.update(runExit=run.returncode,expectedRunExit=0,runStdout=actual,expectedStdout=expected['runStdout'],runStderr=runerr)
   row.update(status='passed' if ok else 'failed',passed=ok);r['cases'].append(row)
   if not ok:raise ValueError('NATIVE_DECLARATION_REFERENCE_DIFFERENCE:'+case['id'])
   r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
