from pathlib import Path
import json,hashlib,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';source=b/'runtime18184-observer.slg';output=b/'runtime18186-observer';c=json.loads((b/'runtime18167-source12.json').read_text(encoding='utf-8'));previous=json.loads((b/'runtime18169-source12/result.json').read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
pins=dict(previous['inputHashes'])
for p in [source,Path(__file__).resolve()]:pins[str(p)]=sha(p)
def stable():return all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
assert stable();assert previous['inputsStable'] and previous['processesStopped']
retained=[b/'v12432/compiler-build01',b/'v17599/compiler-build01',b/'v18092/compiler-build01'];initialize_output(root,output,reusable_directories=retained);assert not output.exists();output.mkdir()
r={'schemaVersion':1,'status':'running','scope':'Diagnostic observation only of original39 drop seeds and original859 capacity interpolation; not compiler qualification or replacement expected output.','inputHashes':pins,'completed':0,'total':2,'maximumBuildAttempts':1,'caseBudgetSeconds':180,'cases':[],'claimsGoalComplete':False}
with VerificationContractLease([Path(p) for p in pins]):
 x=VerificationExecution(root,output,r,stable,sha);error=None
 try:
  exe=output/'probe.exe';compiler=b/'managed18060/compiler/Sollang.Compiler.exe'
  args=[str(compiler),'build',str(source),*[str(root/p) for p in c['reusableCheckedProducer']['additionalSources']],'-o',str(exe),'--target','windows-x64','--keep-temps','-O0','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')]
  a=x.run(args,output/'build',timeout=180);r.update(buildExit=a.returncode,buildStderr=a.stderr.strip())
  if a.returncode or a.stderr.strip():raise ValueError('OBSERVER_BUILD_FAILED: '+a.stderr[:1000])
  pins[str(exe)]=sha(exe);r['observerSha256']=sha(exe)
  for program,expectedPrefix in [('examples/regression/39-stack-promoted-int-dictionary.slg','dictionary node='),('examples/regression/859-collection-reserve.slg','capacity node=')]:
   name=Path(program).stem;a=x.run([str(exe),program],output/name,timeout=180)
   passed=a.returncode==0 and not a.stderr.strip() and expectedPrefix in a.stdout and 'observation-end' in a.stdout
   r['cases'].append({'source':program,'status':'observed' if passed else 'failed','exit':a.returncode,'stdoutSha256':sha(output/(name+'.stdout')),'observations':a.stdout.strip(),'stderr':a.stderr.strip()});r['completed']+=int(passed);x.save()
   print(name+(': OBSERVED' if passed else ': FAILED'),flush=True)
   if not passed:raise ValueError('OBSERVER_CASE_FAILED: '+program)
  r['status']='passed'
 except BaseException as exc:error=exc
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}),flush=True)
 if error:raise error
