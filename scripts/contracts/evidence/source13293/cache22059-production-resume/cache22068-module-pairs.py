from pathlib import Path
import sys,json,hashlib,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';native=len(sys.argv)>1 and sys.argv[1]=='native';OUT=B/('cache22070-slg-module-catalog' if native else 'cache22068-csharp-module-catalog');CPP=B/'managed21997/compiler/Sollang.Compiler.exe';manifest=ROOT/'scripts/probes/codegen-compilation-modules/sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
fixtures=[B/'cache22061-csharp-module-catalog/module-sources'/name for name in ['Z.slg','a.slg','empty.slg','other.slg']]
referencePath=B/'cache22061-csharp-module-catalog/result.json';reference=json.loads(referencePath.read_text());assert reference['status']=='passed' and reference['completed']==reference['total']==3 and reference['inputsStable'] and reference['processesStopped'];rows=[c['observation'] for c in reference['cases']]
def expected(files):
 result=''
 for row in rows:
  result+='\n'.join([row['name'],format(row['stableHash'],'016x'),format(row['implementationHash'],'016x'),format(row['interfaceHash'],'016x'),'standard' if row['isStandardLibrary'] else 'user',*row['imports'],'end-module'])+'\n'
 return result
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),manifest,*sources,*fixtures,referencePath,*map(Path,reference['inputHashes']),*sorted((ROOT/'stdlib').rglob('*.slg'))]
if native:
 producerPath=B/'cache22069-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';producer=json.loads(producerPath.read_text());assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'];assert all(sha(p)==h for p,h in producer['inputHashes'].items());paths += [producerPath,EMITTER,*map(Path,producer['inputHashes'])]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Actual SLG compilation module catalog against actual CSharp CreateModuleIdentity: stable/full identity order, source/interface hashes, unique sorted imports, standard flag and caller cursor. Forward and reverse input; no production cache reuse/publication claim.',claimsGoalComplete=False)
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
   result['cases'].append(dict(id=label,passed=True,modules=3,importCount=sum(len(r['imports']) for r in rows),stdout=done.stdout));result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
