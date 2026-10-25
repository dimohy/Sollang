from pathlib import Path
import hashlib,json,sys
root=Path.cwd();base=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import verified_consumer_closure
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
plan_path=root/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067/matching-inputs14373/native-plan14603.json';plan=read(plan_path);parameters=plan['parameters'];assert plan['compilerBuildBudgetSeconds']==600 and plan['maximumBuildInvocations']==1;assert parameters['Optimization']=='O2' and parameters['Jobs']==4
proofs=[Path(p) for p in parameters['ManagedProofRecord']+parameters['SlgEmissionProofRecord']+[parameters['StdlibSourceProofRecord']]];proofs += [base/'projection14588-source111/result.json',Path(plan['requiredManagedOriginal3']['path'])];pins={}
for path in proofs:
 r=read(path);assert r['status']=='passed' and r['inputsStable'] and r['processesStopped'] and r['completed']==r['total']>0,str(path)
 if path.parent.name=='projection14588-source111':
  assert r['completed']==111
  contract=read(base/'projection14587-source111.json');ids=[row['id'] for row in r['cases']];expected=[x for group in contract['scopeGroups'].values() for x in group]
  assert len(ids)==len(set(ids))==111 and set(ids)==set(expected) and all(row.get('passed') is True for row in r['cases'])
  assert {k:len(v) for k,v in contract['scopeGroups'].items()}==dict(focusedOwning10=10,exchange1=1,frozenSource100=100)
 if path.parent.name=='projection14595-original-managed3':assert r['completed']==3
 for p,h in r['inputHashes'].items():
  assert Path(p).is_file() and sha(p)==h,str(p)
  assert p not in pins or pins[p]==h,str(p)
  pins[p]=h
 pins[str(path)]=sha(path)
old=base/'v14280/compiler-build01';verified_consumer_closure(root,old,allow_missing_product=True);assert not (old/'compiler.exe').exists(),'Old14280 must be canonically retired first';assert sha(root/plan['currentCompilerSource'])==plan['currentCompilerSourceSha256']
for p,h in plan['currentChangedSourceHashes'].items():assert sha(root/p)==h
assert read(base/'projection14599-positive75.json')['completed']==75
assert read(root/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067/matching-inputs14373/retirement14605/qualification.json')['status']=='canonical-retirement-completed'
wrapper=base/'o2-build14562.ps1'
for p in [wrapper,Path(__file__).resolve(),plan_path,root/'scripts/build-focused-selfhost-compiler.ps1',old/'consumer-closure.json']:pins[str(p)]=sha(p)
out=base/'o2-build14562-supervised';out.mkdir(exist_ok=False);result={'schemaVersion':1,'status':'running','scope':'One current call-stability Native compiler build; all original source100 and exchange1 prerequisite scopes retained. No original1290 or Stage acceptance claim.','inputHashes':pins,'completed':0,'total':1,'claimsGoalComplete':False,'compilerBuildBudgetSeconds':600,'maximumBuildInvocations':1};execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 built=execution.run(['pwsh','-NoProfile','-File',str(wrapper)],out/'build',timeout=600);assert built.returncode==0,built.stderr;product=read(Path(parameters['OutputDirectory'])/'result.json');assert product['status']=='passed' and product['inputsStable'];assert product['steps']=={'semanticPreflight':0,'build':0,'llvmAs':0,'v004':0,'parallelCallbacks':0};assert sha(Path(parameters['OutputDirectory'])/'compiler.exe')==product['compilerSha256'];result.update(status='passed',completed=1,compilerSha256=product['compilerSha256'])
except BaseException as caught:error=caught
finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped','compilerSha256']}));sys.exit(0 if result['status']=='passed' else 1)
