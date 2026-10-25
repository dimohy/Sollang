from pathlib import Path
import json,sys,hashlib,importlib.util
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_stdlib_source_preflight import validate
from completed_artifact_plan import initialize_output
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';old=b/'pattern13216-source';original=R(old/'result.json');oc=R(b/'pattern13216-contract.json');cases=oc['cases'][-6:];canonical=R(r/'scripts/contracts/typed-pattern-scope-coverage.json')['cases'];assert [z['id'] for z in cases]==[z['id'] for z in canonical]
managed=b/'pattern15034-managed6/result.json';mp=R(managed);assert mp['status']=='passed' and mp['completed']==mp['total']==6 and mp['inputsStable'] and mp['processesStopped']
for f,h in mp['inputHashes'].items():assert H(f)==h,f
stdlib=b/'bounded-reference14765-stdlib/result.json';validate(r,stdlib)
manifest=r/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';sources=[r/oc['producer']]+[r/line.strip() for line in manifest.read_text().splitlines() if line.strip()][1:];oldbuild=original['processes'][2]['command'];assert list(map(str,sources))==oldbuild[2:oldbuild.index('-o')]
compiler=b/'managed14487/compiler/Sollang.Compiler.exe';formatter=b/'v12432/compiler-build01/compiler.exe';harness=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe';out=b/'pattern15037-source6';retained=[b/n for n in ['v12432','v14562','v14775']];initialize_output(r,out,reusable_directories=retained);out.mkdir(exist_ok=False)
inputs=sources+[r/z['source'] for z in oc['cases']]+[manifest,managed,stdlib,b/'pattern13216-contract.json',old/'result.json',b/'pattern15035-source-comparison.json',Path(__file__),formatter]+list(compiler.parent.glob('Sollang.Compiler.*'))+list(harness.parent.glob('SemanticPreflight.*'))+list((r/'stdlib').rglob('*.slg'))
pins={str(p):H(p) for p in inputs};stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
record=dict(schemaVersion=1,status='running',mode='managed-compiled-current-slg-source',scope='Exact original enum6 selected from original composite23; original producer source/151 source order/default build jobs4/emission180/assembly120/link120/runtime10 retained. Other array17 not executed or credited. Current CSharp6 and current full stdlib144 checked first.',completed=0,total=6,inputHashes=pins,cases=[],producerBuildCount=0,producerBuildLimitThisRequalification=1,historicalSourceComposite= str(old/'result.json'),originalOracleAndProfilesUnchanged=True,claimsGoalComplete=False)
v=VerificationExecution(r,out,record,stable,H);error=None;norm=lambda p:Path(p).read_bytes().replace(b'\r\n',b'\n')
try:
 a=v.run([str(formatter),'format','--check',str(sources[0])],out/'format',timeout=30);assert a.returncode==0 and not a.stderr
 a=v.run([str(harness),str(compiler.with_suffix('.dll')),*map(str,sources)],out/'frontend',timeout=60);assert a.returncode==0 and not a.stderr;front=json.loads(a.stdout);assert front['warnings']==0 and front['codegenInvoked'] is False and front['sourceCount']==151
 exe=out/'producer.exe';command=[str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','--jobs','4','--llvm',str(r/'.tools/llvm-22.1.8')];expected=[s.replace(str(b/'managed13056/compiler'),str(compiler.parent)).replace(str(old),str(out)) for s in oldbuild];assert command==expected
 record['producerBuildCount']=1;v.save();a=v.run(command,out/'build',timeout=180);assert a.returncode==0 and not a.stderr;record['producerSha256']=H(exe)
 for case in cases:
  validate(r,stdlib);folder=out/case['id'];folder.mkdir();row=dict(id=case['id'],status='running',passed=False);record['cases'].append(row);v.save();a=v.run([str(exe),case['source'],'windows'],folder/'emit',timeout=180);row['emissionExit']=a.returncode;assert a.returncode==case['exit'] and not a.stderr
  if case['exit']==1:
   assert a.stdout.strip()==case['stderr'] and 'target triple =' not in a.stdout;assert norm(folder/'emit.stdout')==norm(old/case['id']/'emit.stdout');assert not list(folder.glob('*.ll')) and not list(folder.glob('*.bc')) and not list(folder.glob('*.exe'));row['admissionRejected']=True
  else:
   llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['emittedLlvmSha256']=H(llvm)
   a=v.run([str(r/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble',timeout=120);row['assemblyExit']=a.returncode;assert a.returncode==0 and not a.stderr
   native=folder/'emitted.exe';a=v.run([str(r/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O0','-o',str(native),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'link',timeout=120);row['nativeLinkExit']=a.returncode;assert a.returncode==0 and not a.stderr
   a=v.run([str(native)],folder/'run',timeout=10);row.update(nativeRunExit=a.returncode,nativeRunStdout=a.stdout,nativeRunStderr=a.stderr);assert a.returncode==0 and not a.stderr and a.stdout.replace('\r\n','\n')==case['runtimeStdout'];assert norm(folder/'run.stdout')==norm(old/case['id']/'run.stdout') and norm(folder/'run.stderr')==norm(old/case['id']/'run.stderr')
  row.update(status='passed',passed=True);record['completed']+=1;v.save();print(case['id']+': PASS',flush=True)
 record['status']='passed'
except BaseException as caught:error=caught
finally:v.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}));sys.exit(0 if record['status']=='passed' else 1)
