"""Qualify C722 against actual current paired evidence; retain every final gate."""
from pathlib import Path
import hashlib,json,runpy,sys
E=Path(__file__).resolve().parent;R=E.parents[3];B=Path('artifacts/scratch/resume-20261006-owner-continuation22')
sys.path.insert(0,str(R/'scripts'))
from verification_source_proof import current_build_inputs

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def saved(name):return E/'records'/B/name

print('Historical baseline3E follows; its pending wording is not the current candidate status.')
runpy.run_path(str(E.parent/'literal13110/verify.py'),run_name='__main__')
for item in read(E/'manifest.json')['files']:
 assert sha(E/item['archive'])==item['sha256'],item['archive']
contract=read(saved('literal13147-contract.json'));sourceContract=read(saved('literal13144-contract.json'))
assert len(contract['cases'])==len(sourceContract['cases'])==17
proofs={name:read(saved(name+'/result.json')) for name in ['literal13147-managed','literal13144-source','literal13145-runtime','literal13153-native']}
for name,count in [('literal13147-managed',17),('literal13144-source',17),('literal13145-runtime',11),('literal13153-native',17)]:
 p=proofs[name];assert p['status']=='passed' and p['completed']==p['total']==count and p['inputsStable'] and p['processesStopped'],name
 for path,h in p['inputHashes'].items():assert sha(Path(path))==h,path
 assert all(c['status']=='passed' for c in p['cases']),name
for case in contract['cases']:
 for name in ['literal13147-managed','literal13153-native']:
  p=proofs[name];row=next(c for c in p['cases'] if c['id']==case['id']);assert row['buildExit']==case['exit'] and row['buildStderr']==case['stderr']
  if case['exit']==0:assert row['runExit']==0 and row['runStdout']==case['stdout'] and row['runStderr']==''
  assert sha(R/case['source'])==p['inputHashes'][str((R/case['source']).resolve())]
for case in sourceContract['cases']:
 raw=saved('literal13144-source/'+case['id']+'/emit.stdout');row=next(c for c in proofs['literal13144-source']['cases'] if c['id']==case['id'])
 if case.get('admitted')==False:
  text=raw.read_text(encoding='utf-8-sig');assert text.strip()==case['expectedDiagnostic'] and 'target triple =' not in text and row['admissionRejected']
 else:
  assert sha(raw)==row['emittedLlvmSha256'] and row['assemblyExit']==0
  runtime=next(c for c in proofs['literal13145-runtime']['cases'] if c['id']==case['id']);assert runtime['nativeRunExit']==case['exit'] and runtime['nativeRunStdout'].replace('\r\n','\n')==case['stdout'] and runtime['stderr']==case['stderr']
product=read(saved('v13149/compiler-build01/result.json'));current_build_inputs(R,product)
native=R/B/'v13149/compiler-build01/compiler.exe';assert sha(native)==product['compilerSha256']==proofs['literal13153-native']['inputHashes'][str(native)]
assert sha(R/B/'managed13056/compiler/Sollang.Compiler.dll')=='8310858A4407EF263ACE7292A2CF1EA70FB018DB6520E450CC100F2BE777394D'
comparison=read(saved('literal13150-source-comparison.json'))
for path,h in comparison['sourceHashes'].items():assert sha(R/path)==h,path
original=next(c for c in contract['cases'] if c['id']=='original1188');assert original['source']=='examples/regression/1188-io-memory-reader-caller-buffer.slg'
print('PASS: C722 current CSharp17, SLG source17, emitted runtime11 and native17; original1188 unchanged. Candidate only; whole405/22, original14/source7/runtime2708, Stage2/3, stdlib22/platform/performance remain pending.')
