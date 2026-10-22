from pathlib import Path
import json,hashlib,re
r=Path(__file__).resolve().parents[4]
b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
c=read(r/'scripts/contracts/c690-prefix-cleanup-controls.json')
assert sha(r/c['cases'][0]['source'])==read(Path(__file__).resolve().parent/'baseline.json')['inputFingerprint']
assert sha(r/next(x['source'] for x in c['cases'] if x['id']=='compound-recursive-original'))==read(r/'scripts/contracts/evidence/C2026-10-23-690/baseline.json')['inputFingerprint']
managed=read(b/'tryparallel12468-managed/result.json')
source=read(b/'tryparallel12471-source/result.json')
runtime=read(b/'tryparallel12473-runtime/result.json')
for d in [managed,source,runtime]:
 assert d['status']=='passed' and d['completed']==d['total']==16 and d['inputsStable'] and d['processesStopped']
 for name,h in d['inputHashes'].items():assert sha(Path(name))==h,name
assert sha(b/'tryparallel12471-source/producer.exe')==source['producerSha256']
assert sha(b/'managed12467/compiler/Sollang.Compiler.dll')==c['expectedManagedDllSha256']
for expected,a,z in zip(c['cases'],managed['cases'],runtime['cases']):
 for actual in [a,z]:
  assert actual['id']==expected['id'] and actual['passed'] and actual['runExit']==expected['exit']
  assert actual['stdout'].replace('\r\n','\n')==expected['stdout'] and actual['stderr'].replace('\r\n','\n')==expected['stderr']
for case in source['cases']:
 assert case['status']=='passed' and case['emissionExit']==case['assemblyExit']==0
 llvm=(b/'tryparallel12471-source'/case['id']/'emitted.ll').read_text(encoding='utf-8-sig')
 if case['id'].startswith('compound-'):
  assert re.search(r'^tryparallel[0-9]+_sequential_header:',llvm,re.M)
  assert not re.search(r'^  call void @sollang_compute_execute',llvm,re.M)
 if case['id'] in ['recursive-original','success','first-error','empty','ordered','function','region']:
  assert re.search(r'^  call void @sollang_compute_execute',llvm,re.M)
llvm=(b/'tryparallel12471-source/recursive-original/emitted.ll').read_text(encoding='utf-8-sig')
cleanup=re.search(r'^tryparallel[0-9]+_cleanup_ok:\n(.*?)(?=^[A-Za-z0-9_]+:)',llvm,re.M|re.S).group(1)
arrayType=re.search(r'call void @sollang_drop_t([0-9]+)\(',cleanup).group(1)
def body(t):return re.search(r'^define internal void @sollang_drop_t'+t+r'\([^\n]*\) \{\n.*?^\}',llvm,re.M|re.S).group(0)
array=body(arrayType)
boxType=re.search(r'call void @sollang_drop_t([0-9]+)\(ptr %element\)',array).group(1)
box=body(boxType)
assert 'call void @free(ptr %data)' in array and 'call void @free(ptr %value)' in box
assert '_cleanup_is_selected = icmp eq' in llvm and '_cleanup_should_drop = and i1' in llvm
print('CSharp16 and current SLG source emission/assembly/runtime16 pass with complete current input closures; direct/compound routes and discarded array -> box -> free LLVM call chain verified. Fresh native, extra boundary cases and runtime allocation accounting are not claimed.')
