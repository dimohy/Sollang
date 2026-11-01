from pathlib import Path
import argparse,hashlib,json,shutil,struct,sys,time,re
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
parser=argparse.ArgumentParser(description='Actual CSharp or SLG production codegen cache comparison')
parser.add_argument('--compiler',type=Path,required=True)
parser.add_argument('--native',action='store_true',help='Exercise the SLG CLI with the same seven fixtures and cache assertions')
parser.add_argument('--entry-mode',choices=['files','project','workspace'],default='files',help='Select explicit sources or a manifest without changing the fixtures or cache assertions')
parser.add_argument('--semantic-reuse',action='store_true',help='Remove only the owned frontend snapshot before the exact case to exercise semantic restoration')
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--reusable-directory',type=Path,action='append',required=True)
args=parser.parse_args();OUT=args.output.resolve();CPP=args.compiler.resolve()
assert not (args.native and args.semantic_reuse), 'Native CLI already restores semantic owners without a frontend snapshot'
P=ROOT/'scripts/probes/codegen-function-order';Q=ROOT/'scripts/probes/codegen-cache-production'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
paths=[Path(__file__),CPP,*([] if args.native else managed_runtime_inputs(CPP)),*P.iterdir(),*Q.iterdir(),*sorted((ROOT/'stdlib').rglob('*.slg')),*[p for p in (ROOT/'src/Sollang.Compiler').rglob('*.cs') if not {'obj','bin'}.intersection(p.parts)]]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=args.reusable_directory);OUT.mkdir();project=OUT/'project';project.mkdir()
module_directory=project if args.entry_mode=='files' else project/'cache';module_directory.mkdir(exist_ok=True)
manifests=[]
if args.entry_mode!='files':
 manifest=project/'sollang.project';manifest.write_text('project { name: "cacheproof", version: "1.0.0", root: "main.slg" }\n',encoding='utf-8');manifests.append(manifest)
 if args.entry_mode=='workspace':
  manifest=project/'sollang.workspace';manifest.write_text('workspace { members: ["."] }\n',encoding='utf-8');manifests.append(manifest)
def units(path):
 raw=path.read_bytes();w=struct.unpack('<'+'Q'*(len(raw)//8),raw);i=8;rows={}
 for _ in range(w[5]):
  h=w[i:i+8];name=bytes(w[i+8:i+8+h[4]]).decode();start=i+8+h[4];data=b''.join(v.to_bytes(8,'little') for v in w[start:start+h[6]])[:h[5]]
  rows[(h[0],name)]=dict(interface=h[2],implementation=h[3],fragmentSha256=hashlib.sha256(data).hexdigest().upper());i=start+h[6]
 return rows
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=7,cases=[],inputHashes=inputs,claimsGoalComplete=False,scope=f"Actual {'SLG' if args.native else 'CSharp'} CLI codegen cache cold/exact/body-only reuse/type-universe invalidation/corrupt rejection/fresh equivalence/kept LLVM publication; cross-compiler numeric key parity is a separate check.")
 run=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);error=None
 try:
  shutil.copyfile(P/'main.slg',project/'main.slg');shutil.copyfile(P/'before.slg',module_directory/'beta.slg');previous=None;type_units=None
  cases=[('cold',P/'alpha.slg','program','beta\n10\npeer\n7\n'),('exact',P/'alpha.slg','program','beta\n10\npeer\n7\n'),('body-change',Q/'alpha-body.slg','program','beta\n11\npeer\n8\n'),('type-change',Q/'alpha-type.slg','program','beta\n11\npeer\n8\n'),('corrupt',Q/'alpha-type.slg','program','beta\n11\npeer\n8\n'),('fresh',Q/'alpha-type.slg','fresh','beta\n11\npeer\n8\n'),('kept',Q/'alpha-type.slg','kept','beta\n11\npeer\n8\n')]
  for name,alpha,product,expected in cases:
   shutil.copyfile(alpha,module_directory/'alpha.slg');sources=[project/'main.slg',module_directory/'alpha.slg',module_directory/'beta.slg'];live={str(p):sha(p) for p in [*sources,*manifests]};d=OUT/name;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));exe=project/(product+'.exe')
   rejected_hash=None
   if name=='exact' and args.semantic_reuse:
    snapshots=list((project/'.sollang-cache').glob(product+'.*.sources'));assert len(snapshots)==1
    snapshots[0].unlink()
   if name=='corrupt':
    cached=list((project/'.sollang-cache').glob(product+'.*.cgu'));assert len(cached)==1
    damaged=bytearray(cached[0].read_bytes());damaged[-1]^=1;cached[0].write_bytes(damaged);rejected_hash=sha(cached[0])
   entry=list(map(str,sources)) if args.entry_mode=='files' else (['--project',str(project)] if args.entry_mode=='project' else ['--workspace',str(project),'--package','cacheproof'])
   command=[str(CPP),'build',*entry,'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0']
   if args.native: command.extend(['--stdlib',str(ROOT/'stdlib')])
   if name=='kept': command.append('--keep-temps')
   done=run.run(command,d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
   log=done.stdout;cache=list((project/'.sollang-cache').glob(product+'.*.cgu'));assert len(cache)==1;current=units(cache[0]);beta=current[(1,'cache.beta')];m=re.search(r'\[codegen-cache\] (?:(.*?); )?reused (\d+)/(\d+) units;',log);assert m,log
   status,reused,total=m.group(1) or 'not-reported',int(m.group(2)),int(m.group(3))
   if name=='cold':assert reused==0
   if name=='exact':
    assert reused==total and (args.native or args.semantic_reuse or 'exact' in status)
    if args.semantic_reuse:assert '[frontend-cache] exact hit' not in log
   if name=='body-change':assert beta==previous[(1,'cache.beta')] and 0<reused<total
   if name=='type-change':
    assert beta['implementation']!=previous[(1,'cache.beta')]['implementation'];assert reused<total;type_units=current
   if name in ('corrupt','fresh','kept'):assert current==type_units and reused==0
   if name=='kept':assert Path(str(exe)+'.ll').is_file()
   done=run.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout+done.stderr
   assert all(sha(p)==h for p,h in live.items());result['cases'].append(dict(id=name,passed=True,sourceHashes=live,cacheStatus=status,reused=reused,units=total,beta=beta,stdout=done.stdout,rejectedCacheSha256=rejected_hash));result['completed']+=1;previous=current;run.save()
  result['status']='passed'
 except BaseException as e:error=e
 finally:run.finalize(error,cleanup=False)
 if error:raise error
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
