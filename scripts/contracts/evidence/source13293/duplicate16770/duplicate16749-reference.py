from pathlib import Path
import sys,json,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
planpath=b/'duplicate16748-reference10.json';plan=json.loads(planpath.read_text(encoding='utf-8-sig'));compiler=b/'managed16362/compiler/Sollang.Compiler.exe';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert sha(compiler.with_suffix('.dll'))==plan['expectedManagedDllSha256']
inputs=[Path(__file__),planpath,*compiler.parent.glob('Sollang.Compiler.*'),*[root/p for case in plan['cases'] for p in case['sources']],*root.glob('stdlib/**/*.slg')];inputs=list(dict.fromkeys(inputs));out=b/'duplicate16749-reference10';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=len(plan['cases']),inputHashes=pins,cases=[],scope=plan['scope'],claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  for case in plan['cases']:
   folder=out/case['id'];folder.mkdir();program=folder/'program.exe';build=x.run([str(compiler),'build',*[str(root/p) for p in case['sources']],'-o',str(program),'--target','windows-x64','--llvm',str(root/'.tools/llvm-22.1.8'),'--stdlib',str(root/'stdlib'),'-O0','--jobs','1','--keep-temps'],folder/'build',timeout=180);stderr=(folder/'build.stderr').read_text(encoding='utf-8-sig').strip();ok=build.returncode==case['expectedExit'] and (case['expectedFragment'] in stderr if case['expectedExit'] else not stderr);row=dict(id=case['id'],status='failed',buildExit=build.returncode,expectedBuildExit=case['expectedExit'],buildStderr=stderr)
   if ok and build.returncode==0:
    run=x.run([str(program)],folder/'run',timeout=180);actual=(folder/'run.stdout').read_text(encoding='utf-8-sig').strip();runerr=(folder/'run.stderr').read_text(encoding='utf-8-sig').strip();ok=run.returncode==0 and actual==case['expectedStdout'] and not runerr;row.update(runExit=run.returncode,runStdout=actual,runStderr=runerr)
   row.update(status='passed' if ok else 'failed',passed=ok);r['cases'].append(row)
   if not ok:raise ValueError('DUPLICATE_REFERENCE_CONTRACT_FAILED:'+case['id'])
   r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
