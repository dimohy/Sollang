from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'forms21877-slg-type-spelling';producerPath=B/'forms21867-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';referencePath=B/'forms21874-csharp-type-spelling/result.json';producer=json.loads(producerPath.read_text(encoding='utf-8-sig'));reference=json.loads(referencePath.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
for r in [producer,reference]:assert r['status']=='passed' and r['inputsStable'] and r['processesStopped'] and all(sha(p)==h for p,h in r['inputHashes'].items())
manifest=ROOT/'scripts/probes/codegen-type-spelling/sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s];fixtures=sorted([ROOT/'scripts/probes/codegen-type-spelling/types.slg',*sorted((ROOT/'scripts/probes/codegen-type-spelling/input').glob('*.slg'))],key=lambda p:p.name);expected=reference['stdout'];assert reference['fieldSpellings']==20
paths=[Path(__file__),producerPath,EMITTER,referencePath,*map(Path,producer['inputHashes']),*map(Path,reference['inputHashes']),manifest,*sources,*fixtures];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=inputs,scope='Current compiled SLG live parsed TypeAnnotation adapter matches actual CSharp loaded compilation public type strings across six source files:20 spellings. Includes canonical containers, explicit/open aliases, sibling-module shadowing, generic/associated names. Complete public declaration projection and normal Native codegen cache remain pending.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(OUT/'unused.semantic'),str(OUT/'unused-stage.semantic'),*map(str,sources)],OUT/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2000:]+done.stderr
  ll=OUT/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n');exe=OUT/'program.exe'
  done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'program.bc')],OUT/'assemble',timeout=budget());assert done.returncode==0,done.stderr
  done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=budget());assert done.returncode==0,done.stderr
  done=ex.run([str(exe),*map(str,fixtures)],OUT/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,(done.stdout,done.stderr,expected)
  result.update(status='passed',completed=1,fieldSpellings=20,stdout=done.stdout)
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
