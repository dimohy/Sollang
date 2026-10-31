from pathlib import Path
import sys,json,hashlib,time,struct
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'owner21697-original197-pair';CPP=B/'managed21688/compiler/Sollang.Compiler.exe';producerPath=B/'owner21695-source-emitter/result.json';producer=json.loads(producerPath.read_text());EMITTER=producerPath.parent/'emitter.exe';runnerPath=B/'sync21618-test-runner/result.json';runnerRecord=json.loads(runnerPath.read_text());RUNNER=runnerPath.parent/'compiler/Sollang.ExampleTests.dll';source=ROOT/'examples/regression/197-move-owned-struct-field.slg';oracle=ROOT/'examples/regression/expected/197-move-owned-struct-field.stdout.txt'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'];assert all(sha(p)==h for p,h in producer['inputHashes'].items());assert runnerRecord['status']=='passed' and runnerRecord['inputsStable'] and runnerRecord['processesStopped'];testSources=[Path(p) for p in runnerRecord['inputHashes'] if 'tests/Sollang.ExampleTests/' in p.replace('\\','/') and p.endswith('.cs')];assert testSources and all(sha(p)==runnerRecord['inputHashes'][str(p)] for p in testSources)
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),producerPath,EMITTER,*map(Path,producer['inputHashes']),runnerPath,RUNNER,*managed_runtime_inputs(RUNNER),*testSources,source,oracle,ROOT/'examples/regression/expected/197-move-owned-struct-field.llvm.contains.txt'];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,maximumCaseSeconds=180,claimsGoalComplete=False,scope='Focused original197 current CSharp and SLG: unchanged runtime, structural LLVM and drop assertions via source-matching reusable assertion verifier. Does not count final original14.')
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  for role in ['csharp','slg']:
   d=OUT/role;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));exe=d/'program.exe';ll=d/'program.ll'
   if role=='csharp':
    done=ex.run([str(CPP),'build',str(source),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0'],d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
    files=list((d/'.sollang-cache').glob('program.*.cgu'));assert len(files)==1;raw=files[0].read_bytes();words=struct.unpack('<'+'Q'*(len(raw)//8),raw);cursor=8;parts=[]
    for _ in range(words[5]):
     h=words[cursor:cursor+8];begin=cursor+8+h[4];parts.append(b''.join(v.to_bytes(8,'little') for v in words[begin:begin+h[6]])[:h[5]].decode());cursor=begin+h[6]
    ll.write_text(''.join(parts),encoding='utf-8',newline='\n')
   else:
    done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(d/'unused.semantic'),str(d/'unused-stage.semantic'),str(source)],d/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr;ll.write_text(done.stdout,encoding='utf-8',newline='\n')
    done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(d/'program.bc')],d/'assemble',timeout=budget());assert done.returncode==0,done.stderr
    done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],d/'link',timeout=budget());assert done.returncode==0,done.stderr
   done=ex.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==oracle.read_text(encoding='utf-8-sig'),done.stdout+done.stderr
   check=ex.run(['dotnet',str(RUNNER),'--verify-common-llvm',str(ll),'197-move-owned-struct-field','windows-x64',str(d/'llvm-assertions.json')],d/'llvm-assertions',timeout=budget());assert check.returncode==0,check.stdout+check.stderr
   result['cases'].append(dict(id=role,passed=True,stdout=done.stdout,llvmAssertions='passed'));result['completed']+=1;ex.save()
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
