from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'source21758-focused-module-pairs';CPP=B/'managed21747/compiler/Sollang.Compiler.exe';producerPath=B/'source21756-source-emitter/result.json';EMITTER=producerPath.parent/'emitter.exe';referencePath=B/'source21750-valid-module-sources/result.json';reference=json.loads(referencePath.read_text(encoding='utf-8-sig'));producer=json.loads(producerPath.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert producer['status']=='passed' and producer['inputsStable'] and producer['processesStopped'] and all(sha(p)==h for p,h in producer['inputHashes'].items())
assert reference['status']=='passed' and reference['completed']==reference['total']==5 and reference['inputsStable'] and reference['processesStopped'] and all(sha(p)==h for p,h in reference['inputHashes'].items())
rows={c['observation']['name']:c['observation'] for c in reference['cases']}
expected={n:(r['hash'],2,'true' if n=='case-distinct' else 'false') for n,r in rows.items() if 'reversed' in r}
expected.update({'mixed-case-reversed':expected['mixed-case'],'case-distinct-reversed':(rows['case-distinct']['hash'],2,'false'),'comments':(rows['comments']['hash'],1,'false'),'comments-changed':(rows['comments']['changed'],1,'false'),'module-group':(rows['comments']['hash'],1,'false'),'duplicate-path':'duplicate','empty-path':'empty','invalid-input':'invalid'})
manifest=ROOT/'scripts/probes/codegen-module-sources/sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s]
priorPath=B/'source21757-module-pairs/result.json';prior=json.loads(priorPath.read_text(encoding='utf-8-sig'));assert prior['status']!='passed' and prior['completed']==1 and prior['inputsStable'] and prior['processesStopped'];assert len(sources)==28 and all(str(p.resolve()) in prior['inputHashes'] and sha(p)==prior['inputHashes'][str(p.resolve())] for p in sources)
paths=[priorPath,Path(__file__),CPP,*managed_runtime_inputs(CPP),producerPath,EMITTER,referencePath,*map(Path,reference['inputHashes']),manifest,*sources,*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,scope='Focused 28-source dependency closure, unchanged probe and all11 oracles. Actual CSharp module metadata hashes matched by source adapter on current CSharp and current compiled SLG backends, plus grouping, stdlib classification and invalid-input controls; no production cache lookup/publication or platform filesystem claim.',claimsGoalComplete=False)
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
