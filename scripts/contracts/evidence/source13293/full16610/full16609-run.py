from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output,assert_build_space
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
plan=b/'full16607-input/plan.json';p=read(plan);semantic=b/'full16607-semantic/result.json';focused=b/'text16603-source23/result.json';s=read(semantic);f=read(focused)
for record,count in [(s,4),(f,23)]:assert record['status']=='passed' and record['completed']==record['total']==count and record['inputsStable'] and record['processesStopped']
managed=r/p['managedCompiler'];assert sha(managed.with_suffix('.dll'))==p['expectedManagedDllSha256'];assert len(p['compilerSources'])==151 and len(p['standardLibrarySources'])==144 and len(p['providers'])==150
for name,h in p['sourceHashes'].items():assert sha(r/name)==h,name
llvm=r/'.tools/llvm-22.1.8/bin';closure=r/'scripts/verify-llvm-direct-call-closure.ps1';o=b/'full16609-emission';reusable=[b/x/'compiler-build01' for x in ['v12432','v16219','v16382']];initialize_output(r,o,reusable_directories=reusable);assert_build_space(o);o.mkdir(exist_ok=False)
inputs=list(dict.fromkeys([Path(__file__),plan,semantic,focused,r/'scripts/verification_execution.py',r/'scripts/verification_contract_lease.py',r/'scripts/completed_artifact_plan.py',r/'scripts/Invoke-CompletedArtifactCleanup.ps1',r/'scripts/ArtifactLifecycle.ps1',r/'scripts/contracts/artifact-lifecycle.json',*managed_runtime_inputs(managed),llvm/'llvm-as.exe',llvm/'clang.exe',closure,*[r/name for name in p['sourceHashes']]]));pins={str(x):sha(x) for x in inputs};stable=lambda:all(Path(x).is_file() and sha(x)==h for x,h in pins.items())
d=dict(schemaVersion=1,status='running',completed=0,total=4,inputHashes=pins,cases=[],scope=p['scope'],compileSources=151,stdlibSources=144,stdlibAuthorityCount=144,producerProviderSources=150,producerBuildSeconds=180,fullEmissionSeconds=3600,rootCompilerSourcesChanged=False,generalCompilerProductCreated=False,stageCredit=0,wholeSourceOrRuntimeCredit=0,originalNativeFailure='scripts/contracts/evidence/source13293/while16518/qualification.json',sourceCandidate='scripts/contracts/evidence/source13293/combined16608/qualification.json',fullEmissionAttemptAfterQualifiedRepair=1,claimsGoalComplete=False)
with VerificationContractLease(inputs):
 x=VerificationExecution(r,o,d,stable,sha);error=None
 try:
  command=list(f['processes'][0]['command']); assert command[0]==str(managed) and command[1]=='build'; assert command[3:command.index('-o')]==[str(r/name) for name in p['providers']]; command[2]=str(r/p['producer']); command[command.index('-o')+1]=str(o/'probe.exe'); d['producerBuildCommandAuthority']=str(focused); d['previousCliOnlyFailure']=str(b/'while16570-full-emission/result.json')
  a=x.run(command,o/'producer-build',timeout=180);assert a.returncode==0 and not a.stderr.strip(),('FIXED_FULL_PRODUCER_BUILD_FAILED',a.returncode,a.stderr[:1200]);d['completed']=1;d['cases'].append(dict(id='fixed-input-producer-build',status='passed',producerSha256=sha(o/'probe.exe')));x.save()
  a=x.run([str(o/'probe.exe')],o/'emission',timeout=3600);assert a.returncode==0 and not a.stderr.strip(),('FIXED_FULL_SLG_EMISSION_FAILED',a.returncode,a.stderr[:1200]);d['completed']=2;d['cases'].append(dict(id='fixed-full-slg-emission',status='passed',llvmSha256=sha(o/'emission.stdout')));x.save()
  a=x.run([str(llvm/'llvm-as.exe'),str(o/'emission.stdout'),'-o',str(o/'compiler.bc')],o/'assembly',timeout=180);assert a.returncode==0 and not a.stderr.strip(),('FIXED_FULL_LLVM_ASSEMBLY_FAILED',a.returncode,a.stderr[:1200]);d['completed']=3;d['cases'].append(dict(id='llvm-assembly',status='passed'));x.save()
  a=x.run(['pwsh','-NoProfile','-File',str(closure),'-LlvmPath',str(o/'emission.stdout')],o/'closure',timeout=180);assert a.returncode==0 and not a.stderr.strip(),('FIXED_FULL_LLVM_CLOSURE_FAILED',a.returncode,a.stderr[:1200]);d['completed']=4;d['cases'].append(dict(id='llvm-call-closure',status='passed'));d['status']='passed'
 except BaseException as e:error=e
 finally:
  d['generatedOutputHashes']={str(q):sha(q) for q in [o/'probe.exe',o/'probe.exe.ll',o/'compiler.bc',o/'emission.stdout'] if q.is_file()};x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if d['status']=='passed' else 1)
