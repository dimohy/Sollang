from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'native-self16505';o.mkdir(exist_ok=False);sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
plan=b/'native-self16505-plan.json';p=read(plan);seed=b/'v16382/compiler-build01/compiler.exe';build=b/'v16382/compiler-build01/result.json';native=b/'epoch16466-native100/result.json';managed=b/'epoch16465-managed111/result.json';stdlib=b/'epoch16364-stdlib/result.json'
for path,count in [(native,100),(managed,111),(stdlib,1)]:
 d=read(path);assert d['status']=='passed' and d['completed']==d['total']==count and d['inputsStable'] and d['processesStopped'],path
assert len(p['CompilerSources'])==151 and len(p['StandardLibrarySources'])==144 and p['EmissionArguments'][:4]==['windows-stdlib',str(r/'stdlib'),'--jobs','4']
inputs=[Path(__file__),plan,seed,build,native,managed,stdlib,r/'scripts/verification_execution.py',r/'scripts/selfhost-stage-inputs.ps1',*map(Path,p['FingerprintPaths']),r/'.tools/llvm-22.1.8/bin/llvm-as.exe',r/'scripts/verify-llvm-direct-call-closure.ps1',r/'scripts/verify-selfhost-parallel-callback-llvm.ps1'];pins={str(x):sha(x) for x in inputs}
bd=read(build);assert bd['status']=='passed' and bd['compilerSha256']==sha(seed)
for path in p['CompilerSources']+p['StandardLibrarySources']:assert bd['inputHashesStart'][path]==bd['inputHashesEnd'][path]==sha(path)
d=dict(schemaVersion=1,status='running',completed=0,total=3,inputHashes=pins,cases=[],scope='One current Native self-emission of all151 compiler plus144 stdlib sources, then LLVM assembly and closure. Prepares actual next generation IR without creating a fourth compiler product. Original Stage oracle failures remain required; no Stage2/3 acceptance credit.',emissionBudgetSeconds=3600,compileSources=151,stdlibSources=144,jobs=4,seedCompilerSha256=sha(seed),claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 a=x.run([str(seed),*p['EmissionArguments']],o/'emission',timeout=3600);assert a.returncode==0 and not a.stderr.strip(),('NATIVE_SELF_EMISSION_FAILED',a.returncode,a.stderr[:1500]);d['completed']=1;d['cases'].append(dict(id='native-full-self-emission',status='passed',llvmSha256=sha(o/'emission.stdout')));x.save()
 a=x.run([str(r/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(o/'emission.stdout'),'-o',str(o/'compiler.bc')],o/'assembly',timeout=180);assert a.returncode==0 and not a.stderr.strip(),('NATIVE_SELF_LLVM_ASSEMBLY_FAILED',a.stderr[:1500]);d['completed']=2;d['cases'].append(dict(id='llvm-assembly',status='passed'));x.save()
 a=x.run(['pwsh','-NoProfile','-File',str(r/'scripts/verify-llvm-direct-call-closure.ps1'),'-LlvmPath',str(o/'emission.stdout')],o/'closure',timeout=180);assert a.returncode==0 and not a.stderr.strip(),('NATIVE_SELF_LLVM_CLOSURE_FAILED',a.stderr[:1500]);d.update(status='passed',completed=3);d['cases'].append(dict(id='llvm-call-closure',status='passed'))
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if d['status']=='passed' else 1)
