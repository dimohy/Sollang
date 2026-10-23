from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'diagnostic12689';o.mkdir(exist_ok=False)
cpath=b/'scratch12680-contract.json';c=json.loads(cpath.read_text(encoding='utf-8-sig'))
c['cases']=[row for row in c['cases'] if row['id'] in ['stream-control-nested','stream-role-types','integer-stream','unit-bool-observation']]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
origin=b/'scratch12680-source/result.json';prior=json.loads(origin.read_text(encoding='utf-8-sig'));exe=b/'scratch12680-source/producer.exe'
assert prior['buildExit']==0 and prior['producerSha256']==sha(exe) and prior['processesStopped'] and prior['inputsStable']
inputs=[Path(__file__),cpath,origin,exe,root/'.tools/llvm-22.1.8/bin/llvm-as.exe']+[root/row['source'] for row in c['cases']]+list((root/'stdlib').rglob('*.slg'));pins={str(p):sha(p) for p in inputs}
r={'schemaVersion':1,'status':'running','scope':'Diagnostic reuse of frozen producer12680. Observe four remaining risk/control cases before next build; canonical source is now changed, so this is not current-source qualification.','inputHashes':pins,'completed':0,'total':4,'cases':[],'budget':c['budget'],'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  folder=o/case['id'];folder.mkdir();row={'id':case['id'],'status':'running','source':case['source'],'target':case['target']};r['cases'].append(row);x.save()
  a=x.run([str(exe),case['source'],case['target']],folder/'emit',timeout=180);row['emissionExit']=a.returncode
  if case.get('admitted') == False:
   expected='parallel callback SourceText is supported only as a direct top-level tryParallel Result payload'
   if a.returncode != 1 or a.stderr.strip() or a.stdout.count(expected) != 1 or 'target triple =' in a.stdout:raise ValueError('NEGATIVE_ADMISSION_FAILED '+case['id']+a.stdout[:500]+a.stderr[:500])
   row.update(status='passed',admissionRejected=True);r['completed']+=1;x.save();continue
  if a.returncode or a.stderr.strip():raise ValueError('EMISSION_FAILED: '+case['id']+a.stderr[:500])
  llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['emittedLlvmSha256']=sha(llvm)
  a=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble',timeout=180);row['assemblyExit']=a.returncode
  row['diagnosticAssemblyFailure']=a.stderr if a.returncode else None
  row['status']='observed';r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
