from pathlib import Path
import json,hashlib,shutil,datetime
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';out=r/'scripts/contracts/evidence/C2026-10-24-732/field-value13489';out.mkdir(exist_ok=False);old=b/'bounded13489-preimages';old.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
proof=b/'bounded13488-managed/result.json';d=json.loads(proof.read_text(encoding='utf-8'));assert d['status']=='passed' and d['completed']==d['total']==3 and d['inputsStable'] and d['processesStopped']
observations=[]
for name in ['848-bounded-inline-collections','850-bounded-owned-element-drop','1619-finite-bounded-array-layout']:
 p=b/'bounded13488-managed'/name/'probe.exe.ll';text=p.read_text(encoding='utf-8')
 for suffix,positive in [('llvm.contains.txt',True),('llvm.not-contains.txt',False)]:
  contract=r/'examples/regression/expected'/f'{name}.{suffix}'
  if contract.exists():
   for line in contract.read_text(encoding='utf-8').splitlines():
    if line.strip():assert (line.strip() in text)==positive,(name,line,positive)
 observations.append(dict(id=name,llvmSha256=sha(p),lines=[dict(line=i+1,text=s) for i,s in enumerate(text.splitlines()) if 'bounded_array.t' in s or 'call void @sollang_free' in s][:55]))
paths=['selfhost/llvm/text/foundation.slg','selfhost/llvm/text/ownership.slg','selfhost/llvm/text/platform_io.slg','selfhost/llvm/text/function_expressions.slg','selfhost/llvm/text/entry_expressions.slg','selfhost/llvm/text/control_region_expressions.slg','selfhost/llvm/text/core_calls.slg','selfhost/llvm/text/call_arguments.slg','selfhost/llvm/text/containers.slg','selfhost/llvm/text/container_control.slg','selfhost/llvm/text/core_prepare.slg','selfhost/llvm/text/functions.slg']
for p in paths:shutil.copyfile(r/p,old/Path(p).name)
record=dict(schemaVersion=1,status='source-reviewed-before-slg-edit',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),managedFirst=dict(existing32='scripts/contracts/evidence/C2026-10-24-732/value-abi13472/qualification13486.json',additional3=str(proof.relative_to(r)).replace('\\','/'),additional3Sha256=sha(proof),completed=35,total=35),before=[dict(path=p,sha256=sha(r/p)) for p in paths],cppLlvmObservations=observations,authority=['BoundProgram.RegisterBoundedArrays: element inline size/alignment, aligned i64 length header and N inline elements.','LlvmEmitter.Structs.MaterializeAggregateValue/CreateRuntimeAggregateValue: field and element value boundaries use inline bounded bytes, expression operations keep local descriptors.','LlvmEmitter.FunctionCalls.CreateProjectedMutableBorrowArgument: inline bounded length0/data1 adapt to existing three-address mutable borrow ABI.'],plan='Make canonical semantic bounded types/layouts inline and preserve runtime descriptor types through writeIrType; materialize at aggregate/element stores and reconstruct at field/index reads. Keep projected borrow addresses tied to the actual field. Complete drop and async consumers before whole/native qualification.',claimsCandidateFixed=False,claimsGoalComplete=False)
(out/'source-comparison13489.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('Current CSharp35 passed; retained LLVM contracts checked; field/element source comparison and preimages captured before edits.')
