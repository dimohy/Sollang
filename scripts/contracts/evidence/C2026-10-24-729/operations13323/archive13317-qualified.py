from pathlib import Path
import datetime,hashlib,json,shutil
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def archive_tree(source,target):
    target.mkdir(exist_ok=False,parents=True)
    for p in source.rglob('*'):
        if p.is_file() and p.suffix in ['.json','.txt','.stdout','.stderr'] and '.sollang-cache' not in p.parts:
            q=target/p.relative_to(source)
            q.parent.mkdir(exist_ok=True,parents=True)
            shutil.copy2(p,q)
unit_paths={
 'C2026-10-24-728':['array4','boundary2'],
 'C2026-10-24-729':['signed3','unsigned1','function1']}
records={}
for unit,names in unit_paths.items():
    for name in names:
        source=base/('native13313-'+name)
        r=read(source/'result.json')
        assert r['status']=='passed' and r['inputsStable'] and r['processesStopped'] and r['completed']==r['total']>0
        assert all(c['passed'] for c in r['cases'])
        archive_tree(source,root/'scripts/contracts/evidence'/unit/'current-native13317'/name)
        records[name]=dict(reference=str((root/'scripts/contracts/evidence'/unit/'current-native13317'/name/'result.json').relative_to(root)).replace('\\','/'),completed=r['completed'],total=r['total'],sha256=sha(source/'result.json'))
assert sum(x['completed'] for x in records.values())==11
native=read(base/'v13312/compiler-build01/result.json')
assert native['status']=='passed' and native['inputsStable']
e=root/'scripts/contracts/evidence/C2026-10-24-729/current-native13317'
product=e/'compiler-product'
product.mkdir()
for p in (base/'v13312/compiler-build01').iterdir():
    if p.is_file() and p.suffix in ['.json','.txt']:
        shutil.copy2(p,product/p.name)
archive_tree(base/'o2-build13312-supervised',e/'supervised-build')
archive_tree(base/'function13314-managed',e/'function-managed')
for p in [base/'function13314-contract.json',base/'native13315-plan.json',base/'c728-candidate13316.ps1',Path(__file__),root/'scripts/probes/readonly-array-elements/function-interpolation-control.slg']:
    shutil.copy2(p,e/p.name)
for unit,names in unit_paths.items():
    total=sum(records[name]['total'] for name in names)
    qualification=dict(schemaVersion=1,status='current-native-focused-qualified-final-pending',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),defectId=unit,completed=total,total=total,percentage=100.0,managedFirst=dict(completed=total,total=total,proofs=['readonly-elements13265-managed/result.json','readonly-elements13278-managed/result.json'] if unit.endswith('728') else ['signed-interpolation13288-managed/result.json','unsigned-interpolation13290-managed/result.json','function13314-managed/result.json']),nativeRecords=[records[name] for name in names],canonicalSourceProof='scripts/contracts/evidence/C2026-10-24-729/current-source13308/canonical-source10/result.json',canonicalSourceCases=10,canonicalRuntimeCases=7,compiler=dict(path='artifacts/scratch/resume-20261006-owner-continuation22/v13312/compiler-build01/compiler.exe',sha256=native['compilerSha256'],optimization='O2',compilerSources=151,stdlibSources=144),inputsStable=True,processesStopped=True,originalExpectedOutputAndWarningsUnchanged=True,claimsPhaseClosure=False,claimsFinalDefectClosure=False,claimsGoalComplete=False,remaining='Final fixed-source original14/source7/runtime2708/Stage2/Stage3 and required platform/stdlib/performance evidence; focused implementation qualification only.')
    target=root/'scripts/contracts/evidence'/unit/'qualification13317.json'
    assert not target.exists()
    target.write_text(json.dumps(qualification,indent=2)+'\n',encoding='utf-8')
print('Archived current C728 CSharp6/Native6 and C729 CSharp5/Native5; final closure remains pending.')
