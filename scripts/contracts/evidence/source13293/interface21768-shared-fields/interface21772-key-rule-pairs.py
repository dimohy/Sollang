from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'interface21772-key-rule-pairs';CPP=B/'managed21763/compiler/Sollang.Compiler.exe';producerPath=B/'interface21771-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();producer=json.loads(producerPath.read_text(encoding='utf-8-sig'))
assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'] and all(sha(p)==h for p,h in producer['inputHashes'].items())
sets=[('interface','codegen-interface-key-rules','interface-rule-vectors',4),('legacy','codegen-cache-key-rules','key-rule-vectors',13)];manifests=[ROOT/'scripts/probes'/folder/'sources.txt' for _,folder,_,_ in sets];allSources=[ROOT/line for m in manifests for line in m.read_text(encoding='utf-8-sig').splitlines() if line]
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),producerPath,EMITTER,*manifests,*allSources,ROOT/'scripts/probes/codegen-identity/Limits.cs',ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj',*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};generated={};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=4,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Current CSharp and current compiled SLG hash four new compiled interface plans and original nine plus changed/empty/repeated plans; preserve missing/duplicate input rejection. Complete live Native declaration discovery and production cache connection remain pending.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()) and all(sha(p)==h for p,h in generated.items()),sha);err=None
 try:
  done=ex.run(['dotnet','build','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false',str(ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj'),'-c','Release','-o',str(OUT/'harness'),'--artifacts-path',str(OUT/'dotnet-artifacts')],OUT/'harness-build',timeout=180);assert done.returncode==0,done.stdout+done.stderr
  for name,folder,mode,count in sets:
   vector=OUT/(name+'-vectors');done=ex.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP.with_suffix('.dll')),str(vector),mode],OUT/(name+'-vectors'),timeout=60);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
   rows=[json.loads(line) for line in done.stdout.splitlines()];assert len(rows)==count;expected=''.join(row['name']+'='+str(row['hash'])+'\n' for row in rows)
   sources=[ROOT/line for line in (ROOT/'scripts/probes'/folder/'sources.txt').read_text(encoding='utf-8-sig').splitlines() if line]
   if name=='legacy':
    expected+='missing=ok\nduplicate=ok\n';smoke=vector/'key-rule-smoke.slg';sources.append(smoke);generated[str(smoke)]=sha(smoke)
   expectedPath=OUT/(name+'-expected.stdout.txt');expectedPath.write_text(expected,encoding='utf-8',newline='\n');generated[str(expectedPath)]=sha(expectedPath);result['generatedInputHashes']=generated;ex.save()
   for backend in ['csharp','slg']:
    d=OUT/(name+'-'+backend);d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));exe=d/'program.exe'
    if backend=='csharp':
     done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0'],d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
    else:
     done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(d/'unused.semantic'),str(d/'unused-stage.semantic'),*map(str,sources)],d/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
     ll=d/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n')
     done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(d/'program.bc')],d/'assemble',timeout=budget());assert done.returncode==0,done.stderr
     done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],d/'link',timeout=budget());assert done.returncode==0,done.stderr
    done=ex.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout+done.stderr
    result['cases'].append(dict(id=name+'-'+backend,passed=True,keyHashes=count,negativeControls=2 if name=='legacy' else 0,stdout=done.stdout));result['completed']+=1;ex.save()
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
