from pathlib import Path
import hashlib,json,shutil,struct,sys,time,re
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'source21754-csharp-cache';CPP=B/'managed21747/compiler/Sollang.Compiler.exe'
P=ROOT/'scripts/probes/codegen-function-order';Q=ROOT/'scripts/probes/codegen-cache-production'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),*P.iterdir(),*Q.iterdir(),*sorted((ROOT/'stdlib').rglob('*.slg')),*[p for p in (ROOT/'src/Sollang.Compiler').rglob('*.cs') if not {'obj','bin'}.intersection(p.parts)]]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir();project=OUT/'project';project.mkdir()
def units(path):
 raw=path.read_bytes();w=struct.unpack('<'+'Q'*(len(raw)//8),raw);i=8;rows={}
 for _ in range(w[5]):
  h=w[i:i+8];name=bytes(w[i+8:i+8+h[4]]).decode();start=i+8+h[4];data=b''.join(v.to_bytes(8,'little') for v in w[start:start+h[6]])[:h[5]]
  rows[(h[0],name)]=dict(interface=h[2],implementation=h[3],fragmentSha256=hashlib.sha256(data).hexdigest().upper());i=start+h[6]
 return rows
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=5,cases=[],inputHashes=inputs,claimsGoalComplete=False,scope='Actual CSharp CLI codegen cache cold/exact/body-only reuse/type-universe invalidation/fresh equivalence; no SLG production cache claim.')
 run=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);error=None
 try:
  shutil.copyfile(P/'main.slg',project/'main.slg');shutil.copyfile(P/'before.slg',project/'beta.slg');previous=None;type_units=None
  cases=[('cold',P/'alpha.slg','program','beta\n10\npeer\n7\n'),('exact',P/'alpha.slg','program','beta\n10\npeer\n7\n'),('body-change',Q/'alpha-body.slg','program','beta\n11\npeer\n8\n'),('type-change',Q/'alpha-type.slg','program','beta\n11\npeer\n8\n'),('fresh',Q/'alpha-type.slg','fresh','beta\n11\npeer\n8\n')]
  for name,alpha,product,expected in cases:
   shutil.copyfile(alpha,project/'alpha.slg');sources=[project/n for n in ['main.slg','alpha.slg','beta.slg']];live={str(p):sha(p) for p in sources};d=OUT/name;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));exe=project/(product+'.exe')
   done=run.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0'],d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
   log=done.stdout;cache=list((project/'.sollang-cache').glob(product+'.*.cgu'));assert len(cache)==1;current=units(cache[0]);beta=current[(1,'cache.beta')];m=re.search(r'\[codegen-cache\] (.*?); reused (\d+)/(\d+) units;',log);assert m,log
   status,reused,total=m.group(1),int(m.group(2)),int(m.group(3))
   if name=='cold':assert reused==0
   if name=='exact':assert reused==total and 'exact' in status
   if name=='body-change':assert beta==previous[(1,'cache.beta')] and 0<reused<total
   if name=='type-change':
    assert beta['implementation']!=previous[(1,'cache.beta')]['implementation'];assert reused<total;type_units=current
   if name=='fresh':assert current==type_units and reused==0
   done=run.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout+done.stderr
   assert all(sha(p)==h for p,h in live.items());result['cases'].append(dict(id=name,passed=True,sourceHashes=live,cacheStatus=status,reused=reused,units=total,beta=beta,stdout=done.stdout));result['completed']+=1;previous=current;run.save()
  result['status']='passed'
 except BaseException as e:error=e
 finally:run.finalize(error,cleanup=False)
 if error:raise error
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
