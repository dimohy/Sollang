from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'type21788-parser-name-pairs';CPP=B/'managed21775/compiler/Sollang.Compiler.exe';producerPath=B/'roles21787-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';referencePath=B/'type21776-csharp-current/result.json';reference=json.loads(referencePath.read_text(encoding='utf-8-sig'));producer=json.loads(producerPath.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'] and all(sha(p)==h for p,h in producer['inputHashes'].items())
assert reference['status']=='passed' and reference['completed']==reference['total']==31 and reference['inputsStable'] and reference['processesStopped'] and all(sha(p)==h for p,h in reference['inputHashes'].items())
expected={c['observation']['name']:str(c['observation']['builtin']).lower() for c in reference['cases']}
manifest=ROOT/'scripts/probes/parser-type-names/sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),producerPath,EMITTER,referencePath,*map(Path,reference['inputHashes']),manifest,*sources,*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,scope='Shared parser builtin-name catalog: both current backends compare31 names against actual CSharp generated Parser.IsBuiltinTypeName. No live Native declaration fact/module-interface claim.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None
 try:
  for backend in ['csharp','slg']:
   d=OUT/backend;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));exe=d/'program.exe'
   if backend=='csharp':
    done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2500:]+done.stderr
   else:
    done=ex.run([str(EMITTER),'plain-windows',str(ROOT/'stdlib'),str(d/'unused.semantic'),str(d/'unused-stage.semantic'),*map(str,sources)],d/'emit',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2500:]+done.stderr
    ll=d/'program.ll';ll.write_text(done.stdout,encoding='utf-8',newline='\n')
    done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(d/'program.bc')],d/'assemble',timeout=budget());assert done.returncode==0,done.stderr
    done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),'-O0','-Wno-override-module','-o',str(exe),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],d/'link',timeout=budget());assert done.returncode==0,done.stderr
   done=ex.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
   actual=dict(line.split('=',1) for line in done.stdout.splitlines());assert len(actual)==len(expected),(actual,expected)
   for name,want in expected.items():
    text=','.join(map(str,want)) if isinstance(want,tuple) else want
    assert actual[name]==text,(backend,name,actual[name],text)
   result['cases'].append(dict(id=backend,passed=True,controls=len(expected),stdout=done.stdout));result['completed']+=1;ex.save()
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
