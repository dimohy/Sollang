from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';native=len(sys.argv)>1 and sys.argv[1]=='native';OUT=B/('module21922-slg-stream' if native else 'module21920-csharp-stream');CPP=B/'managed21908/compiler/Sollang.Compiler.exe';manifest=ROOT/'scripts/probes/codegen-module-interface/sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
fixtures=[ROOT/'scripts/probes/codegen-module-interface'/name for name in ['Z.slg','a.slg','empty.slg','other.slg']]
referencePath=B/'module21915-csharp-current/result.json';reference=json.loads(referencePath.read_text());assert reference['status']=='passed' and reference['completed']==reference['total']==3 and reference['inputsStable'] and reference['processesStopped'];rows=[c['observation'] for c in reference['cases']];byFile={name:row for row in rows for name in row['sources']}
def expected(files):
 seen=set();result=''
 for path in files:
  row=byFile[path.name]
  if row['name'] in seen:continue
  seen.add(row['name']);result+='\n'.join([row['name'],*row['fields'],format(row['hash'],'016x')])+'\n'
 return result
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),manifest,*sources,*fixtures,referencePath,*map(Path,reference['inputHashes']),*sorted((ROOT/'stdlib').rglob('*.slg'))]
if native:
 producerPath=B/'module21921-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';producer=json.loads(producerPath.read_text());assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'];assert all(sha(p)==h for p,h in producer['inputHashes'].items());paths += [producerPath,EMITTER,*map(Path,producer['inputHashes'])]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Actual SLG module interface API against actual managed CreateModuleIdentity fields/hash:3 modules, empty/private-only and unrelated modules, multiple files and category/name order, forward/reverse source inputs. No actual cache admission/reuse/publication claim.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  exe=OUT/'program.exe'
  if native:
   done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(OUT/'unused.semantic'),str(OUT/'unused-stage.semantic'),*map(str,sources)],OUT/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2000:]+done.stderr
   ll=OUT/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n')
   done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'program.bc')],OUT/'assemble',timeout=budget());assert done.returncode==0,done.stderr
   done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=budget());assert done.returncode==0,done.stderr
  else:
   done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2000:]+done.stderr
  for label,files in [('forward',fixtures),('reverse',list(reversed(fixtures)))]:
   done=ex.run([str(exe),*map(str,files)],OUT/label,timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected(files),(done.returncode,done.stdout,done.stderr,expected(files))
   result['cases'].append(dict(id=label,passed=True,modules=3,fieldCount=sum(len(r['fields']) for r in rows),stdout=done.stdout));result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
