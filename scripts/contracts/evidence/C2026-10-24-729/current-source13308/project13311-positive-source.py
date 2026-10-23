from pathlib import Path
import hashlib,json
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
parent=base/'grouped13306-source/result.json'
r=json.loads(parent.read_text(encoding='utf-8-sig'))
assert r['status']=='passed' and r['completed']==r['total']==10 and r['inputsStable'] and r['processesStopped']
positive=[x for x in r['cases'] if x.get('emittedLlvmSha256')]
negative=[x for x in r['cases'] if not x.get('emittedLlvmSha256')]
assert len(positive)==7 and len(negative)==3
assert all(x['passed'] and x['assemblyExit']==x['nativeLinkExit']==x['nativeRunExit']==0 for x in positive)
assert all(x['passed'] for x in negative)
projection={k:r[k] for k in ['schemaVersion','mode','managedCompiler','managedCompilerDllSha256','inputHashes','semanticPreflight','stdlibSourcePreflight','inputsStable','processesStopped','processes']}
projection['inputHashes']=dict(r['inputHashes'])
projection['inputHashes'][str(parent)]=hashlib.sha256(parent.read_bytes()).hexdigest().upper()
projection.update(recordType='executed-positive-case-subset-projection',status='passed',completed=7,total=7,cases=positive,parentRecord=str(parent),parentTotal=10,excludedSemanticRejectionCaseIds=[x['id'] for x in negative],scope='Actual LLVM assembly/link/runtime7 subset of complete canonical source10. The other3 exact semantic rejections remain passed only in the parent proof; no new execution or producer build.',claimsGoalComplete=False)
target=base/'grouped13311-source-positive7.json'
assert not target.exists()
target.write_text(json.dumps(projection,indent=2)+'\n',encoding='utf-8')
print('Projected actual positive runtime7 for the existing compiler builder; semantic rejection3 retained in complete parent10.')
