from pathlib import Path
import hashlib,json,sys,shutil,datetime
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';a=root/'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067/matching-inputs14373';sys.path.insert(0,str(root/'scripts'))
from completed_artifact_plan import close_compiler_consumers,verified_consumer_closure,cleanup_output
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
source=read(b/'projection14588-source111/result.json');contract=read(b/'projection14587-source111.json')
assert source['status']=='passed' and source['completed']==source['total']==111 and source['inputsStable'] is True and source['processesStopped'] is True,'SOURCE111_NOT_QUALIFIED'
assert all(Path(p).is_file() and sha(p)==h for p,h in source['inputHashes'].items()),'SOURCE111_INPUT_DRIFT'
ids=[row['id'] for row in source['cases']];expected=[x for group in contract['scopeGroups'].values() for x in group]
assert len(ids)==len(set(ids))==111 and set(ids)==set(expected) and all(x.get('passed') is True for x in source['cases'])
assert {k:len(v) for k,v in contract['scopeGroups'].items()}==dict(focusedOwning10=10,exchange1=1,frozenSource100=100)
q=read(a/'retirement14602/qualification.json');proposal=read(a/'retirement14602/read-only-closure.json')
assert q['cohortCount']==14 and q['terminalRecordCount']==16 and q['originalTestCompletionAdded']==0
for row in q['mappings']:assert sha(root/row['originalCohort'])==row['originalSha256']
for observation in read(a/'retirement14602/provenance-validation.json')['observations']:
 p=Path(observation['path']);assert sha(p)==observation['sha256']
 record=read(p);assert all(Path(k).is_file() and sha(k)==h for k,h in record['inputHashes'].items())
 assert record['claimsTestPassed'] is False and not any(k in record for k in ('completed','total','cases'))
old=(b/'v14280/compiler-build01').resolve();replacement=(b/'v14390/compiler-build01').resolve();assert old.is_relative_to(root.resolve()) and old.name=='compiler-build01' and old.parent.name=='v14280'
consumers=[Path(row['path']) for row in proposal['consumers']];assert len(consumers)==16
out=a/'retirement14605';out.mkdir(exist_ok=False);shutil.copy2(old/'result.json',out/'retired-build-result.json')
closure=close_compiler_consumers(root,old,consumers,replacement,legacy_terminal=True);verified_consumer_closure(root,old)
assert read(closure)==proposal,'RETIREMENT_PROPOSAL_DRIFT'
plan=cleanup_output(root,old,execute=True,retention_terminal=True,reusable_directories=[b/'v12432/compiler-build01',replacement])
assert not (old/'compiler.exe').exists();verified_consumer_closure(root,old,allow_missing_product=True)
for row in q['mappings']:assert sha(root/row['originalCohort'])==row['originalSha256']
shutil.copy2(closure,out/'consumer-closure.json');shutil.copy2(plan,out/'artifact-cleanup-plan.json')
result=dict(schemaVersion=1,status='canonical-retirement-completed',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),retiringProduct=str(old),terminalRecords=16,historicalCohorts=14,failedConsumerOutputsPreserved=True,originalTestCompletionAdded=0,retainedProducts=[str(b/'v12432/compiler-build01'),str(replacement)],reservedNewProduct=str(b/'v14562/compiler-build01'),claimsGoalComplete=False)
(out/'qualification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
