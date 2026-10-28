from pathlib import Path
import re,json,sys
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_llvm_allocation import allocation_failure_call_binding
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def calls(path,pattern):return re.findall(pattern,path.read_text(encoding='utf-8'))
def case(identity,path,needle,owner):
    allocation_failure_call_binding(path.read_text(encoding='utf-8'),needle,owner)
    return dict(id=identity,llvm=path.as_posix(),allocationCall=needle,sourceFunction=owner,exit=0,expectedRuntimeExit=-1073741795,stdout='')
rows=[]
managed=b/'resize17780-managed1/reserve-loop-grow-and-keep/probe.exe.ll'
needles=calls(managed,r'call ptr @sollang_alloc\(i64 %array_reserve_bytes\d+\)');assert len(needles)==2
rows.append(case('managed-reserve-grow',managed,needles[0],'main'))
native=b/'resize17786-source4/reserve-loop-grow-and-keep/run.stdout'
needles=calls(native,r'call ptr @sollang_resize\(ptr %reserve[^\n]+\)');assert len(needles)==2
rows.append(case('slg-reserve-grow',native,needles[0],'main'))
for identity,path,pattern in [
    ('managed-materialize-grow',b/'resize17785-managed-materialize1/581-materialized-text-arena/probe.exe.ll',r'call ptr @sollang_alloc\(i64 %arena_new_capacity\d+\)'),
    ('slg-materialize-grow',b/'resize17786-source4/581-materialized-text-arena/run.stdout',r'call ptr @sollang_resize\(ptr %materialize[^\n]+\)')]:
    selected=[]
    for needle in calls(path,pattern):
        try:binding=allocation_failure_call_binding(path.read_text(encoding='utf-8'),needle,'.formatLine')
        except ValueError as error:
            assert str(error)=='ALLOCATION_FAILURE_DIAGNOSTIC_OWNER_MISMATCH',str(error)
            continue
        selected.append(needle)
    assert len(selected)==1,(identity,selected)
    rows.append(case(identity,path,selected[0],'.formatLine'))
old=b/'allocation17756-source7/1401-selfhost-reserve-before-aggregate-transfer/run.stdout'
needles=calls(old,r'call ptr @sollang_resize\(ptr %reserve[^\n]+\)');assert len(needles)==1
negative=dict(id='old-reserve-missing-guard-rejected-before-link',llvm=old.as_posix(),allocationCall=needles[0],sourceFunction='.prepare',expectedFailureId='ALLOCATION_FAILURE_GUARD_MISSING_BEFORE_USE')
contract=dict(schemaVersion=1,scope='One rule for source-owned reserve/materialize failure guards. First reserve targets the declared16-element request; function materialize targets the unique formatLine operation. No original expected file changes and no byte-identical generated-label claim.',sourceFixtures=[(b/'resize17780-loop-control.slg').as_posix(),'examples/regression/581-materialized-text-arena.slg'],cases=rows,negativeCases=[negative],constantCompatibility=[dict(id='managed-constant-call-compatibility',llvm=(b/'placement17610-managed4/42-fixed-array-placement/probe.exe.ll').as_posix()),dict(id='slg-constant-call-compatibility',llvm=(b/'resize17786-source4/42-fixed-array-placement/run.stdout').as_posix())],budget=dict(caseSeconds=180,retryCount=0))
(b/'resize17787-failure-contract.json').write_text(json.dumps(contract,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(frozenCallSites=len(rows),negativeCases=1,constantCompatibility=2)))
